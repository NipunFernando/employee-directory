package main

import (
	"employee-directory-demo/v1/backend/database"
	"employee-directory-demo/v1/backend/handlers"
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/joho/godotenv"
)

func main() {
	// Load .env file
	// VULNERABILITY: .env file might contain sensitive data and could be committed to git
	err := godotenv.Load()
	if err != nil {
		log.Println("Warning: .env file not found. Using environment variables.")
	}

	r := gin.Default()

	// VULNERABLE: Insecure CORS policy allows all origins
	r.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}
		c.Next()
	})

	// Connect to the database (credentials loaded from .env)
	database.ConnectDatabase()

	// Routes
	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	api := r.Group("/api")
	{
		api.POST("/employees", handlers.CreateEmployee)
		api.GET("/employees", handlers.GetEmployees)
		api.GET("/employees/search", handlers.SearchEmployees) // Vulnerable to SQLi
		api.PUT("/employees/:id", handlers.UpdateEmployee)
		api.DELETE("/employees/:id", handlers.DeleteEmployee)
	}

	r.Run(":8080")
}
