package server

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/auth"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/game/internal/store"
)

type contextKey string

const userIDKey contextKey = "user_id"

// HTTPHandler serves the game service's REST endpoints.
type HTTPHandler struct {
	manager    *Manager
	store      *store.Store
	jwtManager *auth.JWTManager
	log        *logger.Logger
}

// NewHTTPHandler creates the REST handler.
func NewHTTPHandler(manager *Manager, st *store.Store, jwtManager *auth.JWTManager, log *logger.Logger) *HTTPHandler {
	return &HTTPHandler{manager: manager, store: st, jwtManager: jwtManager, log: log}
}

// RequireAuth validates the Bearer access token.
func (h *HTTPHandler) RequireAuth(next http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		header := r.Header.Get("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			h.error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Missing bearer token")
			return
		}
		claims, err := h.jwtManager.ValidateToken(strings.TrimPrefix(header, "Bearer "), auth.AccessToken)
		if err != nil {
			h.error(w, http.StatusUnauthorized, "UNAUTHORIZED", "Invalid or expired token")
			return
		}
		next(w, r.WithContext(context.WithValue(r.Context(), userIDKey, claims.UserID)))
	}
}

// Health reports service liveness.
func (h *HTTPHandler) Health(w http.ResponseWriter, r *http.Request) {
	h.json(w, http.StatusOK, map[string]string{"status": "healthy", "service": "game"})
}

// CreateBotMatch starts a match against a bot for the authenticated player.
// POST /api/v1/match/bot
func (h *HTTPHandler) CreateBotMatch(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		h.error(w, http.StatusMethodNotAllowed, "METHOD", "POST required")
		return
	}
	userID, _ := r.Context().Value(userIDKey).(string)

	matchID, bot, err := h.manager.CreateBotMatch(r.Context(), userID)
	if err != nil {
		h.log.Error("Bot match creation failed", map[string]interface{}{"error": err.Error()})
		h.error(w, http.StatusInternalServerError, "BOT_MATCH_FAILED", "Could not create bot match")
		return
	}

	h.json(w, http.StatusOK, map[string]interface{}{
		"match_id":  matchID,
		"game_mode": "BOT_MATCH",
		"is_ranked": false,
		"opponent": map[string]interface{}{
			"user_id":  bot.UserID,
			"username": bot.Username,
			"elo":      bot.ELO,
			"is_bot":   true,
		},
	})
}

// GetHistory lists the player's completed matches.
// GET /api/v1/matches/history?limit=20
func (h *HTTPHandler) GetHistory(w http.ResponseWriter, r *http.Request) {
	userID, _ := r.Context().Value(userIDKey).(string)

	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 50 {
		limit = 20
	}

	entries, err := h.store.GetHistory(r.Context(), userID, limit)
	if err != nil {
		h.log.Error("History query failed", map[string]interface{}{"error": err.Error()})
		h.error(w, http.StatusInternalServerError, "HISTORY_FAILED", "Could not load match history")
		return
	}
	h.json(w, http.StatusOK, map[string]interface{}{"matches": entries})
}

// GetReplay returns the replay document of a completed match.
// GET /api/v1/matches/replay?match_id=...
func (h *HTTPHandler) GetReplay(w http.ResponseWriter, r *http.Request) {
	matchID := r.URL.Query().Get("match_id")
	if matchID == "" {
		h.error(w, http.StatusBadRequest, "BAD_REQUEST", "match_id is required")
		return
	}

	replay, err := h.store.GetReplay(r.Context(), matchID)
	if err == sql.ErrNoRows {
		h.error(w, http.StatusNotFound, "NOT_FOUND", "No replay for this match")
		return
	}
	if err != nil {
		h.log.Error("Replay query failed", map[string]interface{}{"error": err.Error()})
		h.error(w, http.StatusInternalServerError, "REPLAY_FAILED", "Could not load replay")
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	w.Write(replay)
}

// GetLiveMatches lists rooms currently in progress (for the spectate menu).
// GET /api/v1/matches/live
func (h *HTTPHandler) GetLiveMatches(w http.ResponseWriter, r *http.Request) {
	h.manager.mu.RLock()
	ids := make([]string, 0, len(h.manager.rooms))
	for id := range h.manager.rooms {
		ids = append(ids, id)
	}
	h.manager.mu.RUnlock()
	h.json(w, http.StatusOK, map[string]interface{}{"match_ids": ids})
}

func (h *HTTPHandler) json(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *HTTPHandler) error(w http.ResponseWriter, status int, code, message string) {
	h.json(w, status, map[string]interface{}{
		"error": map[string]string{"code": code, "message": message},
	})
}
