# Employee Directory - Version 1 (Vulnerable)

This is the vulnerable version of the Employee Directory application, intentionally designed with security vulnerabilities for demonstration purposes.

## Prerequisites

- Go 1.18 or higher
- Node.js 14+ and npm
- PostgreSQL database (or Neon, Supabase, etc.)

## Backend Setup

1. Navigate to the backend directory:
   ```bash
   cd backend
   ```

2. Install Go dependencies:
   ```bash
   go mod tidy
   ```

3. Update database connection in `database/db.go`:
   Replace the placeholders in line 18:
   ```go
   dsn := "host=YOUR_NEON_HOST user=YOUR_NEON_USER password=YOUR_NEON_PASSWORD dbname=YOUR_NEON_DB port=5432 sslmode=require"
   ```
   With your actual database credentials.

4. Run the backend server:
   ```bash
   go run main.go
   ```
   
   The server will start on `http://localhost:8080`

## Frontend Setup

1. Navigate to the frontend directory:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the development server:
   ```bash
   npm start
   ```
   
   The app will open at `http://localhost:3000`

## Database Setup

The application uses GORM's AutoMigrate feature, so the `employees` table will be created automatically when you first run the backend.

## Known Vulnerabilities

This version intentionally contains multiple security vulnerabilities:

- **CWE-798**: Hardcoded database credentials
- **CWE-89**: SQL Injection in search endpoint
- **CWE-79**: Cross-Site Scripting (XSS) in employee position field
- **CWE-20**: No input validation
- **CWE-327**: Weak cryptographic algorithm (MD5)
- **CWE-390**: Missing error handling
- **CWE-250**: Insecure error handling
- **CWE-942**: Insecure CORS policy
- **CVE-2020-26160**: Vulnerable jwt-go dependency
- Outdated dependencies with known vulnerabilities

## API Endpoints

- `GET /health` - Health check
- `GET /api/employees` - Get all employees
- `GET /api/employees/search?q=query` - Search employees (SQL Injection vulnerable)
- `POST /api/employees` - Create employee
- `PUT /api/employees/:id` - Update employee
- `DELETE /api/employees/:id` - Delete employee

## Notes

⚠️ **This code is for educational/demonstration purposes only. Do not use in production.**

