package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/practice/internal"
)

type PracticeRepository struct {
	db *sql.DB
}

func NewPracticeRepository(db *sql.DB) *PracticeRepository {
	return &PracticeRepository{db: db}
}

// CreateSession creates a new practice session
func (r *PracticeRepository) CreateSession(ctx context.Context, session *internal.PracticeSession) error {
	query := `
		INSERT INTO practice_sessions (
			id, user_id, puzzle_id, cipher_type, difficulty, mode,
			time_limit_ms, hints_used, attempts
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	session.ID = uuid.New().String()
	session.StartedAt = time.Now()
	session.Attempts = 1

	_, err := r.db.ExecContext(ctx, query,
		session.ID,
		session.UserID,
		session.PuzzleID,
		session.CipherType,
		session.Difficulty,
		session.Mode,
		session.TimeLimitMs,
		session.HintsUsed,
		session.Attempts,
	)

	return err
}

// UpdateSessionWithSolution updates session with submitted solution
func (r *PracticeRepository) UpdateSessionWithSolution(
	ctx context.Context,
	sessionID string,
	solution string,
	solveTimeMs int64,
	isCorrect bool,
	accuracyPct float64,
	score int,
	perfectSolve bool,
) error {
	query := `
		UPDATE practice_sessions
		SET submitted_at = NOW(),
		    solve_time_ms = $2,
		    user_solution = $3,
		    is_correct = $4,
		    accuracy_percentage = $5,
		    score = $6,
		    perfect_solve = $7
		WHERE id = $1
	`

	_, err := r.db.ExecContext(ctx, query,
		sessionID,
		solveTimeMs,
		solution,
		isCorrect,
		accuracyPct,
		score,
		perfectSolve,
	)
	return err
}

// GetSessionByID retrieves a practice session by ID
func (r *PracticeRepository) GetSessionByID(ctx context.Context, sessionID string) (*internal.PracticeSession, error) {
	query := `
		SELECT id, user_id, puzzle_id, cipher_type, difficulty, mode,
		       started_at, submitted_at, solve_time_ms, time_limit_ms,
		       user_solution, is_correct, accuracy_percentage, hints_used,
		       score, perfect_solve, attempts
		FROM practice_sessions
		WHERE id = $1
	`

	var session internal.PracticeSession
	err := r.db.QueryRowContext(ctx, query, sessionID).Scan(
		&session.ID,
		&session.UserID,
		&session.PuzzleID,
		&session.CipherType,
		&session.Difficulty,
		&session.Mode,
		&session.StartedAt,
		&session.SubmittedAt,
		&session.SolveTimeMs,
		&session.TimeLimitMs,
		&session.UserSolution,
		&session.IsCorrect,
		&session.AccuracyPercentage,
		&session.HintsUsed,
		&session.Score,
		&session.PerfectSolve,
		&session.Attempts,
	)

	if err != nil {
		return nil, err
	}

	return &session, nil
}

// GetUserHistory retrieves practice session history
func (r *PracticeRepository) GetUserHistory(
	ctx context.Context,
	userID string,
	cipherType *string,
	limit, offset int,
) ([]*internal.PracticeSession, int, error) {
	var sessions []*internal.PracticeSession
	var total int

	// Count total
	countQuery := `SELECT COUNT(*) FROM practice_sessions WHERE user_id = $1`
	args := []interface{}{userID}

	if cipherType != nil && *cipherType != "" {
		countQuery += ` AND cipher_type = $2`
		args = append(args, *cipherType)
	}

	err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	// Get sessions
	query := `
		SELECT id, user_id, puzzle_id, cipher_type, difficulty, mode,
		       started_at, submitted_at, solve_time_ms, time_limit_ms,
		       user_solution, is_correct, accuracy_percentage, hints_used,
		       score, perfect_solve, attempts
		FROM practice_sessions
		WHERE user_id = $1
	`

	queryArgs := []interface{}{userID}
	argIdx := 2

	if cipherType != nil && *cipherType != "" {
		query += fmt.Sprintf(` AND cipher_type = $%d`, argIdx)
		queryArgs = append(queryArgs, *cipherType)
		argIdx++
	}

	query += fmt.Sprintf(` ORDER BY started_at DESC LIMIT $%d OFFSET $%d`, argIdx, argIdx+1)
	queryArgs = append(queryArgs, limit, offset)

	rows, err := r.db.QueryContext(ctx, query, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	for rows.Next() {
		var session internal.PracticeSession
		err := rows.Scan(
			&session.ID,
			&session.UserID,
			&session.PuzzleID,
			&session.CipherType,
			&session.Difficulty,
			&session.Mode,
			&session.StartedAt,
			&session.SubmittedAt,
			&session.SolveTimeMs,
			&session.TimeLimitMs,
			&session.UserSolution,
			&session.IsCorrect,
			&session.AccuracyPercentage,
			&session.HintsUsed,
			&session.Score,
			&session.PerfectSolve,
			&session.Attempts,
		)
		if err != nil {
			return nil, 0, err
		}
		sessions = append(sessions, &session)
	}

	return sessions, total, nil
}

// GetPersonalBests retrieves personal best records
func (r *PracticeRepository) GetPersonalBests(
	ctx context.Context,
	userID string,
	cipherType *string,
	difficulty *int,
) ([]*internal.PersonalBest, error) {
	query := `
		SELECT id, user_id, cipher_type, difficulty, fastest_solve_ms,
		       fastest_session_id, fastest_achieved_at, highest_score,
		       highest_score_session_id, total_practice_sessions,
		       perfect_solves, average_solve_time_ms, updated_at
		FROM practice_leaderboards
		WHERE user_id = $1
	`

	args := []interface{}{userID}
	argIdx := 2

	if cipherType != nil && *cipherType != "" {
		query += fmt.Sprintf(` AND cipher_type = $%d`, argIdx)
		args = append(args, *cipherType)
		argIdx++
	}

	if difficulty != nil {
		query += fmt.Sprintf(` AND difficulty = $%d`, argIdx)
		args = append(args, *difficulty)
	}

	query += ` ORDER BY cipher_type, difficulty`

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var records []*internal.PersonalBest
	for rows.Next() {
		var record internal.PersonalBest
		err := rows.Scan(
			&record.ID,
			&record.UserID,
			&record.CipherType,
			&record.Difficulty,
			&record.FastestSolveMs,
			&record.FastestSessionID,
			&record.FastestAchievedAt,
			&record.HighestScore,
			&record.HighestScoreSessionID,
			&record.TotalPracticeSessions,
			&record.PerfectSolves,
			&record.AverageSolveTimeMs,
			&record.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}
		records = append(records, &record)
	}

	return records, nil
}
