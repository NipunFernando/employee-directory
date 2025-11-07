package main

import (
	"employee-directory-demo/v2/backend/database"
	"employee-directory-demo/v2/backend/handlers"
	"employee-directory-demo/v2/backend/middleware"
	"log"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file (optional - for local development)
	// FIXED: .env file is optional and should not be committed to git
	err := godotenv.Load()
	if err != nil {
		log.Println("Note: .env file not found. Using environment variables from system.")
	}

	// FIXED: Set Gin to release mode in production
	if os.Getenv("GIN_MODE") == "" {
		gin.SetMode(gin.ReleaseMode)
	}

	r := gin.Default()

	// FIXED: Use secure CORS middleware instead of wildcard
	r.Use(middleware.SecureCORS())

	// Connect to the database (credentials loaded from environment variables)
	database.ConnectDatabase()

	// Routes
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	api := r.Group("/api")
	{
		api.POST("/employees", handlers.CreateEmployee)
		api.GET("/employees", handlers.GetEmployees)
		api.GET("/employees/search", handlers.SearchEmployees) // FIXED: No longer vulnerable to SQLi
		api.PUT("/employees/:id", handlers.UpdateEmployee)
		api.DELETE("/employees/:id", handlers.DeleteEmployee)
	}

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Server starting on port %s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatal("Failed to start server: ", err)
	}
}
