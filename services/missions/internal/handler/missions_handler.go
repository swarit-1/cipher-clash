package handler

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/missions/internal/service"
)

type MissionsHandler struct {
	missionsService *service.MissionsService
	log             *logger.Logger
}

func NewMissionsHandler(missionsService *service.MissionsService, log *logger.Logger) *MissionsHandler {
	return &MissionsHandler{
		missionsService: missionsService,
		log:             log,
	}
}

// GetMissionTemplates returns all mission templates
func (h *MissionsHandler) GetMissionTemplates(w http.ResponseWriter, r *http.Request) {
	category := r.URL.Query().Get("category")
	frequency := r.URL.Query().Get("frequency")

	templates, err := h.missionsService.GetMissionTemplates(r.Context(), category, frequency)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"templates": templates,
	})
}

// GetMissionTemplate returns a specific mission template
func (h *MissionsHandler) GetMissionTemplate(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	templateID := vars["id"]

	template, err := h.missionsService.GetMissionTemplate(r.Context(), templateID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, template)
}

// GetUserMissions returns all missions for a user
func (h *MissionsHandler) GetUserMissions(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	missions, err := h.missionsService.GetUserMissions(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"missions": missions,
	})
}

// GetActiveMissions returns active missions for a user
func (h *MissionsHandler) GetActiveMissions(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	missions, err := h.missionsService.GetActiveMissions(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"missions": missions,
		"count":    len(missions),
	})
}

// AssignDailyMissions assigns new daily missions to a user
func (h *MissionsHandler) AssignDailyMissions(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID uuid.UUID `json:"user_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	missions, err := h.missionsService.AssignDailyMissions(r.Context(), req.UserID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{
		"missions": missions,
		"message":  "Daily missions assigned successfully",
	})
}

// UpdateMissionProgress updates progress for a specific mission
func (h *MissionsHandler) UpdateMissionProgress(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID     uuid.UUID `json:"user_id"`
		TemplateID string    `json:"template_id"`
		Progress   int       `json:"progress"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	mission, err := h.missionsService.UpdateMissionProgress(r.Context(), req.UserID, req.TemplateID, req.Progress)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"mission": mission,
		"message": "Mission progress updated",
	})
}

// CompleteMission marks a mission as completed
func (h *MissionsHandler) CompleteMission(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID     uuid.UUID `json:"user_id"`
		TemplateID string    `json:"template_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	mission, err := h.missionsService.CompleteMission(r.Context(), req.UserID, req.TemplateID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"mission": mission,
		"message": "Mission completed! Rewards pending claim",
	})
}

// ClaimMissionReward claims rewards for a completed mission
func (h *MissionsHandler) ClaimMissionReward(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID     uuid.UUID `json:"user_id"`
		TemplateID string    `json:"template_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	rewards, err := h.missionsService.ClaimMissionReward(r.Context(), req.UserID, req.TemplateID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"rewards": rewards,
		"message": "Mission rewards claimed successfully",
	})
}

// RefreshMissions manually refreshes missions for a user
func (h *MissionsHandler) RefreshMissions(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID uuid.UUID `json:"user_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	missions, err := h.missionsService.RefreshExpiredMissions(r.Context(), req.UserID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"missions": missions,
		"message":  "Missions refreshed",
	})
}

// GetMissionStats returns mission statistics for a user
func (h *MissionsHandler) GetMissionStats(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	stats, err := h.missionsService.GetMissionStats(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, stats)
}

// Helper methods
func (h *MissionsHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *MissionsHandler) respondError(w http.ResponseWriter, err error) {
	w.Header().Set("Content-Type", "application/json")

	appErr, ok := err.(*errors.AppError)
	if !ok {
		appErr = errors.NewInternalError("Internal server error")
	}

	w.WriteHeader(appErr.HTTPStatus)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error": map[string]interface{}{
			"code":    appErr.Code,
			"message": appErr.Message,
		},
	})

	h.log.LogError("Request error", "code", appErr.Code, "message", appErr.Message)
}
