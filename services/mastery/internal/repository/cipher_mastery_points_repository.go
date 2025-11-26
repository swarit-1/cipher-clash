package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/models"
)

type CipherMasteryPointsRepository interface {
	CreateCipherPoints(ctx context.Context, points *models.CipherMasteryPoints) error
	GetCipherPoints(ctx context.Context, userID uuid.UUID, cipherType string) (*models.CipherMasteryPoints, error)
	GetAllUserPoints(ctx context.Context, userID uuid.UUID) ([]*models.CipherMasteryPoints, error)
	UpdateCipherPoints(ctx context.Context, points *models.CipherMasteryPoints) error
	GetLeaderboard(ctx context.Context, cipherType string, limit int) ([]*models.LeaderboardEntry, error)
}

type cipherMasteryPointsRepository struct {
	db *sql.DB
}

func NewCipherMasteryPointsRepository(db *sql.DB) CipherMasteryPointsRepository {
	return &cipherMasteryPointsRepository{db: db}
}

func (r *cipherMasteryPointsRepository) CreateCipherPoints(ctx context.Context, points *models.CipherMasteryPoints) error {
	query := `
		INSERT INTO cipher_mastery_points (
			user_id, cipher_type, total_points, available_points, spent_points,
			level, puzzles_solved, total_solve_time_ms, fastest_solve_ms
		)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	_, err := r.db.ExecContext(ctx, query,
		points.UserID,
		points.CipherType,
		points.TotalPoints,
		points.AvailablePoints,
		points.SpentPoints,
		points.Level,
		points.PuzzlesSolved,
		points.TotalSolveTimeMS,
		points.FastestSolveMS,
	)

	return err
}

func (r *cipherMasteryPointsRepository) GetCipherPoints(ctx context.Context, userID uuid.UUID, cipherType string) (*models.CipherMasteryPoints, error) {
	query := `
		SELECT user_id, cipher_type, total_points, available_points, spent_points,
		       level, puzzles_solved, total_solve_time_ms, fastest_solve_ms
		FROM cipher_mastery_points
		WHERE user_id = $1 AND cipher_type = $2
	`

	points := &models.CipherMasteryPoints{}

	err := r.db.QueryRowContext(ctx, query, userID, cipherType).Scan(
		&points.UserID,
		&points.CipherType,
		&points.TotalPoints,
		&points.AvailablePoints,
		&points.SpentPoints,
		&points.Level,
		&points.PuzzlesSolved,
		&points.TotalSolveTimeMS,
		&points.FastestSolveMS,
	)

	if err == sql.ErrNoRows {
		return nil, err
	}

	if err != nil {
		return nil, err
	}

	return points, nil
}

func (r *cipherMasteryPointsRepository) GetAllUserPoints(ctx context.Context, userID uuid.UUID) ([]*models.CipherMasteryPoints, error) {
	query := `
		SELECT user_id, cipher_type, total_points, available_points, spent_points,
		       level, puzzles_solved, total_solve_time_ms, fastest_solve_ms
		FROM cipher_mastery_points
		WHERE user_id = $1
		ORDER BY cipher_type
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var allPoints []*models.CipherMasteryPoints

	for rows.Next() {
		points := &models.CipherMasteryPoints{}

		err := rows.Scan(
			&points.UserID,
			&points.CipherType,
			&points.TotalPoints,
			&points.AvailablePoints,
			&points.SpentPoints,
			&points.Level,
			&points.PuzzlesSolved,
			&points.TotalSolveTimeMS,
			&points.FastestSolveMS,
		)

		if err != nil {
			return nil, err
		}

		allPoints = append(allPoints, points)
	}

	return allPoints, rows.Err()
}

func (r *cipherMasteryPointsRepository) UpdateCipherPoints(ctx context.Context, points *models.CipherMasteryPoints) error {
	query := `
		UPDATE cipher_mastery_points
		SET total_points = $1,
		    available_points = $2,
		    spent_points = $3,
		    level = $4,
		    puzzles_solved = $5,
		    total_solve_time_ms = $6,
		    fastest_solve_ms = $7,
		    updated_at = NOW()
		WHERE user_id = $8 AND cipher_type = $9
	`

	_, err := r.db.ExecContext(ctx, query,
		points.TotalPoints,
		points.AvailablePoints,
		points.SpentPoints,
		points.Level,
		points.PuzzlesSolved,
		points.TotalSolveTimeMS,
		points.FastestSolveMS,
		points.UserID,
		points.CipherType,
	)

	return err
}

func (r *cipherMasteryPointsRepository) GetLeaderboard(ctx context.Context, cipherType string, limit int) ([]*models.LeaderboardEntry, error) {
	query := `
		SELECT cmp.user_id, u.username, cmp.total_points, cmp.level
		FROM cipher_mastery_points cmp
		JOIN users u ON cmp.user_id = u.id
		WHERE cmp.cipher_type = $1
		ORDER BY cmp.total_points DESC, cmp.level DESC
		LIMIT $2
	`

	rows, err := r.db.QueryContext(ctx, query, cipherType, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var entries []*models.LeaderboardEntry

	for rows.Next() {
		entry := &models.LeaderboardEntry{}

		err := rows.Scan(
			&entry.UserID,
			&entry.Username,
			&entry.TotalPoints,
			&entry.Level,
		)

		if err != nil {
			return nil, err
		}

		entries = append(entries, entry)
	}

	return entries, rows.Err()
}
