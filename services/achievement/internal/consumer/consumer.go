// Package consumer turns match.completed events into achievement progress,
// unlocks, and XP awards — the piece that makes achievements actually
// unlock from gameplay.
package consumer

import (
	"context"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	internal "github.com/swarit-1/cipher-clash/services/achievement/internal"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/repository"
)

// requirement is the parsed achievements.requirement JSON.
type requirement struct {
	Type    string `json:"type"`
	UnderMs int64  `json:"under_ms,omitempty"`
}

// Requirement types and their progress semantics:
//
//	TOTAL_WINS, TOTAL_GAMES, PUZZLES_SOLVED, BOT_WINS, PERFECT_MATCHES —
//	    incremented by deltas from each match
//	WIN_STREAK, ELO_RATING — absolute values; progress is max-so-far
//	FASTEST_SOLVE_MS — unlocks when any solve beats requirement.under_ms
const (
	reqTotalWins      = "TOTAL_WINS"
	reqTotalGames     = "TOTAL_GAMES"
	reqPuzzlesSolved  = "PUZZLES_SOLVED"
	reqBotWins        = "BOT_WINS"
	reqPerfectMatches = "PERFECT_MATCHES"
	reqWinStreak      = "WIN_STREAK"
	reqEloRating      = "ELO_RATING"
	reqFastestSolve   = "FASTEST_SOLVE_MS"
)

// Consumer applies match results to achievement progress.
type Consumer struct {
	achievements repository.AchievementRepository
	progress     repository.UserAchievementRepository
	db           *db.DB
	cache        *cache.Cache
	publisher    *messaging.Publisher
	log          *logger.Logger
}

// New creates the consumer.
func New(
	achievements repository.AchievementRepository,
	progress repository.UserAchievementRepository,
	database *db.DB,
	cacheClient *cache.Cache,
	publisher *messaging.Publisher,
	log *logger.Logger,
) *Consumer {
	return &Consumer{
		achievements: achievements,
		progress:     progress,
		db:           database,
		cache:        cacheClient,
		publisher:    publisher,
		log:          log,
	}
}

type attempt struct {
	UserID      string
	CipherType  string
	IsCorrect   bool
	SolveTimeMs int64
}

// HandleMatchCompleted processes one match.completed event.
func (c *Consumer) HandleMatchCompleted(event messaging.Event) error {
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()

	data := event.Data
	winnerID, _ := data["winner_id"].(string)
	p1, _ := data["player1_id"].(string)
	p2, _ := data["player2_id"].(string)
	p1Bot, _ := data["player1_is_bot"].(bool)
	p2Bot, _ := data["player2_is_bot"].(bool)
	attempts := parseAttempts(data["attempts"])
	newElos := parseIntMap(data["new_elos"])

	all, err := c.achievements.GetAll(ctx)
	if err != nil {
		return err
	}

	type playerCtx struct {
		id          string
		isBot       bool
		opponentBot bool
	}
	players := []playerCtx{
		{id: p1, isBot: p1Bot, opponentBot: p2Bot},
		{id: p2, isBot: p2Bot, opponentBot: p1Bot},
	}

	for _, p := range players {
		if p.id == "" || p.isBot {
			continue
		}

		won := p.id == winnerID
		solved := 0
		wrong := 0
		var fastest int64 = -1
		for _, a := range attempts {
			if a.UserID != p.id {
				continue
			}
			if a.IsCorrect {
				solved++
				if fastest < 0 || a.SolveTimeMs < fastest {
					fastest = a.SolveTimeMs
				}
			} else {
				wrong++
			}
		}

		// Current streak for absolute-progress achievements.
		var winStreak int
		_ = c.db.QueryRowContext(ctx, `SELECT win_streak FROM users WHERE id = $1`, p.id).Scan(&winStreak)

		for _, ach := range all {
			var req requirement
			if err := json.Unmarshal([]byte(ach.Requirement), &req); err != nil {
				continue
			}

			delta, absolute := 0, -1
			switch req.Type {
			case reqTotalGames:
				delta = 1
			case reqTotalWins:
				if won {
					delta = 1
				}
			case reqBotWins:
				if won && p.opponentBot {
					delta = 1
				}
			case reqPuzzlesSolved:
				delta = solved
			case reqPerfectMatches:
				if won && wrong == 0 && solved > 0 {
					delta = 1
				}
			case reqWinStreak:
				absolute = winStreak
			case reqEloRating:
				if elo, ok := newElos[p.id]; ok {
					absolute = elo
				}
			case reqFastestSolve:
				if fastest >= 0 && req.UnderMs > 0 && fastest < req.UnderMs {
					absolute = ach.Total // immediate unlock
				}
			default:
				continue
			}

			if delta == 0 && absolute < 0 {
				continue
			}
			if err := c.applyProgress(ctx, p.id, ach, delta, absolute); err != nil {
				c.log.Error("Failed to apply achievement progress", map[string]interface{}{
					"user_id": p.id, "achievement": ach.ID, "error": err.Error(),
				})
			}
		}

		c.cache.Delete(ctx, "user:"+p.id+":achievements", "user:"+p.id+":achievement_stats")
	}
	return nil
}

// applyProgress upserts progress and, on crossing the target, unlocks the
// achievement, credits its XP to the user, and publishes the unlock event.
func (c *Consumer) applyProgress(ctx context.Context, userID string, ach *internal.Achievement, delta, absolute int) error {
	ua, err := c.progress.GetByUserAndAchievement(ctx, userID, ach.ID)
	if err != nil || ua == nil {
		ua = &internal.UserAchievement{
			ID:            uuid.New().String(),
			UserID:        userID,
			AchievementID: ach.ID,
		}
		if err := c.progress.Create(ctx, ua); err != nil {
			return err
		}
	}
	if ua.Unlocked {
		return nil
	}

	newProgress := ua.Progress + delta
	if absolute >= 0 && absolute > newProgress {
		newProgress = absolute
	}
	if newProgress <= ua.Progress {
		return nil
	}
	if newProgress > ach.Total {
		newProgress = ach.Total
	}

	if err := c.progress.UpdateProgress(ctx, userID, ach.ID, newProgress); err != nil {
		return err
	}
	if newProgress < ach.Total {
		return nil
	}

	if err := c.progress.UnlockAchievement(ctx, userID, ach.ID); err != nil {
		return err
	}
	if ach.XPReward > 0 {
		if _, err := c.db.ExecContext(ctx,
			`UPDATE users SET xp = xp + $2 WHERE id = $1`, userID, ach.XPReward); err != nil {
			c.log.Error("Failed to credit achievement XP", map[string]interface{}{
				"user_id": userID, "achievement": ach.ID, "error": err.Error(),
			})
		}
	}

	c.log.Info("Achievement unlocked", map[string]interface{}{
		"user_id": userID, "achievement": ach.ID, "name": ach.Name, "xp": ach.XPReward,
	})
	c.publisher.Publish(ctx, messaging.ExchangeAchievements, "achievement.unlocked", messaging.Event{
		Type: messaging.EventAchievementUnlocked,
		Data: map[string]interface{}{
			"user_id":        userID,
			"achievement_id": ach.ID,
			"name":           ach.Name,
			"rarity":         ach.Rarity,
			"xp_reward":      ach.XPReward,
		},
	})
	return nil
}

func parseAttempts(raw interface{}) []attempt {
	list, ok := raw.([]interface{})
	if !ok {
		return nil
	}
	out := make([]attempt, 0, len(list))
	for _, item := range list {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		a := attempt{}
		a.UserID, _ = m["user_id"].(string)
		a.CipherType, _ = m["cipher_type"].(string)
		a.IsCorrect, _ = m["is_correct"].(bool)
		if v, ok := m["solve_time_ms"].(float64); ok {
			a.SolveTimeMs = int64(v)
		}
		out = append(out, a)
	}
	return out
}

func parseIntMap(raw interface{}) map[string]int {
	m, ok := raw.(map[string]interface{})
	if !ok {
		return nil
	}
	out := make(map[string]int, len(m))
	for k, v := range m {
		if f, ok := v.(float64); ok {
			out[k] = int(f)
		}
	}
	return out
}
