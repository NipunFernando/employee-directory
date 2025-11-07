package utils

import (
	"employee-directory-demo/v2/backend/models"
	"errors"
	"fmt"
	"regexp"
	"strings"

	"github.com/go-playground/validator/v10"
)

var validate *validator.Validate

func init() {
	validate = validator.New()

	// Register custom validation for email format
	validate.RegisterValidation("email", func(fl validator.FieldLevel) bool {
		email := fl.Field().String()
		emailRegex := regexp.MustCompile(`^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$`)
		return emailRegex.MatchString(email)
	})
}

// ValidateEmployee validates an employee struct and returns formatted error messages
func ValidateEmployee(emp *models.Employee) error {
	if err := validate.Struct(emp); err != nil {
		var validationErrors []string

		for _, err := range err.(validator.ValidationErrors) {
			field := err.Field()
			tag := err.Tag()

			var message string
			switch tag {
			case "required":
				message = fmt.Sprintf("%s is required", field)
			case "email":
				message = fmt.Sprintf("%s must be a valid email address", field)
			case "min":
				message = fmt.Sprintf("%s must be at least %s characters", field, err.Param())
			case "max":
				message = fmt.Sprintf("%s must be at most %s characters", field, err.Param())
			case "gte":
				message = fmt.Sprintf("%s must be greater than or equal to %s", field, err.Param())
			default:
				message = fmt.Sprintf("%s is invalid", field)
			}

			validationErrors = append(validationErrors, message)
		}

		return errors.New(strings.Join(validationErrors, "; "))
	}

	return nil
}

// SanitizeString removes potentially dangerous characters from user input
func SanitizeString(input string) string {
	// Remove null bytes and control characters
	input = strings.ReplaceAll(input, "\x00", "")
	input = strings.ReplaceAll(input, "\r", "")
	input = strings.ReplaceAll(input, "\n", "")
	input = strings.ReplaceAll(input, "\t", "")

	// Trim whitespace
	input = strings.TrimSpace(input)

	return input
}

// SanitizeSearchQuery sanitizes search input to prevent SQL injection
func SanitizeSearchQuery(query string) string {
	// Remove SQL injection patterns
	query = strings.ToLower(query)
	query = strings.ReplaceAll(query, ";", "")
	query = strings.ReplaceAll(query, "--", "")
	query = strings.ReplaceAll(query, "/*", "")
	query = strings.ReplaceAll(query, "*/", "")
	query = strings.ReplaceAll(query, "'", "")
	query = strings.ReplaceAll(query, "\"", "")
	query = strings.ReplaceAll(query, "\\", "")

	// Trim and limit length
	query = strings.TrimSpace(query)
	if len(query) > 100 {
		query = query[:100]
	}

	return query
}
