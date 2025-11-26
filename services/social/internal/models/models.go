package models

import (
	"time"

	"github.com/google/uuid"
)

// Friendship represents a friendship between two users
type Friendship struct {
	ID         uuid.UUID  `json:"id"`
	User1ID    uuid.UUID  `json:"user1_id"`
	User2ID    uuid.UUID  `json:"user2_id"`
	Status     string     `json:"status"`
	CreatedAt  time.Time  `json:"created_at"`
	AcceptedAt *time.Time `json:"accepted_at,omitempty"`
}

// MatchInvite represents an invitation to a match
type MatchInvite struct {
	ID         uuid.UUID `json:"id"`
	FromUserID uuid.UUID `json:"from_user_id"`
	ToUserID   uuid.UUID `json:"to_user_id"`
	GameMode   string    `json:"game_mode"`
	Status     string    `json:"status"`
	CreatedAt  time.Time `json:"created_at"`
	ExpiresAt  time.Time `json:"expires_at"`
}

// SpectatorSession represents a spectator session for a match
type SpectatorSession struct {
	ID       uuid.UUID  `json:"id"`
	UserID   uuid.UUID  `json:"user_id"`
	MatchID  uuid.UUID  `json:"match_id"`
	JoinedAt time.Time  `json:"joined_at"`
	LeftAt   *time.Time `json:"left_at,omitempty"`
}
