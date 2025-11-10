package database

import (
	"employee-directory-demo/v1/backend/models"
	"log"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

var DB *gorm.DB

func ConnectDatabase() {
	var err error

	// Read database credentials from environment variables
	// VULNERABILITY (CWE-209): Information Exposure Through Error Messages
	// If env vars are missing, the error message might expose sensitive info
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
	dsn := "host=" + host + " user=" + user + " password=" + password + " dbname=" + dbname + " port=" + port + " sslmode=" + sslmode
	if endpointID != "" {
		dsn += " options=endpoint=" + endpointID
	}

	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{})

	// VULNERABILITY (CWE-390): Missing Error Handling
	// If the connection fails, the error is not properly handled,
	// and the application might crash or behave unpredictably.
	if err != nil {
		log.Println("Failed to connect to database. But we'll continue anyway...")
	}

	// Auto-migrate the schema
	DB.AutoMigrate(&models.Employee{})
}
