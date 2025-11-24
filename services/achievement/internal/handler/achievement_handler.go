package handler

import (
	"encoding/json"
	"net/http"
	"strings"

	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/achievement/internal"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/middleware"
	"github.com/swarit-1/cipher-clash/services/achievement/internal/service"
)

type AchievementHandler struct {
	service service.AchievementService
	log     *logger.Logger
}

func NewAchievementHandler(service service.AchievementService, log *logger.Logger) *AchievementHandler {
	return &AchievementHandler{
		service: service,
		log:     log,
	}
}

func (h *AchievementHandler) Health(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"status":  "healthy",
		"service": "achievement-service",
	})
}

func (h *AchievementHandler) ListAchievements(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Check for rarity filter
	rarity := r.URL.Query().Get("rarity")

	var achievements []*internal.Achievement
	var err error

	if rarity != "" {
		achievements, err = h.service.GetAchievementsByRarity(r.Context(), strings.ToUpper(rarity))
	} else {
		achievements, err = h.service.GetAllAchievements(r.Context())
	}

	if err != nil {
		h.log.Error("Failed to get achievements", map[string]interface{}{
			"error": err.Error(),
		})
		http.Error(w, `{"error":"Failed to get achievements"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"achievements": achievements,
		"count":        len(achievements),
	})
}

func (h *AchievementHandler) GetAchievement(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	// Extract ID from path
	path := strings.TrimPrefix(r.URL.Path, "/api/v1/achievements/")
	if path == "" || path == r.URL.Path {
		http.Error(w, `{"error":"Achievement ID required"}`, http.StatusBadRequest)
		return
	}

	achievement, err := h.service.GetAchievement(r.Context(), path)
	if err != nil {
		h.log.Error("Failed to get achievement", map[string]interface{}{
			"error": err.Error(),
			"id":    path,
		})
		http.Error(w, `{"error":"Achievement not found"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(achievement)
}

func (h *AchievementHandler) GetUserAchievements(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, `{"error":"User ID not found in context"}`, http.StatusUnauthorized)
		return
	}

	achievements, err := h.service.GetUserAchievements(r.Context(), userID)
	if err != nil {
		h.log.Error("Failed to get user achievements", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		http.Error(w, `{"error":"Failed to get achievements"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"achievements": achievements,
		"count":        len(achievements),
	})
}

func (h *AchievementHandler) GetUserProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, `{"error":"User ID not found in context"}`, http.StatusUnauthorized)
		return
	}

	// Get filter for unlocked/locked
	filter := r.URL.Query().Get("filter") // "unlocked", "locked", or empty for all

	achievements, err := h.service.GetUserAchievements(r.Context(), userID)
	if err != nil {
		h.log.Error("Failed to get user progress", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		http.Error(w, `{"error":"Failed to get progress"}`, http.StatusInternalServerError)
		return
	}

	// Apply filter
	if filter != "" {
		filtered := make([]*internal.AchievementWithProgress, 0)
		for _, a := range achievements {
			if filter == "unlocked" && a.Unlocked {
				filtered = append(filtered, a)
			} else if filter == "locked" && !a.Unlocked {
				filtered = append(filtered, a)
			}
		}
		achievements = filtered
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{
		"achievements": achievements,
		"count":        len(achievements),
	})
}

func (h *AchievementHandler) GetUserStats(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	userID, ok := middleware.GetUserIDFromContext(r.Context())
	if !ok {
		http.Error(w, `{"error":"User ID not found in context"}`, http.StatusUnauthorized)
		return
	}

	stats, err := h.service.GetUserStats(r.Context(), userID)
	if err != nil {
		h.log.Error("Failed to get user stats", map[string]interface{}{
			"error":   err.Error(),
			"user_id": userID,
		})
		http.Error(w, `{"error":"Failed to get stats"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(stats)
}

func (h *AchievementHandler) CreateAchievement(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.CreateAchievementRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	achievement, err := h.service.CreateAchievement(r.Context(), &req)
	if err != nil {
		h.log.Error("Failed to create achievement", map[string]interface{}{
			"error": err.Error(),
		})
		http.Error(w, `{"error":"Failed to create achievement"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(achievement)
}

func (h *AchievementHandler) UpdateAchievement(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		http.Error(w, `{"error":"Method not allowed"}`, http.StatusMethodNotAllowed)
		return
	}

	var req internal.UpdateAchievementRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
		return
	}

	achievement, err := h.service.UpdateAchievement(r.Context(), &req)
	if err != nil {
		h.log.Error("Failed to update achievement", map[string]interface{}{
			"error": err.Error(),
			"id":    req.ID,
		})
		http.Error(w, `{"error":"Failed to update achievement"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(achievement)
}
