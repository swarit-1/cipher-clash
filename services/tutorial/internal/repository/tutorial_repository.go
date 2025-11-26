package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/swarit-1/cipher-clash/services/tutorial/internal"
)

type TutorialRepository interface {
	GetAllSteps(ctx context.Context) ([]*internal.TutorialStep, error)
	GetStepByID(ctx context.Context, stepID string) (*internal.TutorialStep, error)
	GetStepsByCipherType(ctx context.Context, cipherType string) ([]*internal.TutorialStep, error)
	GetRequiredSteps(ctx context.Context) ([]*internal.TutorialStep, error)
}

type tutorialRepository struct {
	db *sql.DB
}

func NewTutorialRepository(db *sql.DB) TutorialRepository {
	return &tutorialRepository{db: db}
}

func (r *tutorialRepository) GetAllSteps(ctx context.Context) ([]*internal.TutorialStep, error) {
	query := `
		SELECT id, step_number, title, description, type, content, cipher_type, required, order_index, created_at, updated_at
		FROM tutorial_steps
		ORDER BY order_index ASC
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query tutorial steps: %w", err)
	}
	defer rows.Close()

	var steps []*internal.TutorialStep
	for rows.Next() {
		var step internal.TutorialStep
		err := rows.Scan(
			&step.ID,
			&step.StepNumber,
			&step.Title,
			&step.Description,
			&step.Type,
			&step.Content,
			&step.CipherType,
			&step.Required,
			&step.OrderIndex,
			&step.CreatedAt,
			&step.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan tutorial step: %w", err)
		}
		steps = append(steps, &step)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tutorial steps: %w", err)
	}

	return steps, nil
}

func (r *tutorialRepository) GetStepByID(ctx context.Context, stepID string) (*internal.TutorialStep, error) {
	query := `
		SELECT id, step_number, title, description, type, content, cipher_type, required, order_index, created_at, updated_at
		FROM tutorial_steps
		WHERE id = $1
	`

	var step internal.TutorialStep
	err := r.db.QueryRowContext(ctx, query, stepID).Scan(
		&step.ID,
		&step.StepNumber,
		&step.Title,
		&step.Description,
		&step.Type,
		&step.Content,
		&step.CipherType,
		&step.Required,
		&step.OrderIndex,
		&step.CreatedAt,
		&step.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("tutorial step not found: %s", stepID)
	}
	if err != nil {
		return nil, fmt.Errorf("failed to get tutorial step: %w", err)
	}

	return &step, nil
}

func (r *tutorialRepository) GetStepsByCipherType(ctx context.Context, cipherType string) ([]*internal.TutorialStep, error) {
	query := `
		SELECT id, step_number, title, description, type, content, cipher_type, required, order_index, created_at, updated_at
		FROM tutorial_steps
		WHERE cipher_type = $1
		ORDER BY order_index ASC
	`

	rows, err := r.db.QueryContext(ctx, query, cipherType)
	if err != nil {
		return nil, fmt.Errorf("failed to query tutorial steps by cipher type: %w", err)
	}
	defer rows.Close()

	var steps []*internal.TutorialStep
	for rows.Next() {
		var step internal.TutorialStep
		err := rows.Scan(
			&step.ID,
			&step.StepNumber,
			&step.Title,
			&step.Description,
			&step.Type,
			&step.Content,
			&step.CipherType,
			&step.Required,
			&step.OrderIndex,
			&step.CreatedAt,
			&step.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan tutorial step: %w", err)
		}
		steps = append(steps, &step)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tutorial steps: %w", err)
	}

	return steps, nil
}

func (r *tutorialRepository) GetRequiredSteps(ctx context.Context) ([]*internal.TutorialStep, error) {
	query := `
		SELECT id, step_number, title, description, type, content, cipher_type, required, order_index, created_at, updated_at
		FROM tutorial_steps
		WHERE required = true
		ORDER BY order_index ASC
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, fmt.Errorf("failed to query required tutorial steps: %w", err)
	}
	defer rows.Close()

	var steps []*internal.TutorialStep
	for rows.Next() {
		var step internal.TutorialStep
		err := rows.Scan(
			&step.ID,
			&step.StepNumber,
			&step.Title,
			&step.Description,
			&step.Type,
			&step.Content,
			&step.CipherType,
			&step.Required,
			&step.OrderIndex,
			&step.CreatedAt,
			&step.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("failed to scan tutorial step: %w", err)
		}
		steps = append(steps, &step)
	}

	if err = rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating tutorial steps: %w", err)
	}

	return steps, nil
}
