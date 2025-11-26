package models

import (
	"time"

	"github.com/google/uuid"
)

type MasteryNode struct {
	ID               string  `json:"id"`
	CipherType       string  `json:"cipher_type"`
	Tier             int     `json:"tier"`
	Name             string  `json:"name"`
	Description      string  `json:"description"`
	UnlockCost       int     `json:"unlock_cost"`
	PrerequisiteNode *string `json:"prerequisite_node"`
	BonusType        string  `json:"bonus_type"`
	BonusValue       float64 `json:"bonus_value"`
	Icon             string  `json:"icon"`
}

type UserMasteryNode struct {
	ID          uuid.UUID    `json:"id"`
	UserID      uuid.UUID    `json:"user_id"`
	NodeID      string       `json:"node_id"`
	Node        *MasteryNode `json:"node,omitempty"`
	UnlockedAt  time.Time    `json:"unlocked_at"`
	PointsSpent int          `json:"points_spent"`
}

type CipherMasteryPoints struct {
	UserID           uuid.UUID `json:"user_id"`
	CipherType       string    `json:"cipher_type"`
	TotalPoints      int       `json:"total_points"`
	AvailablePoints  int       `json:"available_points"`
	SpentPoints      int       `json:"spent_points"`
	Level            int       `json:"level"`
	PuzzlesSolved    int       `json:"puzzles_solved"`
	TotalSolveTimeMS int64     `json:"total_solve_time_ms"`
	FastestSolveMS   int64     `json:"fastest_solve_ms"`
}

type MasteryTree struct {
	CipherType string              `json:"cipher_type"`
	Tiers      map[int][]*MasteryNode `json:"tiers"`
	TotalNodes int                 `json:"total_nodes"`
}

type LeaderboardEntry struct {
	UserID      uuid.UUID `json:"user_id"`
	Username    string    `json:"username"`
	TotalPoints int       `json:"total_points"`
	Level       int       `json:"level"`
	Rank        int       `json:"rank"`
}
