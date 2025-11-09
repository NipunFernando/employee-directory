# DAST React Frontend Scanner

Automated DAST security scanning for the React Frontend application using OWASP ZAP.

## Configuration

### Environment Variables

- `REACT_FRONTEND_URL`: Target React app URL (required)
- `REACT_SESSION_COOKIE`: Session cookie for authenticated scanning (optional)
- `SLACK_WEBHOOK_URL`: Slack webhook for notifications (optional)
- `SCAN_TIMEOUT_MINUTES`: Scan timeout in minutes (default: 15)
- `SCAN_TYPE`: `baseline` (faster) or `full` (comprehensive)

### Schedule

Runs daily at 2:30 AM UTC. Can also be triggered manually.

### Authentication

For authenticated scanning, provide a session cookie:

1. Login to the React app in a browser
2. Open DevTools → Application → Cookies
3. Copy session cookie value
4. Add to Choreo secrets as `react-session-cookie`

## Manual Trigger

1. Go to Choreo Console
2. Navigate to Scheduled Tasks
3. Select "DAST - React Frontend Scanner"
4. Click "Run Now"

## Scan Types

- **Baseline**: Passive scan, faster (~10-15 min)
- **Full**: Active scan, comprehensive (~30-60 min)

## Reports

Scan reports are available in the task execution logs.