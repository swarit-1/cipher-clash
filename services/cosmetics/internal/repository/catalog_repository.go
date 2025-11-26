package repository

import (
	"context"
	"database/sql"
	"encoding/json"

	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/models"
)

type CatalogRepository interface {
	GetAllCosmetics(ctx context.Context, category, rarity string, purchasableOnly bool) ([]*models.Cosmetic, error)
	GetCosmeticByID(ctx context.Context, id string) (*models.Cosmetic, error)
	GetCosmeticsByIDs(ctx context.Context, ids []string) (map[string]*models.Cosmetic, error)
	GetCosmeticsByCategory(ctx context.Context, category string) ([]*models.Cosmetic, error)
	CreateCosmetic(ctx context.Context, cosmetic *models.Cosmetic) error
	UpdateCosmetic(ctx context.Context, cosmetic *models.Cosmetic) error
}

type catalogRepository struct {
	db *sql.DB
}

func NewCatalogRepository(db *sql.DB) CatalogRepository {
	return &catalogRepository{db: db}
}

func (r *catalogRepository) GetAllCosmetics(ctx context.Context, category, rarity string, purchasableOnly bool) ([]*models.Cosmetic, error) {
	query := `
		SELECT id, name, description, category, rarity, asset_url,
		       metadata, unlock_requirement, coin_cost, is_premium,
		       is_tradable, is_active, created_at, updated_at
		FROM cosmetics
		WHERE is_active = true
	`
	args := []interface{}{}
	argPos := 1

	if category != "" {
		query += " AND category = $" + string(rune('0'+argPos))
		args = append(args, category)
		argPos++
	}

	if rarity != "" {
		query += " AND rarity = $" + string(rune('0'+argPos))
		args = append(args, rarity)
		argPos++
	}

	if purchasableOnly {
		query += " AND coin_cost > 0"
	}

	query += " ORDER BY rarity, name"

	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cosmetics []*models.Cosmetic
	for rows.Next() {
		cosmetic := &models.Cosmetic{}
		var metadataJSON []byte

		err := rows.Scan(
			&cosmetic.ID,
			&cosmetic.Name,
			&cosmetic.Description,
			&cosmetic.Category,
			&cosmetic.Rarity,
			&cosmetic.AssetURL,
			&metadataJSON,
			&cosmetic.UnlockRequirement,
			&cosmetic.CoinCost,
			&cosmetic.IsPremium,
			&cosmetic.IsTradable,
			&cosmetic.IsActive,
			&cosmetic.CreatedAt,
			&cosmetic.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		// Parse metadata JSON
		if len(metadataJSON) > 0 {
			var metadata map[string]string
			if err := json.Unmarshal(metadataJSON, &metadata); err == nil {
				cosmetic.Metadata = metadata
			}
		}

		cosmetics = append(cosmetics, cosmetic)
	}

	return cosmetics, rows.Err()
}

func (r *catalogRepository) GetCosmeticByID(ctx context.Context, id string) (*models.Cosmetic, error) {
	query := `
		SELECT id, name, description, category, rarity, asset_url,
		       metadata, unlock_requirement, coin_cost, is_premium,
		       is_tradable, is_active, created_at, updated_at
		FROM cosmetics
		WHERE id = $1
	`

	cosmetic := &models.Cosmetic{}
	var metadataJSON []byte

	err := r.db.QueryRowContext(ctx, query, id).Scan(
		&cosmetic.ID,
		&cosmetic.Name,
		&cosmetic.Description,
		&cosmetic.Category,
		&cosmetic.Rarity,
		&cosmetic.AssetURL,
		&metadataJSON,
		&cosmetic.UnlockRequirement,
		&cosmetic.CoinCost,
		&cosmetic.IsPremium,
		&cosmetic.IsTradable,
		&cosmetic.IsActive,
		&cosmetic.CreatedAt,
		&cosmetic.UpdatedAt,
	)

	if err != nil {
		return nil, err
	}

	// Parse metadata JSON
	if len(metadataJSON) > 0 {
		var metadata map[string]string
		if err := json.Unmarshal(metadataJSON, &metadata); err == nil {
			cosmetic.Metadata = metadata
		}
	}

	return cosmetic, nil
}

func (r *catalogRepository) GetCosmeticsByIDs(ctx context.Context, ids []string) (map[string]*models.Cosmetic, error) {
	if len(ids) == 0 {
		return make(map[string]*models.Cosmetic), nil
	}

	query := `
		SELECT id, name, description, category, rarity, asset_url,
		       metadata, unlock_requirement, coin_cost, is_premium,
		       is_tradable, is_active, created_at, updated_at
		FROM cosmetics
		WHERE id = ANY($1)
	`

	rows, err := r.db.QueryContext(ctx, query, ids)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	cosmetics := make(map[string]*models.Cosmetic)
	for rows.Next() {
		cosmetic := &models.Cosmetic{}
		var metadataJSON []byte

		err := rows.Scan(
			&cosmetic.ID,
			&cosmetic.Name,
			&cosmetic.Description,
			&cosmetic.Category,
			&cosmetic.Rarity,
			&cosmetic.AssetURL,
			&metadataJSON,
			&cosmetic.UnlockRequirement,
			&cosmetic.CoinCost,
			&cosmetic.IsPremium,
			&cosmetic.IsTradable,
			&cosmetic.IsActive,
			&cosmetic.CreatedAt,
			&cosmetic.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		// Parse metadata JSON
		if len(metadataJSON) > 0 {
			var metadata map[string]string
			if err := json.Unmarshal(metadataJSON, &metadata); err == nil {
				cosmetic.Metadata = metadata
			}
		}

		cosmetics[cosmetic.ID] = cosmetic
	}

	return cosmetics, rows.Err()
}

func (r *catalogRepository) GetCosmeticsByCategory(ctx context.Context, category string) ([]*models.Cosmetic, error) {
	query := `
		SELECT id, name, description, category, rarity, asset_url,
		       metadata, unlock_requirement, coin_cost, is_premium,
		       is_tradable, is_active, created_at, updated_at
		FROM cosmetics
		WHERE category = $1 AND is_active = true
		ORDER BY rarity, name
	`

	rows, err := r.db.QueryContext(ctx, query, category)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var cosmetics []*models.Cosmetic
	for rows.Next() {
		cosmetic := &models.Cosmetic{}
		var metadataJSON []byte

		err := rows.Scan(
			&cosmetic.ID,
			&cosmetic.Name,
			&cosmetic.Description,
			&cosmetic.Category,
			&cosmetic.Rarity,
			&cosmetic.AssetURL,
			&metadataJSON,
			&cosmetic.UnlockRequirement,
			&cosmetic.CoinCost,
			&cosmetic.IsPremium,
			&cosmetic.IsTradable,
			&cosmetic.IsActive,
			&cosmetic.CreatedAt,
			&cosmetic.UpdatedAt,
		)
		if err != nil {
			return nil, err
		}

		// Parse metadata JSON
		if len(metadataJSON) > 0 {
			var metadata map[string]string
			if err := json.Unmarshal(metadataJSON, &metadata); err == nil {
				cosmetic.Metadata = metadata
			}
		}

		cosmetics = append(cosmetics, cosmetic)
	}

	return cosmetics, rows.Err()
}

func (r *catalogRepository) CreateCosmetic(ctx context.Context, cosmetic *models.Cosmetic) error {
	query := `
		INSERT INTO cosmetics (id, name, description, category, rarity, asset_url,
		                       metadata, unlock_requirement, coin_cost, is_premium,
		                       is_tradable, is_active, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
	`

	metadataJSON, _ := json.Marshal(cosmetic.Metadata)

	_, err := r.db.ExecContext(ctx, query,
		cosmetic.ID,
		cosmetic.Name,
		cosmetic.Description,
		cosmetic.Category,
		cosmetic.Rarity,
		cosmetic.AssetURL,
		metadataJSON,
		cosmetic.UnlockRequirement,
		cosmetic.CoinCost,
		cosmetic.IsPremium,
		cosmetic.IsTradable,
		cosmetic.IsActive,
		cosmetic.CreatedAt,
		cosmetic.UpdatedAt,
	)

	return err
}

func (r *catalogRepository) UpdateCosmetic(ctx context.Context, cosmetic *models.Cosmetic) error {
	query := `
		UPDATE cosmetics
		SET name = $2, description = $3, category = $4, rarity = $5,
		    asset_url = $6, metadata = $7, unlock_requirement = $8,
		    coin_cost = $9, is_premium = $10, is_tradable = $11,
		    is_active = $12, updated_at = $13
		WHERE id = $1
	`

	metadataJSON, _ := json.Marshal(cosmetic.Metadata)

	_, err := r.db.ExecContext(ctx, query,
		cosmetic.ID,
		cosmetic.Name,
		cosmetic.Description,
		cosmetic.Category,
		cosmetic.Rarity,
		cosmetic.AssetURL,
		metadataJSON,
		cosmetic.UnlockRequirement,
		cosmetic.CoinCost,
		cosmetic.IsPremium,
		cosmetic.IsTradable,
		cosmetic.IsActive,
		cosmetic.UpdatedAt,
	)

	return err
}
