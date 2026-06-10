package service

import (
	"context"
	"database/sql"
	"fmt"
	"math"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/queue"
)

const matchAssignmentTTL = 2 * time.Minute

// MatchmakerService handles matchmaking operations
type MatchmakerService struct {
	db        *db.DB
	cache     *cache.Cache
	queue     *queue.MatchmakingQueue
	publisher *messaging.Publisher
	log       *logger.Logger
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
		db:        database,
		cache:     cacheClient,
		queue:     queueSystem,
		publisher: pub,
		log:       log,
	}

	go ms.handleMatches()
	return ms
}

// JoinQueueRequest represents queue join input. Identity comes from the JWT;
// rating and region come from the database — never from the client.
type JoinQueueRequest struct {
	GameMode string `json:"game_mode"`
}

// JoinQueueResponse represents queue join result
type JoinQueueResponse struct {
	QueueID              string `json:"queue_id"`
	EstimatedWaitSeconds int    `json:"estimated_wait_time_seconds"`
	PlayersInQueue       int    `json:"players_in_queue"`
	Position             int    `json:"position"`
}

// OpponentInfo describes the matched opponent in a status response.
type OpponentInfo struct {
	UserID   string `json:"user_id"`
	Username string `json:"username"`
	ELO      int    `json:"elo"`
}

// MatchAssignment is cached per player when a match forms, so the queue
// status poll can hand the client its match.
type MatchAssignment struct {
	MatchID  string       `json:"match_id"`
	GameMode string       `json:"game_mode"`
	IsRanked bool         `json:"is_ranked"`
	Opponent OpponentInfo `json:"opponent"`
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

// JoinQueue adds an authenticated player to matchmaking. Rating, region,
// and username are loaded from the database.
func (ms *MatchmakerService) JoinQueue(ctx context.Context, userID string, req *JoinQueueRequest) (*JoinQueueResponse, error) {
	if req.GameMode == "" {
		req.GameMode = "RANKED_1V1"
	}

	var username, region string
	var elo int
	var isBanned, isBot bool
	err := ms.db.QueryRowContext(ctx,
		`SELECT username, region, elo_rating, is_banned, is_bot FROM users WHERE id = $1`,
		userID,
	).Scan(&username, &region, &elo, &isBanned, &isBot)
	if err == sql.ErrNoRows {
		return nil, errors.NewUserNotFoundError()
	}
	if err != nil {
		return nil, errors.NewDatabaseError(err)
	}
	if isBanned || isBot {
		return nil, errors.NewForbiddenError("Account cannot join matchmaking")
	}

	// Clear any stale assignment from a previous match.
	ms.cache.Delete(ctx, assignmentKey(userID))

	entry := &queue.QueueEntry{
		UserID:   userID,
		Username: username,
		ELO:      elo,
		Region:   region,
		GameMode: req.GameMode,
	}
	if err := ms.queue.AddPlayer(entry); err != nil {
		return nil, errors.NewAlreadyInQueueError()
	}

	_, position, playersInQueue, _ := ms.queue.GetQueueStatus(userID)

	go ms.saveQueueMetrics(context.Background(), userID, req.GameMode, elo, region)

	ms.publisher.Publish(ctx, messaging.ExchangeQueue, "player.joined", messaging.Event{
		Type: messaging.EventPlayerJoinedQueue,
		Data: map[string]interface{}{
			"user_id":   userID,
			"game_mode": req.GameMode,
			"elo":       elo,
		},
	})

	ms.log.Info("Player joined queue", map[string]interface{}{
		"user_id":          userID,
		"game_mode":        req.GameMode,
		"players_in_queue": playersInQueue,
	})

	return &JoinQueueResponse{
		QueueID:              userID,
		EstimatedWaitSeconds: ms.estimateWaitTime(elo, playersInQueue),
		PlayersInQueue:       playersInQueue,
		Position:             position,
	}, nil
}

// LeaveQueue removes a player from matchmaking
func (ms *MatchmakerService) LeaveQueue(ctx context.Context, userID string) error {
	removed := ms.queue.RemovePlayer(userID)
	if !removed {
		return errors.NewInvalidInputError("Player not in queue")
	}

	ms.publisher.Publish(ctx, messaging.ExchangeQueue, "player.left", messaging.Event{
		Type: messaging.EventPlayerLeftQueue,
		Data: map[string]interface{}{
			"user_id": userID,
		},
	})

	ms.log.Info("Player left queue", map[string]interface{}{"user_id": userID})
	return nil
}

// GetQueueStatus reports the player's matchmaking state:
//   - searching: still queued (with real wait time and search range)
//   - match_found: a match was created; payload carries match_id + opponent
//   - idle: not queued and no pending assignment
func (ms *MatchmakerService) GetQueueStatus(ctx context.Context, userID string) (map[string]interface{}, error) {
	if entry, position, playersInQueue, err := ms.queue.GetQueueStatus(userID); err == nil {
		return map[string]interface{}{
			"status":            "searching",
			"in_queue":          true,
			"wait_time_seconds": int(time.Since(entry.QueuedAt).Seconds()),
			"position":          position,
			"players_in_queue":  playersInQueue,
			"game_mode":         entry.GameMode,
			"search_range":      entry.SearchRange,
		}, nil
	}

	var assignment MatchAssignment
	if err := ms.cache.Get(ctx, assignmentKey(userID), &assignment); err == nil && assignment.MatchID != "" {
		return map[string]interface{}{
			"status":    "match_found",
			"in_queue":  false,
			"match_id":  assignment.MatchID,
			"game_mode": assignment.GameMode,
			"is_ranked": assignment.IsRanked,
			"opponent":  assignment.Opponent,
		}, nil
	}

	return map[string]interface{}{
		"status":   "idle",
		"in_queue": false,
	}, nil
}

// GetLeaderboard retrieves top players
func (ms *MatchmakerService) GetLeaderboard(ctx context.Context, region string, seasonID, limit, offset int) ([]*LeaderboardEntry, error) {
	cacheKey := fmt.Sprintf("leaderboard:%s:%d:%d:%d", region, seasonID, limit, offset)
	var cachedLeaderboard []*LeaderboardEntry
	if err := ms.cache.Get(ctx, cacheKey, &cachedLeaderboard); err == nil {
		return cachedLeaderboard, nil
	}

	query := `
		SELECT
			ROW_NUMBER() OVER (ORDER BY elo_rating DESC) as rank,
			id, username, display_name, avatar_url, elo_rating, rank_tier,
			total_games, wins, losses, win_streak,
			CASE WHEN total_games > 0 THEN ROUND((wins::NUMERIC / total_games::NUMERIC) * 100, 2) ELSE 0 END as win_rate
		FROM users
		WHERE is_banned = FALSE AND is_bot = FALSE AND total_games >= 1
	`
	args := []interface{}{}
	if region != "" {
		args = append(args, region)
		query += fmt.Sprintf(" AND region = $%d", len(args))
	}
	args = append(args, limit)
	query += fmt.Sprintf(" ORDER BY elo_rating DESC LIMIT $%d", len(args))
	args = append(args, offset)
	query += fmt.Sprintf(" OFFSET $%d", len(args))

	rows, err := ms.db.QueryContext(ctx, query, args...)
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

	ms.cache.Set(ctx, cacheKey, entries, cache.TTLLeaderboard)
	return entries, nil
}

// RatingResult reports the outcome of an ELO update.
type RatingResult struct {
	Player1ID     string `json:"player1_id"`
	Player2ID     string `json:"player2_id"`
	Player1Change int    `json:"player1_change"`
	Player2Change int    `json:"player2_change"`
	Player1New    int    `json:"player1_new"`
	Player2New    int    `json:"player2_new"`
}

// UpdateRatings applies a standard ELO update (K=32) for a finished ranked
// match and records win/loss stats, all in one transaction.
func (ms *MatchmakerService) UpdateRatings(ctx context.Context, matchID, winnerID, player1ID, player2ID string) (*RatingResult, error) {
	tx, err := ms.db.BeginTx(ctx)
	if err != nil {
		return nil, errors.NewDatabaseError(err)
	}
	defer tx.Rollback()

	var p1ELO, p2ELO int
	if err := tx.QueryRowContext(ctx, `SELECT elo_rating FROM users WHERE id = $1 FOR UPDATE`, player1ID).Scan(&p1ELO); err != nil {
		return nil, errors.NewDatabaseError(err)
	}
	if err := tx.QueryRowContext(ctx, `SELECT elo_rating FROM users WHERE id = $1 FOR UPDATE`, player2ID).Scan(&p2ELO); err != nil {
		return nil, errors.NewDatabaseError(err)
	}

	const k = 32.0
	expectedP1 := 1.0 / (1.0 + math.Pow(10, float64(p2ELO-p1ELO)/400.0))
	expectedP2 := 1.0 - expectedP1

	actualP1, actualP2 := 0.0, 0.0
	if winnerID == player1ID {
		actualP1 = 1.0
	} else {
		actualP2 = 1.0
	}

	changeP1 := int(math.Round(k * (actualP1 - expectedP1)))
	changeP2 := int(math.Round(k * (actualP2 - expectedP2)))
	newP1 := p1ELO + changeP1
	newP2 := p2ELO + changeP2

	statsQuery := `
		UPDATE users SET
			elo_rating = $2,
			total_games = total_games + 1,
			wins = wins + CASE WHEN $3 THEN 1 ELSE 0 END,
			losses = losses + CASE WHEN $3 THEN 0 ELSE 1 END,
			win_streak = CASE WHEN $3 THEN win_streak + 1 ELSE 0 END,
			best_win_streak = CASE WHEN $3 AND win_streak + 1 > best_win_streak
				THEN win_streak + 1 ELSE best_win_streak END,
			updated_at = NOW()
		WHERE id = $1`
	if _, err := tx.ExecContext(ctx, statsQuery, player1ID, newP1, winnerID == player1ID); err != nil {
		return nil, errors.NewDatabaseError(err)
	}
	if _, err := tx.ExecContext(ctx, statsQuery, player2ID, newP2, winnerID == player2ID); err != nil {
		return nil, errors.NewDatabaseError(err)
	}

	if _, err := tx.ExecContext(ctx,
		`UPDATE matches SET elo_change_p1 = $1, elo_change_p2 = $2 WHERE id = $3`,
		changeP1, changeP2, matchID,
	); err != nil {
		return nil, errors.NewDatabaseError(err)
	}

	if err := tx.Commit(); err != nil {
		return nil, errors.NewDatabaseError(err)
	}

	ms.log.Info("ELO ratings updated", map[string]interface{}{
		"match_id":    matchID,
		"player1_elo": fmt.Sprintf("%d -> %d", p1ELO, newP1),
		"player2_elo": fmt.Sprintf("%d -> %d", p2ELO, newP2),
	})

	return &RatingResult{
		Player1ID:     player1ID,
		Player2ID:     player2ID,
		Player1Change: changeP1,
		Player2Change: changeP2,
		Player1New:    newP1,
		Player2New:    newP2,
	}, nil
}

// Helper functions

func assignmentKey(userID string) string {
	return fmt.Sprintf("match_assignment:%s", userID)
}

func (ms *MatchmakerService) handleMatches() {
	for match := range ms.queue.GetMatches() {
		go ms.createMatch(context.Background(), match)
	}
}

// createMatch persists the match, stores per-player assignments for the
// status poll, and publishes match.created for the game service.
func (ms *MatchmakerService) createMatch(ctx context.Context, match *queue.Match) {
	var gameModeID int
	var isRanked bool
	err := ms.db.QueryRowContext(ctx,
		`SELECT id, is_ranked FROM game_modes WHERE name = $1`, match.GameMode,
	).Scan(&gameModeID, &isRanked)
	if err != nil {
		ms.log.Error("Unknown game mode for match", map[string]interface{}{
			"game_mode": match.GameMode, "error": err.Error(),
		})
		return
	}

	var seasonID sql.NullInt64
	_ = ms.db.QueryRowContext(ctx, `SELECT id FROM seasons WHERE is_active = TRUE ORDER BY start_date DESC LIMIT 1`).Scan(&seasonID)

	_, err = ms.db.ExecContext(ctx, `
		INSERT INTO matches (id, player1_id, player2_id, game_mode_id, season_id, status)
		VALUES ($1, $2, $3, $4, $5, 'WAITING')`,
		match.MatchID, match.Player1.UserID, match.Player2.UserID, gameModeID, seasonID,
	)
	if err != nil {
		ms.log.Error("Failed to create match", map[string]interface{}{"error": err.Error()})
		return
	}

	// Hand each player their assignment via the status poll.
	ms.cache.Set(ctx, assignmentKey(match.Player1.UserID), MatchAssignment{
		MatchID:  match.MatchID,
		GameMode: match.GameMode,
		IsRanked: isRanked,
		Opponent: OpponentInfo{UserID: match.Player2.UserID, Username: match.Player2.Username, ELO: match.Player2.ELO},
	}, matchAssignmentTTL)
	ms.cache.Set(ctx, assignmentKey(match.Player2.UserID), MatchAssignment{
		MatchID:  match.MatchID,
		GameMode: match.GameMode,
		IsRanked: isRanked,
		Opponent: OpponentInfo{UserID: match.Player1.UserID, Username: match.Player1.Username, ELO: match.Player1.ELO},
	}, matchAssignmentTTL)

	// Full payload so the game service can create the room without lookups.
	ms.publisher.Publish(ctx, messaging.ExchangeMatches, "match.created", messaging.Event{
		Type: messaging.EventMatchCreated,
		Data: map[string]interface{}{
			"match_id":         match.MatchID,
			"game_mode":        match.GameMode,
			"is_ranked":        isRanked,
			"player1_id":       match.Player1.UserID,
			"player1_username": match.Player1.Username,
			"player1_elo":      match.Player1.ELO,
			"player2_id":       match.Player2.UserID,
			"player2_username": match.Player2.Username,
			"player2_elo":      match.Player2.ELO,
		},
	})

	ms.cache.Set(ctx, fmt.Sprintf("match:%s", match.MatchID), match, cache.TTLActiveGame)
	ms.log.Info("Match created successfully", map[string]interface{}{"match_id": match.MatchID})
}

func (ms *MatchmakerService) saveQueueMetrics(ctx context.Context, userID, gameMode string, elo int, region string) {
	query := `
		INSERT INTO queue_metrics (id, user_id, game_mode_id, elo_at_queue, region)
		VALUES ($1, $2, (SELECT id FROM game_modes WHERE name = $3), $4, $5)
	`
	_, err := ms.db.ExecContext(ctx, query, uuid.New().String(), userID, gameMode, elo, region)
	if err != nil {
		ms.log.Error("Failed to save queue metrics", map[string]interface{}{"error": err.Error()})
	}
}

func (ms *MatchmakerService) estimateWaitTime(elo, playersInQueue int) int {
	if playersInQueue < 5 {
		return 30
	} else if playersInQueue < 20 {
		return 15
	}
	return 10
}
