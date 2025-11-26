package repository

import (
	"context"
	"database/sql"

	"github.com/swarit-1/cipher-clash/services/missions/internal/models"
)

type MissionsRepository interface {
	GetAllTemplates(ctx context.Context, category, frequency string) ([]*models.MissionTemplate, error)
	GetTemplateByID(ctx context.Context, id string) (*models.MissionTemplate, error)
}

type missionsRepository struct {
	db *sql.DB
}

func NewMissionsRepository(db *sql.DB) MissionsRepository {
	return &missionsRepository{db: db}
}

func (r *missionsRepository) GetAllTemplates(ctx context.Context, category, frequency string) ([]*models.MissionTemplate, error) {
	query := `
		SELECT id, title, description, category, frequency, target,
		       xp_reward, coin_reward, difficulty_level, icon, created_at
		FROM mission_templates
		WHERE 1=1
	`
	args := []interface{}{}

	if category != "" {
		query += " AND category = $" + string(rune(len(args)+1))
		args = append(args, category)
	}

	if frequency != "" {
		query += " AND frequency = $" + string(rune(len(args)+1))
		args = append(args, frequency)
	}

	query += " ORDER BY difficulty_level, created_at"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var templates []*models.MissionTemplate
	for rows.Next() {
		template := &models.MissionTemplate{}
		err := rows.Scan(
			&template.ID,
			&template.Title,
			&template.Description,
			&template.Category,
			&template.Frequency,
			&template.Target,
			&template.XPReward,
			&template.CoinReward,
			&template.DifficultyLevel,
			&template.Icon,
			&template.CreatedAt,
		)
		if err != nil {
			return nil, err
		}
		templates = append(templates, template)
	}

	return templates, rows.Err()
}

func (r *missionsRepository) GetTemplateByID(ctx context.Context, id string) (*models.MissionTemplate, error) {
	query := `
		SELECT id, title, description, category, frequency, target,
		       xp_reward, coin_reward, difficulty_level, icon, created_at
		FROM mission_templates
		WHERE id = $1
	`

	template := &models.MissionTemplate{}
	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&template.ID,
		&template.Title,
		&template.Description,
		&template.Category,
		&template.Frequency,
		&template.Target,
		&template.XPReward,
		&template.CoinReward,
		&template.DifficultyLevel,
		&template.Icon,
		&template.CreatedAt,
	)

	if err != nil {
		return nil, err
	}

	return template, nil
}
