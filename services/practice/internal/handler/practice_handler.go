package handler

import (
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/practice/internal"
	"github.com/swarit-1/cipher-clash/services/practice/internal/service"
)

type PracticeHandler struct {
	service    *service.PracticeService
	jwtManager *auth.JWTManager
	log        *logger.Logger
}

func NewPracticeHandler(
	service *service.PracticeService,
	jwtManager *auth.JWTManager,
	log *logger.Logger,
) *PracticeHandler {
	return &PracticeHandler{
		service:    service,
		jwtManager: jwtManager,
		log:        log,
	}
}

// Health check
func (h *PracticeHandler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status":  "healthy",
		"service": "practice",
	})
}

// GeneratePuzzle handles POST /api/v1/practice/generate
func (h *PracticeHandler) GeneratePuzzle(w http.ResponseWriter, r *http.Request) {
	// Extract user ID from JWT
	userID, err := h.getUserIDFromToken(r)
	if err != nil {
		h.respondError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// Parse request
	var req internal.GeneratePuzzleRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate request
	if req.CipherType == "" {
		h.respondError(w, http.StatusBadRequest, "cipher_type is required")
		return
	}
	if req.Difficulty < 1 || req.Difficulty > 10 {
		h.respondError(w, http.StatusBadRequest, "difficulty must be between 1 and 10")
		return
	}
	if req.Mode == "" {
		req.Mode = "UNTIMED"
	}

	// Generate puzzle
	result, err := h.service.GeneratePuzzle(r.Context(), userID, &req)
	if err != nil {
		h.log.Error("Failed to generate puzzle", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		h.respondError(w, http.StatusInternalServerError, "Failed to generate puzzle")
		return
	}

	h.respondSuccess(w, http.StatusOK, result)
}

// SubmitSolution handles POST /api/v1/practice/submit
func (h *PracticeHandler) SubmitSolution(w http.ResponseWriter, r *http.Request) {
	// Extract user ID from JWT
	userID, err := h.getUserIDFromToken(r)
	if err != nil {
		h.respondError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// Parse request
	var req internal.SubmitSolutionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, http.StatusBadRequest, "Invalid request body")
		return
	}

	// Validate request
	if req.SessionID == "" {
		h.respondError(w, http.StatusBadRequest, "session_id is required")
		return
	}
	if req.Solution == "" {
		h.respondError(w, http.StatusBadRequest, "solution is required")
		return
	}

	// Submit solution
	result, err := h.service.SubmitSolution(r.Context(), userID, &req)
	if err != nil {
		h.log.Error("Failed to submit solution", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		h.respondError(w, http.StatusInternalServerError, err.Error())
		return
	}

	h.respondSuccess(w, http.StatusOK, result)
}

// GetHistory handles GET /api/v1/practice/history
func (h *PracticeHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	// Extract user ID from JWT
	userID, err := h.getUserIDFromToken(r)
	if err != nil {
		h.respondError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// Parse query parameters
	cipherType := r.URL.Query().Get("cipher_type")
	var cipherTypePtr *string
	if cipherType != "" {
		cipherTypePtr = &cipherType
	}

	limit := 20
	if limitStr := r.URL.Query().Get("limit"); limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil {
			limit = l
		}
	}

	offset := 0
	if offsetStr := r.URL.Query().Get("offset"); offsetStr != "" {
		if o, err := strconv.Atoi(offsetStr); err == nil {
			offset = o
		}
	}

	// Get history
	result, err := h.service.GetHistory(r.Context(), userID, cipherTypePtr, limit, offset)
	if err != nil {
		h.log.Error("Failed to get history", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		h.respondError(w, http.StatusInternalServerError, "Failed to get history")
		return
	}

	h.respondSuccess(w, http.StatusOK, result)
}

// GetPersonalBests handles GET /api/v1/practice/leaderboard/:cipher_type
func (h *PracticeHandler) GetPersonalBests(w http.ResponseWriter, r *http.Request) {
	// Extract user ID from JWT
	userID, err := h.getUserIDFromToken(r)
	if err != nil {
		h.respondError(w, http.StatusUnauthorized, "Unauthorized")
		return
	}

	// Extract cipher type from path
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/api/v1/practice/leaderboard/"), "/")
	if len(parts) == 0 || parts[0] == "" {
		h.respondError(w, http.StatusBadRequest, "cipher_type is required")
		return
	}
	cipherType := parts[0]

	// Parse difficulty query parameter
	var difficultyPtr *int
	if diffStr := r.URL.Query().Get("difficulty"); diffStr != "" {
		if d, err := strconv.Atoi(diffStr); err == nil {
			difficultyPtr = &d
		}
	}

	// Get personal bests
	result, err := h.service.GetPersonalBests(r.Context(), userID, &cipherType, difficultyPtr)
	if err != nil {
		h.log.Error("Failed to get personal bests", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		h.respondError(w, http.StatusInternalServerError, "Failed to get personal bests")
		return
	}

	h.respondSuccess(w, http.StatusOK, result)
}

// Helper functions

func (h *PracticeHandler) getUserIDFromToken(r *http.Request) (string, error) {
	authHeader := r.Header.Get("Authorization")
	if authHeader == "" {
		return "", http.ErrNoCookie
	}

	token := strings.TrimPrefix(authHeader, "Bearer ")
	claims, err := h.jwtManager.ValidateToken(token, auth.AccessToken)
	if err != nil {
		return "", err
	}

	return claims.UserID, nil
}

func (h *PracticeHandler) respondSuccess(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": true,
		"data":    data,
	})
}

func (h *PracticeHandler) respondError(w http.ResponseWriter, status int, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"success": false,
		"error":   message,
	})
}
