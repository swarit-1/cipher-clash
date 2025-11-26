package models

import (
	"time"

	"github.com/google/uuid"
)

type MissionTemplate struct {
	ID              string    `json:"id"`
	Title           string    `json:"title"`
	Description     string    `json:"description"`
	Category        string    `json:"category"`
	Frequency       string    `json:"frequency"`
	Target          int       `json:"target"`
	XPReward        int       `json:"xp_reward"`
	CoinReward      int       `json:"coin_reward"`
	DifficultyLevel int       `json:"difficulty_level"`
	Icon            string    `json:"icon"`
	CreatedAt       time.Time `json:"created_at"`
}

type UserMission struct {
	ID           uuid.UUID        `json:"id"`
	UserID       uuid.UUID        `json:"user_id"`
	TemplateID   string           `json:"template_id"`
	Template     *MissionTemplate `json:"template,omitempty"`
	Progress     int              `json:"progress"`
	Target       int              `json:"target"`
	Status       string           `json:"status"`
	AssignedDate time.Time        `json:"assigned_date"`
	ExpiresAt    time.Time        `json:"expires_at"`
	CompletedAt  *time.Time       `json:"completed_at,omitempty"`
	ClaimedAt    *time.Time       `json:"claimed_at,omitempty"`
}

type MissionStats struct {
	TotalAssigned    int     `json:"total_assigned"`
	TotalCompleted   int     `json:"total_completed"`
	TotalClaimed     int     `json:"total_claimed"`
	CompletionRate   float64 `json:"completion_rate"`
	CurrentStreak    int     `json:"current_streak"`
	LongestStreak    int     `json:"longest_streak"`
	TotalXPEarned    int     `json:"total_xp_earned"`
	TotalCoinsEarned int     `json:"total_coins_earned"`
}

type UpdateProgressRequest struct {
	UserMissionID uuid.UUID `json:"user_mission_id"`
	Progress      int       `json:"progress"`
}

type CompleteMissionRequest struct {
	UserMissionID uuid.UUID `json:"user_mission_id"`
}

type ClaimRewardRequest struct {
	UserMissionID uuid.UUID `json:"user_mission_id"`
}

type AssignMissionsRequest struct {
	UserID uuid.UUID `json:"user_id"`
}

type RefreshMissionsRequest struct {
	UserID uuid.UUID `json:"user_id"`
}
