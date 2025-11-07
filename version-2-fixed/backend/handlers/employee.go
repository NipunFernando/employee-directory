package handlers

import (
	"employee-directory-demo/v2/backend/database"
	"employee-directory-demo/v2/backend/models"
	"employee-directory-demo/v2/backend/utils"
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

// CreateEmployee handler
// FIXED: Added input validation, proper error handling, and secure password hashing
func CreateEmployee(c *gin.Context) {
	var input models.Employee

	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request format",
		})
		return
	}

	// FIXED: Sanitize input to prevent XSS
	input.Name = utils.SanitizeString(input.Name)
	input.Email = utils.SanitizeString(input.Email)
	input.Department = utils.SanitizeString(input.Department)
	input.Position = utils.SanitizeString(input.Position)

	// FIXED: Validate input using validator
	if err := utils.ValidateEmployee(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// FIXED: Use bcrypt instead of MD5 for secure password hashing
	// Using employee's name as a stand-in for password (for demo purposes)
	hash, err := bcrypt.GenerateFromPassword([]byte(input.Name), bcrypt.DefaultCost)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to process request",
		})
		return
	}
	input.PasswordHash = string(hash)

	// FIXED: Proper error handling for database operations
	if err := database.DB.Create(&input).Error; err != nil {
		// Check for duplicate email
		if errors.Is(err, gorm.ErrDuplicatedKey) ||
			database.DB.Where("email = ?", input.Email).First(&models.Employee{}).Error == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "An employee with this email already exists",
			})
			return
		}

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to create employee",
		})
		return
	}

	c.JSON(http.StatusCreated, gin.H{"data": input})
}

// GetEmployees handler
// FIXED: Added proper error handling
func GetEmployees(c *gin.Context) {
	var employees []models.Employee

	if err := database.DB.Find(&employees).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve employees",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": employees})
}

// SearchEmployees handler
// FIXED: Fixed SQL injection by using parameterized queries with GORM
func SearchEmployees(c *gin.Context) {
	query := c.Query("q")

	// FIXED: Sanitize search query to prevent SQL injection
	query = utils.SanitizeSearchQuery(query)

	if query == "" {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Search query is required",
		})
		return
	}

	var employees []models.Employee

	// FIXED: Use parameterized queries instead of string concatenation
	// GORM automatically escapes parameters, preventing SQL injection
	searchPattern := "%" + query + "%"
	if err := database.DB.Where(
		"(name ILIKE ? OR email ILIKE ? OR position ILIKE ?) AND deleted_at IS NULL",
		searchPattern, searchPattern, searchPattern,
	).Find(&employees).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to search employees",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": employees})
}

// UpdateEmployee handler
// FIXED: Added input validation and proper error handling
func UpdateEmployee(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid employee ID",
		})
		return
	}

	var employee models.Employee
	if err := database.DB.Where("id = ?", id).First(&employee).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Employee not found",
			})
			return
		}

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve employee",
		})
		return
	}

	var input models.Employee
	if err := c.ShouldBindJSON(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid request format",
		})
		return
	}

	// FIXED: Sanitize and validate input
	input.Name = utils.SanitizeString(input.Name)
	input.Email = utils.SanitizeString(input.Email)
	input.Department = utils.SanitizeString(input.Department)
	input.Position = utils.SanitizeString(input.Position)

	if err := utils.ValidateEmployee(&input); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": err.Error(),
		})
		return
	}

	// FIXED: Check for duplicate email if email is being changed
	if input.Email != employee.Email {
		var existingEmployee models.Employee
		if err := database.DB.Where("email = ?", input.Email).First(&existingEmployee).Error; err == nil {
			c.JSON(http.StatusConflict, gin.H{
				"error": "An employee with this email already exists",
			})
			return
		}
	}

	// FIXED: Proper error handling for update
	if err := database.DB.Model(&employee).Updates(input).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to update employee",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": employee})
}

// DeleteEmployee handler
// FIXED: Added proper error handling
func DeleteEmployee(c *gin.Context) {
	idParam := c.Param("id")
	id, err := strconv.ParseUint(idParam, 10, 32)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{
			"error": "Invalid employee ID",
		})
		return
	}

	var employee models.Employee
	if err := database.DB.Where("id = ?", id).First(&employee).Error; err != nil {
		if errors.Is(err, gorm.ErrRecordNotFound) {
			c.JSON(http.StatusNotFound, gin.H{
				"error": "Employee not found",
			})
			return
		}

		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to retrieve employee",
		})
		return
	}

	// FIXED: Proper error handling for delete
	if err := database.DB.Delete(&employee).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": "Failed to delete employee",
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{"data": true})
}
