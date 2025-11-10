package database

import (
	"employee-directory-demo/v1/backend/models"
	"log"
	"os"
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
)

var DB *gorm.DB

// isSQLServerConnection detects if the connection string is for SQL Server
// SQL Server connection strings typically start with "Server=" or contain "sqlserver://"
func isSQLServerConnection(dsn string) bool {
	dsnLower := strings.ToLower(strings.TrimSpace(dsn))
	return strings.HasPrefix(dsnLower, "server=") || strings.Contains(dsnLower, "sqlserver://")
}

func ConnectDatabase() {
	var err error

	// Read database credentials from Choreo connection environment variables
	// VULNERABILITY (CWE-209): Information Exposure Through Error Messages
	// If env vars are missing, the error message might expose sensitive info
	// Choreo connection name "devdb" (defined in component.yaml) automatically provides:
	// CHOREO_DEVDB_CONNECTIONSTRING, CHOREO_DEVDB_DBUSERNAME, CHOREO_DEVDB_DBUSERPASSWORD
	choreoConnectionString := os.Getenv("CHOREO_DEVDB_CONNECTIONSTRING")
	choreoUsername := os.Getenv("CHOREO_DEVDB_DBUSERNAME")
	choreoPassword := os.Getenv("CHOREO_DEVDB_DBUSERPASSWORD")

	var dsn string
	var isSQLServer bool

	// Use Choreo connection string if available
	if choreoConnectionString != "" {
		dsn = choreoConnectionString
		isSQLServer = isSQLServerConnection(dsn)
	} else if choreoUsername != "" && choreoPassword != "" {
		// Construct DSN from Choreo username/password if connection string not provided
		// Check DB_TYPE to determine database type, default to PostgreSQL
		dbType := strings.ToLower(os.Getenv("DB_TYPE"))
		if dbType == "mssql" || dbType == "sqlserver" {
			// Construct SQL Server connection string
			host := os.Getenv("DB_HOST")
			dbname := os.Getenv("DB_NAME")
			port := os.Getenv("DB_PORT")
			if port == "" {
				port = "1433"
			}
			// SQL Server connection string format
			dsn = "sqlserver://" + choreoUsername + ":" + choreoPassword + "@" + host + ":" + port + "?database=" + dbname + "&encrypt=true"
			isSQLServer = true
		} else {
			// Construct PostgreSQL connection string
			host := os.Getenv("DB_HOST")
			dbname := os.Getenv("DB_NAME")
			port := os.Getenv("DB_PORT")
			if port == "" {
				port = "5432"
			}
			sslmode := os.Getenv("DB_SSLMODE")
			if sslmode == "" {
				sslmode = "require"
			}

			// VULNERABILITY (CWE-209): Connection string might be logged
			// For Neon, extract endpoint ID from hostname and add as parameter
			endpointID := os.Getenv("DB_ENDPOINT_ID")
			dsn = "host=" + host + " user=" + choreoUsername + " password=" + choreoPassword + " dbname=" + dbname + " port=" + port + " sslmode=" + sslmode
			if endpointID != "" {
				dsn += " options=endpoint=" + endpointID
			}
			isSQLServer = false
		}
	} else {
		// Fallback to individual env vars for local development
		// Check DB_TYPE to determine database type, default to PostgreSQL
		dbType := strings.ToLower(os.Getenv("DB_TYPE"))
		if dbType == "mssql" || dbType == "sqlserver" {
			// Construct SQL Server connection string
			host := os.Getenv("DB_HOST")
			user := os.Getenv("DB_USER")
			password := os.Getenv("DB_PASSWORD")
			dbname := os.Getenv("DB_NAME")
			port := os.Getenv("DB_PORT")
			if port == "" {
				port = "1433"
			}
			// SQL Server connection string format
			dsn = "sqlserver://" + user + ":" + password + "@" + host + ":" + port + "?database=" + dbname + "&encrypt=true"
			isSQLServer = true
		} else {
			// Construct PostgreSQL connection string
			host := os.Getenv("DB_HOST")
			user := os.Getenv("DB_USER")
			password := os.Getenv("DB_PASSWORD")
			dbname := os.Getenv("DB_NAME")
			port := os.Getenv("DB_PORT")
			if port == "" {
				port = "5432"
			}
			sslmode := os.Getenv("DB_SSLMODE")
			if sslmode == "" {
				sslmode = "require"
			}

			// VULNERABILITY (CWE-209): Connection string might be logged
			// For Neon, extract endpoint ID from hostname and add as parameter
			endpointID := os.Getenv("DB_ENDPOINT_ID")
			dsn = "host=" + host + " user=" + user + " password=" + password + " dbname=" + dbname + " port=" + port + " sslmode=" + sslmode
			if endpointID != "" {
				dsn += " options=endpoint=" + endpointID
			}
			isSQLServer = false
		}
	}

	// Open database connection with appropriate driver
	if isSQLServer {
		DB, err = gorm.Open(sqlserver.Open(dsn), &gorm.Config{})
	} else {
		DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})
	}

	// VULNERABILITY (CWE-390): Missing Error Handling
	// If the connection fails, the error is not properly handled,
	// and the application might crash or behave unpredictably.
	if err != nil {
		log.Println("Failed to connect to database. But we'll continue anyway...")
	}

	// Auto-migrate the schema
	DB.AutoMigrate(&models.Employee{})
}
