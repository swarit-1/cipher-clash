package service

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/queue"
)

// MatchmakerService handles matchmaking operations
type MatchmakerService struct {
	db       *db.DB
	cache    *cache.Cache
	queue    *queue.MatchmakingQueue
	publisher *messaging.Publisher
	log      *logger.Logger
}

// NewMatchmakerService creates a new matchmaker service
func NewMatchmakerService(
	database *db.DB,
	cacheClient *cache.Cache,
	queueSystem *queue.MatchmakingQueue,
	pub *messaging.Publisher,
	log *logger.Logger,
) *MatchmakerService {
	ms := &MatchmakerService{
		db:       database,
		cache:    cacheClient,
		queue:    queueSystem,
		publisher: pub,
		log:      log,
	}

	// Start listening for matches
	go ms.handleMatches()

	return ms
}

// JoinQueueRequest represents queue join input
type JoinQueueRequest struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	ELO      int    `json:"elo"`
	Region   string `json:"region"`
	GameMode string `json:"game_mode"`
}

// JoinQueueResponse represents queue join result
type JoinQueueResponse struct {
	QueueID                string `json:"queue_id"`
	EstimatedWaitSeconds   int    `json:"estimated_wait_time_seconds"`
	PlayersInQueue         int    `json:"players_in_queue"`
	Position               int    `json:"position"`
}

// LeaderboardEntry represents a leaderboard entry
type LeaderboardEntry struct {
	Rank        int     `json:"rank"`
	UserID      string  `json:"user_id"`
	Username    string  `json:"username"`
	DisplayName string  `json:"display_name"`
	AvatarURL   string  `json:"avatar_url"`
	EloRating   int     `json:"elo_rating"`
	RankTier    string  `json:"rank_tier"`
	TotalGames  int     `json:"total_games"`
	Wins        int     `json:"wins"`
	Losses      int     `json:"losses"`
	WinRate     float64 `json:"win_rate"`
	WinStreak   int     `json:"win_streak"`
}

// JoinQueue adds a player to matchmaking
func (ms *MatchmakerService) JoinQueue(ctx context.Context, req *JoinQueueRequest) (*JoinQueueResponse, error) {
	// Validate game mode
	if req.GameMode == "" {
		req.GameMode = "RANKED_1V1"
	}

	// Create queue entry
	entry := &queue.QueueEntry{
		UserID:   req.UserID,
		Username: req.Username,
		ELO:      req.ELO,
		Region:   req.Region,
		GameMode: req.GameMode,
	}

	// Add to queue
	if err := ms.queue.AddPlayer(entry); err != nil {
		return nil, errors.NewAlreadyInQueueError()
	}

	// Get queue status
	_, playersInQueue, _ := ms.queue.GetQueueStatus(req.UserID)

	// Save queue metrics
	go ms.saveQueueMetrics(context.Background(), req.UserID, req.GameMode, req.ELO, req.Region)

	// Publish event
	ms.publisher.Publish(ctx, messaging.ExchangeQueue, "player.joined", messaging.Event{
		Type: messaging.EventPlayerJoinedQueue,
		Data: map[string]interface{}{
			"user_id":   req.UserID,
			"game_mode": req.GameMode,
			"elo":       req.ELO,
		},
	})

	ms.log.Info("Player joined queue", map[string]interface{}{
		"user_id":          req.UserID,
		"game_mode":        req.GameMode,
		"players_in_queue": playersInQueue,
	})

	return &JoinQueueResponse{
		QueueID:              req.UserID, // Using userID as queue ID
		EstimatedWaitSeconds: ms.estimateWaitTime(req.ELO, playersInQueue),
		PlayersInQueue:       playersInQueue,
		Position:             playersInQueue,
	}, nil
}

// LeaveQueue removes a player from matchmaking
func (ms *MatchmakerService) LeaveQueue(ctx context.Context, userID string) error {
	removed := ms.queue.RemovePlayer(userID)
	if !removed {
		return errors.NewInvalidInputError("Player not in queue")
	}

	// Publish event
	ms.publisher.Publish(ctx, messaging.ExchangeQueue, "player.left", messaging.Event{
		Type: messaging.EventPlayerLeftQueue,
		Data: map[string]interface{}{
			"user_id": userID,
		},
	})

	ms.log.Info("Player left queue", map[string]interface{}{
		"user_id": userID,
	})

	return nil
}

// GetQueueStatus returns current queue status for a player
func (ms *MatchmakerService) GetQueueStatus(ctx context.Context, userID string) (map[string]interface{}, error) {
	entry, playersInQueue, err := ms.queue.GetQueueStatus(userID)
	if err != nil {
		return nil, errors.NewInvalidInputError("Player not in queue")
	}

	waitSeconds := int(entry.QueuedAt.Unix())

	return map[string]interface{}{
		"in_queue":         true,
		"wait_time_seconds": waitSeconds,
		"players_in_queue": playersInQueue,
		"game_mode":        entry.GameMode,
		"search_range":     entry.SearchRange,
	}, nil
}

// GetLeaderboard retrieves top players
func (ms *MatchmakerService) GetLeaderboard(ctx context.Context, region string, seasonID, limit, offset int) ([]*LeaderboardEntry, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("leaderboard:%s:%d:%d:%d", region, seasonID, limit, offset)
	var cachedLeaderboard []*LeaderboardEntry
	if err := ms.cache.Get(ctx, cacheKey, &cachedLeaderboard); err == nil {
		return cachedLeaderboard, nil
	}

	// Query from database
	query := `
		SELECT
			ROW_NUMBER() OVER (ORDER BY elo_rating DESC) as rank,
			id, username, display_name, avatar_url, elo_rating, rank_tier,
			total_games, wins, losses, win_streak,
			CASE WHEN total_games > 0 THEN ROUND((wins::FLOAT / total_games::FLOAT) * 100, 2) ELSE 0 END as win_rate
		FROM users
		WHERE is_banned = FALSE AND total_games >= 10
	`

	// Add region filter if specified
	if region != "" {
		query += ` AND region = $1`
	}

	query += ` ORDER BY elo_rating DESC LIMIT $2 OFFSET $3`

	var rows *sql.Rows
	var err error

	if region != "" {
		rows, err = ms.db.QueryContext(ctx, query, region, limit, offset)
	} else {
		rows, err = ms.db.QueryContext(ctx, query, limit, offset)
	}

	if err != nil {
		return nil, errors.NewDatabaseError(err)
	}
	defer rows.Close()

	entries := make([]*LeaderboardEntry, 0)
	for rows.Next() {
		entry := &LeaderboardEntry{}
		var displayName, avatarURL sql.NullString

		err := rows.Scan(
			&entry.Rank,
			&entry.UserID,
			&entry.Username,
			&displayName,
			&avatarURL,
			&entry.EloRating,
			&entry.RankTier,
			&entry.TotalGames,
			&entry.Wins,
			&entry.Losses,
			&entry.WinStreak,
			&entry.WinRate,
		)
		if err != nil {
			return nil, errors.NewDatabaseError(err)
		}

		if displayName.Valid {
			entry.DisplayName = displayName.String
		}
		if avatarURL.Valid {
			entry.AvatarURL = avatarURL.String
		}

		entries = append(entries, entry)
	}

	// Cache for 1 minute
	ms.cache.Set(ctx, cacheKey, entries, cache.TTLLeaderboard)

	return entries, nil
}

// UpdateRatings updates player ELO after a match
func (ms *MatchmakerService) UpdateRatings(ctx context.Context, matchID, winnerID string, player1ID, player2ID string, p1ELO, p2ELO int) error {
	// Calculate ELO changes using simplified algorithm
	k := 32 // K-factor

	// Expected scores
	expectedP1 := 1.0 / (1.0 + pow10((float64(p2ELO-p1ELO))/400.0))
	expectedP2 := 1.0 / (1.0 + pow10((float64(p1ELO-p2ELO))/400.0))

	// Actual scores
	actualP1 := 0.0
	actualP2 := 0.0
	if winnerID == player1ID {
		actualP1 = 1.0
	} else {
		actualP2 = 1.0
	}

	// New ELOs
	newP1ELO := p1ELO + int(float64(k)*(actualP1-expectedP1))
	newP2ELO := p2ELO + int(float64(k)*(actualP2-expectedP2))

	// Update database
	query := `UPDATE users SET elo_rating = $1, updated_at = NOW() WHERE id = $2`
	_, err := ms.db.ExecContext(ctx, query, newP1ELO, player1ID)
	if err != nil {
		return errors.NewDatabaseError(err)
	}

	_, err = ms.db.ExecContext(ctx, query, newP2ELO, player2ID)
	if err != nil {
		return errors.NewDatabaseError(err)
	}

	// Update match with ELO changes
	matchQuery := `
		UPDATE matches
		SET elo_change_p1 = $1, elo_change_p2 = $2
		WHERE id = $3
	`
	_, err = ms.db.ExecContext(ctx, matchQuery, newP1ELO-p1ELO, newP2ELO-p2ELO, matchID)

	// Invalidate leaderboard cache
	ms.cache.Delete(ctx, "leaderboard:*")

	ms.log.Info("ELO ratings updated", map[string]interface{}{
		"match_id":    matchID,
		"player1_elo": fmt.Sprintf("%d -> %d", p1ELO, newP1ELO),
		"player2_elo": fmt.Sprintf("%d -> %d", p2ELO, newP2ELO),
	})

	return nil
}

// Helper functions

func (ms *MatchmakerService) handleMatches() {
	for match := range ms.queue.GetMatches() {
		go ms.createMatch(context.Background(), match)
	}
}

func (ms *MatchmakerService) createMatch(ctx context.Context, match *queue.Match) {
	// Get current season
	seasonID := 1 // TODO: Get active season from DB

	// Create match in database
	query := `
		INSERT INTO matches (id, player1_id, player2_id, game_mode_id, season_id, status)
		VALUES ($1, $2, $3, (SELECT id FROM game_modes WHERE name = $4), $5, 'WAITING')
	`

	_, err := ms.db.ExecContext(ctx, query,
		match.MatchID,
		match.Player1.UserID,
		match.Player2.UserID,
		match.GameMode,
		seasonID,
	)

	if err != nil {
		ms.log.Error("Failed to create match", map[string]interface{}{
			"error": err.Error(),
		})
		return
	}

	// Publish match created event
	ms.publisher.Publish(ctx, messaging.ExchangeMatches, "match.created", messaging.Event{
		Type: messaging.EventMatchCreated,
		Data: map[string]interface{}{
			"match_id":   match.MatchID,
			"player1_id": match.Player1.UserID,
			"player2_id": match.Player2.UserID,
			"game_mode":  match.GameMode,
		},
	})

	// Cache match details
	cacheKey := fmt.Sprintf("match:%s", match.MatchID)
	ms.cache.Set(ctx, cacheKey, match, cache.TTLActiveGame)

	ms.log.Info("Match created successfully", map[string]interface{}{
		"match_id": match.MatchID,
	})
}

func (ms *MatchmakerService) saveQueueMetrics(ctx context.Context, userID, gameMode string, elo int, region string) {
	query := `
		INSERT INTO queue_metrics (id, user_id, game_mode_id, elo_at_queue, region)
		VALUES ($1, $2, (SELECT id FROM game_modes WHERE name = $3), $4, $5)
	`
	_, err := ms.db.ExecContext(ctx, query, uuid.New().String(), userID, gameMode, elo, region)
	if err != nil {
		ms.log.Error("Failed to save queue metrics", map[string]interface{}{
			"error": err.Error(),
		})
	}
}

func (ms *MatchmakerService) estimateWaitTime(elo, playersInQueue int) int {
	// Simple estimation: fewer players = longer wait
	if playersInQueue < 5 {
		return 30
	} else if playersInQueue < 20 {
		return 15
	}
	return 10
}

func pow10(x float64) float64 {
	result := 1.0
	for i := 0; i < int(x*10); i++ {
		result *= 1.1
	}
	return result
}
