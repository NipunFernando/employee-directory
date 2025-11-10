#!/bin/bash
set -e

echo "=========================================="
echo "DAST - Backend Employee Directory"
echo "=========================================="
echo "Started: $(date)"
echo ""

# Config
BACKEND_URL="${GO_BACKEND_URL}"
TEST_KEY="${GO_BACKEND_TOKEN}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"

# Validate
if [ -z "$BACKEND_URL" ] || [ -z "$TEST_KEY" ]; then
    echo "ERROR: Missing GO_BACKEND_URL or GO_BACKEND_TOKEN"
    exit 1
fi

echo "Target: $BACKEND_URL"
echo ""

# Check backend
echo "Checking backend..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Test-Key: $TEST_KEY" \
    "$BACKEND_URL/employees" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" != "200" ]; then
    echo "❌ Backend not accessible (HTTP $HTTP_CODE)"
    exit 1
fi

echo "✅ Backend accessible"
echo ""

# Start ZAP
echo "Starting ZAP..."
ZAP_PORT=8090

zap.sh \
    -daemon \
    -port $ZAP_PORT \
    -host 0.0.0.0 \
    -config api.disablekey=true \
    > /dev/null 2>&1 &

ZAP_PID=$!

# Wait for ZAP
echo "Waiting for ZAP (30 seconds)..."
sleep 30

if ! curl -s http://localhost:$ZAP_PORT/JSON/core/view/version/ > /dev/null 2>&1; then
    echo "❌ ZAP failed to start"
    kill $ZAP_PID 2>/dev/null || true
    exit 1
fi

ZAP_VERSION=$(curl -s http://localhost:$ZAP_PORT/JSON/core/view/version/ | jq -r '.version' 2>/dev/null || echo "unknown")
echo "✅ ZAP started (version: $ZAP_VERSION)"
echo ""

# Configure authentication
echo "Configuring authentication..."
curl -s "http://localhost:$ZAP_PORT/JSON/replacer/action/addRule/" \
    --data-urlencode "description=Add Test-Key" \
    --data-urlencode "enabled=true" \
    --data-urlencode "matchType=REQ_HEADER" \
    --data-urlencode "matchString=Test-Key" \
    --data-urlencode "replacement=$TEST_KEY" \
    > /dev/null 2>&1

echo "✅ Authentication configured"
echo ""

# Spider
echo "=========================================="
echo "Spidering target..."
echo "=========================================="

SPIDER_ID=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/action/scan/" \
    --data-urlencode "url=$BACKEND_URL" \
    --data-urlencode "maxChildren=20" \
    | jq -r '.scan' 2>/dev/null || echo "0")

echo "Spider ID: $SPIDER_ID"

# Wait for spider
for i in {1..24}; do
    STATUS=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/view/status/?scanId=$SPIDER_ID" \
        | jq -r '.status' 2>/dev/null || echo "0")
    
    echo "Spider progress: $STATUS%"
    
    if [ "$STATUS" = "100" ]; then
        break
    fi
    
    sleep 5
done

URL_COUNT=$(curl -s "http://localhost:$ZAP_PORT/JSON/spider/view/fullResults/?scanId=$SPIDER_ID" \
    | jq '.urlsInScope | length' 2>/dev/null || echo "0")

echo "✅ Spider complete - Found $URL_COUNT URLs"
echo ""

# Active scan
echo "=========================================="
echo "Starting security scan..."
echo "=========================================="

SCAN_ID=$(curl -s "http://localhost:$ZAP_PORT/JSON/ascan/action/scan/" \
    --data-urlencode "url=$BACKEND_URL" \
    --data-urlencode "recurse=true" \
    | jq -r '.scan' 2>/dev/null || echo "0")

echo "Scan ID: $SCAN_ID"

# Wait for scan
for i in {1..96}; do
    STATUS=$(curl -s "http://localhost:$ZAP_PORT/JSON/ascan/view/status/?scanId=$SCAN_ID" \
        | jq -r '.status' 2>/dev/null || echo "0")
    
    if [ $((i % 4)) -eq 0 ]; then
        echo "Scan progress: $STATUS%"
    fi
    
    if [ "$STATUS" = "100" ]; then
        break
    fi
    
    sleep 5
done

echo "✅ Scan complete"
echo ""

# Get results - SAVE TO /tmp WITH FULL PATH
echo "=========================================="
echo "Fetching scan results..."
echo "=========================================="

ALERTS_FILE="/tmp/alerts-$$.json"
curl -s "http://localhost:$ZAP_PORT/JSON/alert/view/alerts/" > "$ALERTS_FILE"

# Verify file was created
if [ ! -f "$ALERTS_FILE" ]; then
    echo "❌ Failed to fetch alerts"
    kill $ZAP_PID 2>/dev/null || true
    exit 1
fi

echo ""

# Parse results - USE FULL PATH
echo "=========================================="
echo "SCAN RESULTS"
echo "=========================================="

python3 << PYCODE
import json
import sys

try:
    with open("$ALERTS_FILE") as f:
        data = json.load(f)

    alerts = data.get("alerts", [])

    high = sum(1 for a in alerts if a.get("risk") == "High")
    medium = sum(1 for a in alerts if a.get("risk") == "Medium")
    low = sum(1 for a in alerts if a.get("risk") == "Low")
    info = sum(1 for a in alerts if a.get("risk") == "Informational")

    print(f"\nTotal Alerts: {len(alerts)}")
    print(f"🔴 High:   {high}")
    print(f"🟠 Medium: {medium}")
    print(f"🟡 Low:    {low}")
    print(f"ℹ️  Info:   {info}")
    print("")

    if high > 0:
        print("=" * 60)
        print("HIGH RISK VULNERABILITIES:")
        print("=" * 60)
        for a in alerts:
            if a.get("risk") == "High":
                print(f"\n  • {a.get('name')}")
                desc = a.get('description', '')[:150]
                print(f"    {desc}...")
        print("")

    if medium > 0 and medium <= 10:
        print("=" * 60)
        print("MEDIUM RISK VULNERABILITIES:")
        print("=" * 60)
        for a in alerts:
            if a.get("risk") == "Medium":
                print(f"  • {a.get('name')}")
        print("")

    # Save summary
    summary = {"high": high, "medium": medium, "low": low, "info": info}
    with open("/tmp/summary-$$.json", "w") as f:
        json.dump(summary, f)

    sys.exit(1 if high > 0 else 0)

except Exception as e:
    print(f"ERROR: Failed to parse results: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(2)
PYCODE

EXIT_CODE=$?

# Slack notification
SUMMARY_FILE="/tmp/summary-$$.json"
if [ -n "$SLACK_WEBHOOK" ] && [ -f "$SUMMARY_FILE" ]; then
    HIGH=$(jq -r '.high' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    MEDIUM=$(jq -r '.medium' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    LOW=$(jq -r '.low' "$SUMMARY_FILE" 2>/dev/null || echo "0")
    
    if [ "$HIGH" -gt 0 ]; then
        STATUS="🚨 FAILED - $HIGH High Risk Found"
    else
        STATUS="✅ PASSED - No High Risk Issues"
    fi
    
    MESSAGE="🛡️ *DAST - Backend Employee*\n\n*Status:* $STATUS\n\n*Results:*\n  High: $HIGH\n  Medium: $MEDIUM\n  Low: $LOW\n\n*Target:* Backend Employee API\n*Date:* $(date '+%Y-%m-%d %H:%M UTC')"
    
    curl -s -X POST "$SLACK_WEBHOOK" \
        -H 'Content-Type: application/json' \
        -d "{\"text\":\"$MESSAGE\"}" || true
fi

# Cleanup
echo ""
echo "Cleaning up..."
curl -s "http://localhost:$ZAP_PORT/JSON/core/action/shutdown/" > /dev/null 2>&1 || true
sleep 2
kill $ZAP_PID 2>/dev/null || true

# Remove temp files
rm -f "$ALERTS_FILE" "$SUMMARY_FILE" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Scan completed: $(date)"
echo "=========================================="
echo ""

if [ $EXIT_CODE -eq 1 ]; then
    echo "STATUS: ❌ FAILED (High-risk vulnerabilities found)"
elif [ $EXIT_CODE -eq 2 ]; then
    echo "STATUS: ⚠️ ERROR (Failed to parse results)"
else
    echo "STATUS: ✅ PASSED (No high-risk vulnerabilities)"
fi

exit $EXIT_CODE