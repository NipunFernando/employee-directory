#!/bin/bash
set -e

echo "=========================================="
echo "DAST - React Frontend Scanner"
echo "=========================================="
echo "Scan started: $(date)"
echo ""

# Configuration from environment variables
TARGET_URL="${REACT_FRONTEND_URL}"
SESSION_COOKIE="${REACT_SESSION_COOKIE}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
SCAN_TIMEOUT="${SCAN_TIMEOUT_MINUTES:-15}"
SCAN_TYPE="${SCAN_TYPE:-baseline}"  # baseline or full

# Validate required variables
if [ -z "$TARGET_URL" ]; then
    echo "ERROR: REACT_FRONTEND_URL is required"
    exit 1
fi

echo "Configuration:"
echo "  Target URL: $TARGET_URL"
echo "  Timeout: $SCAN_TIMEOUT minutes"
echo "  Scan Type: $SCAN_TYPE"
echo "  Authenticated: $([ -n "$SESSION_COOKIE" ] && echo 'Yes' || echo 'No')"
echo ""

REPORT_DIR="/zap/wrk/reports"
mkdir -p "$REPORT_DIR"

# ============================================
# Check Frontend Availability
# ============================================
echo "Checking React Frontend availability..."

MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$TARGET_URL" || echo "000")
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "301" ] || [ "$HTTP_CODE" = "302" ]; then
        echo "React Frontend is accessible (HTTP $HTTP_CODE)"
        break
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES - HTTP $HTTP_CODE - waiting 10s..."
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: React Frontend is not accessible after $MAX_RETRIES attempts"
    
    # Send failure notification
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d '{"text":":warning: *DAST React Frontend* - Service not accessible. Scan aborted."}' \
            2>/dev/null || true
    fi
    
    exit 1
fi

echo ""

# ============================================
# Setup Authentication (if session cookie provided)
# ============================================
if [ -n "$SESSION_COOKIE" ]; then
    echo "Configuring authenticated scan..."
    
    cat > /zap/wrk/add-session-cookie.js << 'EOF'
function sendingRequest(msg, initiator, helper) {
    var sessionCookie = org.parosproxy.paros.model.Model.getSingleton()
                        .getOptionsParam().getConfig().getString("session.cookie");
    
    if (sessionCookie) {
        msg.getRequestHeader().setHeader("Cookie", sessionCookie);
    }
}

function responseReceived(msg, initiator, helper) {
    // Nothing to do
}
EOF
    
    ZAP_OPTIONS="-config session.cookie=$SESSION_COOKIE -script /zap/wrk/add-session-cookie.js"
    echo "Authentication configured with session cookie"
else
    echo "Running unauthenticated scan (no session cookie provided)"
    ZAP_OPTIONS=""
fi

echo ""

# ============================================
# Run ZAP Scan
# ============================================
echo "=========================================="
echo "Starting ZAP $SCAN_TYPE Scan"
echo "=========================================="

if [ "$SCAN_TYPE" = "full" ]; then
    # Full scan (more comprehensive but slower)
    if [ -n "$ZAP_OPTIONS" ]; then
        zap-full-scan.py \
            -t "$TARGET_URL" \
            -z "$ZAP_OPTIONS" \
            -J "$REPORT_DIR/react-frontend-zap.json" \
            -r "$REPORT_DIR/react-frontend-zap.html" \
            -w "$REPORT_DIR/react-frontend-zap.md" \
            -x "$REPORT_DIR/react-frontend-zap.xml" \
            -m "$SCAN_TIMEOUT" \
            -I || true
    else
        zap-full-scan.py \
            -t "$TARGET_URL" \
            -J "$REPORT_DIR/react-frontend-zap.json" \
            -r "$REPORT_DIR/react-frontend-zap.html" \
            -w "$REPORT_DIR/react-frontend-zap.md" \
            -x "$REPORT_DIR/react-frontend-zap.xml" \
            -m "$SCAN_TIMEOUT" \
            -I || true
    fi
else
    # Baseline scan (faster, passive checks)
    if [ -n "$ZAP_OPTIONS" ]; then
        zap-baseline.py \
            -t "$TARGET_URL" \
            -z "$ZAP_OPTIONS" \
            -J "$REPORT_DIR/react-frontend-zap.json" \
            -r "$REPORT_DIR/react-frontend-zap.html" \
            -w "$REPORT_DIR/react-frontend-zap.md" \
            -x "$REPORT_DIR/react-frontend-zap.xml" \
            -m "$SCAN_TIMEOUT" \
            -I || true
    else
        zap-baseline.py \
            -t "$TARGET_URL" \
            -J "$REPORT_DIR/react-frontend-zap.json" \
            -r "$REPORT_DIR/react-frontend-zap.html" \
            -w "$REPORT_DIR/react-frontend-zap.md" \
            -x "$REPORT_DIR/react-frontend-zap.xml" \
            -m "$SCAN_TIMEOUT" \
            -I || true
    fi
fi

echo ""
echo "ZAP scan completed"
echo ""

# ============================================
# Parse and Display Results
# ============================================
echo "=========================================="
echo "Scan Results"
echo "=========================================="

if [ ! -f "$REPORT_DIR/react-frontend-zap.json" ]; then
    echo "ERROR: Scan report not generated"
    exit 1
fi

# Parse results with Python
python3 << 'PYCODE'
import json
import sys

report_file = "/zap/wrk/reports/react-frontend-zap.json"

try:
    with open(report_file, "r") as f:
        data = json.load(f)
    
    alerts = []
    for site in data.get("site", []):
        alerts.extend(site.get("alerts", []))
    
    # Count by severity
    high = sum(1 for a in alerts if a.get("riskcode") == "3")
    medium = sum(1 for a in alerts if a.get("riskcode") == "2")
    low = sum(1 for a in alerts if a.get("riskcode") == "1")
    info = sum(1 for a in alerts if a.get("riskcode") == "0")
    
    total = high + medium + low + info
    
    print(f"\nVulnerability Summary:")
    print(f"  Total Alerts: {total}")
    print(f"  High Risk:    {high}")
    print(f"  Medium Risk:  {medium}")
    print(f"  Low Risk:     {low}")
    print(f"  Info:         {info}")
    print("")
    
    # Display high-risk vulnerabilities
    if high > 0:
        print("HIGH RISK VULNERABILITIES:")
        for a in alerts:
            if a.get("riskcode") == "3":
                name = a.get("name", "Unknown")
                desc = a.get("desc", "No description")[:200]
                url = a.get("url", "N/A")
                print(f"\n  - {name}")
                print(f"    URL: {url}")
                print(f"    {desc}...")
        print("")
    
    # Display medium-risk vulnerabilities (top 5)
    if medium > 0:
        print("MEDIUM RISK VULNERABILITIES (top 5):")
        count = 0
        for a in alerts:
            if a.get("riskcode") == "2" and count < 5:
                name = a.get("name", "Unknown")
                url = a.get("url", "N/A")
                print(f"  - {name} ({url})")
                count += 1
        if medium > 5:
            print(f"  ... and {medium - 5} more")
        print("")
    
    # Common frontend issues to highlight
    print("Common Frontend Security Checks:")
    
    # Check for missing security headers
    security_headers = {
        "X-Content-Type-Options Header Missing": False,
        "X-Frame-Options Header Not Set": False,
        "Content Security Policy (CSP) Header Not Set": False,
        "Strict-Transport-Security Header Not Set": False
    }
    
    for alert in alerts:
        name = alert.get("name", "")
        if name in security_headers:
            security_headers[name] = True
    
    for header, found in security_headers.items():
        status = "FOUND" if found else "OK"
        symbol = "!" if found else "✓"
        print(f"  {symbol} {header}: {status}")
    
    print("")
    
    # Save summary for Slack
    summary = {
        "total": total,
        "high": high,
        "medium": medium,
        "low": low,
        "info": info
    }
    
    with open("/zap/wrk/reports/summary.json", "w") as f:
        json.dump(summary, f)
    
    # Exit with error if high-risk vulnerabilities found
    sys.exit(1 if high > 0 else 0)
    
except Exception as e:
    print(f"ERROR: Failed to parse results: {e}", file=sys.stderr)
    sys.exit(2)
PYCODE

SCAN_EXIT_CODE=$?

# ============================================
# Send Slack Notification
# ============================================
if [ -n "$SLACK_WEBHOOK" ]; then
    echo "Sending Slack notification..."
    
    if [ -f "$REPORT_DIR/summary.json" ]; then
        SUMMARY=$(cat "$REPORT_DIR/summary.json")
        HIGH=$(echo "$SUMMARY" | jq -r '.high')
        MEDIUM=$(echo "$SUMMARY" | jq -r '.medium')
        LOW=$(echo "$SUMMARY" | jq -r '.low')
        TOTAL=$(echo "$SUMMARY" | jq -r '.total')
        
        if [ "$HIGH" -gt 0 ]; then
            EMOJI=":rotating_light:"
            STATUS="FAILED - High Risk Found"
        elif [ "$MEDIUM" -gt 5 ]; then
            EMOJI=":warning:"
            STATUS="WARNING - Multiple Medium Risk"
        else
            EMOJI=":shield:"
            STATUS="PASSED"
        fi
        
        AUTH_STATUS=$([ -n "$SESSION_COOKIE" ] && echo "Authenticated" || echo "Unauthenticated")
        
        MESSAGE="$EMOJI *DAST - React Frontend*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n*Scan Type:* $SCAN_TYPE ($AUTH_STATUS)\n\n*Results:*\n  Total: $TOTAL\n  High: $HIGH\n  Medium: $MEDIUM\n  Low: $LOW\n\n*Target:* React Web Application\n*Reports:* Check scheduled task logs"
        
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$MESSAGE\"}" \
            2>/dev/null || echo "Failed to send Slack notification"
    else
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d '{"text":":shield: *DAST - React Frontend* scan completed. Check logs for details."}' \
            2>/dev/null || echo "Failed to send Slack notification"
    fi
fi

# ============================================
# Cleanup and Exit
# ============================================
echo ""
echo "=========================================="
echo "Scan completed: $(date)"
echo "=========================================="
echo ""
echo "Reports available at:"
echo "  - HTML: $REPORT_DIR/react-frontend-zap.html"
echo "  - JSON: $REPORT_DIR/react-frontend-zap.json"
echo "  - XML:  $REPORT_DIR/react-frontend-zap.xml"
echo ""

exit $SCAN_EXIT_CODE