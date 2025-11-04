package models

import (
	"time"

	"gorm.io/gorm"
)

type Employee struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	Name         string         `json:"name"`
	Email        string         `json:"email"`
	Department   string         `json:"department"`
	Position     string         `json:"position"`
	Salary       float64        `json:"salary"`
	PasswordHash string         `json:"-"` // To demonstrate weak hashing
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

// Note: No input validation tags are present.