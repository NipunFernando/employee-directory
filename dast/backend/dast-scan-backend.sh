#!/bin/bash
set -e

echo "=========================================="
echo "DAST - Backend Employee Directory Scanner"
echo "=========================================="
echo "Scan started: $(date)"
echo ""

# Configuration from environment variables
BASE_URL="${GO_BACKEND_URL}"
AUTH_TOKEN="${GO_BACKEND_TOKEN}"
SLACK_WEBHOOK="${SLACK_WEBHOOK_URL}"
SCAN_TIMEOUT="${SCAN_TIMEOUT_MINUTES:-10}"

# Validate required variables
if [ -z "$BASE_URL" ]; then
    echo "ERROR: GO_BACKEND_URL is required"
    echo "Example: https://[uuid]-dev.e1-us-east-azure.choreoapis.dev/[org]/[service]/v1.0"
    exit 1
fi

if [ -z "$AUTH_TOKEN" ]; then
    echo "ERROR: GO_BACKEND_TOKEN is required"
    exit 1
fi

echo "Configuration:"
echo "  Base URL: $BASE_URL"
echo "  Timeout: $SCAN_TIMEOUT minutes"
echo ""

# Determine writable work directory (use /tmp as fallback if /zap/wrk is not writable)
WORK_DIR="/zap/wrk"
if ! mkdir -p "$WORK_DIR" 2>/dev/null || [ ! -w "$WORK_DIR" ]; then
    echo "Warning: Cannot write to /zap/wrk, using /tmp instead"
    WORK_DIR="/tmp"
    mkdir -p "$WORK_DIR"
fi

REPORT_DIR="$WORK_DIR/reports"
mkdir -p "$REPORT_DIR"

# ============================================
# Check Service Availability
# ============================================
echo "Checking Backend Employee Directory availability..."

MAX_RETRIES=5
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Test API endpoint with authentication (primary check)
    # Try multiple possible paths since Choreo basePath configuration might affect the path
    API_URLS=(
        "${BASE_URL%/}/api/employees"
        "${BASE_URL%/}/employees"
        "${BASE_URL%/}"
    )
    
    # Try choreo-apis pattern (used by Choreo frontend apps)
    # Extract path after domain (org/service/version)
    if [[ "$BASE_URL" =~ (https?://[^/]+)(/.+)? ]]; then
        GATEWAY_BASE="${BASH_REMATCH[1]}"
        PATH_PART="${BASH_REMATCH[2]}"
        
        if [ -n "$PATH_PART" ]; then
            # Remove leading slash and trailing version if present
            PATH_PART="${PATH_PART#/}"
            # Remove version suffix (v1.0 or v1) to get org/service
            ORG_SERVICE="${PATH_PART%/*}"
            VERSION="${PATH_PART##*/}"
            
            # Try with /choreo-apis prefix
            if [ -n "$ORG_SERVICE" ] && [ "$ORG_SERVICE" != "$PATH_PART" ]; then
                # Try with full version (v1.0)
                API_URLS+=("${GATEWAY_BASE}/choreo-apis/${ORG_SERVICE}/${VERSION}/employees")
                API_URLS+=("${GATEWAY_BASE}/choreo-apis/${ORG_SERVICE}/${VERSION}/api/employees")
                # Try with version without .0 (v1)
                VERSION_SHORT="${VERSION%.0}"
                if [ "$VERSION_SHORT" != "$VERSION" ]; then
                    API_URLS+=("${GATEWAY_BASE}/choreo-apis/${ORG_SERVICE}/${VERSION_SHORT}/employees")
                    API_URLS+=("${GATEWAY_BASE}/choreo-apis/${ORG_SERVICE}/${VERSION_SHORT}/api/employees")
                fi
                # Try with full path as-is
                API_URLS+=("${GATEWAY_BASE}/choreo-apis/${PATH_PART}/employees")
                API_URLS+=("${GATEWAY_BASE}/choreo-apis/${PATH_PART}/api/employees")
            else
                # If no org/service separation, try with full path
                API_URLS+=("${GATEWAY_BASE}/choreo-apis/${PATH_PART}/employees")
                API_URLS+=("${GATEWAY_BASE}/choreo-apis/${PATH_PART}/api/employees")
            fi
        fi
    fi
    
    API_HTTP_CODE="000"
    WORKING_URL=""
    
    for TEST_URL in "${API_URLS[@]}"; do
        API_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Test-Key: $AUTH_TOKEN" \
            -H "accept: */*" \
            "$TEST_URL" || echo "000")
        
        if [ "$API_HTTP_CODE" = "200" ] || [ "$API_HTTP_CODE" = "401" ]; then
            echo "Backend API is accessible at $TEST_URL (HTTP $API_HTTP_CODE)"
            WORKING_URL="$TEST_URL"
            break
        fi
    done
    
    if [ -n "$WORKING_URL" ]; then
        break
    fi
    
    # Optional: Test health endpoint (informational only)
    if [ $RETRY_COUNT -eq 0 ]; then
        HEALTH_URL="${BASE_URL%/}/health"
        HEALTH_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$HEALTH_URL" || echo "000")
        if [ "$HEALTH_CODE" = "200" ]; then
            echo "Health endpoint is also accessible (HTTP $HEALTH_CODE)"
        fi
    fi
    
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "Attempt $RETRY_COUNT/$MAX_RETRIES - API returned HTTP $API_HTTP_CODE - waiting 10s..."
    sleep 10
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "ERROR: Backend is not accessible after $MAX_RETRIES attempts"
    echo "Please verify:"
    echo "  1. Service is deployed to DEV environment"
    echo "  2. URL is correct: $BASE_URL"
    echo "  3. GO_BACKEND_TOKEN (Test-Key) is valid"
    
    # Send failure notification
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\":warning: *DAST Backend Employee Directory* - Service not accessible (HTTP $HTTP_CODE). Scan aborted.\n\nURL: \`$BASE_URL\`\"}" \
            2>/dev/null || true
    fi
    
    exit 1
fi

echo ""

# ============================================
# Create ZAP Authentication Script
# ============================================
echo "Preparing ZAP authentication configuration..."

cat > "$WORK_DIR/add-test-key.js" << 'EOF'
function sendingRequest(msg, initiator, helper) {
    var testKey = org.parosproxy.paros.model.Model.getSingleton()
                  .getOptionsParam().getConfig().getString("testkey");
    
    if (testKey) {
        msg.getRequestHeader().setHeader("Test-Key", testKey);
        msg.getRequestHeader().setHeader("accept", "*/*");
    }
}

function responseReceived(msg, initiator, helper) {
    // Nothing to do
}
EOF

echo "Authentication script created"
echo ""

# ============================================
# Run ZAP Baseline Scan
# ============================================
echo "=========================================="
echo "Starting ZAP Baseline Scan"
echo "=========================================="
echo ""
echo "Target: $BASE_URL"
echo "This will scan all endpoints under the base URL"
echo "Timeout: $SCAN_TIMEOUT minutes"
echo ""

# Ensure BASE_URL doesn't end with / for ZAP scanning
SCAN_URL="${BASE_URL%/}"

# Set ZAP environment variables to use writable directories
export ZAP_HOME="$WORK_DIR/.zap"
mkdir -p "$ZAP_HOME"

# Set HOME to writable directory (ZAP may try to write to ~/zap.yaml)
ZAP_HOME_DIR="$WORK_DIR/home"
mkdir -p "$ZAP_HOME_DIR/zap"
export HOME="$ZAP_HOME_DIR"

# Set ZAP user directory
export ZAP_USER_DIR="$WORK_DIR/.zap"

# Patch zap-baseline.py at runtime to use writable directory instead of /zap/wrk
# Create a patched copy of the script
echo "Preparing ZAP scan script..."
ZAP_BASELINE_PATCHED="$WORK_DIR/zap-baseline-patched.py"
python3 << PYTHON_PATCH
with open('/zap/zap-baseline.py', 'r') as f:
    content = f.read()
# Replace /zap/wrk with writable directory
content = content.replace('/zap/wrk', '$WORK_DIR/zap_wrk')
with open('$ZAP_BASELINE_PATCHED', 'w') as f:
    f.write(content)
PYTHON_PATCH

chmod +x "$ZAP_BASELINE_PATCHED"
mkdir -p "$WORK_DIR/zap_wrk"

# Set PYTHONPATH to include /zap so zap_common can be imported
export PYTHONPATH="/zap:$PYTHONPATH"

# Run ZAP baseline scan with patched script from /zap directory
# This ensures all imports work correctly
echo "Starting ZAP scan (this may take several minutes)..."
echo "Report directory: $REPORT_DIR"
echo "Work directory: $WORK_DIR"
cd /zap

# Run ZAP with verbose output to see what's happening
# Add -d flag for debug output and -g for generate report
echo "Running ZAP scan with the following parameters:"
echo "  Target: $SCAN_URL"
echo "  Timeout: $SCAN_TIMEOUT minutes"
echo "  Reports will be saved to: $REPORT_DIR"
echo ""

python3 "$ZAP_BASELINE_PATCHED" \
    -t "$SCAN_URL" \
    -z "-config testkey=$AUTH_TOKEN -script $WORK_DIR/add-test-key.js" \
    -J "$REPORT_DIR/backend-employee-zap.json" \
    -r "$REPORT_DIR/backend-employee-zap.html" \
    -w "$REPORT_DIR/backend-employee-zap.md" \
    -x "$REPORT_DIR/backend-employee-zap.xml" \
    -m "$SCAN_TIMEOUT" \
    -d \
    -I 2>&1 | tee "$WORK_DIR/zap-scan-output.log" || ZAP_EXIT_CODE=$?

echo ""
echo "ZAP scan exit code: ${ZAP_EXIT_CODE:-0}"
echo "Checking for generated reports..."
ls -la "$REPORT_DIR/" 2>/dev/null || echo "Report directory not accessible"
echo ""
echo "ZAP scan completed"
echo ""

# Check for reports in multiple possible locations
REPORT_FOUND=""
for possible_report in \
    "$REPORT_DIR/backend-employee-zap.json" \
    "$WORK_DIR/zap_wrk/reports/backend-employee-zap.json" \
    "/tmp/reports/backend-employee-zap.json" \
    "$WORK_DIR/backend-employee-zap.json"; do
    if [ -f "$possible_report" ]; then
        echo "Found report at: $possible_report"
        REPORT_FOUND="$possible_report"
        # Copy to our expected location if different
        if [ "$possible_report" != "$REPORT_DIR/backend-employee-zap.json" ]; then
            cp "$possible_report" "$REPORT_DIR/backend-employee-zap.json" 2>/dev/null || true
        fi
        break
    fi
done

if [ -z "$REPORT_FOUND" ]; then
    echo "WARNING: No report found in expected locations"
    echo "Checking for any JSON files in work directory..."
    find "$WORK_DIR" -name "*.json" -type f 2>/dev/null | head -5 || true
fi
echo ""

# ============================================
# Parse and Display Results
# ============================================
echo "=========================================="
echo "Scan Results"
echo "=========================================="

# Check if report exists (use the found report if available)
if [ -n "$REPORT_FOUND" ] && [ -f "$REPORT_FOUND" ]; then
    REPORT_FILE="$REPORT_FOUND"
elif [ -f "$REPORT_DIR/backend-employee-zap.json" ]; then
    REPORT_FILE="$REPORT_DIR/backend-employee-zap.json"
else
    echo "ERROR: Scan report not generated"
    echo "Checked locations:"
    echo "  - $REPORT_DIR/backend-employee-zap.json"
    echo "  - $WORK_DIR/zap_wrk/reports/backend-employee-zap.json"
    echo "  - /tmp/reports/backend-employee-zap.json"
    echo ""
    echo "ZAP scan output (last 50 lines):"
    tail -50 "$WORK_DIR/zap-scan-output.log" 2>/dev/null || echo "No scan output log found"
    
    if [ -n "$SLACK_WEBHOOK" ]; then
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d '{"text":":x: *DAST Backend Employee Directory* - Scan failed. No report generated. Check logs for details."}' \
            2>/dev/null || true
    fi
    
    exit 1
fi

echo "Using report file: $REPORT_FILE"

# Parse results with Python
export REPORT_FILE
export REPORT_DIR
python3 << PYCODE
import json
import sys
import os

# Use the report file we found
report_file = os.environ.get('REPORT_FILE', os.path.join(os.environ.get('REPORT_DIR', '/zap/wrk/reports'), 'backend-employee-zap.json'))

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
        print("=" * 60)
        print("HIGH RISK VULNERABILITIES:")
        print("=" * 60)
        for a in alerts:
            if a.get("riskcode") == "3":
                name = a.get("name", "Unknown")
                desc = a.get("desc", "No description")[:300]
                solution = a.get("solution", "No solution provided")[:200]
                urls = a.get("instances", [])
                
                print(f"\n[!] {name}")
                print(f"    Description: {desc}...")
                print(f"    Solution: {solution}...")
                
                if urls:
                    print(f"    Affected URLs ({len(urls)}):")
                    for idx, instance in enumerate(urls[:3], 1):
                        url = instance.get("uri", "N/A")
                        print(f"      {idx}. {url}")
                    if len(urls) > 3:
                        print(f"      ... and {len(urls) - 3} more")
        print("")
    
    # Display medium-risk vulnerabilities (top 5)
    if medium > 0:
        print("=" * 60)
        print("MEDIUM RISK VULNERABILITIES (top 5):")
        print("=" * 60)
        count = 0
        for a in alerts:
            if a.get("riskcode") == "2" and count < 5:
                name = a.get("name", "Unknown")
                instances = len(a.get("instances", []))
                print(f"  [{count+1}] {name} ({instances} instance{'s' if instances != 1 else ''})")
                count += 1
        if medium > 5:
            print(f"  ... and {medium - 5} more")
        print("")
    
    # Common API security checks
    print("=" * 60)
    print("API Security Checklist:")
    print("=" * 60)
    
    security_checks = {
        "Missing Anti-clickjacking Header": ("X-Frame-Options", False),
        "Content Security Policy (CSP) Header Not Set": ("CSP", False),
        "Strict-Transport-Security Header Not Set": ("HSTS", False),
        "X-Content-Type-Options Header Missing": ("X-Content-Type-Options", False),
        "Server Leaks Version Information": ("Server Version", False),
        "Information Disclosure": ("Info Disclosure", False)
    }
    
    for alert in alerts:
        name = alert.get("name", "")
        for check_name in security_checks.keys():
            if check_name in name:
                security_checks[check_name] = (security_checks[check_name][0], True)
    
    for check_name, (short_name, found) in security_checks.items():
        if found:
            print(f"  [!] {short_name}: FOUND")
        else:
            print(f"  [✓] {short_name}: OK")
    
    print("")
    
    # Save summary for Slack
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
        if a.get("riskcode") == "3":
            summary["high_details"].append({
                "name": a.get("name", "Unknown"),
                "count": len(a.get("instances", []))
            })
    
    summary_file = os.path.join(os.environ.get('REPORT_DIR', '/zap/wrk/reports'), 'summary.json')
    with open(summary_file, "w") as f:
        json.dump(summary, f, indent=2)
    
    # Print summary to console for logging
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

# ============================================
# Display Summary File Content
# ============================================
echo ""
echo "=========================================="
echo "Summary File Content"
echo "=========================================="
if [ -f "$REPORT_DIR/summary.json" ]; then
    echo "Summary file location: $REPORT_DIR/summary.json"
    cat "$REPORT_DIR/summary.json"
    echo ""
else
    echo "WARNING: Summary file not found at $REPORT_DIR/summary.json"
    # Try to find it in other locations
    for possible_summary in \
        "$WORK_DIR/summary.json" \
        "$WORK_DIR/zap_wrk/reports/summary.json" \
        "/tmp/reports/summary.json"; do
        if [ -f "$possible_summary" ]; then
            echo "Found summary at: $possible_summary"
            cat "$possible_summary"
            cp "$possible_summary" "$REPORT_DIR/summary.json" 2>/dev/null || true
            break
        fi
    done
    echo ""
fi

# ============================================
# Send Slack Notification
# ============================================
if [ -n "$SLACK_WEBHOOK" ]; then
    echo "Sending Slack notification..."
    
    # Try multiple locations for summary file
    SUMMARY_FILE=""
    for possible_summary in \
        "$REPORT_DIR/summary.json" \
        "$WORK_DIR/summary.json" \
        "$WORK_DIR/zap_wrk/reports/summary.json" \
        "/tmp/reports/summary.json"; do
        if [ -f "$possible_summary" ]; then
            SUMMARY_FILE="$possible_summary"
            break
        fi
    done
    
    if [ -n "$SUMMARY_FILE" ] && [ -f "$SUMMARY_FILE" ]; then
        SUMMARY=$(cat "$SUMMARY_FILE")
        HIGH=$(echo "$SUMMARY" | jq -r '.high')
        MEDIUM=$(echo "$SUMMARY" | jq -r '.medium')
        LOW=$(echo "$SUMMARY" | jq -r '.low')
        TOTAL=$(echo "$SUMMARY" | jq -r '.total')
        
        # Determine status and emoji
        if [ "$HIGH" -gt 0 ]; then
            EMOJI=":rotating_light:"
            STATUS="FAILED - High Risk Vulnerabilities Found"
            COLOR="danger"
            
            # Get high vulnerability names
            HIGH_DETAILS=$(echo "$SUMMARY" | jq -r '.high_details[] | "  • \(.name) (\(.count) instance\(if .count > 1 then "s" else "" end))"' | head -n 3)
            
            MESSAGE="$EMOJI *DAST - Backend Employee Directory*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n\n*Results:*\n  Total: $TOTAL\n  :red_circle: High: $HIGH\n  :large_orange_diamond: Medium: $MEDIUM\n  :white_circle: Low: $LOW\n\n*High Risk Issues:*\n$HIGH_DETAILS\n\n*Target:* Backend Employee API\n*URL:* \`$BASE_URL\`\n*Action Required:* Review and fix high-risk vulnerabilities"
        elif [ "$MEDIUM" -gt 5 ]; then
            EMOJI=":warning:"
            STATUS="WARNING - Multiple Medium Risk Issues"
            COLOR="warning"
            
            MESSAGE="$EMOJI *DAST - Backend Employee Directory*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n\n*Results:*\n  Total: $TOTAL\n  :white_circle: High: $HIGH\n  :large_orange_diamond: Medium: $MEDIUM\n  :white_circle: Low: $LOW\n\n*Target:* Backend Employee API\n*URL:* \`$BASE_URL\`\n*Recommendation:* Review medium-risk findings"
        else
            EMOJI=":shield:"
            STATUS="PASSED"
            COLOR="good"
            
            MESSAGE="$EMOJI *DAST - Backend Employee Directory*\n\n*Status:* $STATUS\n*Scan Date:* $(date '+%Y-%m-%d %H:%M:%S')\n\n*Results:*\n  Total: $TOTAL\n  :white_check_mark: High: $HIGH\n  :white_circle: Medium: $MEDIUM\n  :white_circle: Low: $LOW\n\n*Target:* Backend Employee API\n*URL:* \`$BASE_URL\`\n*Security Status:* No high-risk vulnerabilities detected"
        fi
        
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d "{\"text\":\"$MESSAGE\"}" \
            2>/dev/null || echo "Failed to send Slack notification"
    else
        curl -X POST "$SLACK_WEBHOOK" \
            -H 'Content-Type: application/json' \
            -d '{"text":":shield: *DAST - Backend Employee Directory* scan completed. Check logs for details."}' \
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
echo "Reports available in logs above"
echo "Report files:"
echo "  - HTML: $REPORT_DIR/backend-employee-zap.html"
echo "  - JSON: $REPORT_DIR/backend-employee-zap.json"
echo "  - XML:  $REPORT_DIR/backend-employee-zap.xml"
echo "  - Markdown: $REPORT_DIR/backend-employee-zap.md"
echo ""

if [ $SCAN_EXIT_CODE -eq 1 ]; then
    echo "STATUS: FAILED (High-risk vulnerabilities found)"
elif [ $SCAN_EXIT_CODE -eq 2 ]; then
    echo "STATUS: ERROR (Scan parsing failed)"
else
    echo "STATUS: PASSED (No high-risk vulnerabilities)"
fi

exit $SCAN_EXIT_CODE