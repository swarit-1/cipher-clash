package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/service"
)

type MasteryHandler struct {
	masteryService *service.MasteryService
	log            *logger.Logger
}

func NewMasteryHandler(masteryService *service.MasteryService, log *logger.Logger) *MasteryHandler {
	return &MasteryHandler{
		masteryService: masteryService,
		log:            log,
	}
}

// GetMasteryTree returns the complete mastery tree for a specific cipher
func (h *MasteryHandler) GetMasteryTree(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	cipherType := vars["cipher_type"]

	if cipherType == "" {
		h.respondError(w, errors.NewInvalidInputError("Cipher type required"))
		return
	}

	tree, err := h.masteryService.GetMasteryTree(r.Context(), cipherType)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"cipher_type": cipherType,
		"tree":        tree,
	})
}

// GetAllNodes returns all mastery nodes across all ciphers
func (h *MasteryHandler) GetAllNodes(w http.ResponseWriter, r *http.Request) {
	nodes, err := h.masteryService.GetAllNodes(r.Context())
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"nodes": nodes,
		"count": len(nodes),
	})
}

// GetNode returns a specific mastery node
func (h *MasteryHandler) GetNode(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	nodeID := vars["node_id"]

	node, err := h.masteryService.GetNode(r.Context(), nodeID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, node)
}

// GetUserMastery returns all unlocked nodes for a user
func (h *MasteryHandler) GetUserMastery(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	mastery, err := h.masteryService.GetUserMastery(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":        userID,
		"unlocked_nodes": mastery,
		"count":          len(mastery),
	})
}

// GetUserCipherMastery returns mastery progress for a specific cipher
func (h *MasteryHandler) GetUserCipherMastery(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}
	cipherType := vars["cipher_type"]

	mastery, err := h.masteryService.GetUserCipherMastery(r.Context(), userID, cipherType)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"user_id":     userID,
		"cipher_type": cipherType,
		"mastery":     mastery,
	})
}

// UnlockNode unlocks a mastery node for a user
func (h *MasteryHandler) UnlockNode(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID uuid.UUID `json:"user_id"`
		NodeID string    `json:"node_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if req.UserID == uuid.Nil || req.NodeID == "" {
		h.respondError(w, errors.NewInvalidInputError("User ID and Node ID required"))
		return
	}

	result, err := h.masteryService.UnlockNode(r.Context(), req.UserID, req.NodeID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"node":    result,
		"message": "Node unlocked successfully",
	})
}

// GetUserMasteryPoints returns mastery points for all ciphers
func (h *MasteryHandler) GetUserMasteryPoints(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	points, err := h.masteryService.GetUserMasteryPoints(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"user_id": userID,
		"points":  points,
	})
}

// AwardMasteryPoints awards mastery points to a user for a cipher
func (h *MasteryHandler) AwardMasteryPoints(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID     uuid.UUID `json:"user_id"`
		CipherType string    `json:"cipher_type"`
		Points     int       `json:"points"`
		Reason     string    `json:"reason"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if req.UserID == uuid.Nil || req.CipherType == "" || req.Points <= 0 {
		h.respondError(w, errors.NewInvalidInputError("User ID, cipher type, and positive points required"))
		return
	}

	result, err := h.masteryService.AwardMasteryPoints(r.Context(), req.UserID, req.CipherType, req.Points, req.Reason)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"cipher_points": result,
		"message":       "Mastery points awarded",
	})
}

// GetMasteryLeaderboard returns top players for a specific cipher
func (h *MasteryHandler) GetMasteryLeaderboard(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	cipherType := vars["cipher_type"]

	limitStr := r.URL.Query().Get("limit")
	limit := 100
	if limitStr != "" {
		if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 500 {
			limit = l
		}
	}

	leaderboard, err := h.masteryService.GetMasteryLeaderboard(r.Context(), cipherType, limit)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"cipher_type": cipherType,
		"leaderboard": leaderboard,
		"count":       len(leaderboard),
	})
}

// Helper methods
func (h *MasteryHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *MasteryHandler) respondError(w http.ResponseWriter, err error) {
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
