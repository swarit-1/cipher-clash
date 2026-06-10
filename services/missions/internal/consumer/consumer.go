// Package consumer advances mission progress from match.completed events,
// so daily/weekly missions track real gameplay instead of manual POSTs.
package consumer

import (
	"context"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/missions/internal/service"
)

// Consumer applies match results to active missions.
type Consumer struct {
	svc *service.MissionsService
	db  *db.DB
	log *logger.Logger
}

// New creates the consumer.
func New(svc *service.MissionsService, database *db.DB, log *logger.Logger) *Consumer {
	return &Consumer{svc: svc, db: database, log: log}
}

// knownCiphers maps mission-template id fragments to cipher types for
// CIPHER_SPECIFIC missions (e.g. daily_caesar_3 -> CAESAR).
var knownCiphers = []string{
	"CAESAR", "VIGENERE", "RAIL_FENCE", "PLAYFAIR", "SUBSTITUTION",
	"TRANSPOSITION", "XOR", "BASE64", "MORSE", "BINARY", "HEXADECIMAL",
	"ROT13", "ATBASH", "BOOK_CIPHER", "RSA", "AFFINE", "AUTOKEY", "ENIGMA",
}

func cipherFromTemplateID(templateID string) string {
	upper := strings.ToUpper(templateID)
	for _, c := range knownCiphers {
		if strings.Contains(upper, c) {
			return c
		}
	}
	return ""
}

// HandleMatchCompleted advances every active mission of both human players.
func (c *Consumer) HandleMatchCompleted(event messaging.Event) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	data := event.Data
	winnerID, _ := data["winner_id"].(string)
	players := []struct {
		id    string
		isBot bool
	}{
		{str(data, "player1_id"), boolean(data, "player1_is_bot")},
		{str(data, "player2_id"), boolean(data, "player2_is_bot")},
	}

	// Per-user correct solve counts, total and per cipher type.
	solvedTotal := map[string]int{}
	solvedByCipher := map[string]map[string]int{}
	if attempts, ok := data["attempts"].([]interface{}); ok {
		for _, item := range attempts {
			m, ok := item.(map[string]interface{})
			if !ok || m["is_correct"] != true {
				continue
			}
			uid, _ := m["user_id"].(string)
			cipher, _ := m["cipher_type"].(string)
			solvedTotal[uid]++
			if solvedByCipher[uid] == nil {
				solvedByCipher[uid] = map[string]int{}
			}
			solvedByCipher[uid][strings.ToUpper(cipher)]++
		}
	}

	for _, p := range players {
		if p.id == "" || p.isBot {
			continue
		}
		userID, err := uuid.Parse(p.id)
		if err != nil {
			continue
		}

		missions, err := c.svc.GetActiveMissions(ctx, userID)
		if err != nil {
			c.log.LogError("Failed to load active missions", "user_id", p.id, "error", err)
			continue
		}
		if len(missions) == 0 {
			continue
		}

		won := p.id == winnerID
		var winStreak int
		if won {
			_ = c.db.QueryRowContext(ctx, `SELECT win_streak FROM users WHERE id = $1`, p.id).Scan(&winStreak)
		}

		for _, mission := range missions {
			if mission.Status != "active" || mission.Template == nil {
				continue
			}

			newProgress := mission.Progress
			switch mission.Template.Category {
			case "PLAY":
				newProgress++
			case "WINS":
				if won {
					newProgress++
				}
			case "PUZZLES":
				newProgress += solvedTotal[p.id]
			case "CIPHER_SPECIFIC":
				cipher := cipherFromTemplateID(mission.TemplateID)
				if cipher != "" {
					newProgress += solvedByCipher[p.id][cipher]
				}
			case "STREAK":
				if winStreak > newProgress {
					newProgress = winStreak
				}
			}

			if newProgress == mission.Progress {
				continue
			}
			if _, err := c.svc.UpdateMissionProgress(ctx, userID, mission.TemplateID, newProgress); err != nil {
				c.log.LogError("Failed to update mission progress",
					"user_id", p.id, "template", mission.TemplateID, "error", err)
			}
		}
	}
	return nil
}

func str(m map[string]interface{}, key string) string {
	v, _ := m[key].(string)
	return v
}

func boolean(m map[string]interface{}, key string) bool {
	v, _ := m[key].(bool)
	return v
}
