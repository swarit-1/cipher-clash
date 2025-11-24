package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/service"
)

// MatchmakerHandler handles HTTP requests for matchmaking
type MatchmakerHandler struct {
	matchmakerService *service.MatchmakerService
	log               *logger.Logger
}

// NewMatchmakerHandler creates a new matchmaker handler
func NewMatchmakerHandler(matchmakerService *service.MatchmakerService, log *logger.Logger) *MatchmakerHandler {
	return &MatchmakerHandler{
		matchmakerService: matchmakerService,
		log:               log,
	}
}

// JoinQueue handles queue join requests
func (h *MatchmakerHandler) JoinQueue(w http.ResponseWriter, r *http.Request) {
	var req service.JoinQueueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	response, err := h.matchmakerService.JoinQueue(r.Context(), &req)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, response)
}

// LeaveQueue handles queue leave requests
func (h *MatchmakerHandler) LeaveQueue(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID string `json:"user_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if err := h.matchmakerService.LeaveQueue(r.Context(), req.UserID); err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Left queue successfully",
	})
}

// GetQueueStatus returns current queue status
func (h *MatchmakerHandler) GetQueueStatus(w http.ResponseWriter, r *http.Request) {
	userID := r.URL.Query().Get("user_id")
	if userID == "" {
		h.respondError(w, errors.NewInvalidInputError("User ID is required"))
		return
	}

	status, err := h.matchmakerService.GetQueueStatus(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, status)
}

// GetLeaderboard returns leaderboard
func (h *MatchmakerHandler) GetLeaderboard(w http.ResponseWriter, r *http.Request) {
	region := r.URL.Query().Get("region")
	seasonID, _ := strconv.Atoi(r.URL.Query().Get("season_id"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))

	if limit == 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}

	entries, err := h.matchmakerService.GetLeaderboard(r.Context(), region, seasonID, limit, offset)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"entries":      entries,
		"total_count":  len(entries),
		"limit":        limit,
		"offset":       offset,
	})
}

// Health check endpoint
func (h *MatchmakerHandler) Health(w http.ResponseWriter, r *http.Request) {
	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"status":  "healthy",
		"service": "matchmaker",
	})
}

// Helper methods

func (h *MatchmakerHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(data); err != nil {
		h.log.Error("Failed to encode response", map[string]interface{}{
			"error": err.Error(),
		})
	}
}

func (h *MatchmakerHandler) respondError(w http.ResponseWriter, err error) {
	var appErr *errors.AppError
	var ok bool
	if appErr, ok = err.(*errors.AppError); !ok {
		appErr = errors.NewInternalServerError(err)
	}

	h.log.Error("Request error", map[string]interface{}{
		"code":    appErr.Code,
		"message": appErr.Message,
		"error":   appErr.Error(),
	})

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(appErr.HTTPStatus)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]interface{}{
			"code":    appErr.Code,
			"message": appErr.Message,
		},
	})
}
