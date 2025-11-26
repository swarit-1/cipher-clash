package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal"
	"github.com/swarit-1/cipher-clash/services/tutorial/internal/service"
)

type TutorialHandler struct {
	tutorialService   service.TutorialService
	visualizerService service.VisualizerService
	jwtManager        *auth.JWTManager
	log               *logger.Logger
}

func NewTutorialHandler(
	tutorialService service.TutorialService,
	visualizerService service.VisualizerService,
	jwtManager *auth.JWTManager,
	log *logger.Logger,
) *TutorialHandler {
	return &TutorialHandler{
		tutorialService:   tutorialService,
		visualizerService: visualizerService,
		jwtManager:        jwtManager,
		log:               log,
	}
}

func (h *TutorialHandler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"service": "tutorial-service",
	})
}

func (h *TutorialHandler) GetTutorialSteps(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Check for user_id query parameter to include progress
	userID := r.URL.Query().Get("user_id")

	if userID != "" {
		// Return steps with progress
		stepsWithProgress, err := h.tutorialService.GetStepsWithProgress(r.Context(), userID)
		if err != nil {
			h.log.Error("Failed to get steps with progress", map[string]interface{}{
				"error":   err.Error(),
				"user_id": userID,
			})
			http.Error(w, `{"error":"Failed to get tutorial steps"}`, http.StatusInternalServerError)
			return
		}

		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(map[string]interface{}{
			"steps": stepsWithProgress,
			"count": len(stepsWithProgress),
		})
		return
	}

	// Return steps without progress
	steps, err := h.tutorialService.GetAllSteps(r.Context())
	if err != nil {
		h.log.Error("Failed to get tutorial steps", map[string]interface{}{
			"error": err.Error(),
		})
		http.Error(w, `{"error":"Failed to get tutorial steps"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"steps": steps,
		"count": len(steps),
	})
}

func (h *TutorialHandler) GetUserProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		http.Error(w, `{"error":"user_id is required"}`, http.StatusBadRequest)
		return
	}

	progress, err := h.tutorialService.GetUserProgress(r.Context(), userID)
	if err != nil {
		h.log.Error("Failed to get user progress", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		http.Error(w, `{"error":"Failed to get user progress"}`, http.StatusInternalServerError)
		return
	}

	stats, err := h.tutorialService.GetUserStats(r.Context(), userID)
	if err != nil {
		h.log.Error("Failed to get user stats", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		http.Error(w, `{"error":"Failed to get user stats"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"progress": progress,
		"stats":    stats,
	})
}

func (h *TutorialHandler) UpdateProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.UpdateProgressRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.UserID == "" || req.StepID == "" {
		http.Error(w, `{"error":"user_id and step_id are required"}`, http.StatusBadRequest)
		return
	}

	err := h.tutorialService.UpdateProgress(r.Context(), req.UserID, req.StepID, req.TimeSpentSecs, req.Score)
	if err != nil {
		h.log.Error("Failed to update progress", map[string]interface{}{
			"error":   err.Error(),
			"user_id": req.UserID,
			"step_id": req.StepID,
		})
		http.Error(w, `{"error":"Failed to update progress"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Progress updated successfully",
	})
}

func (h *TutorialHandler) CompleteStep(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.CompleteStepRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.UserID == "" || req.StepID == "" {
		http.Error(w, `{"error":"user_id and step_id are required"}`, http.StatusBadRequest)
		return
	}

	err := h.tutorialService.CompleteStep(r.Context(), req.UserID, req.StepID, req.TimeSpentSecs, req.Score)
	if err != nil {
		h.log.Error("Failed to complete step", map[string]interface{}{
			"error":   err.Error(),
			"user_id": req.UserID,
			"step_id": req.StepID,
		})
		http.Error(w, `{"error":"Failed to complete step"}`, http.StatusInternalServerError)
		return
	}

	// Get updated stats
	stats, err := h.tutorialService.GetUserStats(r.Context(), req.UserID)
	if err != nil {
		h.log.Error("Failed to get user stats after completion", map[string]interface{}{
			"error":   err.Error(),
			"user_id": req.UserID,
		})
		// Don't fail the request, just log the error
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Step completed successfully",
		"stats":   stats,
	})
}

func (h *TutorialHandler) SkipTutorial(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.SkipTutorialRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.UserID == "" {
		http.Error(w, `{"error":"user_id is required"}`, http.StatusBadRequest)
		return
	}

	err := h.tutorialService.SkipTutorial(r.Context(), req.UserID)
	if err != nil {
		h.log.Error("Failed to skip tutorial", map[string]interface{}{
			"error":   err.Error(),
			"user_id": req.UserID,
		})
		http.Error(w, `{"error":"Failed to skip tutorial"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Tutorial skipped successfully",
	})
}

func (h *TutorialHandler) GetCipherVisualization(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Extract cipher type from URL path
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/tutorial/visualize/")
	cipherType := strings.ToUpper(path)

	if cipherType == "" {
		http.Error(w, `{"error":"cipher_type is required"}`, http.StatusBadRequest)
		return
	}

	// Parse request body for input and key
	var reqBody struct {
		Input string `json:"input"`
		Key   string `json:"key"`
	}

	if err := json.NewDecoder(r.Body).Decode(&reqBody); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if reqBody.Input == "" {
		reqBody.Input = "HELLO"
	}

	visualization, err := h.visualizerService.GetCipherVisualization(r.Context(), cipherType, reqBody.Input, reqBody.Key)
	if err != nil {
		h.log.Error("Failed to get cipher visualization", map[string]interface{}{
			"error":       err.Error(),
			"cipher_type": cipherType,
		})
		http.Error(w, `{"error":"Failed to get visualization"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(visualization)
}

func (h *TutorialHandler) GetAvailableVisualizers(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	visualizers, err := h.visualizerService.GetAvailableVisualizers(r.Context())
	if err != nil {
		h.log.Error("Failed to get available visualizers", map[string]interface{}{
			"error": err.Error(),
		})
		http.Error(w, `{"error":"Failed to get visualizers"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"visualizers": visualizers,
		"count":       len(visualizers),
	})
}

func (h *TutorialHandler) StartBotBattle(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.StartBotBattleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.UserID == "" || req.CipherType == "" {
		http.Error(w, `{"error":"user_id and cipher_type are required"}`, http.StatusBadRequest)
		return
	}

	// This is a simplified implementation
	// In a real scenario, you would create a bot battle in the database
	// and possibly call the puzzle engine service to generate a puzzle

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message":     "Bot battle started",
		"battle_id":   "bot-battle-123",
		"cipher_type": req.CipherType,
		"difficulty":  req.Difficulty,
	})
}

func (h *TutorialHandler) SubmitBotBattleSolution(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.SubmitBotBattleSolutionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.BattleID == "" || req.UserID == "" || req.Solution == "" {
		http.Error(w, `{"error":"battle_id, user_id, and solution are required"}`, http.StatusBadRequest)
		return
	}

	// This is a simplified implementation
	// In a real scenario, you would validate the solution and update the battle

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"message": "Solution submitted",
		"correct": true,
		"won":     true,
		"score":   100,
	})
}
