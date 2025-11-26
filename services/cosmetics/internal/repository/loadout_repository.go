package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/models"
)

type LoadoutRepository interface {
	GetUserLoadout(ctx context.Context, userID uuid.UUID) (*models.UserLoadout, error)
	CreateLoadout(ctx context.Context, loadout *models.UserLoadout) error
	UpdateLoadout(ctx context.Context, loadout *models.UserLoadout) error
	EquipCosmetic(ctx context.Context, userID uuid.UUID, category, cosmeticID string) error
	UnequipCosmetic(ctx context.Context, userID uuid.UUID, category string) error
}

type loadoutRepository struct {
	db *sql.DB
}

func NewLoadoutRepository(db *sql.DB) LoadoutRepository {
	return &loadoutRepository{db: db}
}

func (r *loadoutRepository) GetUserLoadout(ctx context.Context, userID uuid.UUID) (*models.UserLoadout, error) {
	query := `
		SELECT id, user_id, background_id, particle_effect_id, title_id, avatar_frame_id, updated_at
		FROM user_loadouts
		WHERE user_id = $1
	`

	loadout := &models.UserLoadout{}
	var backgroundID, particleEffectID, titleID, avatarFrameID sql.NullString

	err := r.db.QueryRowContext(ctx, query, userID).Scan(
		&loadout.ID,
		&loadout.UserID,
		&backgroundID,
		&particleEffectID,
		&titleID,
		&avatarFrameID,
		&loadout.UpdatedAt,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}

	// Convert nullable strings to pointers
	if backgroundID.Valid {
		loadout.BackgroundID = &backgroundID.String
	}
	if particleEffectID.Valid {
		loadout.ParticleEffectID = &particleEffectID.String
	}
	if titleID.Valid {
		loadout.TitleID = &titleID.String
	}
	if avatarFrameID.Valid {
		loadout.AvatarFrameID = &avatarFrameID.String
	}

	return loadout, nil
}

func (r *loadoutRepository) CreateLoadout(ctx context.Context, loadout *models.UserLoadout) error {
	query := `
		INSERT INTO user_loadouts (id, user_id, background_id, particle_effect_id, title_id, avatar_frame_id, updated_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`

	_, err := r.db.ExecContext(ctx, query,
		loadout.ID,
		loadout.UserID,
		loadout.BackgroundID,
		loadout.ParticleEffectID,
		loadout.TitleID,
		loadout.AvatarFrameID,
		loadout.UpdatedAt,
	)

	return err
}

func (r *loadoutRepository) UpdateLoadout(ctx context.Context, loadout *models.UserLoadout) error {
	query := `
		UPDATE user_loadouts
		SET background_id = $2, particle_effect_id = $3, title_id = $4, avatar_frame_id = $5, updated_at = $6
		WHERE user_id = $1
	`

	_, err := r.db.ExecContext(ctx, query,
		loadout.UserID,
		loadout.BackgroundID,
		loadout.ParticleEffectID,
		loadout.TitleID,
		loadout.AvatarFrameID,
		loadout.UpdatedAt,
	)

	return err
}

func (r *loadoutRepository) EquipCosmetic(ctx context.Context, userID uuid.UUID, category, cosmeticID string) error {
	var columnName string
	switch category {
	case "background":
		columnName = "background_id"
	case "particle_effect":
		columnName = "particle_effect_id"
	case "title":
		columnName = "title_id"
	case "avatar_frame":
		columnName = "avatar_frame_id"
	default:
		return sql.ErrNoRows
	}

	query := `UPDATE user_loadouts SET ` + columnName + ` = $2, updated_at = NOW() WHERE user_id = $1`
	_, err := r.db.ExecContext(ctx, query, userID, cosmeticID)
	return err
}

func (r *loadoutRepository) UnequipCosmetic(ctx context.Context, userID uuid.UUID, category string) error {
	var columnName string
	switch category {
	case "background":
		columnName = "background_id"
	case "particle_effect":
		columnName = "particle_effect_id"
	case "title":
		columnName = "title_id"
	case "avatar_frame":
		columnName = "avatar_frame_id"
	default:
		return sql.ErrNoRows
	}

	query := `UPDATE user_loadouts SET ` + columnName + ` = NULL, updated_at = NOW() WHERE user_id = $1`
	_, err := r.db.ExecContext(ctx, query, userID)
	return err
}
