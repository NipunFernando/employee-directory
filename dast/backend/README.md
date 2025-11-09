# DAST Go Backend Scanner

Automated DAST security scanning for the Go Backend service using OWASP ZAP.

## Configuration

### Environment Variables

- `GO_BACKEND_URL`: Target Go Backend URL (required)
- `GO_BACKEND_TOKEN`: Test-Key authentication token (required)
- `SLACK_WEBHOOK_URL`: Slack webhook for notifications (optional)
- `SCAN_TIMEOUT_MINUTES`: Scan timeout in minutes (default: 10)

### Schedule

Runs daily at 2:00 AM UTC. Can also be triggered manually.

## Manual Trigger

1. Go to Choreo Console
2. Navigate to Scheduled Tasks
3. Select "DAST - Go Backend Scanner"
4. Click "Run Now"

## Reports

Scan reports are available in the task execution logs:
- HTML report: Visual report with detailed findings
- JSON report: Machine-readable for automation
- XML report: Compatible with other security tools
```

---

## Scheduled Task 2: React Frontend DAST Scanner

### **Project Structure**
```
dast-react-frontend/
├── Dockerfile
├── dast-scan-frontend.sh
├── .choreo/
│   └── component-config.yaml
└── README.md