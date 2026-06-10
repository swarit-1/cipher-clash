package handler

import (
	"context"
	"crypto/subtle"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/matchmaker/internal/service"
)

type contextKey string

const userIDKey contextKey = "user_id"

// MatchmakerHandler handles HTTP requests for matchmaking
type MatchmakerHandler struct {
	matchmakerService *service.MatchmakerService
	jwtManager        *auth.JWTManager
	internalToken     string
	log               *logger.Logger
}

// NewMatchmakerHandler creates a new matchmaker handler
func NewMatchmakerHandler(matchmakerService *service.MatchmakerService, jwtManager *auth.JWTManager, internalToken string, log *logger.Logger) *MatchmakerHandler {
	return &MatchmakerHandler{
		matchmakerService: matchmakerService,
		jwtManager:        jwtManager,
		internalToken:     internalToken,
		log:               log,
	}
}

// RequireAuth validates the Bearer access token and injects the user id.
func (h *MatchmakerHandler) RequireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			h.respondError(w, errors.NewUnauthorizedError("Missing bearer token"))
			return
		}
		claims, err := h.jwtManager.ValidateToken(strings.TrimPrefix(header, "Bearer "), auth.AccessToken)
		if err != nil {
			h.respondError(w, errors.NewUnauthorizedError("Invalid or expired token"))
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userIDKey, claims.UserID)))
	}
}

// RequireInternal guards service-to-service endpoints with a shared token.
func (h *MatchmakerHandler) RequireInternal(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token := r.Header.Get("X-Internal-Token")
		if h.internalToken == "" || subtle.ConstantTimeCompare([]byte(token), []byte(h.internalToken)) != 1 {
			h.respondError(w, errors.NewForbiddenError("Invalid internal token"))
			return
		}
		next(w, r)
	}
}

func userID(r *http.Request) string {
	id, _ := r.Context().Value(userIDKey).(string)
	return id
}

// JoinQueue handles queue join requests (authenticated).
func (h *MatchmakerHandler) JoinQueue(w http.ResponseWriter, r *http.Request) {
	var req service.JoinQueueRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	response, err := h.matchmakerService.JoinQueue(r.Context(), userID(r), &req)
	if err != nil {
		h.respondError(w, err)
		return
	}
	h.respondJSON(w, http.StatusOK, response)
}

// LeaveQueue handles queue leave requests (authenticated).
func (h *MatchmakerHandler) LeaveQueue(w http.ResponseWriter, r *http.Request) {
	if err := h.matchmakerService.LeaveQueue(r.Context(), userID(r)); err != nil {
		h.respondError(w, err)
		return
	}
	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Left queue successfully",
	})
}

// GetQueueStatus returns the player's matchmaking state, including
// match_found with the match id once a match forms.
func (h *MatchmakerHandler) GetQueueStatus(w http.ResponseWriter, r *http.Request) {
	status, err := h.matchmakerService.GetQueueStatus(r.Context(), userID(r))
	if err != nil {
		h.respondError(w, err)
		return
	}
	h.respondJSON(w, http.StatusOK, status)
}

// UpdateRatings applies an ELO update for a completed ranked match.
// Internal: called by the game service.
func (h *MatchmakerHandler) UpdateRatings(w http.ResponseWriter, r *http.Request) {
	var req struct {
		MatchID   string `json:"match_id"`
		WinnerID  string `json:"winner_id"`
		Player1ID string `json:"player1_id"`
		Player2ID string `json:"player2_id"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}
	if req.MatchID == "" || req.WinnerID == "" || req.Player1ID == "" || req.Player2ID == "" {
		h.respondError(w, errors.NewInvalidInputError("match_id, winner_id, player1_id, player2_id are required"))
		return
	}

	result, err := h.matchmakerService.UpdateRatings(r.Context(), req.MatchID, req.WinnerID, req.Player1ID, req.Player2ID)
	if err != nil {
		h.respondError(w, err)
		return
	}
	h.respondJSON(w, http.StatusOK, result)
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
		"entries":     entries,
		"total_count": len(entries),
		"limit":       limit,
		"offset":      offset,
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
