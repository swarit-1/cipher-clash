package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/missions/internal/models"
	"github.com/swarit-1/cipher-clash/services/missions/internal/repository"
)

type MissionRewards struct {
	XP    int `json:"xp"`
	Coins int `json:"coins"`
}

type MissionsService struct {
	missionsRepo     repository.MissionsRepository
	userMissionsRepo repository.UserMissionsRepository
	log              *logger.Logger
}

func NewMissionsService(
	missionsRepo repository.MissionsRepository,
	userMissionsRepo repository.UserMissionsRepository,
	log *logger.Logger,
) *MissionsService {
	return &MissionsService{
		missionsRepo:     missionsRepo,
		userMissionsRepo: userMissionsRepo,
		log:              log,
	}
}

// GetMissionTemplates retrieves all mission templates with optional filters
func (s *MissionsService) GetMissionTemplates(ctx context.Context, category, frequency string) ([]*models.MissionTemplate, error) {
	templates, err := s.missionsRepo.GetAllTemplates(ctx, category, frequency)
	if err != nil {
		s.log.LogError("Failed to get mission templates", "error", err)
		return nil, errors.NewInternalError("Failed to retrieve mission templates")
	}

	return templates, nil
}

// GetMissionTemplate retrieves a specific mission template
func (s *MissionsService) GetMissionTemplate(ctx context.Context, templateID string) (*models.MissionTemplate, error) {
	template, err := s.missionsRepo.GetTemplateByID(ctx, templateID)
	if err != nil {
		s.log.LogError("Failed to get mission template", "template_id", templateID, "error", err)
		return nil, errors.NewNotFoundError("Mission template not found")
	}

	return template, nil
}

// GetUserMissions retrieves all missions for a user
func (s *MissionsService) GetUserMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error) {
	missions, err := s.userMissionsRepo.GetUserMissions(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get user missions", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve user missions")
	}

	// Populate template data for each mission
	for _, mission := range missions {
		template, err := s.missionsRepo.GetTemplateByID(ctx, mission.TemplateID)
		if err == nil {
			mission.Template = template
		}
	}

	return missions, nil
}

// GetActiveMissions retrieves active (non-expired) missions for a user
func (s *MissionsService) GetActiveMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error) {
	missions, err := s.userMissionsRepo.GetActiveMissions(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get active missions", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve active missions")
	}

	// Populate template data
	for _, mission := range missions {
		template, err := s.missionsRepo.GetTemplateByID(ctx, mission.TemplateID)
		if err == nil {
			mission.Template = template
		}
	}

	return missions, nil
}

// AssignDailyMissions assigns new daily missions to a user
func (s *MissionsService) AssignDailyMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error) {
	// Get daily mission templates
	templates, err := s.missionsRepo.GetAllTemplates(ctx, "", "daily")
	if err != nil {
		return nil, errors.NewInternalError("Failed to get daily mission templates")
	}

	if len(templates) == 0 {
		return nil, errors.NewNotFoundError("No daily mission templates available")
	}

	// Assign 3-5 random daily missions
	assignCount := 3
	if len(templates) > 5 {
		assignCount = 5
	}

	var newMissions []*models.UserMission
	expiresAt := time.Now().Add(24 * time.Hour)

	for i := 0; i < assignCount && i < len(templates); i++ {
		template := templates[i]

		mission := &models.UserMission{
			ID:           uuid.New(),
			UserID:       userID,
			TemplateID:   template.ID,
			Progress:     0,
			Target:       template.Target,
			Status:       "active",
			AssignedDate: time.Now(),
			ExpiresAt:    expiresAt,
		}

		if err := s.userMissionsRepo.CreateUserMission(ctx, mission); err != nil {
			s.log.LogError("Failed to create user mission", "error", err)
			continue
		}

		mission.Template = template
		newMissions = append(newMissions, mission)
	}

	s.log.LogInfo("Assigned daily missions", "user_id", userID, "count", len(newMissions))
	return newMissions, nil
}

// UpdateMissionProgress updates progress for a specific mission
func (s *MissionsService) UpdateMissionProgress(ctx context.Context, userID uuid.UUID, templateID string, progress int) (*models.UserMission, error) {
	mission, err := s.userMissionsRepo.GetUserMissionByTemplate(ctx, userID, templateID)
	if err != nil {
		return nil, errors.NewNotFoundError("Mission not found")
	}

	if mission.Status != "active" {
		return nil, errors.NewInvalidInputError("Mission is not active")
	}

	// Check if expired
	if time.Now().After(mission.ExpiresAt) {
		mission.Status = "expired"
		s.userMissionsRepo.UpdateUserMission(ctx, mission)
		return nil, errors.NewInvalidInputError("Mission has expired")
	}

	// Update progress
	mission.Progress = progress
	if mission.Progress >= mission.Target {
		mission.Progress = mission.Target
		// Auto-complete when target reached
		mission.Status = "completed"
		now := time.Now()
		mission.CompletedAt = &now
	}

	if err := s.userMissionsRepo.UpdateUserMission(ctx, mission); err != nil {
		s.log.LogError("Failed to update mission progress", "error", err)
		return nil, errors.NewInternalError("Failed to update mission")
	}

	// Populate template
	template, _ := s.missionsRepo.GetTemplateByID(ctx, mission.TemplateID)
	mission.Template = template

	return mission, nil
}

// CompleteMission marks a mission as completed
func (s *MissionsService) CompleteMission(ctx context.Context, userID uuid.UUID, templateID string) (*models.UserMission, error) {
	mission, err := s.userMissionsRepo.GetUserMissionByTemplate(ctx, userID, templateID)
	if err != nil {
		return nil, errors.NewNotFoundError("Mission not found")
	}

	if mission.Progress < mission.Target {
		return nil, errors.NewInvalidInputError("Mission target not reached")
	}

	mission.Status = "completed"
	now := time.Now()
	mission.CompletedAt = &now

	if err := s.userMissionsRepo.UpdateUserMission(ctx, mission); err != nil {
		return nil, errors.NewInternalError("Failed to complete mission")
	}

	// Populate template
	template, _ := s.missionsRepo.GetTemplateByID(ctx, mission.TemplateID)
	mission.Template = template

	s.log.LogInfo("Mission completed", "user_id", userID, "template_id", templateID)
	return mission, nil
}

// ClaimMissionReward claims rewards for a completed mission
func (s *MissionsService) ClaimMissionReward(ctx context.Context, userID uuid.UUID, templateID string) (*MissionRewards, error) {
	mission, err := s.userMissionsRepo.GetUserMissionByTemplate(ctx, userID, templateID)
	if err != nil {
		return nil, errors.NewNotFoundError("Mission not found")
	}

	if mission.Status != "completed" {
		return nil, errors.NewInvalidInputError("Mission not completed")
	}

	if mission.ClaimedAt != nil {
		return nil, errors.NewInvalidInputError("Rewards already claimed")
	}

	// Get rewards from template
	template, err := s.missionsRepo.GetTemplateByID(ctx, templateID)
	if err != nil {
		return nil, errors.NewNotFoundError("Mission template not found")
	}

	rewards := &MissionRewards{
		XP:    template.XPReward,
		Coins: template.CoinReward,
	}

	// Mark as claimed
	mission.Status = "claimed"
	now := time.Now()
	mission.ClaimedAt = &now

	if err := s.userMissionsRepo.UpdateUserMission(ctx, mission); err != nil {
		return nil, errors.NewInternalError("Failed to claim rewards")
	}

	// TODO: Add rewards to user wallet/profile

	s.log.LogInfo("Mission rewards claimed", "user_id", userID, "xp", rewards.XP, "coins", rewards.Coins)
	return rewards, nil
}

// RefreshExpiredMissions removes expired missions and optionally assigns new ones
func (s *MissionsService) RefreshExpiredMissions(ctx context.Context, userID uuid.UUID) ([]*models.UserMission, error) {
	// Mark expired missions
	if err := s.userMissionsRepo.MarkExpiredMissions(ctx, userID); err != nil {
		s.log.LogError("Failed to mark expired missions", "error", err)
	}

	// Get current active missions
	activeMissions, err := s.GetActiveMissions(ctx, userID)
	if err != nil {
		return nil, err
	}

	// If fewer than 3 active missions, assign new daily missions
	if len(activeMissions) < 3 {
		newMissions, _ := s.AssignDailyMissions(ctx, userID)
		activeMissions = append(activeMissions, newMissions...)
	}

	return activeMissions, nil
}

// GetMissionStats retrieves mission statistics for a user
func (s *MissionsService) GetMissionStats(ctx context.Context, userID uuid.UUID) (*models.MissionStats, error) {
	stats, err := s.userMissionsRepo.GetMissionStats(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get mission stats", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve mission statistics")
	}

	return stats, nil
}
