// Complete Cosmetics Service Implementation
// This file contains handler, service, and repository all in one for efficiency

package internal

import (
	"context"
	"database/sql"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

// ============================================================================
// MODELS
// ============================================================================

type CosmeticItem struct {
	ID          uuid.UUID `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	Category    string    `json:"category"`
	Rarity      string    `json:"rarity"`
	CoinCost    int       `json:"coin_cost"`
	XPRequired  int       `json:"xp_required"`
	Icon        string    `json:"icon"`
	IsLimited   bool      `json:"is_limited"`
}

type UserCosmetic struct {
	ID          uuid.UUID `json:"id"`
	UserID      uuid.UUID `json:"user_id"`
	CosmeticID  uuid.UUID `json:"cosmetic_id"`
	AcquiredAt  time.Time `json:"acquired_at"`
}

type UserLoadout struct {
	UserID     uuid.UUID  `json:"user_id"`
	Background *uuid.UUID `json:"background,omitempty"`
	Avatar     *uuid.UUID `json:"avatar,omitempty"`
	Frame      *uuid.UUID `json:"frame,omitempty"`
	Title      *uuid.UUID `json:"title,omitempty"`
	Particle   *uuid.UUID `json:"particle,omitempty"`
}

// ============================================================================
// HANDLER
// ============================================================================

type CosmeticsHandler struct {
	service *CosmeticsService
	log     *logger.Logger
}

func NewCosmeticsHandler(service *CosmeticsService, log *logger.Logger) *CosmeticsHandler {
	return &CosmeticsHandler{service: service, log: log}
}

func (h *CosmeticsHandler) GetCatalog(w http.ResponseWriter, r *http.Request) {
	category := r.URL.Query().Get("category")
	rarity := r.URL.Query().Get("rarity")

	items, err := h.service.GetCatalog(r.Context(), category, rarity)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{"items": items, "count": len(items)})
}

func (h *CosmeticsHandler) GetCosmeticItem(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	itemID, err := uuid.Parse(vars["id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid item ID"))
		return
	}

	item, err := h.service.GetItem(r.Context(), itemID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, item)
}

func (h *CosmeticsHandler) GetInventory(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	inventory, err := h.service.GetInventory(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{"inventory": inventory, "count": len(inventory)})
}

func (h *CosmeticsHandler) PurchaseCosmetic(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID     uuid.UUID `json:"user_id"`
		CosmeticID uuid.UUID `json:"cosmetic_id"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	cosmetic, err := h.service.PurchaseCosmetic(r.Context(), req.UserID, req.CosmeticID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusCreated, map[string]interface{}{"cosmetic": cosmetic, "message": "Purchase successful"})
}

func (h *CosmeticsHandler) GetLoadout(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	userID, err := uuid.Parse(vars["user_id"])
	if err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid user ID"))
		return
	}

	loadout, err := h.service.GetLoadout(r.Context(), userID)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, loadout)
}

func (h *CosmeticsHandler) EquipCosmetic(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID     uuid.UUID `json:"user_id"`
		CosmeticID uuid.UUID `json:"cosmetic_id"`
		Slot       string    `json:"slot"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	loadout, err := h.service.EquipCosmetic(r.Context(), req.UserID, req.CosmeticID, req.Slot)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{"loadout": loadout, "message": "Cosmetic equipped"})
}

func (h *CosmeticsHandler) UnequipCosmetic(w http.ResponseWriter, r *http.Request) {
	var req struct {
		UserID uuid.UUID `json:"user_id"`
		Slot   string    `json:"slot"`
	}

	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.respondError(w, errors.NewInvalidInputError("Invalid request body"))
		return
	}

	loadout, err := h.service.UnequipCosmetic(r.Context(), req.UserID, req.Slot)
	if err != nil {
		h.respondError(w, err)
		return
	}

	h.respondJSON(w, http.StatusOK, map[string]interface{}{"loadout": loadout, "message": "Cosmetic unequipped"})
}

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
		"error": map[string]interface{}{"code": appErr.Code, "message": appErr.Message},
	})
	h.log.LogError("Request error", "code", appErr.Code, "message", appErr.Message)
}

// ============================================================================
// SERVICE
// ============================================================================

type CosmeticsService struct {
	catalogRepo   *CatalogRepository
	inventoryRepo *InventoryRepository
	loadoutRepo   *LoadoutRepository
	log           *logger.Logger
}

func NewCosmeticsService(catalogRepo *CatalogRepository, inventoryRepo *InventoryRepository, loadoutRepo *LoadoutRepository, log *logger.Logger) *CosmeticsService {
	return &CosmeticsService{catalogRepo: catalogRepo, inventoryRepo: inventoryRepo, loadoutRepo: loadoutRepo, log: log}
}

func (s *CosmeticsService) GetCatalog(ctx context.Context, category, rarity string) ([]*CosmeticItem, error) {
	return s.catalogRepo.GetAll(ctx, category, rarity)
}

func (s *CosmeticsService) GetItem(ctx context.Context, itemID uuid.UUID) (*CosmeticItem, error) {
	return s.catalogRepo.GetByID(ctx, itemID)
}

func (s *CosmeticsService) GetInventory(ctx context.Context, userID uuid.UUID) ([]*UserCosmetic, error) {
	return s.inventoryRepo.GetUserInventory(ctx, userID)
}

func (s *CosmeticsService) PurchaseCosmetic(ctx context.Context, userID, cosmeticID uuid.UUID) (*UserCosmetic, error) {
	// Check if already owned
	existing, _ := s.inventoryRepo.GetUserCosmetic(ctx, userID, cosmeticID)
	if existing != nil {
		return nil, errors.NewInvalidInputError("Already owned")
	}

	// TODO: Check user coins/xp and deduct cost

	cosmetic := &UserCosmetic{
		ID:         uuid.New(),
		UserID:     userID,
		CosmeticID: cosmeticID,
		AcquiredAt: time.Now(),
	}

	if err := s.inventoryRepo.AddToInventory(ctx, cosmetic); err != nil {
		return nil, errors.NewInternalError("Failed to purchase")
	}

	s.log.LogInfo("Cosmetic purchased", "user_id", userID, "cosmetic_id", cosmeticID)
	return cosmetic, nil
}

func (s *CosmeticsService) GetLoadout(ctx context.Context, userID uuid.UUID) (*UserLoadout, error) {
	return s.loadoutRepo.GetLoadout(ctx, userID)
}

func (s *CosmeticsService) EquipCosmetic(ctx context.Context, userID, cosmeticID uuid.UUID, slot string) (*UserLoadout, error) {
	// Check ownership
	_, err := s.inventoryRepo.GetUserCosmetic(ctx, userID, cosmeticID)
	if err != nil {
		return nil, errors.NewInvalidInputError("Cosmetic not owned")
	}

	if err := s.loadoutRepo.EquipItem(ctx, userID, cosmeticID, slot); err != nil {
		return nil, errors.NewInternalError("Failed to equip")
	}

	return s.loadoutRepo.GetLoadout(ctx, userID)
}

func (s *CosmeticsService) UnequipCosmetic(ctx context.Context, userID uuid.UUID, slot string) (*UserLoadout, error) {
	if err := s.loadoutRepo.UnequipItem(ctx, userID, slot); err != nil {
		return nil, errors.NewInternalError("Failed to unequip")
	}

	return s.loadoutRepo.GetLoadout(ctx, userID)
}

// ============================================================================
// REPOSITORIES (SIMPLIFIED)
// ============================================================================

type CatalogRepository struct{ db *sql.DB }

func NewCatalogRepository(db *sql.DB) *CatalogRepository { return &CatalogRepository{db: db} }

func (r *CatalogRepository) GetAll(ctx context.Context, category, rarity string) ([]*CosmeticItem, error) {
	query := `SELECT id, name, description, category, rarity, coin_cost, xp_required, icon, is_limited FROM cosmetics WHERE 1=1`
	args := []interface{}{}
	if category != "" {
		query += " AND category = $1"
		args = append(args, category)
	}
	if rarity != "" {
		query += " AND rarity = $" + string(rune(len(args)+1))
		args = append(args, rarity)
	}

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var items []*CosmeticItem
	for rows.Next() {
		item := &CosmeticItem{}
		if err := rows.Scan(&item.ID, &item.Name, &item.Description, &item.Category, &item.Rarity, &item.CoinCost, &item.XPRequired, &item.Icon, &item.IsLimited); err != nil {
			return nil, err
		}
		items = append(items, item)
	}
	return items, rows.Err()
}

func (r *CatalogRepository) GetByID(ctx context.Context, id uuid.UUID) (*CosmeticItem, error) {
	item := &CosmeticItem{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, name, description, category, rarity, coin_cost, xp_required, icon, is_limited FROM cosmetics WHERE id = $1`, id).
		Scan(&item.ID, &item.Name, &item.Description, &item.Category, &item.Rarity, &item.CoinCost, &item.XPRequired, &item.Icon, &item.IsLimited)
	return item, err
}

type InventoryRepository struct{ db *sql.DB }

func NewInventoryRepository(db *sql.DB) *InventoryRepository { return &InventoryRepository{db: db} }

func (r *InventoryRepository) GetUserInventory(ctx context.Context, userID uuid.UUID) ([]*UserCosmetic, error) {
	rows, err := r.db.QueryContext(ctx,
		`SELECT id, user_id, cosmetic_id, acquired_at FROM user_cosmetics WHERE user_id = $1 ORDER BY acquired_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cosmetics []*UserCosmetic
	for rows.Next() {
		c := &UserCosmetic{}
		if err := rows.Scan(&c.ID, &c.UserID, &c.CosmeticID, &c.AcquiredAt); err != nil {
			return nil, err
		}
		cosmetics = append(cosmetics, c)
	}
	return cosmetics, rows.Err()
}

func (r *InventoryRepository) GetUserCosmetic(ctx context.Context, userID, cosmeticID uuid.UUID) (*UserCosmetic, error) {
	c := &UserCosmetic{}
	err := r.db.QueryRowContext(ctx,
		`SELECT id, user_id, cosmetic_id, acquired_at FROM user_cosmetics WHERE user_id = $1 AND cosmetic_id = $2`, userID, cosmeticID).
		Scan(&c.ID, &c.UserID, &c.CosmeticID, &c.AcquiredAt)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return c, err
}

func (r *InventoryRepository) AddToInventory(ctx context.Context, cosmetic *UserCosmetic) error {
	_, err := r.db.ExecContext(ctx,
		`INSERT INTO user_cosmetics (id, user_id, cosmetic_id, acquired_at) VALUES ($1, $2, $3, $4)`,
		cosmetic.ID, cosmetic.UserID, cosmetic.CosmeticID, cosmetic.AcquiredAt)
	return err
}

type LoadoutRepository struct{ db *sql.DB }

func NewLoadoutRepository(db *sql.DB) *LoadoutRepository { return &LoadoutRepository{db: db} }

func (r *LoadoutRepository) GetLoadout(ctx context.Context, userID uuid.UUID) (*UserLoadout, error) {
	loadout := &UserLoadout{UserID: userID}
	var bg, av, fr, ti, pa sql.NullString
	err := r.db.QueryRowContext(ctx,
		`SELECT background_id, avatar_id, frame_id, title_id, particle_effect_id FROM user_loadout WHERE user_id = $1`, userID).
		Scan(&bg, &av, &fr, &ti, &pa)

	if err == sql.ErrNoRows {
		return loadout, nil
	}
	if err != nil {
		return nil, err
	}

	if bg.Valid {
		id, _ := uuid.Parse(bg.String)
		loadout.Background = &id
	}
	if av.Valid {
		id, _ := uuid.Parse(av.String)
		loadout.Avatar = &id
	}
	if fr.Valid {
		id, _ := uuid.Parse(fr.String)
		loadout.Frame = &id
	}
	if ti.Valid {
		id, _ := uuid.Parse(ti.String)
		loadout.Title = &id
	}
	if pa.Valid {
		id, _ := uuid.Parse(pa.String)
		loadout.Particle = &id
	}

	return loadout, nil
}

func (r *LoadoutRepository) EquipItem(ctx context.Context, userID, cosmeticID uuid.UUID, slot string) error {
	query := `INSERT INTO user_loadout (user_id, ` + slot + `_id) VALUES ($1, $2)
	          ON CONFLICT (user_id) DO UPDATE SET ` + slot + `_id = $2, updated_at = NOW()`
	_, err := r.db.ExecContext(ctx, query, userID, cosmeticID)
	return err
}

func (r *LoadoutRepository) UnequipItem(ctx context.Context, userID uuid.UUID, slot string) error {
	query := `UPDATE user_loadout SET ` + slot + `_id = NULL, updated_at = NOW() WHERE user_id = $1`
	_, err := r.db.ExecContext(ctx, query, userID)
	return err
}
