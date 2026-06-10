// Package store persists match results for the game service.
package store

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/game/internal/room"
)

// Store wraps match persistence.
type Store struct {
	db  *db.DB
	log *logger.Logger
}

// New creates a Store.
func New(database *db.DB, log *logger.Logger) *Store {
	return &Store{db: database, log: log}
}

// MarkStarted flips a match to IN_PROGRESS.
func (s *Store) MarkStarted(ctx context.Context, matchID string) error {
	_, err := s.db.ExecContext(ctx,
		`UPDATE matches SET status = 'IN_PROGRESS', started_at = NOW() WHERE id = $1`, matchID)
	return err
}

// CreateBotMatch inserts a match row for an on-demand bot game and returns
// the new match id.
func (s *Store) CreateBotMatch(ctx context.Context, playerID, botID string) (string, error) {
	matchID := uuid.New().String()
	_, err := s.db.ExecContext(ctx, `
		INSERT INTO matches (id, player1_id, player2_id, game_mode_id, status)
		VALUES ($1, $2, $3, (SELECT id FROM game_modes WHERE name = 'BOT_MATCH'), 'WAITING')`,
		matchID, playerID, botID)
	if err != nil {
		return "", fmt.Errorf("insert bot match: %w", err)
	}
	return matchID, nil
}

// PickBot returns the bot user whose rating is closest to elo.
func (s *Store) PickBot(ctx context.Context, elo int) (room.PlayerInfo, error) {
	var info room.PlayerInfo
	err := s.db.QueryRowContext(ctx, `
		SELECT id, username, elo_rating FROM users
		WHERE is_bot = TRUE
		ORDER BY ABS(elo_rating - $1) ASC
		LIMIT 1`, elo,
	).Scan(&info.UserID, &info.Username, &info.ELO)
	if err != nil {
		return info, fmt.Errorf("pick bot: %w", err)
	}
	info.IsBot = true
	return info, nil
}

// GetPlayer loads minimal player info for room setup.
func (s *Store) GetPlayer(ctx context.Context, userID string) (room.PlayerInfo, error) {
	var info room.PlayerInfo
	err := s.db.QueryRowContext(ctx,
		`SELECT id, username, elo_rating, is_bot FROM users WHERE id = $1`, userID,
	).Scan(&info.UserID, &info.Username, &info.ELO, &info.IsBot)
	if err != nil {
		return info, fmt.Errorf("get player: %w", err)
	}
	return info, nil
}

// SaveResult writes the final match row, participants, and attempts.
func (s *Store) SaveResult(ctx context.Context, result room.MatchResult) error {
	tx, err := s.db.BeginTx(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback()

	var winner sql.NullString
	if result.WinnerID != "" {
		winner = sql.NullString{String: result.WinnerID, Valid: true}
	}

	if _, err := tx.ExecContext(ctx, `
		UPDATE matches SET
			status = $2, winner_id = $3, ended_at = NOW(),
			duration_ms = $4, replay_data = $5, abort_reason = $6
		WHERE id = $1`,
		result.MatchID, result.Status, winner, result.DurationMs,
		[]byte(result.Replay), result.Reason,
	); err != nil {
		return fmt.Errorf("update match: %w", err)
	}

	for i, p := range []room.PlayerInfo{result.Player1, result.Player2} {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO match_participants (match_id, user_id, team, solve_time_ms, score)
			VALUES ($1, $2, $3, $4, $5)`,
			result.MatchID, p.UserID, i+1,
			sumMs(result.SolveTimes[p.UserID]), result.Scores[p.UserID],
		); err != nil {
			return fmt.Errorf("insert participant: %w", err)
		}
	}

	for _, a := range result.Attempts {
		if _, err := tx.ExecContext(ctx, `
			INSERT INTO puzzle_attempts (match_id, user_id, puzzle_id, submitted_solution, is_correct, solve_time_ms, completed_at)
			VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
			result.MatchID, a.UserID, a.PuzzleID, a.Solution, a.IsCorrect, a.SolveTimeMs,
		); err != nil {
			return fmt.Errorf("insert attempt: %w", err)
		}
	}

	// Per-puzzle stats on the users row for non-bot players.
	for _, p := range []room.PlayerInfo{result.Player1, result.Player2} {
		if p.IsBot {
			continue
		}
		times := result.SolveTimes[p.UserID]
		if len(times) == 0 {
			continue
		}
		fastest := times[0]
		for _, t := range times {
			if t < fastest {
				fastest = t
			}
		}
		if _, err := tx.ExecContext(ctx, `
			UPDATE users SET
				puzzles_solved = puzzles_solved + $2,
				total_solve_time_ms = total_solve_time_ms + $3,
				fastest_solve_ms = LEAST(COALESCE(fastest_solve_ms, $4), $4)
			WHERE id = $1`,
			p.UserID, len(times), sumMs(times), fastest,
		); err != nil {
			return fmt.Errorf("update user stats: %w", err)
		}
	}

	return tx.Commit()
}

// HistoryEntry is one row of a player's match history.
type HistoryEntry struct {
	MatchID          string `json:"match_id"`
	GameMode         string `json:"game_mode"`
	OpponentID       string `json:"opponent_id"`
	OpponentUsername string `json:"opponent_username"`
	WinnerID         string `json:"winner_id,omitempty"`
	Won              bool   `json:"won"`
	YourScore        int    `json:"your_score"`
	OpponentScore    int    `json:"opponent_score"`
	EloChange        int    `json:"elo_change"`
	DurationMs       int64  `json:"duration_ms"`
	EndedAt          string `json:"ended_at"`
	HasReplay        bool   `json:"has_replay"`
}

// GetHistory returns a player's recent completed matches.
func (s *Store) GetHistory(ctx context.Context, userID string, limit int) ([]HistoryEntry, error) {
	rows, err := s.db.QueryContext(ctx, `
		SELECT
			m.id, gm.name,
			CASE WHEN m.player1_id = $1 THEN m.player2_id ELSE m.player1_id END,
			CASE WHEN m.player1_id = $1 THEN u2.username ELSE u1.username END,
			COALESCE(m.winner_id::text, ''),
			CASE WHEN m.player1_id = $1 THEN COALESCE(mp1.score, 0) ELSE COALESCE(mp2.score, 0) END,
			CASE WHEN m.player1_id = $1 THEN COALESCE(mp2.score, 0) ELSE COALESCE(mp1.score, 0) END,
			CASE WHEN m.player1_id = $1 THEN COALESCE(m.elo_change_p1, 0) ELSE COALESCE(m.elo_change_p2, 0) END,
			COALESCE(m.duration_ms, 0),
			COALESCE(to_char(m.ended_at, 'YYYY-MM-DD"T"HH24:MI:SS"Z"'), ''),
			(m.replay_data IS NOT NULL)
		FROM matches m
		JOIN game_modes gm ON gm.id = m.game_mode_id
		JOIN users u1 ON u1.id = m.player1_id
		LEFT JOIN users u2 ON u2.id = m.player2_id
		LEFT JOIN match_participants mp1 ON mp1.match_id = m.id AND mp1.user_id = m.player1_id
		LEFT JOIN match_participants mp2 ON mp2.match_id = m.id AND mp2.user_id = m.player2_id
		WHERE (m.player1_id = $1 OR m.player2_id = $1) AND m.status = 'COMPLETED'
		ORDER BY m.ended_at DESC
		LIMIT $2`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	entries := make([]HistoryEntry, 0)
	for rows.Next() {
		var e HistoryEntry
		if err := rows.Scan(
			&e.MatchID, &e.GameMode, &e.OpponentID, &e.OpponentUsername,
			&e.WinnerID, &e.YourScore, &e.OpponentScore, &e.EloChange,
			&e.DurationMs, &e.EndedAt, &e.HasReplay,
		); err != nil {
			return nil, err
		}
		e.Won = e.WinnerID == userID
		entries = append(entries, e)
	}
	return entries, rows.Err()
}

// GetReplay returns the replay document of a completed match.
func (s *Store) GetReplay(ctx context.Context, matchID string) (json.RawMessage, error) {
	var replay []byte
	err := s.db.QueryRowContext(ctx,
		`SELECT replay_data FROM matches WHERE id = $1 AND replay_data IS NOT NULL`, matchID,
	).Scan(&replay)
	if err != nil {
		return nil, err
	}
	return json.RawMessage(replay), nil
}

func sumMs(ts []int64) int64 {
	var sum int64
	for _, t := range ts {
		sum += t
	}
	return sum
}
