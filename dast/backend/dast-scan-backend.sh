#!/bin/bash
set -e

echo "=========================================="
echo "DAST - Backend Employee Directory Scanner"
echo "=========================================="
echo "Scan started: $(date)"
echo ""

# Configuration from environment variables
BACKEND_URL="${GO_BACKEND_URL}"
TEST_KEY="${GO_BACKEND_TOKEN}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
SCAN_TIMEOUT="${SCAN_TIMEOUT_MINUTES:-10}"

# Validate required variables
if [ -z "$BACKEND_URL" ]; then
    echo "ERROR: GO_BACKEND_URL is required"
    echo "Example: https://[uuid]-dev.e1-us-east-azure.choreoapis.dev/[org]/[service]/v1.0"
    exit 1
fi

if [ -z "$TEST_KEY" ]; then
    echo "ERROR: GO_BACKEND_TOKEN is required"
    exit 1
fi

echo "Configuration:"
echo "  Target URL: $BACKEND_URL"
echo "  Timeout: $SCAN_TIMEOUT minutes"
echo ""

# Determine API endpoint to test
# Try multiple possible paths
API_ENDPOINTS=(
    "${BACKEND_URL%/}/employees"
    "${BACKEND_URL%/}/api/employees"
    "${BACKEND_URL%/}"
)

# Check backend accessibility
echo "Checking backend accessibility..."
BACKEND_ACCESSIBLE=false

for ENDPOINT in "${API_ENDPOINTS[@]}"; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        -H "Test-Key: $TEST_KEY" \
        -H "accept: */*" \
        "$ENDPOINT" 2>/dev/null || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "401" ]; then
        echo "✅ Backend accessible at: $ENDPOINT (HTTP $HTTP_CODE)"
        BACKEND_ACCESSIBLE=true
        break
    fi
done

if [ "$BACKEND_ACCESSIBLE" = false ]; then
    echo "❌ Backend not accessible. Tried:"
    for ENDPOINT in "${API_ENDPOINTS[@]}"; do
        echo "  - $ENDPOINT"
    done
    
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -s -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\":warning: *DAST Backend Employee Directory* - Backend not accessible. Scan aborted.\"}" \
            > /dev/null 2>&1 || true
    fi
    
    exit 1
fi

echo ""

# Setup work directory
WORK_DIR="/tmp/dast-$$"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

# Set ZAP_HOME and HOME to writable directories
export ZAP_HOME="$WORK_DIR/.zap"
export HOME="$WORK_DIR"
mkdir -p "$ZAP_HOME"

# Cleanup function
cleanup() {
    echo ""
    echo "Cleaning up..."
    if [ -n "$ZAP_PID" ]; then
        curl -s "http://localhost:$ZAP_PORT/JSON/core/action/shutdown/" > /dev/null 2>&1 || true
        kill $ZAP_PID 2>/dev/null || true
        sleep 2
        kill -9 $ZAP_PID 2>/dev/null || true
    fi
    rm -rf "$WORK_DIR" 2>/dev/null || true
}
trap cleanup EXIT

# Start ZAP daemon
echo "Starting ZAP..."
echo "ZAP_HOME: $ZAP_HOME"
ZAP_PORT=8090
zap.sh -daemon -port $ZAP_PORT \
    -config api.disablekey=true \
    -config database.recoverylog=false \
    > "$WORK_DIR/zap-startup.log" 2>&1 &
ZAP_PID=$!

# Wait for ZAP to be ready (max 60 seconds)
echo "Waiting for ZAP to start..."
for i in {1..12}; do
    sleep 5
    if curl -s "http://localhost:$ZAP_PORT/JSON/core/view/version/" > /dev/null 2>&1; then
        ZAP_VERSION=$(curl -s "http://localhost:$ZAP_PORT/JSON/core/view/version/" | jq -r '.version' 2>/dev/null || echo "unknown")
        echo "✅ ZAP started (version: $ZAP_VERSION)"
        break
    fi
    if [ $i -eq 12 ]; then
        echo "❌ ZAP failed to start after 60 seconds"
        cat "$WORK_DIR/zap-startup.log" 2>/dev/null || true
        exit 1
    fi
done

echo ""

# Configure authentication header using Replacer add-on
echo "Configuring authentication (Test-Key header)..."
REPLACER_RESPONSE=$(curl -s "http://localhost:$ZAP_PORT/JSON/replacer/action/addRule/" \
    --data-urlencode "description=Add Test-Key Authentication" \
    --data-urlencode "enabled=true" \
    --data-urlencode "matchType=REQ_HEADER" \
    --data-urlencode "matchString=Test-Key" \
    --data-urlencode "regex=false" \
    --data-urlencode "replacement=$TEST_KEY")

if echo "$REPLACER_RESPONSE" | jq -e '.Result' > /dev/null 2>&1; then
    echo "✅ Authentication configured"
else
    echo "⚠️  Warning: Authentication configuration may have failed"
    echo "Response: $REPLACER_RESPONSE"
fi

echo ""

# Spider the target
echo "=========================================="
echo "Spidering target..."
echo "=========================================="
SPIDER_RESPONSE=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/action/scan/" \
    --data-urlencode "url=$BACKEND_URL" \
    --data-urlencode "maxChildren=50" \
    --data-urlencode "recurse=true")

SPIDER_ID=$(echo "$SPIDER_RESPONSE" | jq -r '.scan' 2>/dev/null || echo "")

if [ -z "$SPIDER_ID" ] || [ "$SPIDER_ID" = "null" ]; then
    echo "❌ Failed to start spider"
    echo "Response: $SPIDER_RESPONSE"
    exit 1
fi

echo "Spider ID: $SPIDER_ID"

# Wait for spider to complete (max 3 minutes)
SPIDER_TIMEOUT=36
for i in $(seq 1 $SPIDER_TIMEOUT); do
    sleep 5
    STATUS_RESPONSE=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/view/status/?scanId=$SPIDER_ID")
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status' 2>/dev/null || echo "0")
    
    if [ "$STATUS" != "null" ] && [ -n "$STATUS" ]; then
        echo "Spider progress: ${STATUS}%"
        
        if [ "$STATUS" = "100" ]; then
            break
        fi
    fi
    
    if [ $i -eq $SPIDER_TIMEOUT ]; then
        echo "⚠️  Spider timeout reached, continuing with scan..."
        break
    fi
done

# Get spider results
URLS_FOUND=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/view/results/?scanId=$SPIDER_ID" | jq -r '.results | length' 2>/dev/null || echo "0")
echo "✅ Spider complete - Found $URLS_FOUND URLs"
echo ""

# Active security scan
echo "=========================================="
echo "Starting security scan..."
echo "=========================================="
SCAN_RESPONSE=$(curl -s "http://localhost:$ZAP_PORT/JSON/ascan/action/scan/" \
    --data-urlencode "url=$BACKEND_URL" \
    --data-urlencode "recurse=true" \
    --data-urlencode "inScopeOnly=false")

SCAN_ID=$(echo "$SCAN_RESPONSE" | jq -r '.scan' 2>/dev/null || echo "")

if [ -z "$SCAN_ID" ] || [ "$SCAN_ID" = "null" ]; then
    echo "❌ Failed to start active scan"
    echo "Response: $SCAN_RESPONSE"
    exit 1
fi

echo "Scan ID: $SCAN_ID"

# Wait for scan to complete (based on timeout)
SCAN_TIMEOUT_SECONDS=$((SCAN_TIMEOUT * 60))
SCAN_TIMEOUT_ITERATIONS=$((SCAN_TIMEOUT_SECONDS / 5))
if [ $SCAN_TIMEOUT_ITERATIONS -gt 120 ]; then
    SCAN_TIMEOUT_ITERATIONS=120  # Max 10 minutes
fi

for i in $(seq 1 $SCAN_TIMEOUT_ITERATIONS); do
    sleep 5
    STATUS_RESPONSE=$(curl -s "http://localhost:$ZAP_PORT/JSON/ascan/view/status/?scanId=$SCAN_ID")
    STATUS=$(echo "$STATUS_RESPONSE" | jq -r '.status' 2>/dev/null || echo "0")
    
    if [ "$STATUS" != "null" ] && [ -n "$STATUS" ]; then
        echo "Scan progress: ${STATUS}%"
        
        if [ "$STATUS" = "100" ]; then
            break
        fi
    fi
    
    if [ $i -eq $SCAN_TIMEOUT_ITERATIONS ]; then
        echo "⚠️  Scan timeout reached, fetching partial results..."
        break
    fi
done

echo "✅ Scan complete"
echo ""

# Get scan results
echo "=========================================="
echo "Fetching scan results..."
echo "=========================================="
curl -s "http://localhost:$ZAP_PORT/JSON/alert/view/alerts/?baseurl=$BACKEND_URL" > "$WORK_DIR/alerts.json"

# Parse and display results
echo ""
echo "=========================================="
echo "SCAN RESULTS"
echo "=========================================="

python3 << 'PYCODE'
import json
import sys
import os

alerts_file = os.path.join(os.environ.get('WORK_DIR', '/tmp'), 'alerts.json')

try:
    with open(alerts_file, 'r') as f:
        data = json.load(f)
    
    alerts = data.get("alerts", [])
    
    # Count by risk level
    high = sum(1 for a in alerts if a.get("risk") == "High")
    medium = sum(1 for a in alerts if a.get("risk") == "Medium")
    low = sum(1 for a in alerts if a.get("risk") == "Low")
    info = sum(1 for a in alerts if a.get("risk") == "Informational")
    
    total = len(alerts)
    
    print(f"\nVulnerability Summary:")
    print(f"  Total Alerts: {total}")
    print(f"  🔴 High Risk:    {high}")
    print(f"  🟠 Medium Risk:  {medium}")
    print(f"  🟡 Low Risk:     {low}")
    print(f"  ℹ️  Info:         {info}")
    print("")
    
    # Display high-risk vulnerabilities
    if high > 0:
        print("=" * 60)
        print("HIGH RISK VULNERABILITIES:")
        print("=" * 60)
        for a in alerts:
            if a.get("risk") == "High":
                name = a.get("name", "Unknown")
                desc = a.get("description", "No description")[:200]
                instances = len(a.get("instances", []))
                
                print(f"\n[!] {name}")
                print(f"    Description: {desc}...")
                print(f"    Instances: {instances}")
        print("")
    
    # Display medium-risk vulnerabilities (top 5)
    if medium > 0:
        print("=" * 60)
        print("MEDIUM RISK VULNERABILITIES (top 5):")
        print("=" * 60)
        count = 0
        for a in alerts:
            if a.get("risk") == "Medium" and count < 5:
                name = a.get("name", "Unknown")
                instances = len(a.get("instances", []))
                print(f"  [{count+1}] {name} ({instances} instance{'s' if instances != 1 else ''})")
                count += 1
        if medium > 5:
            print(f"  ... and {medium - 5} more")
        print("")
    
    # Save summary
    summary = {
        "total": total,
        "high": high,
        "medium": medium,
        "low": low,
        "info": info,
        "high_details": []
    }
    
    # Extract high vulnerability names for Slack
    for a in alerts:
        if a.get("risk") == "High":
            summary["high_details"].append({
                "name": a.get("name", "Unknown"),
                "count": len(a.get("instances", []))
            })
    
    summary_file = os.path.join(os.environ.get('WORK_DIR', '/tmp'), 'summary.json')
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)
    
    # Print summary for logs
    print("=" * 60)
    print("SUMMARY (for logs and Slack):")
    print("=" * 60)
    print(json.dumps(summary, indent=2))
    print("=" * 60)
    
    # Exit with error if high-risk vulnerabilities found
    sys.exit(1 if high > 0 else 0)
    
except Exception as e:
    print(f"ERROR: Failed to parse results: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc()
    sys.exit(2)
PYCODE

SCAN_EXIT_CODE=$?

# Display summary file
echo ""
echo "=========================================="
echo "Summary File Content"
echo "=========================================="
if [ -f "$WORK_DIR/summary.json" ]; then
    cat "$WORK_DIR/summary.json"
    echo ""
else
    echo "WARNING: Summary file not generated"
    echo ""
fi

# Send Slack notification
if [ -n "$SLACK_WEBHOOK" ] && [ -f "$WORK_DIR/summary.json" ]; then
    echo "Sending Slack notification..."
    
    SUMMARY=$(cat "$WORK_DIR/summary.json")
    HIGH=$(echo "$SUMMARY" | jq -r '.high')
    MEDIUM=$(echo "$SUMMARY" | jq -r '.medium')
    LOW=$(echo "$SUMMARY" | jq -r '.low')
    TOTAL=$(echo "$SUMMARY" | jq -r '.total')
    
    # Determine status and emoji
    if [ "$HIGH" -gt 0 ]; then
        EMOJI=":rotating_light:"
        STATUS="FAILED - High Risk Vulnerabilities Found"
        
        # Get high vulnerability names
        HIGH_DETAILS=$(echo "$SUMMARY" | jq -r '.high_details[] | "  • \(.name) (\(.count) instance\(if .count > 1 then "s" else "" end))"' | head -n 3)
        
        MESSAGE="$EMOJI *DAST - Backend Employee Directory*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n\n*Results:*\n  Total: $TOTAL\n  :red_circle: High: $HIGH\n  :large_orange_diamond: Medium: $MEDIUM\n  :white_circle: Low: $LOW\n\n*High Risk Issues:*\n$HIGH_DETAILS\n\n*Target:* Backend Employee API\n*URL:* \`$BACKEND_URL\`\n*Action Required:* Review and fix high-risk vulnerabilities"
    elif [ "$MEDIUM" -gt 5 ]; then
        EMOJI=":warning:"
        STATUS="WARNING - Multiple Medium Risk Issues"
        
        MESSAGE="$EMOJI *DAST - Backend Employee Directory*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n\n*Results:*\n  Total: $TOTAL\n  :white_circle: High: $HIGH\n  :large_orange_diamond: Medium: $MEDIUM\n  :white_circle: Low: $LOW\n\n*Target:* Backend Employee API\n*URL:* \`$BACKEND_URL\`\n*Recommendation:* Review medium-risk findings"
    else
        EMOJI=":shield:"
        STATUS="PASSED"
        
        MESSAGE="$EMOJI *DAST - Backend Employee Directory*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n\n*Results:*\n  Total: $TOTAL\n  :white_check_mark: High: $HIGH\n  :white_circle: Medium: $MEDIUM\n  :white_circle: Low: $LOW\n\n*Target:* Backend Employee API\n*URL:* \`$BACKEND_URL\`\n*Security Status:* No high-risk vulnerabilities detected"
    fi
    
    curl -s -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"$MESSAGE\"}" \
        > /dev/null 2>&1 || echo "Failed to send Slack notification"
fi

echo ""
echo "=========================================="
echo "Scan completed: $(date)"
echo "=========================================="
echo ""

if [ $SCAN_EXIT_CODE -eq 1 ]; then
    echo "STATUS: FAILED (High-risk vulnerabilities found)"
elif [ $SCAN_EXIT_CODE -eq 2 ]; then
    echo "STATUS: ERROR (Scan parsing failed)"
else
    echo "STATUS: PASSED (No high-risk vulnerabilities)"
fi

exit $SCAN_EXIT_CODE
