package handlers

import (
	"crypto/md5"
	"encoding/hex"
	"employee-directory-demo/v1/backend/database"
	"employee-directory-demo/v1/backend/models"
	"net/http"

	"github.com/gin-gonic/gin"
)

// CreateEmployee handler
func CreateEmployee(c *gin.Context) {
	var input models.Employee

	// VULNERABILITY (CWE-20): No Input Validation
	// We bind the JSON directly without checking if fields are valid,
	// e.g., if email is a valid format or if salary is a positive number.
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// VULNERABILITY (CWE-327): Use of a Broken or Risky Cryptographic Algorithm
	// Using MD5 for "password" hashing. MD5 is fast and not collision-resistant,
	// making it trivial to crack with rainbow tables.
	// We'll just hash the employee's name as a stand-in for a password.
	hash := md5.Sum([]byte(input.Name))
	input.PasswordHash = hex.EncodeToString(hash[:])

	// VULNERABILITY (CWE-250): Missing Error Handling
	// The result of the database operation is not checked.
	// If the create fails (e.g., duplicate email), the API
	// will still return a 200 OK, which is misleading.
	database.DB.Create(&input)

	c.JSON(http.StatusOK, gin.H{"data": input})
}

// GetEmployees handler
func GetEmployees(c *gin.Context) {
	var employees []models.Employee
	database.DB.Find(&employees)
	c.JSON(http.StatusOK, gin.H{"data": employees})
}

// SearchEmployees handler
func SearchEmployees(c *gin.Context) {
	query := c.Query("q")
	var employees []models.Employee

	// VULNERABILITY (CWE-89): SQL Injection
	// The search query 'q' is directly concatenated into the SQL string.
	// A user can provide malicious input like: `'; DROP TABLE users; --`
	// This will be flagged by SAST (Static Analysis) and DAST (Dynamic Analysis) tools.
	// Example query: "SELECT * FROM employees WHERE name ILIKE '%" + query + "%'"
	sql := "SELECT * FROM employees WHERE (name ILIKE '%" + query + "%' OR email ILIKE '%" + query + "%' OR position ILIKE '%" + query + "%') AND deleted_at IS NULL"
	
	// VULNERABILITY (CWE-390): Missing Error Handling
	// If the Raw SQL query fails, the error is ignored.
	database.DB.Raw(sql).Scan(&employees)

	c.JSON(http.StatusOK, gin.H{"data": employees})
}

// UpdateEmployee handler
func UpdateEmployee(c *gin.Context) {
	var employee models.Employee
	// VULNERABILITY: Missing error handling on Find
	if err := database.DB.Where("id = ?", c.Param("id")).First(&employee).Error; err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Record not found!"})
		return
	}

	var input models.Employee
	// VULNERABILITY (CWE-20): No Input Validation on update
	c.ShouldBindJSON(&input)

	database.DB.Model(&employee).Updates(input)
	c.JSON(http.StatusOK, gin.H{"data": employee})
}

// DeleteEmployee handler
func DeleteEmployee(c *gin.Context) {
	var employee models.Employee
	// VULNERABILITY: Missing error handling
	database.DB.Where("id = ?", c.Param("id")).Delete(&employee)
	c.JSON(http.StatusOK, gin.H{"data": true})
}