package handler

import (
	"encoding/json"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/models"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/service"
)

type CosmeticsHandler struct {
	cosmeticsService *service.CosmeticsService
	log              *logger.Logger
}

func NewCosmeticsHandler(cosmeticsService *service.CosmeticsService, log *logger.Logger) *CosmeticsHandler {
	return &CosmeticsHandler{
		cosmeticsService: cosmeticsService,
		log:              log,
	}
}

// GetCatalog returns the cosmetics catalog
func (h *CosmeticsHandler) GetCatalog(w http.ResponseWriter, r *http.Request) {
	category := r.URL.Query().Get("category")
	rarity := r.URL.Query().Get("rarity")
	purchasableOnly := r.URL.Query().Get("purchasable_only") == "true"

	cosmetics, err := h.cosmeticsService.GetCatalog(r.Context(), category, rarity, purchasableOnly)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"cosmetics": cosmetics,
		"count":     len(cosmetics),
	})
}

// GetCosmeticItem returns a specific cosmetic item
func (h *CosmeticsHandler) GetCosmeticItem(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	cosmeticID := vars["id"]

	cosmetic, err := h.cosmeticsService.GetCosmeticItem(r.Context(), cosmeticID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, cosmetic)
}

// GetInventory returns a user's cosmetic inventory
func (h *CosmeticsHandler) GetInventory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	category := r.URL.Query().Get("category")

	inventory, totalOwned, totalEquipped, err := h.cosmeticsService.GetInventory(r.Context(), userID, category)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"cosmetics":      inventory,
		"total_owned":    totalOwned,
		"total_equipped": totalEquipped,
	})
}

// PurchaseCosmetic handles cosmetic purchases
func (h *CosmeticsHandler) PurchaseCosmetic(w http.ResponseWriter, r *http.Request) {
	var req models.PurchaseCosmeticRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	userCosmetic, newBalance, err := h.cosmeticsService.PurchaseCosmetic(r.Context(), req.UserID, req.CosmeticID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{
		"success":          true,
		"cosmetic":         userCosmetic,
		"new_coin_balance": newBalance,
		"message":          "Cosmetic purchased successfully",
	})
}

// GetLoadout returns a user's current loadout
func (h *CosmeticsHandler) GetLoadout(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	loadout, err := h.cosmeticsService.GetLoadout(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"loadout": loadout,
	})
}

// EquipCosmetic handles equipping a cosmetic
func (h *CosmeticsHandler) EquipCosmetic(w http.ResponseWriter, r *http.Request) {
	var req models.EquipCosmeticRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	loadout, err := h.cosmeticsService.EquipCosmetic(r.Context(), req.UserID, req.CosmeticID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"loadout": loadout,
		"message": "Cosmetic equipped successfully",
	})
}

// UnequipCosmetic handles unequipping a cosmetic from a category
func (h *CosmeticsHandler) UnequipCosmetic(w http.ResponseWriter, r *http.Request) {
	var req models.UnequipCosmeticRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	loadout, err := h.cosmeticsService.UnequipCosmetic(r.Context(), req.UserID, req.Category)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"loadout": loadout,
		"message": "Cosmetic unequipped successfully",
	})
}

// UpdateLoadout handles updating multiple loadout slots
func (h *CosmeticsHandler) UpdateLoadout(w http.ResponseWriter, r *http.Request) {
	var req models.UpdateLoadoutRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	loadout, err := h.cosmeticsService.UpdateLoadout(
		r.Context(),
		req.UserID,
		req.BackgroundID,
		req.ParticleEffectID,
		req.TitleID,
		req.AvatarFrameID,
	)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{
		"success": true,
		"loadout": loadout,
		"message": "Loadout updated successfully",
	})
}

// GrantCosmetic handles granting a cosmetic (admin/system function)
func (h *CosmeticsHandler) GrantCosmetic(w http.ResponseWriter, r *http.Request) {
	var req models.GrantCosmeticRequest

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	userCosmetic, err := h.cosmeticsService.GrantCosmetic(r.Context(), req.UserID, req.CosmeticID, req.Source)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{
		"success":  true,
		"cosmetic": userCosmetic,
		"message":  "Cosmetic granted successfully",
	})
}

// Helper methods

func (h *CosmeticsHandler) respondJSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(data)
}

func (h *CosmeticsHandler) respondError(w http.ResponseWriter, err error) {
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
