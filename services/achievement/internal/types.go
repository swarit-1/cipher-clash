package internal

import "time"

// Achievement represents a game achievement
type Achievement struct {
	ID          string    `json:"id" db:"id"`
	Name        string    `json:"name" db:"name"`
	Description string    `json:"description" db:"description"`
	Icon        string    `json:"icon" db:"icon"` // Icon name or emoji
	Rarity      string    `json:"rarity" db:"rarity"` // COMMON, RARE, EPIC, LEGENDARY
	XPReward    int       `json:"xp_reward" db:"xp_reward"`
	Requirement string    `json:"requirement" db:"requirement"` // JSON for requirement criteria
	Total       int       `json:"total" db:"total"` // Total count needed (e.g., 100 wins)
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// UserAchievement represents a user's progress on an achievement
type UserAchievement struct {
	ID            string    `json:"id" db:"id"`
	UserID        string    `json:"user_id" db:"user_id"`
	AchievementID string    `json:"achievement_id" db:"achievement_id"`
	Progress      int       `json:"progress" db:"progress"` // Current count
	Unlocked      bool      `json:"unlocked" db:"unlocked"`
	UnlockedAt    *time.Time `json:"unlocked_at,omitempty" db:"unlocked_at"`
	CreatedAt     time.Time `json:"created_at" db:"created_at"`
	UpdatedAt     time.Time `json:"updated_at" db:"updated_at"`
}

// AchievementWithProgress combines achievement and user progress
type AchievementWithProgress struct {
	Achievement
	Progress   int        `json:"progress"`
	Unlocked   bool       `json:"unlocked"`
	UnlockedAt *time.Time `json:"unlocked_at,omitempty"`
}

// UserAchievementStats represents user's overall achievement statistics
type UserAchievementStats struct {
	UserID           string `json:"user_id"`
	TotalAchievements int    `json:"total_achievements"`
	UnlockedCount    int    `json:"unlocked_count"`
	TotalXPEarned    int    `json:"total_xp_earned"`
	CompletionRate   float64 `json:"completion_rate"` // Percentage
	LegendaryCount   int    `json:"legendary_count"`
	EpicCount        int    `json:"epic_count"`
	RareCount        int    `json:"rare_count"`
	CommonCount      int    `json:"common_count"`
}

// CreateAchievementRequest represents request to create achievement
type CreateAchievementRequest struct {
	Name        string `json:"name" validate:"required,min=3,max=100"`
	Description string `json:"description" validate:"required,min=10,max=500"`
	Icon        string `json:"icon" validate:"required"`
	Rarity      string `json:"rarity" validate:"required,oneof=COMMON RARE EPIC LEGENDARY"`
	XPReward    int    `json:"xp_reward" validate:"required,min=10,max=1000"`
	Requirement string `json:"requirement" validate:"required"`
	Total       int    `json:"total" validate:"required,min=1"`
}

// UpdateAchievementRequest represents request to update achievement
type UpdateAchievementRequest struct {
	ID          string `json:"id" validate:"required,uuid"`
	Name        string `json:"name,omitempty" validate:"omitempty,min=3,max=100"`
	Description string `json:"description,omitempty" validate:"omitempty,min=10,max=500"`
	Icon        string `json:"icon,omitempty"`
	Rarity      string `json:"rarity,omitempty" validate:"omitempty,oneof=COMMON RARE EPIC LEGENDARY"`
	XPReward    int    `json:"xp_reward,omitempty" validate:"omitempty,min=10,max=1000"`
	Requirement string `json:"requirement,omitempty"`
	Total       int    `json:"total,omitempty" validate:"omitempty,min=1"`
}

// AchievementProgress Event represents achievement progress update
type AchievementProgressEvent struct {
	UserID          string    `json:"user_id"`
	AchievementType string    `json:"achievement_type"` // e.g., "wins", "cipher_solved", etc.
	Increment       int       `json:"increment"`
	Timestamp       time.Time `json:"timestamp"`
}
