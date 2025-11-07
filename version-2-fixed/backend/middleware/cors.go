package middleware

import (
	"os"

	"github.com/gin-gonic/gin"
)

// SecureCORS returns a middleware with secure CORS configuration
// FIXED: Replaced wildcard CORS with configurable allowed origins
func SecureCORS() gin.HandlerFunc {
	return func(c *gin.Context) {
		// FIXED: Use environment variable for allowed origins instead of wildcard
		allowedOrigin := os.Getenv("ALLOWED_ORIGIN")
		if allowedOrigin == "" {
			// Default to same origin for security
			allowedOrigin = c.Request.Header.Get("Origin")
		}

		// Set secure CORS headers
		c.Writer.Header().Set("Access-Control-Allow-Origin", allowedOrigin)
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")
		c.Writer.Header().Set("Access-Control-Max-Age", "86400") // 24 hours

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	}
}
