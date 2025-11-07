package models

import (
	"time"

	"gorm.io/gorm"
)

type Employee struct {
	ID           uint           `gorm:"primarykey" json:"id"`
	Name         string         `gorm:"not null;size:255" json:"name" validate:"required,min=1,max=255"`
	Email        string         `gorm:"not null;uniqueIndex;size:255" json:"email" validate:"required,email,max=255"`
	Department   string         `gorm:"size:100" json:"department" validate:"max=100"`
	Position     string         `gorm:"size:100" json:"position" validate:"max=100"`
	Salary       float64        `gorm:"type:decimal(10,2);check:salary >= 0" json:"salary" validate:"gte=0"`
	PasswordHash string         `gorm:"size:255" json:"-"` // FIXED: Using bcrypt (60 chars) instead of MD5
	CreatedAt    time.Time      `json:"created_at"`
	UpdatedAt    time.Time      `json:"updated_at"`
	DeletedAt    gorm.DeletedAt `gorm:"index" json:"-"`
}

// FIXED: Added validation tags for input validation
// The validate tags are used by the validator package to ensure data integrity
