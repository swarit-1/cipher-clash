package repository

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal"
)

type ProgressRepository interface {
	GetUserProgress(ctx context.Context, userID string) ([]*internal.UserProgress, error)
	GetUserProgressForStep(ctx context.Context, userID, stepID string) (*internal.UserProgress, error)
	CreateProgress(ctx context.Context, progress *internal.UserProgress) error
	UpdateProgress(ctx context.Context, progress *internal.UserProgress) error
	CompleteStep(ctx context.Context, userID, stepID string, timeSpentSecs int, score *int) error
	GetUserStats(ctx context.Context, userID string) (*internal.UserTutorialStats, error)
	MarkAllStepsSkipped(ctx context.Context, userID string) error
}

type progressRepository struct {
	db *sql.DB
}

func NewProgressRepository(db *sql.DB) ProgressRepository {
	return &progressRepository{db: db}
}

func (r *progressRepository) GetUserProgress(ctx context.Context, userID string) ([]*internal.UserProgress, error) {
	query := `
		SELECT id, user_id, step_id, completed, completed_at, time_spent_secs, score, created_at, updated_at
		FROM user_tutorial_progress
		WHERE user_id = $1
		ORDER BY created_at ASC
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, fmt.Errorf("failed to query user progress: %w", err)
	}
	defer rows.Close()

	var progressList []*internal.UserProgress
	for rows.Next() {
		var progress internal.UserProgress
		err := rows.Scan(
			&progress.ID,
			&progress.UserID,
			&progress.StepID,
			&progress.Completed,
			&progress.CompletedAt,
			&progress.TimeSpentSecs,
			&progress.Score,
			&progress.CreatedAt,
			&progress.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan user progress: %w", err)
		}
		progressList = append(progressList, &progress)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating user progress: %w", err)
	}

	return progressList, nil
}

func (r *progressRepository) GetUserProgressForStep(ctx context.Context, userID, stepID string) (*internal.UserProgress, error) {
	query := `
		SELECT id, user_id, step_id, completed, completed_at, time_spent_secs, score, created_at, updated_at
		FROM user_tutorial_progress
		WHERE user_id = $1 AND step_id = $2
	`

	var progress internal.UserProgress
	err := r.db.QueryRowContext(ctx, query, userID, stepID).Scan(
		&progress.ID,
		&progress.UserID,
		&progress.StepID,
		&progress.Completed,
		&progress.CompletedAt,
		&progress.TimeSpentSecs,
		&progress.Score,
		&progress.CreatedAt,
		&progress.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil // No progress yet
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get user progress for step: %w", err)
	}

	return &progress, nil
}

func (r *progressRepository) CreateProgress(ctx context.Context, progress *internal.UserProgress) error {
	if progress.ID == "" {
		progress.ID = uuid.New().String()
	}

	now := time.Now()
	progress.CreatedAt = now
	progress.UpdatedAt = now

	query := `
		INSERT INTO user_tutorial_progress (id, user_id, step_id, completed, completed_at, time_spent_secs, score, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	_, err := r.db.ExecContext(ctx, query,
		progress.ID,
		progress.UserID,
		progress.StepID,
		progress.Completed,
		progress.CompletedAt,
		progress.TimeSpentSecs,
		progress.Score,
		progress.CreatedAt,
		progress.UpdatedAt,
	)

	if err != nil {
		return fmt.Errorf("failed to create progress: %w", err)
	}

	return nil
}

func (r *progressRepository) UpdateProgress(ctx context.Context, progress *internal.UserProgress) error {
	progress.UpdatedAt = time.Now()

	query := `
		UPDATE user_tutorial_progress
		SET completed = $1, completed_at = $2, time_spent_secs = $3, score = $4, updated_at = $5
		WHERE id = $6
	`

	result, err := r.db.ExecContext(ctx, query,
		progress.Completed,
		progress.CompletedAt,
		progress.TimeSpentSecs,
		progress.Score,
		progress.UpdatedAt,
		progress.ID,
	)

	if err != nil {
		return fmt.Errorf("failed to update progress: %w", err)
	}

	rows, err := result.RowsAffected()
	if err != nil {
		return fmt.Errorf("failed to get rows affected: %w", err)
	}

	if rows == 0 {
		return fmt.Errorf("progress not found: %s", progress.ID)
	}

	return nil
}

func (r *progressRepository) CompleteStep(ctx context.Context, userID, stepID string, timeSpentSecs int, score *int) error {
	// First check if progress exists
	existingProgress, err := r.GetUserProgressForStep(ctx, userID, stepID)
	if err != nil {
		return err
	}

	now := time.Now()

	if existingProgress == nil {
		// Create new progress entry
		progress := &internal.UserProgress{
			ID:            uuid.New().String(),
			UserID:        userID,
			StepID:        stepID,
			Completed:     true,
			CompletedAt:   &now,
			TimeSpentSecs: timeSpentSecs,
			Score:         score,
			CreatedAt:     now,
			UpdatedAt:     now,
		}
		return r.CreateProgress(ctx, progress)
	}

	// Update existing progress
	existingProgress.Completed = true
	existingProgress.CompletedAt = &now
	existingProgress.TimeSpentSecs += timeSpentSecs
	if score != nil {
		existingProgress.Score = score
	}

	return r.UpdateProgress(ctx, existingProgress)
}

func (r *progressRepository) GetUserStats(ctx context.Context, userID string) (*internal.UserTutorialStats, error) {
	query := `
		SELECT
			COUNT(DISTINCT ts.id) as total_steps,
			COUNT(DISTINCT CASE WHEN utp.completed = true THEN ts.id END) as completed_steps,
			COALESCE(SUM(utp.time_spent_secs), 0) as total_time_spent_secs,
			COUNT(DISTINCT CASE WHEN ts.required = true THEN ts.id END) as required_steps,
			COUNT(DISTINCT CASE WHEN ts.required = true AND utp.completed = true THEN ts.id END) as completed_required_steps
		FROM tutorial_steps ts
		LEFT JOIN user_tutorial_progress utp ON ts.id = utp.step_id AND utp.user_id = $1
	`

	var stats internal.UserTutorialStats
	var totalSteps, completedSteps, totalTime, requiredSteps, completedRequiredSteps int

	err := r.db.QueryRowContext(ctx, query, userID).Scan(
		&totalSteps,
		&completedSteps,
		&totalTime,
		&requiredSteps,
		&completedRequiredSteps,
	)

	if err != nil {
		return nil, fmt.Errorf("failed to get user stats: %w", err)
	}

	stats.UserID = userID
	stats.TotalSteps = totalSteps
	stats.CompletedSteps = completedSteps
	stats.TotalTimeSpentSecs = totalTime

	if totalSteps > 0 {
		stats.CompletionRate = float64(completedSteps) / float64(totalSteps) * 100
	}

	// Tutorial is completed if all required steps are done
	stats.TutorialCompleted = (requiredSteps > 0 && completedRequiredSteps >= requiredSteps)

	return &stats, nil
}

func (r *progressRepository) MarkAllStepsSkipped(ctx context.Context, userID string) error {
	// Get all steps
	query := `SELECT id FROM tutorial_steps`
	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return fmt.Errorf("failed to query tutorial steps: %w", err)
	}
	defer rows.Close()

	var stepIDs []string
	for rows.Next() {
		var stepID string
		if err := rows.Scan(&stepID); err != nil {
			return fmt.Errorf("failed to scan step ID: %w", err)
		}
		stepIDs = append(stepIDs, stepID)
	}

	if err = rows.Err(); err != nil {
		return fmt.Errorf("error iterating steps: %w", err)
	}

	// Mark all steps as completed (skipped)
	now := time.Now()
	for _, stepID := range stepIDs {
		existingProgress, err := r.GetUserProgressForStep(ctx, userID, stepID)
		if err != nil {
			return err
		}

		if existingProgress == nil {
			// Create new progress entry
			progress := &internal.UserProgress{
				ID:            uuid.New().String(),
				UserID:        userID,
				StepID:        stepID,
				Completed:     true,
				CompletedAt:   &now,
				TimeSpentSecs: 0,
				Score:         nil,
				CreatedAt:     now,
				UpdatedAt:     now,
			}
			if err := r.CreateProgress(ctx, progress); err != nil {
				return err
			}
		} else if !existingProgress.Completed {
			// Update to completed
			existingProgress.Completed = true
			existingProgress.CompletedAt = &now
			if err := r.UpdateProgress(ctx, existingProgress); err != nil {
				return err
			}
		}
	}

	return nil
}
