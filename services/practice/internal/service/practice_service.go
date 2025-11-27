package service

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"

	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/practice/internal"
	"github.com/swarit-1/cipher-clash/services/practice/internal/repository"
)

type PracticeService struct {
	repo           *repository.PracticeRepository
	scoringService *ScoringService
	puzzleEngineURL string
	log             *logger.Logger
}

func NewPracticeService(
	repo *repository.PracticeRepository,
	scoringService *ScoringService,
	puzzleEngineURL string,
	log *logger.Logger,
) *PracticeService {
	return &PracticeService{
		repo:           repo,
		scoringService: scoringService,
		puzzleEngineURL: puzzleEngineURL,
		log:            log,
	}
}

// GeneratePuzzle generates a practice puzzle
func (s *PracticeService) GeneratePuzzle(ctx context.Context, userID string, req *internal.GeneratePuzzleRequest) (map[string]interface{}, error) {
	// Call puzzle engine to generate puzzle
	puzzleReq := map[string]interface{}{
		"cipher_type": req.CipherType,
		"difficulty":  req.Difficulty,
	}

	jsonData, err := json.Marshal(puzzleReq)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	resp, err := http.Post(
		s.puzzleEngineURL+"/api/v1/puzzle/generate",
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to call puzzle engine: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("puzzle engine returned error: %s", string(body))
	}

	var puzzleResp map[string]interface{}
	if err := json.Unmarshal(body, &puzzleResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	puzzleData, ok := puzzleResp["data"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid puzzle response format")
	}

	// Create practice session
	var timeLimitMs *int64
	if req.TimeLimitSeconds != nil {
		limit := int64(*req.TimeLimitSeconds * 1000)
		timeLimitMs = &limit
	}

	session := &internal.PracticeSession{
		UserID:      userID,
		PuzzleID:    puzzleData["id"].(string),
		CipherType:  req.CipherType,
		Difficulty:  req.Difficulty,
		Mode:        internal.PracticeMode(req.Mode),
		TimeLimitMs: timeLimitMs,
		HintsUsed:   0,
	}

	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, fmt.Errorf("failed to create session: %w", err)
	}

	// Build response
	puzzle := &internal.PracticePuzzle{
		ID:             puzzleData["id"].(string),
		CipherType:     req.CipherType,
		Difficulty:     req.Difficulty,
		EncryptedText:  puzzleData["encrypted_text"].(string),
		Config:         puzzleData["config"].(map[string]interface{}),
		HintsAvailable: 3, // Default hints
	}

	result := map[string]interface{}{
		"session_id": session.ID,
		"puzzle":     puzzle,
		"mode":       req.Mode,
		"started_at": session.StartedAt,
	}

	if timeLimitMs != nil {
		result["time_limit_ms"] = *timeLimitMs
	} else {
		result["time_limit_ms"] = 0
	}

	s.log.Info("Practice puzzle generated", map[string]interface{}{
		"user_id":     userID,
		"session_id":  session.ID,
		"cipher_type": req.CipherType,
		"difficulty":  req.Difficulty,
	})

	return result, nil
}

// SubmitSolution submits and validates a solution
func (s *PracticeService) SubmitSolution(ctx context.Context, userID string, req *internal.SubmitSolutionRequest) (map[string]interface{}, error) {
	// Get session
	session, err := s.repo.GetSessionByID(ctx, req.SessionID)
	if err != nil {
		return nil, fmt.Errorf("failed to get session: %w", err)
	}

	if session.UserID != userID {
		return nil, fmt.Errorf("session does not belong to user")
	}

	if session.SubmittedAt != nil {
		return nil, fmt.Errorf("session already completed")
	}

	// Validate solution with puzzle engine
	validateReq := map[string]interface{}{
		"puzzle_id": session.PuzzleID,
		"solution":  req.Solution,
	}

	jsonData, err := json.Marshal(validateReq)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request: %w", err)
	}

	resp, err := http.Post(
		s.puzzleEngineURL+"/api/v1/puzzle/validate",
		"application/json",
		bytes.NewBuffer(jsonData),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to validate solution: %w", err)
	}
	defer resp.Body.Close()

	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}

	var validateResp map[string]interface{}
	if err := json.Unmarshal(body, &validateResp); err != nil {
		return nil, fmt.Errorf("failed to unmarshal response: %w", err)
	}

	validationData, ok := validateResp["data"].(map[string]interface{})
	if !ok {
		return nil, fmt.Errorf("invalid validation response format")
	}

	isCorrect := validationData["is_correct"].(bool)
	correctAnswer := validationData["plaintext"].(string)

	// Calculate accuracy
	accuracy, charDiff := s.scoringService.CalculateAccuracy(correctAnswer, req.Solution)

	// Calculate score
	var timeLimitMs int64
	if session.TimeLimitMs != nil {
		timeLimitMs = *session.TimeLimitMs
	}

	score := s.scoringService.CalculateScore(
		req.SolveTimeMs,
		session.Difficulty,
		req.HintsUsed,
		accuracy,
		timeLimitMs,
	)

	// Check if perfect solve
	perfectSolve := s.scoringService.IsPerfectSolve(
		req.HintsUsed,
		accuracy,
		req.SolveTimeMs,
		session.Difficulty,
	)

	// Update session
	err = s.repo.UpdateSessionWithSolution(
		ctx,
		req.SessionID,
		req.Solution,
		req.SolveTimeMs,
		isCorrect,
		accuracy,
		score,
		perfectSolve,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to update session: %w", err)
	}

	// Build feedback
	feedback := &internal.SolutionFeedback{
		TimeRating:  s.scoringService.GetTimeRating(req.SolveTimeMs, session.Difficulty, timeLimitMs),
		HintsRating: s.scoringService.GetHintsRating(req.HintsUsed),
	}

	if isCorrect {
		feedback.Message = "Correct! Great job!"
		feedback.CharacterDiff = 0
	} else {
		feedback.Message = "Not quite right. Keep trying!"
		feedback.CorrectAnswer = &correctAnswer
		feedback.YourAnswer = &req.Solution
		feedback.CharacterDiff = charDiff
	}

	// Get personal best update
	personalBest := s.getPersonalBestUpdate(ctx, userID, session.CipherType, session.Difficulty, req.SolveTimeMs, score)

	// Calculate mastery XP
	masteryXP := s.calculateMasteryXP(session.Difficulty, req.SolveTimeMs, accuracy, req.HintsUsed, perfectSolve)

	// Build response
	result := map[string]interface{}{
		"is_correct":          isCorrect,
		"accuracy_percentage": accuracy,
		"score":               score,
		"perfect_solve":       perfectSolve,
		"feedback":            feedback,
		"personal_best":       personalBest,
		"mastery_update":      masteryXP,
	}

	s.log.Info("Practice solution submitted", map[string]interface{}{
		"user_id":     userID,
		"session_id":  req.SessionID,
		"is_correct":  isCorrect,
		"score":       score,
		"accuracy":    accuracy,
	})

	return result, nil
}

// GetHistory retrieves practice history
func (s *PracticeService) GetHistory(ctx context.Context, userID string, cipherType *string, limit, offset int) (map[string]interface{}, error) {
	sessions, total, err := s.repo.GetUserHistory(ctx, userID, cipherType, limit, offset)
	if err != nil {
		return nil, fmt.Errorf("failed to get history: %w", err)
	}

	hasMore := (offset + len(sessions)) < total

	result := map[string]interface{}{
		"sessions": sessions,
		"pagination": map[string]interface{}{
			"total":    total,
			"limit":    limit,
			"offset":   offset,
			"has_more": hasMore,
		},
	}

	return result, nil
}

// GetPersonalBests retrieves personal best records
func (s *PracticeService) GetPersonalBests(ctx context.Context, userID string, cipherType *string, difficulty *int) (map[string]interface{}, error) {
	records, err := s.repo.GetPersonalBests(ctx, userID, cipherType, difficulty)
	if err != nil {
		return nil, fmt.Errorf("failed to get personal bests: %w", err)
	}

	// Group by difficulty if cipher type is specified
	var leaderboards []map[string]interface{}
	for _, record := range records {
		leaderboards = append(leaderboards, map[string]interface{}{
			"difficulty":             record.Difficulty,
			"fastest_solve_ms":       record.FastestSolveMs,
			"fastest_achieved_at":    record.FastestAchievedAt,
			"highest_score":          record.HighestScore,
			"total_sessions":         record.TotalPracticeSessions,
			"perfect_solves":         record.PerfectSolves,
			"average_solve_time_ms":  record.AverageSolveTimeMs,
		})
	}

	result := map[string]interface{}{
		"cipher_type":  cipherType,
		"leaderboards": leaderboards,
	}

	return result, nil
}

// Helper function to get personal best update
func (s *PracticeService) getPersonalBestUpdate(ctx context.Context, userID, cipherType string, difficulty int, solveTimeMs int64, score int) *internal.PersonalBestUpdate {
	records, err := s.repo.GetPersonalBests(ctx, userID, &cipherType, &difficulty)
	if err != nil || len(records) == 0 {
		return &internal.PersonalBestUpdate{IsNewRecord: true, RecordType: "FIRST_TIME"}
	}

	record := records[0]
	isNewFastest := solveTimeMs < record.FastestSolveMs
	isNewHighScore := score > record.HighestScore

	if isNewFastest {
		improvement := record.FastestSolveMs - solveTimeMs
		return &internal.PersonalBestUpdate{
			IsNewRecord:       true,
			RecordType:        "FASTEST_TIME",
			PreviousFastestMs: &record.FastestSolveMs,
			ImprovementMs:     &improvement,
		}
	}

	if isNewHighScore {
		return &internal.PersonalBestUpdate{
			IsNewRecord: true,
			RecordType:  "HIGHEST_SCORE",
		}
	}

	return &internal.PersonalBestUpdate{IsNewRecord: false}
}

// Helper function to calculate mastery XP
func (s *PracticeService) calculateMasteryXP(difficulty int, solveTimeMs int64, accuracy float64, hintsUsed int, perfectSolve bool) *internal.MasteryXPGained {
	baseXP := difficulty * 10

	// Speed bonus
	targetTime := int64(difficulty * 30000)
	speedBonus := 0
	if solveTimeMs < targetTime {
		speedBonus = int(float64(baseXP) * 0.2)
	}

	// Accuracy bonus
	accuracyBonus := 0
	if accuracy == 100.0 {
		accuracyBonus = int(float64(baseXP) * 0.1)
	}

	// Mastery multiplier (could be fetched from mastery service)
	masteryMultiplier := 1.0

	totalXP := int(float64(baseXP+speedBonus+accuracyBonus) * masteryMultiplier)

	return &internal.MasteryXPGained{
		CipherType:        "",
		BaseXP:            baseXP,
		SpeedBonus:        speedBonus,
		AccuracyBonus:     accuracyBonus,
		MasteryMultiplier: masteryMultiplier,
		TotalXP:           totalXP,
		NewMasteryXP:      0,    // Would be updated after calling mastery service
		CurrentLevel:      0,    // Would be fetched from mastery service
		LevelUp:           false,
	}
}
