package repository

import (
	"context"
	"database/sql"
	"fmt"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/achievement/internal"
)

type AchievementRepository interface {
	Create(ctx context.Context, achievement *internal.Achievement) error
	GetByID(ctx context.Context, id string) (*internal.Achievement, error)
	GetAll(ctx context.Context) ([]*internal.Achievement, error)
	GetByRarity(ctx context.Context, rarity string) ([]*internal.Achievement, error)
	Update(ctx context.Context, achievement *internal.Achievement) error
	Delete(ctx context.Context, id string) error
}

type achievementRepository struct {
	db  *db.Database
	log *logger.Logger
}

func NewAchievementRepository(database *db.Database, log *logger.Logger) AchievementRepository {
	return &achievementRepository{
		db:  database,
		log: log,
	}
}

func (r *achievementRepository) Create(ctx context.Context, achievement *internal.Achievement) error {
	achievement.ID = uuid.New().String()

	query := `
		INSERT INTO achievements (id, name, description, icon, rarity, xp_reward, requirement, total, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW(), NOW())
		RETURNING created_at, updated_at
	`

	err := r.db.Pool.QueryRow(
		ctx,
		query,
		achievement.ID,
		achievement.Name,
		achievement.Description,
		achievement.Icon,
		achievement.Rarity,
		achievement.XPReward,
		achievement.Requirement,
		achievement.Total,
	).Scan(&achievement.CreatedAt, &achievement.UpdatedAt)

	if err != nil {
		r.log.Error("Failed to create achievement", map[string]interface{}{
			"error": err.Error(),
			"name":  achievement.Name,
		})
		return fmt.Errorf("failed to create achievement: %w", err)
	}

	r.log.Info("Achievement created", map[string]interface{}{
		"achievement_id": achievement.ID,
		"name":           achievement.Name,
		"rarity":         achievement.Rarity,
	})

	return nil
}

func (r *achievementRepository) GetByID(ctx context.Context, id string) (*internal.Achievement, error) {
	query := `
		SELECT id, name, description, icon, rarity, xp_reward, requirement, total, created_at, updated_at
		FROM achievements
		WHERE id = $1
	`

	achievement := &internal.Achievement{}
	err := r.db.Pool.QueryRow(ctx, query, id).Scan(
		&achievement.ID,
		&achievement.Name,
		&achievement.Description,
		&achievement.Icon,
		&achievement.Rarity,
		&achievement.XPReward,
		&achievement.Requirement,
		&achievement.Total,
		&achievement.CreatedAt,
		&achievement.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, fmt.Errorf("achievement not found")
	}

	if err != nil {
		r.log.Error("Failed to get achievement", map[string]interface{}{
			"error": err.Error(),
			"id":    id,
		})
		return nil, fmt.Errorf("failed to get achievement: %w", err)
	}

	return achievement, nil
}

func (r *achievementRepository) GetAll(ctx context.Context) ([]*internal.Achievement, error) {
	query := `
		SELECT id, name, description, icon, rarity, xp_reward, requirement, total, created_at, updated_at
		FROM achievements
		ORDER BY
			CASE rarity
				WHEN 'LEGENDARY' THEN 1
				WHEN 'EPIC' THEN 2
				WHEN 'RARE' THEN 3
				WHEN 'COMMON' THEN 4
			END,
			name ASC
	`

	rows, err := r.db.Pool.Query(ctx, query)
	if err != nil {
		r.log.Error("Failed to get all achievements", map[string]interface{}{
			"error": err.Error(),
		})
		return nil, fmt.Errorf("failed to get achievements: %w", err)
	}
	defer rows.Close()

	var achievements []*internal.Achievement
	for rows.Next() {
		achievement := &internal.Achievement{}
		err := rows.Scan(
			&achievement.ID,
			&achievement.Name,
			&achievement.Description,
			&achievement.Icon,
			&achievement.Rarity,
			&achievement.XPReward,
			&achievement.Requirement,
			&achievement.Total,
			&achievement.CreatedAt,
			&achievement.UpdatedAt,
		)
		if err != nil {
			r.log.Error("Failed to scan achievement", map[string]interface{}{
				"error": err.Error(),
			})
			continue
		}
		achievements = append(achievements, achievement)
	}

	return achievements, nil
}

func (r *achievementRepository) GetByRarity(ctx context.Context, rarity string) ([]*internal.Achievement, error) {
	query := `
		SELECT id, name, description, icon, rarity, xp_reward, requirement, total, created_at, updated_at
		FROM achievements
		WHERE rarity = $1
		ORDER BY name ASC
	`

	rows, err := r.db.Pool.Query(ctx, query, rarity)
	if err != nil {
		r.log.Error("Failed to get achievements by rarity", map[string]interface{}{
			"error":  err.Error(),
			"rarity": rarity,
		})
		return nil, fmt.Errorf("failed to get achievements: %w", err)
	}
	defer rows.Close()

	var achievements []*internal.Achievement
	for rows.Next() {
		achievement := &internal.Achievement{}
		err := rows.Scan(
			&achievement.ID,
			&achievement.Name,
			&achievement.Description,
			&achievement.Icon,
			&achievement.Rarity,
			&achievement.XPReward,
			&achievement.Requirement,
			&achievement.Total,
			&achievement.CreatedAt,
			&achievement.UpdatedAt,
		)
		if err != nil {
			r.log.Error("Failed to scan achievement", map[string]interface{}{
				"error": err.Error(),
			})
			continue
		}
		achievements = append(achievements, achievement)
	}

	return achievements, nil
}

func (r *achievementRepository) Update(ctx context.Context, achievement *internal.Achievement) error {
	query := `
		UPDATE achievements
		SET name = $1, description = $2, icon = $3, rarity = $4,
		    xp_reward = $5, requirement = $6, total = $7, updated_at = NOW()
		WHERE id = $8
		RETURNING updated_at
	`

	err := r.db.Pool.QueryRow(
		ctx,
		query,
		achievement.Name,
		achievement.Description,
		achievement.Icon,
		achievement.Rarity,
		achievement.XPReward,
		achievement.Requirement,
		achievement.Total,
		achievement.ID,
	).Scan(&achievement.UpdatedAt)

	if err == sql.ErrNoRows {
		return fmt.Errorf("achievement not found")
	}

	if err != nil {
		r.log.Error("Failed to update achievement", map[string]interface{}{
			"error": err.Error(),
			"id":    achievement.ID,
		})
		return fmt.Errorf("failed to update achievement: %w", err)
	}

	r.log.Info("Achievement updated", map[string]interface{}{
		"achievement_id": achievement.ID,
		"name":           achievement.Name,
	})

	return nil
}

func (r *achievementRepository) Delete(ctx context.Context, id string) error {
	query := `DELETE FROM achievements WHERE id = $1`

	result, err := r.db.Pool.Exec(ctx, query, id)
	if err != nil {
		r.log.Error("Failed to delete achievement", map[string]interface{}{
			"error": err.Error(),
			"id":    id,
		})
		return fmt.Errorf("failed to delete achievement: %w", err)
	}

	if result.RowsAffected() == 0 {
		return fmt.Errorf("achievement not found")
	}

	r.log.Info("Achievement deleted", map[string]interface{}{
		"achievement_id": id,
	})

	return nil
}
