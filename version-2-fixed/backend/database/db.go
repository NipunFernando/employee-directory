package database

import (
	"employee-directory-demo/v2/backend/models"
	"fmt"
	"log"
	"os"

	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
)

var DB *gorm.DB

func ConnectDatabase() {
	var err error

	// Read database credentials from environment variables
	// FIXED: Proper validation and error handling without exposing sensitive info
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
		log.Fatal("Missing required database environment variables: DB_HOST, DB_USER, DB_PASSWORD, DB_NAME")
	}

	// FIXED: Connection string is not logged to prevent information exposure
	endpointID := os.Getenv("DB_ENDPOINT_ID")
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=%s",
		host, user, password, dbname, port, sslmode)
	if endpointID != "" {
		dsn += " options=endpoint=" + endpointID
	}

	// FIXED: Proper error handling - fail fast if connection fails
	DB, err = gorm.Open(postgres.Open(dsn), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Silent), // Don't log SQL queries in production
	})

	if err != nil {
		log.Fatal("Failed to connect to database: ", err)
	}

	// Auto-migrate the schema
	if err := DB.AutoMigrate(&models.Employee{}); err != nil {
		log.Fatal("Failed to migrate database schema: ", err)
	}

	log.Println("Database connection established successfully")
}
