// Package consumer feeds cipher mastery progression from match.completed
// events: every correct solve earns per-cipher mastery XP.
package consumer

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/service"
)

const (
	pointsPerSolve = 15
	winBonus       = 5
)

// Consumer applies match results to cipher mastery.
type Consumer struct {
	svc *service.MasteryService
	log *logger.Logger
}

// New creates the consumer.
func New(svc *service.MasteryService, log *logger.Logger) *Consumer {
	return &Consumer{svc: svc, log: log}
}

// HandleMatchCompleted awards mastery points for every correct solve by a
// human player; the match winner earns a small bonus per solve.
func (c *Consumer) HandleMatchCompleted(event messaging.Event) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	data := event.Data
	winnerID, _ := data["winner_id"].(string)
	bots := map[string]bool{}
	if id, ok := data["player1_id"].(string); ok {
		bots[id], _ = data["player1_is_bot"].(bool)
	}
	if id, ok := data["player2_id"].(string); ok {
		bots[id], _ = data["player2_is_bot"].(bool)
	}

	attempts, ok := data["attempts"].([]interface{})
	if !ok {
		return nil
	}

	for _, item := range attempts {
		m, ok := item.(map[string]interface{})
		if !ok || m["is_correct"] != true {
			continue
		}
		uid, _ := m["user_id"].(string)
		cipher, _ := m["cipher_type"].(string)
		if uid == "" || cipher == "" || bots[uid] {
			continue
		}
		userID, err := uuid.Parse(uid)
		if err != nil {
			continue
		}

		var solveMs int64
		if v, ok := m["solve_time_ms"].(float64); ok {
			solveMs = int64(v)
		}

		points := pointsPerSolve
		if uid == winnerID {
			points += winBonus
		}
		if err := c.svc.RecordSolve(ctx, userID, cipher, solveMs, points); err != nil {
			c.log.LogError("Failed to record mastery solve", "user_id", uid, "error", err)
		}
	}
	return nil
}
