package service

import (
	"context"
	"fmt"

	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal/repository"
)

type TutorialService interface {
	GetAllSteps(ctx context.Context) ([]*internal.TutorialStep, error)
	GetStepByID(ctx context.Context, stepID string) (*internal.TutorialStep, error)
	GetStepsWithProgress(ctx context.Context, userID string) ([]*internal.TutorialStepWithProgress, error)
	GetUserProgress(ctx context.Context, userID string) ([]*internal.UserProgress, error)
	UpdateProgress(ctx context.Context, userID, stepID string, timeSpentSecs int, score *int) error
	CompleteStep(ctx context.Context, userID, stepID string, timeSpentSecs int, score *int) error
	SkipTutorial(ctx context.Context, userID string) error
	GetUserStats(ctx context.Context, userID string) (*internal.UserTutorialStats, error)
}

type tutorialService struct {
	tutorialRepo repository.TutorialRepository
	progressRepo repository.ProgressRepository
	log          *logger.Logger
}

func NewTutorialService(
	tutorialRepo repository.TutorialRepository,
	progressRepo repository.ProgressRepository,
	log *logger.Logger,
) TutorialService {
	return &tutorialService{
		tutorialRepo: tutorialRepo,
		progressRepo: progressRepo,
		log:          log,
	}
}

func (s *tutorialService) GetAllSteps(ctx context.Context) ([]*internal.TutorialStep, error) {
	steps, err := s.tutorialRepo.GetAllSteps(ctx)
	if err != nil {
		s.log.Error("Failed to get all tutorial steps", map[string]interface{}{
			"error": err.Error(),
		})
		return nil, err
	}

	return steps, nil
}

func (s *tutorialService) GetStepByID(ctx context.Context, stepID string) (*internal.TutorialStep, error) {
	step, err := s.tutorialRepo.GetStepByID(ctx, stepID)
	if err != nil {
		s.log.Error("Failed to get tutorial step", map[string]interface{}{
			"error":   err.Error(),
			"step_id": stepID,
		})
		return nil, err
	}

	return step, nil
}

func (s *tutorialService) GetStepsWithProgress(ctx context.Context, userID string) ([]*internal.TutorialStepWithProgress, error) {
	// Get all tutorial steps
	steps, err := s.tutorialRepo.GetAllSteps(ctx)
	if err != nil {
		return nil, err
	}

	// Get user's progress
	progressList, err := s.progressRepo.GetUserProgress(ctx, userID)
	if err != nil {
		return nil, err
	}

	// Create a map for quick lookup
	progressMap := make(map[string]*internal.UserProgress)
	for _, p := range progressList {
		progressMap[p.StepID] = p
	}

	// Combine steps with progress
	var stepsWithProgress []*internal.TutorialStepWithProgress
	for _, step := range steps {
		swp := &internal.TutorialStepWithProgress{
			TutorialStep:  *step,
			Completed:     false,
			TimeSpentSecs: 0,
		}

		if progress, ok := progressMap[step.ID]; ok {
			swp.Completed = progress.Completed
			swp.CompletedAt = progress.CompletedAt
			swp.TimeSpentSecs = progress.TimeSpentSecs
			swp.Score = progress.Score
		}

		stepsWithProgress = append(stepsWithProgress, swp)
	}

	return stepsWithProgress, nil
}

func (s *tutorialService) GetUserProgress(ctx context.Context, userID string) ([]*internal.UserProgress, error) {
	progress, err := s.progressRepo.GetUserProgress(ctx, userID)
	if err != nil {
		s.log.Error("Failed to get user progress", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		return nil, err
	}

	return progress, nil
}

func (s *tutorialService) UpdateProgress(ctx context.Context, userID, stepID string, timeSpentSecs int, score *int) error {
	// Check if step exists
	_, err := s.tutorialRepo.GetStepByID(ctx, stepID)
	if err != nil {
		return fmt.Errorf("tutorial step not found: %w", err)
	}

	// Get or create progress
	progress, err := s.progressRepo.GetUserProgressForStep(ctx, userID, stepID)
	if err != nil {
		return err
	}

	if progress == nil {
		// Create new progress
		progress = &internal.UserProgress{
			UserID:        userID,
			StepID:        stepID,
			Completed:     false,
			TimeSpentSecs: timeSpentSecs,
			Score:         score,
		}
		return s.progressRepo.CreateProgress(ctx, progress)
	}

	// Update existing progress
	progress.TimeSpentSecs += timeSpentSecs
	if score != nil {
		progress.Score = score
	}

	return s.progressRepo.UpdateProgress(ctx, progress)
}

func (s *tutorialService) CompleteStep(ctx context.Context, userID, stepID string, timeSpentSecs int, score *int) error {
	// Check if step exists
	_, err := s.tutorialRepo.GetStepByID(ctx, stepID)
	if err != nil {
		return fmt.Errorf("tutorial step not found: %w", err)
	}

	err = s.progressRepo.CompleteStep(ctx, userID, stepID, timeSpentSecs, score)
	if err != nil {
		s.log.Error("Failed to complete step", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
			"step_id": stepID,
		})
		return err
	}

	s.log.Info("User completed tutorial step", map[string]interface{}{
		"user_id": userID,
		"step_id": stepID,
	})

	return nil
}

func (s *tutorialService) SkipTutorial(ctx context.Context, userID string) error {
	err := s.progressRepo.MarkAllStepsSkipped(ctx, userID)
	if err != nil {
		s.log.Error("Failed to skip tutorial", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		return err
	}

	s.log.Info("User skipped tutorial", map[string]interface{}{
		"user_id": userID,
	})

	return nil
}

func (s *tutorialService) GetUserStats(ctx context.Context, userID string) (*internal.UserTutorialStats, error) {
	stats, err := s.progressRepo.GetUserStats(ctx, userID)
	if err != nil {
		s.log.Error("Failed to get user stats", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		return nil, err
	}

	return stats, nil
}
