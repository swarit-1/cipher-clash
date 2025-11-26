package handler

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/social/internal/service"
)

type SocialHandler struct {
	socialService *service.SocialService
	log           *logger.Logger
}

func NewSocialHandler(socialService *service.SocialService, log *logger.Logger) *SocialHandler {
	return &SocialHandler{
		socialService: socialService,
		log:           log,
	}
}

// GetFriends returns all friends for a user
func (h *SocialHandler) GetFriends(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	friends, err := h.socialService.GetFriends(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"friends": friends,
		"count":   len(friends),
	})
}

// SendFriendRequest sends a friend request
func (h *SocialHandler) SendFriendRequest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		FromUserID uuid.UUID `json:"from_user_id"`
		ToUserID   uuid.UUID `json:"to_user_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	friendship, err := h.socialService.SendFriendRequest(r.Context(), req.FromUserID, req.ToUserID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{
		"friendship": friendship,
		"message":    "Friend request sent",
	})
}

// AcceptFriendRequest accepts a friend request
func (h *SocialHandler) AcceptFriendRequest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID   uuid.UUID `json:"user_id"`
		FriendID uuid.UUID `json:"friend_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	friendship, err := h.socialService.AcceptFriendRequest(r.Context(), req.UserID, req.FriendID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"friendship": friendship,
		"message":    "Friend request accepted",
	})
}

// RejectFriendRequest rejects a friend request
func (h *SocialHandler) RejectFriendRequest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID   uuid.UUID `json:"user_id"`
		FriendID uuid.UUID `json:"friend_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if err := h.socialService.RejectFriendRequest(r.Context(), req.UserID, req.FriendID); err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Friend request rejected",
	})
}

// RemoveFriend removes a friend
func (h *SocialHandler) RemoveFriend(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID   uuid.UUID `json:"user_id"`
		FriendID uuid.UUID `json:"friend_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if err := h.socialService.RemoveFriend(r.Context(), req.UserID, req.FriendID); err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Friend removed",
	})
}

// GetPendingRequests returns pending friend requests
func (h *SocialHandler) GetPendingRequests(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	requests, err := h.socialService.GetPendingRequests(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"requests": requests,
		"count":    len(requests),
	})
}

// SendMatchInvite sends a match invite
func (h *SocialHandler) SendMatchInvite(w http.ResponseWriter, r *http.Request) {
	var req struct {
		FromUserID uuid.UUID `json:"from_user_id"`
		ToUserID   uuid.UUID `json:"to_user_id"`
		GameMode   string    `json:"game_mode"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	invite, err := h.socialService.SendMatchInvite(r.Context(), req.FromUserID, req.ToUserID, req.GameMode)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{
		"invite":  invite,
		"message": "Match invite sent",
	})
}

// AcceptMatchInvite accepts a match invite
func (h *SocialHandler) AcceptMatchInvite(w http.ResponseWriter, r *http.Request) {
	var req struct {
		InviteID uuid.UUID `json:"invite_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	invite, err := h.socialService.AcceptMatchInvite(r.Context(), req.InviteID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"invite":  invite,
		"message": "Match invite accepted",
	})
}

// RejectMatchInvite rejects a match invite
func (h *SocialHandler) RejectMatchInvite(w http.ResponseWriter, r *http.Request) {
	var req struct {
		InviteID uuid.UUID `json:"invite_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if err := h.socialService.RejectMatchInvite(r.Context(), req.InviteID); err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Match invite rejected",
	})
}

// GetMatchInvites returns match invites for a user
func (h *SocialHandler) GetMatchInvites(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	invites, err := h.socialService.GetMatchInvites(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"invites": invites,
		"count":   len(invites),
	})
}

// JoinAsSpectator allows a user to join as spectator
func (h *SocialHandler) JoinAsSpectator(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID  uuid.UUID `json:"user_id"`
		MatchID uuid.UUID `json:"match_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	session, err := h.socialService.JoinAsSpectator(r.Context(), req.UserID, req.MatchID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{
		"session": session,
		"message": "Joined as spectator",
	})
}

// LeaveSpectatorMode removes a user from spectator mode
func (h *SocialHandler) LeaveSpectatorMode(w http.ResponseWriter, r *http.Request) {
	var req struct {
		SessionID uuid.UUID `json:"session_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	if err := h.socialService.LeaveSpectatorMode(r.Context(), req.SessionID); err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"message": "Left spectator mode",
	})
}

// GetSpectators returns all spectators for a match
func (h *SocialHandler) GetSpectators(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	matchID, err := uuid.Parse(vars["match_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid match ID"))
		return
	}

	spectators, err := h.socialService.GetSpectators(r.Context(), matchID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"spectators": spectators,
		"count":      len(spectators),
	})
}

// Helper methods
func (h *SocialHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *SocialHandler) respondError(w http.ResponseWriter, err error) {
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
