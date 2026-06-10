// Package server wires rooms to the outside world: the room manager
// (RabbitMQ consumer + result persistence), WebSocket transport, and REST
// endpoints.
package server

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/game/internal/clients"
	"github.com/swarit-1/cipher-clash/services/game/internal/room"
	"github.com/swarit-1/cipher-clash/services/game/internal/store"
)

const roomRetention = 60 * time.Second

// BotFactory creates a bot participant for a room. Injected so the server
// package does not depend on the bot implementation.
type BotFactory func(r *room.Room, bot room.PlayerInfo, opponentELO int, puzzles []room.Puzzle) room.Participant

// Manager owns all live rooms and implements room.ResultSink.
type Manager struct {
	mu    sync.RWMutex
	rooms map[string]*room.Room

	store     *store.Store
	puzzles   *clients.PuzzleClient
	ratings   *clients.RatingsClient
	publisher *messaging.Publisher
	botMaker  BotFactory
	log       *logger.Logger
}

// NewManager creates the room manager.
func NewManager(
	st *store.Store,
	puzzles *clients.PuzzleClient,
	ratings *clients.RatingsClient,
	publisher *messaging.Publisher,
	log *logger.Logger,
) *Manager {
	return &Manager{
		rooms:     make(map[string]*room.Room),
		store:     st,
		puzzles:   puzzles,
		ratings:   ratings,
		publisher: publisher,
		log:       log,
	}
}

// SetBotFactory injects the bot constructor (avoids an import cycle).
func (m *Manager) SetBotFactory(f BotFactory) { m.botMaker = f }

// Get returns a live room.
func (m *Manager) Get(matchID string) (*room.Room, bool) {
	m.mu.RLock()
	defer m.mu.RUnlock()
	r, ok := m.rooms[matchID]
	return r, ok
}

// HandleMatchCreated consumes matchmaker match.created events and spins up
// a room with an ELO-scaled puzzle set.
func (m *Manager) HandleMatchCreated(event messaging.Event) error {
	data := event.Data
	matchID, _ := data["match_id"].(string)
	if matchID == "" {
		m.log.Error("match.created without match_id", nil)
		return nil // unprocessable; don't requeue
	}

	m.mu.RLock()
	_, exists := m.rooms[matchID]
	m.mu.RUnlock()
	if exists {
		return nil // duplicate delivery
	}

	info := room.MatchInfo{
		MatchID:  matchID,
		GameMode: str(data, "game_mode"),
		IsRanked: boolean(data, "is_ranked"),
		Player1: room.PlayerInfo{
			UserID:   str(data, "player1_id"),
			Username: str(data, "player1_username"),
			ELO:      integer(data, "player1_elo"),
		},
		Player2: room.PlayerInfo{
			UserID:   str(data, "player2_id"),
			Username: str(data, "player2_username"),
			ELO:      integer(data, "player2_elo"),
		},
	}
	if info.Player1.UserID == "" || info.Player2.UserID == "" {
		m.log.Error("match.created with missing players", map[string]interface{}{"match_id": matchID})
		return nil
	}

	avgELO := (info.Player1.ELO + info.Player2.ELO) / 2
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	puzzles, err := m.puzzles.MatchSet(ctx, room.DefaultPuzzleCount, avgELO)
	if err != nil {
		m.log.Error("Failed to fetch match puzzles", map[string]interface{}{
			"match_id": matchID, "error": err.Error(),
		})
		return err // requeue: puzzle engine may be restarting
	}
	info.Puzzles = puzzles

	m.createRoom(info)
	m.log.Info("Room created for match", map[string]interface{}{
		"match_id": matchID, "avg_elo": avgELO, "puzzles": len(puzzles),
	})
	return nil
}

// CreateBotMatch provisions a match against the closest-rated bot and
// returns the match id plus opponent info. Used by POST /api/v1/match/bot.
func (m *Manager) CreateBotMatch(ctx context.Context, userID string) (string, room.PlayerInfo, error) {
	if m.botMaker == nil {
		return "", room.PlayerInfo{}, fmt.Errorf("bot factory not configured")
	}

	player, err := m.store.GetPlayer(ctx, userID)
	if err != nil {
		return "", room.PlayerInfo{}, err
	}
	bot, err := m.store.PickBot(ctx, player.ELO)
	if err != nil {
		return "", room.PlayerInfo{}, err
	}
	matchID, err := m.store.CreateBotMatch(ctx, player.UserID, bot.UserID)
	if err != nil {
		return "", room.PlayerInfo{}, err
	}

	avgELO := (player.ELO + bot.ELO) / 2
	puzzles, err := m.puzzles.MatchSet(ctx, room.DefaultPuzzleCount, avgELO)
	if err != nil {
		return "", room.PlayerInfo{}, fmt.Errorf("fetch puzzles: %w", err)
	}

	info := room.MatchInfo{
		MatchID:  matchID,
		GameMode: "BOT_MATCH",
		IsRanked: false,
		Player1:  player,
		Player2:  bot,
		Puzzles:  puzzles,
	}
	r := m.createRoom(info)

	// The bot joins immediately; the human connects via /ws.
	botParticipant := m.botMaker(r, bot, player.ELO, puzzles)
	if err := r.Join(bot.UserID, botParticipant, false); err != nil {
		return "", room.PlayerInfo{}, fmt.Errorf("bot join: %w", err)
	}

	m.log.Info("Bot match created", map[string]interface{}{
		"match_id": matchID, "player": player.Username, "bot": bot.Username,
	})
	return matchID, bot, nil
}

func (m *Manager) createRoom(info room.MatchInfo) *room.Room {
	r := room.New(info, m, m.log)
	m.mu.Lock()
	m.rooms[info.MatchID] = r
	m.mu.Unlock()
	return r
}

// MatchStarted implements room.ResultSink.
func (m *Manager) MatchStarted(matchID string) {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := m.store.MarkStarted(ctx, matchID); err != nil {
		m.log.Error("Failed to mark match started", map[string]interface{}{
			"match_id": matchID, "error": err.Error(),
		})
	}
}

// MatchFinished implements room.ResultSink: persist, apply ratings for
// ranked PvP, publish match.completed, schedule room GC.
func (m *Manager) MatchFinished(result room.MatchResult) *room.RatingOutcome {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := m.store.SaveResult(ctx, result); err != nil {
		m.log.Error("Failed to persist match result", map[string]interface{}{
			"match_id": result.MatchID, "error": err.Error(),
		})
	}

	var outcome *room.RatingOutcome
	hasBot := result.Player1.IsBot || result.Player2.IsBot
	if result.IsRanked && !hasBot && result.WinnerID != "" {
		rating, err := m.ratings.UpdateRatings(ctx, result.MatchID, result.WinnerID,
			result.Player1.UserID, result.Player2.UserID)
		if err != nil {
			m.log.Error("Failed to update ratings", map[string]interface{}{
				"match_id": result.MatchID, "error": err.Error(),
			})
		} else {
			outcome = &room.RatingOutcome{
				Changes: map[string]int{
					rating.Player1ID: rating.Player1Change,
					rating.Player2ID: rating.Player2Change,
				},
				NewElos: map[string]int{
					rating.Player1ID: rating.Player1New,
					rating.Player2ID: rating.Player2New,
				},
			}
		}
	}

	if result.Status == room.StatusCompleted {
		m.publishCompleted(ctx, result, outcome)
	}

	// Retain the room briefly so clients can fetch the final state, then GC.
	matchID := result.MatchID
	time.AfterFunc(roomRetention, func() {
		m.mu.Lock()
		r, ok := m.rooms[matchID]
		if ok {
			delete(m.rooms, matchID)
		}
		m.mu.Unlock()
		if ok {
			r.Shutdown()
		}
	})

	return outcome
}

func (m *Manager) publishCompleted(ctx context.Context, result room.MatchResult, outcome *room.RatingOutcome) {
	loserID := ""
	if result.WinnerID != "" {
		if result.WinnerID == result.Player1.UserID {
			loserID = result.Player2.UserID
		} else {
			loserID = result.Player1.UserID
		}
	}

	attempts := make([]map[string]interface{}, 0, len(result.Attempts))
	for _, a := range result.Attempts {
		attempts = append(attempts, map[string]interface{}{
			"user_id":       a.UserID,
			"puzzle_id":     a.PuzzleID,
			"cipher_type":   a.CipherType,
			"is_correct":    a.IsCorrect,
			"solve_time_ms": a.SolveTimeMs,
		})
	}

	data := map[string]interface{}{
		"match_id":       result.MatchID,
		"game_mode":      result.GameMode,
		"is_ranked":      result.IsRanked,
		"winner_id":      result.WinnerID,
		"loser_id":       loserID,
		"reason":         result.Reason,
		"player1_id":     result.Player1.UserID,
		"player2_id":     result.Player2.UserID,
		"player1_is_bot": result.Player1.IsBot,
		"player2_is_bot": result.Player2.IsBot,
		"scores":         result.Scores,
		"duration_ms":    result.DurationMs,
		"attempts":       attempts,
	}
	if outcome != nil {
		data["elo_changes"] = outcome.Changes
		data["new_elos"] = outcome.NewElos
	}

	if err := m.publisher.Publish(ctx, messaging.ExchangeMatches, "match.completed", messaging.Event{
		Type: messaging.EventMatchCompleted,
		Data: data,
	}); err != nil {
		m.log.Error("Failed to publish match.completed", map[string]interface{}{
			"match_id": result.MatchID, "error": err.Error(),
		})
	}
}

// JSON map coercion helpers (RabbitMQ payloads decode numbers as float64).

func str(m map[string]interface{}, key string) string {
	v, _ := m[key].(string)
	return v
}

func boolean(m map[string]interface{}, key string) bool {
	v, _ := m[key].(bool)
	return v
}

func integer(m map[string]interface{}, key string) int {
	switch v := m[key].(type) {
	case float64:
		return int(v)
	case int:
		return v
	}
	return 0
}
