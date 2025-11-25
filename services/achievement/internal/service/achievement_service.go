package service

import (
	"context"
	"fmt"

	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/achievement/internal"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/repository"
)

type AchievementService interface {
	// Achievement management
	CreateAchievement(ctx context.Context, req *internal.CreateAchievementRequest) (*internal.Achievement, error)
	GetAchievement(ctx context.Context, id string) (*internal.Achievement, error)
	GetAllAchievements(ctx context.Context) ([]*internal.Achievement, error)
	GetAchievementsByRarity(ctx context.Context, rarity string) ([]*internal.Achievement, error)
	UpdateAchievement(ctx context.Context, req *internal.UpdateAchievementRequest) (*internal.Achievement, error)

	// User achievement management
	GetUserAchievements(ctx context.Context, userID string) ([]*internal.AchievementWithProgress, error)
	GetUserStats(ctx context.Context, userID string) (*internal.UserAchievementStats, error)
	UpdateProgress(ctx context.Context, userID, achievementID string, increment int) error
	InitializeUserAchievements(ctx context.Context, userID string) error
}

type achievementService struct {
	achievementRepo     repository.AchievementRepository
	userAchievementRepo repository.UserAchievementRepository
	cache               *cache.Cache
	log                 *logger.Logger
}

func NewAchievementService(
	achievementRepo repository.AchievementRepository,
	userAchievementRepo repository.UserAchievementRepository,
	cache *cache.Cache,
	log *logger.Logger,
) AchievementService {
	return &achievementService{
		achievementRepo:     achievementRepo,
		userAchievementRepo: userAchievementRepo,
		cache:               cache,
		log:                 log,
	}
}

func (s *achievementService) CreateAchievement(ctx context.Context, req *internal.CreateAchievementRequest) (*internal.Achievement, error) {
	achievement := &internal.Achievement{
		Name:        req.Name,
		Description: req.Description,
		Icon:        req.Icon,
		Rarity:      req.Rarity,
		XPReward:    req.XPReward,
		Requirement: req.Requirement,
		Total:       req.Total,
	}

	if err := s.achievementRepo.Create(ctx, achievement); err != nil {
		return nil, err
	}

	// Invalidate cache
	s.cache.Delete(ctx, "achievements:all")

	s.log.Info("Achievement created", map[string]interface{}{
		"achievement_id": achievement.ID,
		"name":           achievement.Name,
		"rarity":         achievement.Rarity,
	})

	return achievement, nil
}

func (s *achievementService) GetAchievement(ctx context.Context, id string) (*internal.Achievement, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("achievement:%s", id)
	var cached internal.Achievement
	if err := s.cache.Get(ctx, cacheKey, &cached); err == nil {
		return &cached, nil
	}

	achievement, err := s.achievementRepo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}

	// Cache for 1 hour
	s.cache.Set(ctx, cacheKey, achievement, 3600)

	return achievement, nil
}

func (s *achievementService) GetAllAchievements(ctx context.Context) ([]*internal.Achievement, error) {
	// Try cache first
	cacheKey := "achievements:all"
	var cached []*internal.Achievement
	if err := s.cache.Get(ctx, cacheKey, &cached); err == nil {
		return cached, nil
	}

	achievements, err := s.achievementRepo.GetAll(ctx)
	if err != nil {
		return nil, err
	}

	// Cache for 30 minutes
	s.cache.Set(ctx, cacheKey, achievements, 1800)

	return achievements, nil
}

func (s *achievementService) GetAchievementsByRarity(ctx context.Context, rarity string) ([]*internal.Achievement, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("achievements:rarity:%s", rarity)
	var cached []*internal.Achievement
	if err := s.cache.Get(ctx, cacheKey, &cached); err == nil {
		return cached, nil
	}

	achievements, err := s.achievementRepo.GetByRarity(ctx, rarity)
	if err != nil {
		return nil, err
	}

	// Cache for 30 minutes
	s.cache.Set(ctx, cacheKey, achievements, 1800)

	return achievements, nil
}

func (s *achievementService) UpdateAchievement(ctx context.Context, req *internal.UpdateAchievementRequest) (*internal.Achievement, error) {
	// Get existing achievement
	achievement, err := s.achievementRepo.GetByID(ctx, req.ID)
	if err != nil {
		return nil, err
	}

	// Update fields if provided
	if req.Name != "" {
		achievement.Name = req.Name
	}
	if req.Description != "" {
		achievement.Description = req.Description
	}
	if req.Icon != "" {
		achievement.Icon = req.Icon
	}
	if req.Rarity != "" {
		achievement.Rarity = req.Rarity
	}
	if req.XPReward > 0 {
		achievement.XPReward = req.XPReward
	}
	if req.Requirement != "" {
		achievement.Requirement = req.Requirement
	}
	if req.Total > 0 {
		achievement.Total = req.Total
	}

	if err := s.achievementRepo.Update(ctx, achievement); err != nil {
		return nil, err
	}

	// Invalidate cache
	s.cache.Delete(ctx, fmt.Sprintf("achievement:%s", achievement.ID))
	s.cache.Delete(ctx, "achievements:all")
	s.cache.Delete(ctx, fmt.Sprintf("achievements:rarity:%s", achievement.Rarity))

	return achievement, nil
}

func (s *achievementService) GetUserAchievements(ctx context.Context, userID string) ([]*internal.AchievementWithProgress, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("user:%s:achievements", userID)
	var cached []*internal.AchievementWithProgress
	if err := s.cache.Get(ctx, cacheKey, &cached); err == nil {
		return cached, nil
	}

	achievements, err := s.userAchievementRepo.GetUserAchievementsWithProgress(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Cache for 5 minutes
	s.cache.Set(ctx, cacheKey, achievements, 300)

	return achievements, nil
}

func (s *achievementService) GetUserStats(ctx context.Context, userID string) (*internal.UserAchievementStats, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("user:%s:achievement_stats", userID)
	var cached internal.UserAchievementStats
	if err := s.cache.Get(ctx, cacheKey, &cached); err == nil {
		return &cached, nil
	}

	stats, err := s.userAchievementRepo.GetUserStats(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Cache for 5 minutes
	s.cache.Set(ctx, cacheKey, stats, 300)

	return stats, nil
}

func (s *achievementService) UpdateProgress(ctx context.Context, userID, achievementID string, increment int) error {
	// Get user achievement
	userAchievement, err := s.userAchievementRepo.GetByUserAndAchievement(ctx, userID, achievementID)
	if err != nil {
		return err
	}

	// If not exists, create it
	if userAchievement == nil {
		userAchievement = &internal.UserAchievement{
			UserID:        userID,
			AchievementID: achievementID,
			Progress:      0,
			Unlocked:      false,
		}
		if err := s.userAchievementRepo.Create(ctx, userAchievement); err != nil {
			return err
		}
	}

	// If already unlocked, no need to update
	if userAchievement.Unlocked {
		return nil
	}

	// Update progress
	newProgress := userAchievement.Progress + increment

	// Get achievement details to check total
	achievement, err := s.achievementRepo.GetByID(ctx, achievementID)
	if err != nil {
		return err
	}

	// Check if unlocked
	if newProgress >= achievement.Total {
		newProgress = achievement.Total
		if err := s.userAchievementRepo.UnlockAchievement(ctx, userID, achievementID); err != nil {
			return err
		}

		s.log.Info("Achievement unlocked", map[string]interface{}{
			"user_id":        userID,
			"achievement_id": achievementID,
			"name":           achievement.Name,
			"xp_reward":      achievement.XPReward,
		})

		// TODO: Award XP to user (call user service)
	}

	// Update progress
	if err := s.userAchievementRepo.UpdateProgress(ctx, userID, achievementID, newProgress); err != nil {
		return err
	}

	// Invalidate cache
	s.cache.Delete(ctx, fmt.Sprintf("user:%s:achievements", userID))
	s.cache.Delete(ctx, fmt.Sprintf("user:%s:achievement_stats", userID))

	return nil
}

func (s *achievementService) InitializeUserAchievements(ctx context.Context, userID string) error {
	// Get all achievements
	achievements, err := s.achievementRepo.GetAll(ctx)
	if err != nil {
		return err
	}

	// Create user achievement entry for each
	for _, achievement := range achievements {
		userAchievement := &internal.UserAchievement{
			UserID:        userID,
			AchievementID: achievement.ID,
			Progress:      0,
			Unlocked:      false,
		}

		if err := s.userAchievementRepo.Create(ctx, userAchievement); err != nil {
			s.log.Error("Failed to initialize user achievement", map[string]interface{}{
				"error":          err.Error(),
				"user_id":        userID,
				"achievement_id": achievement.ID,
			})
			continue
		}
	}

	s.log.Info("User achievements initialized", map[string]interface{}{
		"user_id": userID,
		"count":   len(achievements),
	})

	return nil
}
