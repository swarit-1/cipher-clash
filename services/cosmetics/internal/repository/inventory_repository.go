package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/models"
)

type InventoryRepository interface {
	GetUserInventory(ctx context.Context, userID uuid.UUID, category string) ([]*models.UserCosmetic, error)
	GetUserCosmeticByID(ctx context.Context, userID uuid.UUID, cosmeticID string) (*models.UserCosmetic, error)
	HasCosmetic(ctx context.Context, userID uuid.UUID, cosmeticID string) (bool, error)
	AddCosmetic(ctx context.Context, userCosmetic *models.UserCosmetic) error
	RemoveCosmetic(ctx context.Context, id uuid.UUID) error
	UpdateEquippedStatus(ctx context.Context, id uuid.UUID, isEquipped bool) error
	GetEquippedCosmetics(ctx context.Context, userID uuid.UUID) ([]*models.UserCosmetic, error)
	UnequipAllInCategory(ctx context.Context, userID uuid.UUID, category string) error
	GetInventoryStats(ctx context.Context, userID uuid.UUID) (totalOwned, totalEquipped int, err error)
}

type inventoryRepository struct {
	db *sql.DB
}

func NewInventoryRepository(db *sql.DB) InventoryRepository {
	return &inventoryRepository{db: db}
}

func (r *inventoryRepository) GetUserInventory(ctx context.Context, userID uuid.UUID, category string) ([]*models.UserCosmetic, error) {
	query := `
		SELECT id, user_id, cosmetic_id, acquired_at, is_equipped, source
		FROM user_cosmetics
		WHERE user_id = $1
	`
	args := []interface{}{userID}

	if category != "" {
		query += ` AND cosmetic_id IN (
			SELECT id FROM cosmetics WHERE category = $2
		)`
		args = append(args, category)
	}

	query += " ORDER BY acquired_at DESC"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var inventory []*models.UserCosmetic
	for rows.Next() {
		cosmetic := &models.UserCosmetic{}
		err := rows.Scan(
			&cosmetic.ID,
			&cosmetic.UserID,
			&cosmetic.CosmeticID,
			&cosmetic.AcquiredAt,
			&cosmetic.IsEquipped,
			&cosmetic.Source,
		)
		if err != nil {
			return nil, err
		}
		inventory = append(inventory, cosmetic)
	}

	return inventory, rows.Err()
}

func (r *inventoryRepository) GetUserCosmeticByID(ctx context.Context, userID uuid.UUID, cosmeticID string) (*models.UserCosmetic, error) {
	query := `
		SELECT id, user_id, cosmetic_id, acquired_at, is_equipped, source
		FROM user_cosmetics
		WHERE user_id = $1 AND cosmetic_id = $2
	`

	cosmetic := &models.UserCosmetic{}
	err := r.db.QueryRowContext(ctx, query, userID, cosmeticID).Scan(
		&cosmetic.ID,
		&cosmetic.UserID,
		&cosmetic.CosmeticID,
		&cosmetic.AcquiredAt,
		&cosmetic.IsEquipped,
		&cosmetic.Source,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	return cosmetic, nil
}

func (r *inventoryRepository) HasCosmetic(ctx context.Context, userID uuid.UUID, cosmeticID string) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM user_cosmetics
			WHERE user_id = $1 AND cosmetic_id = $2
		)
	`

	var exists bool
	err := r.db.QueryRowContext(ctx, query, userID, cosmeticID).Scan(&exists)
	return exists, err
}

func (r *inventoryRepository) AddCosmetic(ctx context.Context, userCosmetic *models.UserCosmetic) error {
	query := `
		INSERT INTO user_cosmetics (id, user_id, cosmetic_id, acquired_at, is_equipped, source)
		VALUES ($1, $2, $3, $4, $5, $6)
	`

	_, err := r.db.ExecContext(ctx, query,
		userCosmetic.ID,
		userCosmetic.UserID,
		userCosmetic.CosmeticID,
		userCosmetic.AcquiredAt,
		userCosmetic.IsEquipped,
		userCosmetic.Source,
	)

	return err
}

func (r *inventoryRepository) RemoveCosmetic(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM user_cosmetics WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id)
	return err
}

func (r *inventoryRepository) UpdateEquippedStatus(ctx context.Context, id uuid.UUID, isEquipped bool) error {
	query := `UPDATE user_cosmetics SET is_equipped = $2 WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, id, isEquipped)
	return err
}

func (r *inventoryRepository) GetEquippedCosmetics(ctx context.Context, userID uuid.UUID) ([]*models.UserCosmetic, error) {
	query := `
		SELECT id, user_id, cosmetic_id, acquired_at, is_equipped, source
		FROM user_cosmetics
		WHERE user_id = $1 AND is_equipped = true
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cosmetics []*models.UserCosmetic
	for rows.Next() {
		cosmetic := &models.UserCosmetic{}
		err := rows.Scan(
			&cosmetic.ID,
			&cosmetic.UserID,
			&cosmetic.CosmeticID,
			&cosmetic.AcquiredAt,
			&cosmetic.IsEquipped,
			&cosmetic.Source,
		)
		if err != nil {
			return nil, err
		}
		cosmetics = append(cosmetics, cosmetic)
	}

	return cosmetics, rows.Err()
}

func (r *inventoryRepository) UnequipAllInCategory(ctx context.Context, userID uuid.UUID, category string) error {
	query := `
		UPDATE user_cosmetics
		SET is_equipped = false
		WHERE user_id = $1 AND cosmetic_id IN (
			SELECT id FROM cosmetics WHERE category = $2
		)
	`

	_, err := r.db.ExecContext(ctx, query, userID, category)
	return err
}

func (r *inventoryRepository) GetInventoryStats(ctx context.Context, userID uuid.UUID) (totalOwned, totalEquipped int, err error) {
	query := `
		SELECT
			COUNT(*) as total_owned,
			COUNT(*) FILTER (WHERE is_equipped = true) as total_equipped
		FROM user_cosmetics
		WHERE user_id = $1
	`

	err = r.db.QueryRowContext(ctx, query, userID).Scan(&totalOwned, &totalEquipped)
	return
}
