package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/missions/internal/models"
)

type UserMissionsRepository interface {
	CreateUserMission(ctx context.Context, mission *models.UserMission) error
	GetUserMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error)
	GetActiveMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error)
	GetUserMissionByTemplate(ctx context.Context, userID uuid.UUID, templateID string) (*models.UserMission, error)
	UpdateUserMission(ctx context.Context, mission *models.UserMission) error
	MarkExpiredMissions(ctx context.Context, userID uuid.UUID) error
	GetMissionStats(ctx context.Context, userID uuid.UUID) (*models.MissionStats, error)
}

type userMissionsRepository struct {
	db *sql.DB
}

func NewUserMissionsRepository(db *sql.DB) UserMissionsRepository {
	return &userMissionsRepository{db: db}
}

func (r *userMissionsRepository) CreateUserMission(ctx context.Context, mission *models.UserMission) error {
	query := `
		INSERT INTO user_missions (id, user_id, template_id, progress, target, status, assigned_date, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`

	_, err := r.db.ExecContext(ctx, query,
		mission.ID,
		mission.UserID,
		mission.TemplateID,
		mission.Progress,
		mission.Target,
		mission.Status,
		mission.AssignedDate,
		mission.ExpiresAt,
	)

	return err
}

func (r *userMissionsRepository) GetUserMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error) {
	query := `
		SELECT id, user_id, template_id, progress, target, status,
		       assigned_date, expires_at, completed_at, claimed_at, updated_at
		FROM user_missions
		WHERE user_id = $1
		ORDER BY assigned_date DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanMissions(rows)
}

func (r *userMissionsRepository) GetActiveMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error) {
	query := `
		SELECT id, user_id, template_id, progress, target, status,
		       assigned_date, expires_at, completed_at, claimed_at, updated_at
		FROM user_missions
		WHERE user_id = $1
		  AND status IN ('active', 'completed')
		  AND expires_at > NOW()
		ORDER BY assigned_date DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanMissions(rows)
}

func (r *userMissionsRepository) GetUserMissionByTemplate(ctx context.Context, userID uuid.UUID, templateID string) (*models.UserMission, error) {
	query := `
		SELECT id, user_id, template_id, progress, target, status,
		       assigned_date, expires_at, completed_at, claimed_at, updated_at
		FROM user_missions
		WHERE user_id = $1 AND template_id = $2
		  AND status IN ('active', 'completed')
		ORDER BY assigned_date DESC
		LIMIT 1
	`

	mission := &models.UserMission{}
	var completedAt, claimedAt, updatedAt sql.NullTime

	err := r.db.QueryRowContext(ctx, query, userID, templateID).Scan(
		&mission.ID,
		&mission.UserID,
		&mission.TemplateID,
		&mission.Progress,
		&mission.Target,
		&mission.Status,
		&mission.AssignedDate,
		&mission.ExpiresAt,
		&completedAt,
		&claimedAt,
		&updatedAt,
	)

	if err != nil {
		return nil, err
	}

	if completedAt.Valid {
		mission.CompletedAt = &completedAt.Time
	}
	if claimedAt.Valid {
		mission.ClaimedAt = &claimedAt.Time
	}

	return mission, nil
}

func (r *userMissionsRepository) UpdateUserMission(ctx context.Context, mission *models.UserMission) error {
	query := `
		UPDATE user_missions
		SET progress = $1, status = $2, completed_at = $3, claimed_at = $4, updated_at = NOW()
		WHERE id = $5
	`

	_, err := r.db.ExecContext(ctx, query,
		mission.Progress,
		mission.Status,
		mission.CompletedAt,
		mission.ClaimedAt,
		mission.ID,
	)

	return err
}

func (r *userMissionsRepository) MarkExpiredMissions(ctx context.Context, userID uuid.UUID) error {
	query := `
		UPDATE user_missions
		SET status = 'expired', updated_at = NOW()
		WHERE user_id = $1
		  AND status = 'active'
		  AND expires_at <= NOW()
	`

	_, err := r.db.ExecContext(ctx, query, userID)
	return err
}

func (r *userMissionsRepository) GetMissionStats(ctx context.Context, userID uuid.UUID) (*models.MissionStats, error) {
	query := `
		SELECT
			COUNT(*) as total_assigned,
			COUNT(*) FILTER (WHERE status IN ('completed', 'claimed')) as total_completed,
			COUNT(*) FILTER (WHERE status = 'claimed') as total_claimed,
			COALESCE(SUM(CASE WHEN mt.xp_reward IS NOT NULL AND um.status = 'claimed' THEN mt.xp_reward ELSE 0 END), 0) as total_xp,
			COALESCE(SUM(CASE WHEN mt.coin_reward IS NOT NULL AND um.status = 'claimed' THEN mt.coin_reward ELSE 0 END), 0) as total_coins
		FROM user_missions um
		LEFT JOIN mission_templates mt ON um.template_id = mt.id
		WHERE um.user_id = $1
	`

	stats := &models.MissionStats{}
	var totalAssigned, totalCompleted, totalClaimed, totalXP, totalCoins int

	err := r.db.QueryRowContext(ctx, query, userID).Scan(
		&totalAssigned,
		&totalCompleted,
		&totalClaimed,
		&totalXP,
		&totalCoins,
	)

	if err != nil {
		return nil, err
	}

	stats.TotalAssigned = totalAssigned
	stats.TotalCompleted = totalCompleted
	stats.TotalClaimed = totalClaimed
	stats.TotalXPEarned = totalXP
	stats.TotalCoinsEarned = totalCoins

	if totalAssigned > 0 {
		stats.CompletionRate = float64(totalCompleted) / float64(totalAssigned) * 100
	}

	// Calculate streaks
	stats.CurrentStreak = r.calculateCurrentStreak(ctx, userID)
	stats.LongestStreak = r.calculateLongestStreak(ctx, userID)

	return stats, nil
}

func (r *userMissionsRepository) calculateCurrentStreak(ctx context.Context, userID uuid.UUID) int {
	query := `
		SELECT COUNT(DISTINCT DATE(completed_at))
		FROM user_missions
		WHERE user_id = $1
		  AND status IN ('completed', 'claimed')
		  AND completed_at >= CURRENT_DATE - INTERVAL '30 days'
		  AND completed_at >= (
		    SELECT MAX(DATE(completed_at)) - INTERVAL '1 day' *
		      (SELECT COUNT(DISTINCT DATE(completed_at)) FROM user_missions
		       WHERE user_id = $1 AND status IN ('completed', 'claimed')
		       AND DATE(completed_at) = CURRENT_DATE - generate_series(0, 30))
		    FROM user_missions WHERE user_id = $1
		  )
	`

	var streak int
	err := r.db.QueryRowContext(ctx, query, userID).Scan(&streak)
	if err != nil {
		return 0
	}

	return streak
}

func (r *userMissionsRepository) calculateLongestStreak(ctx context.Context, userID uuid.UUID) int {
	// Simplified calculation - in production this would be more sophisticated
	query := `
		SELECT COUNT(DISTINCT DATE(completed_at))
		FROM user_missions
		WHERE user_id = $1
		  AND status IN ('completed', 'claimed')
	`

	var streak int
	err := r.db.QueryRowContext(ctx, query, userID).Scan(&streak)
	if err != nil {
		return 0
	}

	return streak
}

func (r *userMissionsRepository) scanMissions(rows *sql.Rows) ([]*models.UserMission, error) {
	var missions []*models.UserMission

	for rows.Next() {
		mission := &models.UserMission{}
		var completedAt, claimedAt, updatedAt sql.NullTime

		err := rows.Scan(
			&mission.ID,
			&mission.UserID,
			&mission.TemplateID,
			&mission.Progress,
			&mission.Target,
			&mission.Status,
			&mission.AssignedDate,
			&mission.ExpiresAt,
			&completedAt,
			&claimedAt,
			&updatedAt,
		)

		if err != nil {
			return nil, err
		}

		if completedAt.Valid {
			mission.CompletedAt = &completedAt.Time
		}
		if claimedAt.Valid {
			mission.ClaimedAt = &claimedAt.Time
		}

		missions = append(missions, mission)
	}

	return missions, rows.Err()
}
