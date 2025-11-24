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

type UserAchievementRepository interface {
	Create(ctx context.Context, userAchievement *internal.UserAchievement) error
	GetByUserID(ctx context.Context, userID string) ([]*internal.UserAchievement, error)
	GetByUserAndAchievement(ctx context.Context, userID, achievementID string) (*internal.UserAchievement, error)
	UpdateProgress(ctx context.Context, userID, achievementID string, progress int) error
	UnlockAchievement(ctx context.Context, userID, achievementID string) error
	GetUserStats(ctx context.Context, userID string) (*internal.UserAchievementStats, error)
	GetUserAchievementsWithProgress(ctx context.Context, userID string) ([]*internal.AchievementWithProgress, error)
}

type userAchievementRepository struct {
	db  *db.Database
	log *logger.Logger
}

func NewUserAchievementRepository(database *db.Database, log *logger.Logger) UserAchievementRepository {
	return &userAchievementRepository{
		db:  database,
		log: log,
	}
}

func (r *userAchievementRepository) Create(ctx context.Context, userAchievement *internal.UserAchievement) error {
	userAchievement.ID = uuid.New().String()

	query := `
		INSERT INTO user_achievements (id, user_id, achievement_id, progress, unlocked, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		RETURNING created_at, updated_at
	`

	err := r.db.Pool.QueryRow(
		ctx,
		query,
		userAchievement.ID,
		userAchievement.UserID,
		userAchievement.AchievementID,
		userAchievement.Progress,
		userAchievement.Unlocked,
	).Scan(&userAchievement.CreatedAt, &userAchievement.UpdatedAt)

	if err != nil {
		r.log.Error("Failed to create user achievement", map[string]interface{}{
			"error":          err.Error(),
			"user_id":        userAchievement.UserID,
			"achievement_id": userAchievement.AchievementID,
		})
		return fmt.Errorf("failed to create user achievement: %w", err)
	}

	return nil
}

func (r *userAchievementRepository) GetByUserID(ctx context.Context, userID string) ([]*internal.UserAchievement, error) {
	query := `
		SELECT id, user_id, achievement_id, progress, unlocked, unlocked_at, created_at, updated_at
		FROM user_achievements
		WHERE user_id = $1
		ORDER BY unlocked DESC, updated_at DESC
	`

	rows, err := r.db.Pool.Query(ctx, query, userID)
	if err != nil {
		r.log.Error("Failed to get user achievements", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		return nil, fmt.Errorf("failed to get user achievements: %w", err)
	}
	defer rows.Close()

	var userAchievements []*internal.UserAchievement
	for rows.Next() {
		ua := &internal.UserAchievement{}
		err := rows.Scan(
			&ua.ID,
			&ua.UserID,
			&ua.AchievementID,
			&ua.Progress,
			&ua.Unlocked,
			&ua.UnlockedAt,
			&ua.CreatedAt,
			&ua.UpdatedAt,
		)
		if err != nil {
			r.log.Error("Failed to scan user achievement", map[string]interface{}{
				"error": err.Error(),
			})
			continue
		}
		userAchievements = append(userAchievements, ua)
	}

	return userAchievements, nil
}

func (r *userAchievementRepository) GetByUserAndAchievement(ctx context.Context, userID, achievementID string) (*internal.UserAchievement, error) {
	query := `
		SELECT id, user_id, achievement_id, progress, unlocked, unlocked_at, created_at, updated_at
		FROM user_achievements
		WHERE user_id = $1 AND achievement_id = $2
	`

	ua := &internal.UserAchievement{}
	err := r.db.Pool.QueryRow(ctx, query, userID, achievementID).Scan(
		&ua.ID,
		&ua.UserID,
		&ua.AchievementID,
		&ua.Progress,
		&ua.Unlocked,
		&ua.UnlockedAt,
		&ua.CreatedAt,
		&ua.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil // Not found, not an error
	}

	if err != nil {
		r.log.Error("Failed to get user achievement", map[string]interface{}{
			"error":          err.Error(),
			"user_id":        userID,
			"achievement_id": achievementID,
		})
		return nil, fmt.Errorf("failed to get user achievement: %w", err)
	}

	return ua, nil
}

func (r *userAchievementRepository) UpdateProgress(ctx context.Context, userID, achievementID string, progress int) error {
	query := `
		UPDATE user_achievements
		SET progress = $1, updated_at = NOW()
		WHERE user_id = $2 AND achievement_id = $3
		RETURNING id
	`

	var id string
	err := r.db.Pool.QueryRow(ctx, query, progress, userID, achievementID).Scan(&id)

	if err == sql.ErrNoRows {
		return fmt.Errorf("user achievement not found")
	}

	if err != nil {
		r.log.Error("Failed to update progress", map[string]interface{}{
			"error":          err.Error(),
			"user_id":        userID,
			"achievement_id": achievementID,
			"progress":       progress,
		})
		return fmt.Errorf("failed to update progress: %w", err)
	}

	r.log.Info("Achievement progress updated", map[string]interface{}{
		"user_id":        userID,
		"achievement_id": achievementID,
		"progress":       progress,
	})

	return nil
}

func (r *userAchievementRepository) UnlockAchievement(ctx context.Context, userID, achievementID string) error {
	query := `
		UPDATE user_achievements
		SET unlocked = true, unlocked_at = NOW(), updated_at = NOW()
		WHERE user_id = $1 AND achievement_id = $2
		RETURNING id
	`

	var id string
	err := r.db.Pool.QueryRow(ctx, query, userID, achievementID).Scan(&id)

	if err == sql.ErrNoRows {
		return fmt.Errorf("user achievement not found")
	}

	if err != nil {
		r.log.Error("Failed to unlock achievement", map[string]interface{}{
			"error":          err.Error(),
			"user_id":        userID,
			"achievement_id": achievementID,
		})
		return fmt.Errorf("failed to unlock achievement: %w", err)
	}

	r.log.Info("Achievement unlocked", map[string]interface{}{
		"user_id":        userID,
		"achievement_id": achievementID,
	})

	return nil
}

func (r *userAchievementRepository) GetUserStats(ctx context.Context, userID string) (*internal.UserAchievementStats, error) {
	query := `
		SELECT
			COUNT(*) as total_achievements,
			COUNT(CASE WHEN ua.unlocked THEN 1 END) as unlocked_count,
			COALESCE(SUM(CASE WHEN ua.unlocked THEN a.xp_reward ELSE 0 END), 0) as total_xp_earned,
			COUNT(CASE WHEN ua.unlocked AND a.rarity = 'LEGENDARY' THEN 1 END) as legendary_count,
			COUNT(CASE WHEN ua.unlocked AND a.rarity = 'EPIC' THEN 1 END) as epic_count,
			COUNT(CASE WHEN ua.unlocked AND a.rarity = 'RARE' THEN 1 END) as rare_count,
			COUNT(CASE WHEN ua.unlocked AND a.rarity = 'COMMON' THEN 1 END) as common_count
		FROM user_achievements ua
		JOIN achievements a ON ua.achievement_id = a.id
		WHERE ua.user_id = $1
	`

	stats := &internal.UserAchievementStats{UserID: userID}
	err := r.db.Pool.QueryRow(ctx, query, userID).Scan(
		&stats.TotalAchievements,
		&stats.UnlockedCount,
		&stats.TotalXPEarned,
		&stats.LegendaryCount,
		&stats.EpicCount,
		&stats.RareCount,
		&stats.CommonCount,
	)

	if err != nil {
		r.log.Error("Failed to get user stats", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		return nil, fmt.Errorf("failed to get user stats: %w", err)
	}

	// Calculate completion rate
	if stats.TotalAchievements > 0 {
		stats.CompletionRate = float64(stats.UnlockedCount) / float64(stats.TotalAchievements) * 100
	}

	return stats, nil
}

func (r *userAchievementRepository) GetUserAchievementsWithProgress(ctx context.Context, userID string) ([]*internal.AchievementWithProgress, error) {
	query := `
		SELECT
			a.id, a.name, a.description, a.icon, a.rarity, a.xp_reward, a.requirement, a.total, a.created_at, a.updated_at,
			COALESCE(ua.progress, 0) as progress,
			COALESCE(ua.unlocked, false) as unlocked,
			ua.unlocked_at
		FROM achievements a
		LEFT JOIN user_achievements ua ON a.id = ua.achievement_id AND ua.user_id = $1
		ORDER BY
			CASE a.rarity
				WHEN 'LEGENDARY' THEN 1
				WHEN 'EPIC' THEN 2
				WHEN 'RARE' THEN 3
				WHEN 'COMMON' THEN 4
			END,
			a.name ASC
	`

	rows, err := r.db.Pool.Query(ctx, query, userID)
	if err != nil {
		r.log.Error("Failed to get user achievements with progress", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		return nil, fmt.Errorf("failed to get achievements with progress: %w", err)
	}
	defer rows.Close()

	var achievements []*internal.AchievementWithProgress
	for rows.Next() {
		awp := &internal.AchievementWithProgress{}
		err := rows.Scan(
			&awp.ID,
			&awp.Name,
			&awp.Description,
			&awp.Icon,
			&awp.Rarity,
			&awp.XPReward,
			&awp.Requirement,
			&awp.Total,
			&awp.CreatedAt,
			&awp.UpdatedAt,
			&awp.Progress,
			&awp.Unlocked,
			&awp.UnlockedAt,
		)
		if err != nil {
			r.log.Error("Failed to scan achievement with progress", map[string]interface{}{
				"error": err.Error(),
			})
			continue
		}
		achievements = append(achievements, awp)
	}

	return achievements, nil
}
