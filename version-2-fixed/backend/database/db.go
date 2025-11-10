package database

import (
	"employee-directory-demo/v2/backend/models"
	"fmt"
	"log"
	"os"
	"strings"

	"gorm.io/driver/postgres"
	"gorm.io/driver/sqlserver"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
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
	// FIXED: Proper validation and error handling without exposing sensitive info
	// Choreo connection: devdb (database:pge-mssql-db-dev)
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
		// If connection string not provided but username/password are available,
		// fall back to individual env vars for constructing DSN
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

			// Validate required fields
			if host == "" || dbname == "" {
				log.Fatal("Missing required database environment variables: DB_HOST, DB_NAME (when using Choreo username/password for SQL Server)")
			}

			// SQL Server connection string format
			dsn = fmt.Sprintf("sqlserver://%s:%s@%s:%s?database=%s&encrypt=true",
				choreoUsername, choreoPassword, host, port, dbname)
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

			// Validate required fields
			if host == "" || dbname == "" {
				log.Fatal("Missing required database environment variables: DB_HOST, DB_NAME (when using Choreo username/password)")
			}

			// FIXED: Connection string is not logged to prevent information exposure
			endpointID := os.Getenv("DB_ENDPOINT_ID")
			dsn = fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
				host, choreoUsername, choreoPassword, dbname, port, sslmode)
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

			// Validate required fields
			if host == "" || user == "" || password == "" || dbname == "" {
				log.Fatal("Missing required database environment variables: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME (for SQL Server)")
			}

			// SQL Server connection string format
			dsn = fmt.Sprintf("sqlserver://%s:%s@%s:%s?database=%s&encrypt=true",
				user, password, host, port, dbname)
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

			// Validate required fields
			if host == "" || user == "" || password == "" || dbname == "" {
				log.Fatal("Missing required database environment variables: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME (or Choreo connection variables)")
			}

			// FIXED: Connection string is not logged to prevent information exposure
			endpointID := os.Getenv("DB_ENDPOINT_ID")
			dsn = fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
				host, user, password, dbname, port, sslmode)
			if endpointID != "" {
				dsn += " options=endpoint=" + endpointID
			}
			isSQLServer = false
		}
	}

	// FIXED: Proper error handling - fail fast if connection fails
	// Open database connection with appropriate driver
	if isSQLServer {
		DB, err = gorm.Open(sqlserver.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Silent), // Don't log SQL queries in production
		})
	} else {
		DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
			Logger: logger.Default.LogMode(logger.Silent), // Don't log SQL queries in production
		})
	}

	if err != nil {
		log.Fatal("Failed to connect to database: ", err)
	}

	// Auto-migrate the schema
	if err := DB.AutoMigrate(&models.Employee{}); err != nil {
		log.Fatal("Failed to migrate database schema: ", err)
	}

	log.Println("Database connection established successfully")
}
