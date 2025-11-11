# Employee Directory Application

Go Backend, React Frontend and PostgreSQL Database

This repository contains a full-stack employee directory application with multiple versions (vulnerable and fixed) and automated DAST security scanning capabilities. This guide provides comprehensive instructions for deploying all components to Choreo.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Component Deployment Guides](#component-deployment-guides)
  - [Backend Service (Go)](#1-backend-service-go)
  - [Frontend Application (React)](#2-frontend-application-react)
  - [DAST Scheduled Task - Backend Scanner](#3-dast-scheduled-task---backend-scanner)
  - [DAST Scheduled Task - Frontend Scanner](#4-dast-scheduled-task---frontend-scanner)
- [Component Configuration Files](#component-configuration-files)
- [Environment Variables Reference](#environment-variables-reference)
- [Connections and Dependencies](#connections-and-dependencies)
- [Troubleshooting](#troubleshooting)

---

## Overview

This repository contains:

- **Backend Services**: Go-based REST API (available in both vulnerable and fixed versions)
- **Frontend Applications**: React-based web applications (available in both vulnerable and fixed versions)
- **DAST Scanners**: Automated security scanning tasks for both backend and frontend

### Repository Structure

```
employee-directory/
├── version-1-vulnerable/     # Initial version with security vulnerabilities
│   ├── backend/              # Go backend service
│   └── frontend/             # React frontend application
├── version-2-fixed/          # Secured version with fixes
│   ├── backend/              # Go backend service (fixed)
│   └── frontend/             # React frontend application (fixed)
├── dast/                     # DAST scanning components
│   ├── backend/              # Backend scanner scheduled task
│   └── frontend/             # Frontend scanner scheduled task
└── database/                 # Database schema files
```

---

## Prerequisites

Before deploying components to Choreo, ensure you have:

1. **Choreo Account**: Access to Choreo platform
2. **Git Repository Access**: Repository should be accessible from Choreo
3. **Database**: PostgreSQL database instance (can be provisioned in Choreo or external)
4. **Node.js**: Version 16+ (for local frontend development)
5. **Go**: Version 1.18+ (for local backend development)

---

## Component Deployment Guides

### 1. Backend Service (Go)

Deploy the Go backend REST API service to Choreo.

#### Component Type
**Service** (REST API)

#### Language & Runtime
- **Language**: Go
- **Go Version**: 
  - Version 1 (vulnerable): Go 1.18
  - Version 2 (fixed): Go 1.23
- **Runtime**: Container-based (Docker)

#### Project Path
- Version 1: `version-1-vulnerable/backend/`
- Version 2: `version-2-fixed/backend/`

#### Build Configuration

**Build Command:**
```bash
go mod download
go build -o main .
```

**Dockerfile:**
Choreo will auto-generate a Dockerfile, or you can use a custom one if present.

**Port:**
- **8080** (configured in `component.yaml`)

#### Component Configuration File

Location: `.choreo/component.yaml`

The component.yaml file should be present in the backend directory. Key configurations:

- **Endpoint Name**: `employee-api`
- **Base Path**: `/api`
- **Port**: `8080`
- **Type**: `REST`
- **Network Visibilities**: `Public`, `Organization`

#### Required Environment Variables

Configure these in Choreo's Config Form:

| Variable | Type | Required | Description | Example |
|----------|------|----------|-------------|---------|
| `DB_HOST` | string | Yes | PostgreSQL database host | `db.example.com` |
| `DB_USER` | string | Yes | Database username | `postgres` |
| `DB_PASSWORD` | secret | Yes | Database password | `********` |
| `DB_NAME` | string | Yes | Database name | `employee_db` |
| `DB_PORT` | string | No | Database port (default: 5432) | `5432` |
| `DB_SSLMODE` | string | No | SSL mode for connection | `require` |
| `DB_ENDPOINT_ID` | string | No | Database endpoint ID (for Neon) | `ep-xxx` |
| `ALLOWED_ORIGIN` | string | No | CORS allowed origin (V2 only) | `https://app.example.com` |

#### Deployment Steps

1. **Create Component in Choreo**
   - Go to Choreo Console → Components
   - Click "Create Component"
   - Select **Service** → **REST API**

2. **Connect Repository**
   - Connect your Git repository
   - Select the branch (e.g., `main` or `automation-pipeline-db-connection`)

3. **Configure Build**
   - **Source Path**: `version-1-vulnerable/backend/` or `version-2-fixed/backend/`
   - **Dockerfile Path**: Leave empty (auto-generated) or specify custom path
   - **Build Command**: `go mod download && go build -o main .`
   - **Run Command**: `./main`

4. **Configure Component**
   - Choreo will automatically detect `.choreo/component.yaml`
   - Verify endpoint configuration matches your requirements

5. **Set Environment Variables**
   - Navigate to Config Form
   - Add all required environment variables listed above
   - For secrets (DB_PASSWORD), use Choreo's secret management

6. **Deploy**
   - Deploy to DEV environment first
   - Test the API endpoints
   - Promote to production when ready

#### API Endpoints

Once deployed, the service exposes:

- `GET /api/employees` - List all employees
- `GET /api/employees/:id` - Get employee by ID
- `POST /api/employees` - Create new employee
- `PUT /api/employees/:id` - Update employee
- `DELETE /api/employees/:id` - Delete employee

---

### 2. Frontend Application (React)

Deploy the React frontend application to Choreo.

#### Component Type
**Service** (Web Application)

#### Language & Runtime
- **Language**: TypeScript/React
- **Node.js Version**: 
  - Version 1: Node 16+ (React 17, react-scripts 4.0.3)
  - Version 2: Node 16+ (React 18, react-scripts 5.0.1)
- **Runtime**: Container-based (Docker)

#### Project Path
- Version 1: `version-1-vulnerable/frontend/`
- Version 2: `version-2-fixed/frontend/`

#### Build Configuration

**Build Command:**
```bash
npm install
npm run build
```

**Serve Command:**
```bash
# For production build
npx serve -s build -l 3000
```

**Port:**
- **3000** (configured in `component.yaml`)

#### Component Configuration File

Location: `.choreo/component.yaml`

Key configurations:

- **Endpoint Name**: `employee-frontend`
- **Base Path**: `/`
- **Port**: `3000`
- **Type**: `REST`
- **Network Visibilities**: `Public`, `Organization`

#### Required Environment Variables

| Variable | Type | Required | Description | Example |
|----------|------|----------|-------------|---------|
| `REACT_APP_API_URL` | string | No | Backend API URL (fallback) | `https://api.example.com/api` |
| `NODE_OPTIONS` | string | No | Node.js options (for OpenSSL legacy provider) | `--openssl-legacy-provider` |

**Note**: The frontend primarily uses `window.configs.apiUrl` which is automatically configured when you create a connection to the backend service in Choreo. The `REACT_APP_API_URL` serves as a fallback.

#### Deployment Steps

1. **Create Component in Choreo**
   - Go to Choreo Console → Components
   - Click "Create Component"
   - Select **Service** → **Web Application**

2. **Connect Repository**
   - Connect your Git repository
   - Select the branch

3. **Configure Build**
   - **Source Path**: `version-1-vulnerable/frontend/` or `version-2-fixed/frontend/`
   - **Dockerfile Path**: Leave empty (auto-generated) or specify custom path
   - **Build Command**: `npm install && npm run build`
   - **Run Command**: `npx serve -s build -l 3000`

4. **Configure Component**
   - Choreo will automatically detect `.choreo/component.yaml`
   - Verify endpoint configuration

5. **Set Environment Variables** (Optional)
   - Add `REACT_APP_API_URL` if not using Choreo connection
   - Add `NODE_OPTIONS` if needed for older React Scripts

6. **Create Connection to Backend**
   - In Choreo, create a connection from frontend to backend service
   - This automatically configures `window.configs.apiUrl` in the frontend
   - Connection format: `service:/ProjectName/ComponentName/Version/Revision/Visibility`

7. **Deploy**
   - Deploy to DEV environment
   - Test the application
   - Promote to production when ready

#### Frontend Features

- Employee listing with search
- Add/Edit/Delete employees
- Form validation
- Error handling
- Responsive design with Tailwind CSS

---

### 3. DAST Scheduled Task - Backend Scanner

Deploy the automated DAST security scanner for the Go backend service.

#### Component Type
**Scheduled Task**

#### Language & Runtime
- **Language**: Bash Script
- **Base Image**: `ghcr.io/zaproxy/zaproxy:stable`
- **Runtime**: Container-based (Docker)

#### Project Path
`dast/backend/`

#### Build Configuration

**Dockerfile Path**: `dast/backend/Dockerfile`

**Build Context**: `dast/backend/` (IMPORTANT: Must match the directory containing the Dockerfile)

**Entry Point**: `/usr/local/bin/dast-scan.sh`

#### Component Configuration File

Create `.choreo/component.yaml` in `dast/backend/` directory:

```yaml
apiVersion: core.choreo.dev/v1beta1
kind: ScheduledTask
metadata:
  name: dast-go-backend
spec:
  displayName: "DAST - Go Backend Scanner"
  description: "Automated DAST security scanning for Go Backend service"
  schedule:
    expression: "0 2 * * *"  # Daily at 2:00 AM UTC
    timezone: "UTC"
  env:
    - name: GO_BACKEND_URL
      valueFrom:
        configForm:
          displayName: Backend URL
          required: true
          type: string
    - name: GO_BACKEND_TOKEN
      valueFrom:
        configForm:
          displayName: Test-Key Authentication Token
          required: true
          type: secret
    - name: SLACK_WEBHOOK_URL
      valueFrom:
        configForm:
          displayName: Slack Webhook URL (optional)
          required: false
          type: secret
    - name: SCAN_TIMEOUT_MINUTES
      valueFrom:
        configForm:
          displayName: Scan Timeout (minutes)
          required: false
          type: number
          defaultValue: 10
```

#### Required Environment Variables

| Variable | Type | Required | Description | Example |
|----------|------|----------|-------------|---------|
| `GO_BACKEND_URL` | string | Yes | Target Go Backend API URL | `https://backend.example.com/api` |
| `GO_BACKEND_TOKEN` | secret | Yes | Test-Key authentication token | `********` |
| `SLACK_WEBHOOK_URL` | secret | No | Slack webhook for notifications | `https://hooks.slack.com/...` |
| `SCAN_TIMEOUT_MINUTES` | number | No | Scan timeout in minutes (default: 10) | `10` |

#### Deployment Steps

1. **Create Component in Choreo**
   - Go to Choreo Console → Components
   - Click "Create Component"
   - Select **Scheduled Task**

2. **Connect Repository**
   - Connect your Git repository
   - Select the branch

3. **Configure Build**
   - **Source Path**: `dast/backend/`
   - **Dockerfile Path**: `dast/backend/Dockerfile`
   - **Build Context**: `dast/backend/` (CRITICAL: Must match Dockerfile location)

4. **Configure Schedule**
   - Default: Daily at 2:00 AM UTC
   - Can be modified in component.yaml or Choreo UI
   - Format: Cron expression

5. **Set Environment Variables**
   - Add `GO_BACKEND_URL` (your deployed backend service URL)
   - Add `GO_BACKEND_TOKEN` (authentication token as secret)
   - Optionally add `SLACK_WEBHOOK_URL` for notifications
   - Optionally set `SCAN_TIMEOUT_MINUTES`

6. **Deploy**
   - Deploy to DEV environment
   - Test by manually triggering the task
   - Verify scan reports in execution logs

#### Scan Reports

The scanner generates multiple report formats:

- **HTML Report**: Visual report with detailed findings
- **JSON Report**: Machine-readable for automation
- **XML Report**: Compatible with other security tools

Reports are available in the task execution logs in Choreo.

#### Manual Trigger

You can manually trigger scans:

1. Go to Choreo Console
2. Navigate to Scheduled Tasks
3. Select "DAST - Go Backend Scanner"
4. Click "Run Now"

---

### 4. DAST Scheduled Task - Frontend Scanner

Deploy the automated DAST security scanner for the React frontend application.

#### Component Type
**Scheduled Task**

#### Language & Runtime
- **Language**: Bash Script
- **Base Image**: `ghcr.io/zaproxy/zaproxy:stable`
- **Runtime**: Container-based (Docker)

#### Project Path
`dast/frontend/`

#### Build Configuration

**Dockerfile Path**: `dast/frontend/Dockerfile`

**Build Context**: `dast/frontend/` (IMPORTANT: Must match the directory containing the Dockerfile)

**Entry Point**: `/usr/local/bin/dast-scan.sh`

#### Component Configuration File

Location: `.choreo/component.yaml` (already present)

The component.yaml is already configured with:

- **Schedule**: Daily at 2:30 AM UTC (30 minutes after backend scan)
- **Environment Variables**: Pre-configured with all required and optional variables

#### Required Environment Variables

| Variable | Type | Required | Description | Example |
|----------|------|----------|-------------|---------|
| `REACT_FRONTEND_URL` | string | Yes | Target React app URL | `https://app.example.com` |
| `REACT_SESSION_COOKIE` | secret | No | Session cookie for authenticated scanning | `session=abc123...` |
| `SLACK_WEBHOOK_URL` | secret | No | Slack webhook for notifications | `https://hooks.slack.com/...` |
| `SCAN_TIMEOUT_MINUTES` | number | No | Scan timeout in minutes (default: 15) | `15` |
| `SCAN_TYPE` | string | No | Scan type: `baseline` or `full` (default: `baseline`) | `baseline` |

#### Scan Types

- **Baseline**: Passive scan, faster (~10-15 minutes)
- **Full**: Active scan, comprehensive (~30-60 minutes)

#### Deployment Steps

1. **Create Component in Choreo**
   - Go to Choreo Console → Components
   - Click "Create Component"
   - Select **Scheduled Task**

2. **Connect Repository**
   - Connect your Git repository
   - Select the branch

3. **Configure Build**
   - **Source Path**: `dast/frontend/`
   - **Dockerfile Path**: `dast/frontend/Dockerfile`
   - **Build Context**: `dast/frontend/` (CRITICAL: Must match Dockerfile location)

4. **Configure Schedule**
   - Default: Daily at 2:30 AM UTC
   - Configured in `.choreo/component.yaml`
   - Can be modified in Choreo UI

5. **Set Environment Variables**
   - Add `REACT_FRONTEND_URL` (your deployed frontend application URL)
   - Optionally add `REACT_SESSION_COOKIE` for authenticated scanning
   - Optionally add `SLACK_WEBHOOK_URL` for notifications
   - Optionally set `SCAN_TIMEOUT_MINUTES` and `SCAN_TYPE`

6. **Deploy**
   - Deploy to DEV environment
   - Test by manually triggering the task
   - Verify scan reports in execution logs

#### Authenticated Scanning

For authenticated scanning (recommended for comprehensive security testing):

1. Login to the React app in a browser
2. Open DevTools → Application → Cookies
3. Copy the session cookie value
4. Add to Choreo as `REACT_SESSION_COOKIE` secret

#### Manual Trigger

You can manually trigger scans:

1. Go to Choreo Console
2. Navigate to Scheduled Tasks
3. Select "DAST - React Frontend Scanner"
4. Click "Run Now"

---

## Component Configuration Files

All components use `.choreo/component.yaml` files for configuration. These files define:

- **Endpoints**: API endpoints and their configurations
- **Dependencies**: Connections to other components
- **Environment Variables**: Required and optional configuration
- **Schedules**: For scheduled tasks

### File Locations

- Backend: `version-1-vulnerable/backend/.choreo/component.yaml` or `version-2-fixed/backend/.choreo/component.yaml`
- Frontend: `version-1-vulnerable/frontend/.choreo/component.yaml` or `version-2-fixed/frontend/.choreo/component.yaml`
- DAST Backend: `dast/backend/.choreo/component.yaml` (create if not exists)
- DAST Frontend: `dast/frontend/.choreo/component.yaml` (already exists)

---

## Environment Variables Reference

### Backend Service

| Variable | Required | Type | Description |
|----------|----------|------|-------------|
| `DB_HOST` | Yes | string | PostgreSQL database host |
| `DB_USER` | Yes | string | Database username |
| `DB_PASSWORD` | Yes | secret | Database password |
| `DB_NAME` | Yes | string | Database name |
| `DB_PORT` | No | string | Database port (default: 5432) |
| `DB_SSLMODE` | No | string | SSL mode (e.g., `require`, `disable`) |
| `DB_ENDPOINT_ID` | No | string | Database endpoint ID (for Neon) |
| `ALLOWED_ORIGIN` | No | string | CORS allowed origin (V2 only) |

### Frontend Application

| Variable | Required | Type | Description |
|----------|----------|------|-------------|
| `REACT_APP_API_URL` | No | string | Backend API URL (fallback) |
| `NODE_OPTIONS` | No | string | Node.js options (e.g., `--openssl-legacy-provider`) |

**Note**: Frontend primarily uses `window.configs.apiUrl` from Choreo connection.

### DAST Backend Scanner

| Variable | Required | Type | Description |
|----------|----------|------|-------------|
| `GO_BACKEND_URL` | Yes | string | Target backend API URL |
| `GO_BACKEND_TOKEN` | Yes | secret | Authentication token |
| `SLACK_WEBHOOK_URL` | No | secret | Slack webhook URL |
| `SCAN_TIMEOUT_MINUTES` | No | number | Scan timeout (default: 10) |

### DAST Frontend Scanner

| Variable | Required | Type | Description |
|----------|----------|------|-------------|
| `REACT_FRONTEND_URL` | Yes | string | Target frontend URL |
| `REACT_SESSION_COOKIE` | No | secret | Session cookie for auth |
| `SLACK_WEBHOOK_URL` | No | secret | Slack webhook URL |
| `SCAN_TIMEOUT_MINUTES` | No | number | Scan timeout (default: 15) |
| `SCAN_TYPE` | No | string | `baseline` or `full` (default: `baseline`) |

---

## Connections and Dependencies

### Frontend to Backend Connection

The frontend application connects to the backend service via Choreo's Internal Marketplace:

1. **Create Connection in Choreo UI**
   - Navigate to Frontend Component → Connections
   - Click "Create Connection"
   - Select the Backend Service component
   - Choreo automatically generates the connection reference

2. **Automatic Configuration**
   - Choreo creates `/public/config.js` with `window.configs.apiUrl`
   - Frontend code reads from `window.configs.apiUrl` (see `src/services/api.ts`)
   - No manual configuration needed

3. **Connection Format**
   ```
   service:/ProjectName/ComponentName/Version/Revision/Visibility
   ```

### Database Connection

The backend service requires a PostgreSQL database:

1. **Option 1: Choreo Database Component**
   - Create a Database component in Choreo
   - Use Choreo's connection reference in `component.yaml`

2. **Option 2: External Database**
   - Configure database credentials via environment variables
   - Ensure network connectivity from Choreo to your database

---

## Troubleshooting

### Backend Service Issues

**Issue**: Build fails with Go module errors
- **Solution**: Ensure `go.mod` and `go.sum` are committed. Run `go mod tidy` locally.

**Issue**: Database connection fails
- **Solution**: Verify all database environment variables are set correctly. Check network connectivity and SSL settings.

**Issue**: CORS errors (V2)
- **Solution**: Set `ALLOWED_ORIGIN` environment variable to your frontend URL.

### Frontend Application Issues

**Issue**: Build fails with Node.js version errors
- **Solution**: Ensure Node.js 16+ is used. Add `NODE_OPTIONS=--openssl-legacy-provider` if using older React Scripts.

**Issue**: API calls fail
- **Solution**: Verify Choreo connection to backend is configured. Check `window.configs.apiUrl` in browser console.

**Issue**: Build succeeds but app doesn't load
- **Solution**: Verify serve command is correct: `npx serve -s build -l 3000`

### DAST Scanner Issues

**Issue**: Scanner fails with "Backend not accessible"
- **Solution**: Verify `GO_BACKEND_URL` is correct and backend is running. Check authentication token.

**Issue**: Scanner times out
- **Solution**: Increase `SCAN_TIMEOUT_MINUTES` value. For full scans, use 30-60 minutes.

**Issue**: No reports generated
- **Solution**: Check execution logs for errors. Verify ZAP has write permissions to `/zap/wrk/reports`.

**Issue**: Build context error
- **Solution**: Ensure Build Context matches the directory containing the Dockerfile exactly (e.g., `dast/backend/`).

---

## Additional Resources

- [Choreo Documentation](https://wso2.com/choreo/docs/)
- [Go Documentation](https://go.dev/doc/)
- [React Documentation](https://react.dev/)
- [OWASP ZAP Documentation](https://www.zaproxy.org/docs/)

---

## Version Information

### Version 1 (Vulnerable)
- **Backend**: Go 1.18 with vulnerable dependencies
- **Frontend**: React 17 with older dependencies
- **Purpose**: Security training and vulnerability demonstration

### Version 2 (Fixed)
- **Backend**: Go 1.23 with updated, secure dependencies
- **Frontend**: React 18 with updated dependencies
- **Purpose**: Production-ready secure implementation

---

## License

See [LICENSE](LICENSE) file for details.
