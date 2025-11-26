package models

import (
	"time"

	"github.com/google/uuid"
)

// Cosmetic represents a cosmetic item in the catalog
type Cosmetic struct {
	ID                 string            `json:"id"`
	Name               string            `json:"name"`
	Description        string            `json:"description"`
	Category           string            `json:"category"` // background, particle_effect, title, avatar_frame, cipher_skin
	Rarity             string            `json:"rarity"`   // common, rare, epic, legendary, mythic
	AssetURL           string            `json:"asset_url"`
	Metadata           map[string]string `json:"metadata,omitempty"`
	UnlockRequirement  string            `json:"unlock_requirement"`
	CoinCost           int               `json:"coin_cost"`
	IsPremium          bool              `json:"is_premium"`
	IsTradable         bool              `json:"is_tradable"`
	IsActive           bool              `json:"is_active"`
	CreatedAt          time.Time         `json:"created_at"`
	UpdatedAt          time.Time         `json:"updated_at"`
}

// UserCosmetic represents a cosmetic item owned by a user
type UserCosmetic struct {
	ID              uuid.UUID `json:"id"`
	UserID          uuid.UUID `json:"user_id"`
	CosmeticID      string    `json:"cosmetic_id"`
	CosmeticDetails *Cosmetic `json:"cosmetic_details,omitempty"`
	AcquiredAt      time.Time `json:"acquired_at"`
	IsEquipped      bool      `json:"is_equipped"`
	Source          string    `json:"source"` // purchase, mission_reward, achievement_unlock, gift
}

// UserLoadout represents a user's equipped cosmetics
type UserLoadout struct {
	ID               uuid.UUID  `json:"id"`
	UserID           uuid.UUID  `json:"user_id"`
	BackgroundID     *string    `json:"background_id,omitempty"`
	Background       *Cosmetic  `json:"background,omitempty"`
	ParticleEffectID *string    `json:"particle_effect_id,omitempty"`
	ParticleEffect   *Cosmetic  `json:"particle_effect,omitempty"`
	TitleID          *string    `json:"title_id,omitempty"`
	Title            *Cosmetic  `json:"title,omitempty"`
	AvatarFrameID    *string    `json:"avatar_frame_id,omitempty"`
	AvatarFrame      *Cosmetic  `json:"avatar_frame,omitempty"`
	UpdatedAt        time.Time  `json:"updated_at"`
}

// Season represents a seasonal cosmetic collection
type Season struct {
	ID          string    `json:"id"`
	Name        string    `json:"name"`
	Description string    `json:"description"`
	StartDate   time.Time `json:"start_date"`
	EndDate     time.Time `json:"end_date"`
	IsActive    bool      `json:"is_active"`
	CreatedAt   time.Time `json:"created_at"`
}

// Request/Response models

type PurchaseCosmeticRequest struct {
	UserID     uuid.UUID `json:"user_id"`
	CosmeticID string    `json:"cosmetic_id"`
}

type PurchaseCosmeticResponse struct {
	Success         bool          `json:"success"`
	Cosmetic        *UserCosmetic `json:"cosmetic"`
	NewCoinBalance  int           `json:"new_coin_balance"`
}

type EquipCosmeticRequest struct {
	UserID     uuid.UUID `json:"user_id"`
	CosmeticID string    `json:"cosmetic_id"`
}

type EquipCosmeticResponse struct {
	Success bool         `json:"success"`
	Loadout *UserLoadout `json:"loadout"`
}

type UnequipCosmeticRequest struct {
	UserID   uuid.UUID `json:"user_id"`
	Category string    `json:"category"`
}

type UnequipCosmeticResponse struct {
	Success bool         `json:"success"`
	Loadout *UserLoadout `json:"loadout"`
}

type GrantCosmeticRequest struct {
	UserID     uuid.UUID `json:"user_id"`
	CosmeticID string    `json:"cosmetic_id"`
	Source     string    `json:"source"` // mission_reward, achievement_unlock, gift
}

type GrantCosmeticResponse struct {
	Success  bool          `json:"success"`
	Cosmetic *UserCosmetic `json:"cosmetic"`
}

type UpdateLoadoutRequest struct {
	UserID            uuid.UUID `json:"user_id"`
	BackgroundID      *string   `json:"background_id,omitempty"`
	ParticleEffectID  *string   `json:"particle_effect_id,omitempty"`
	TitleID           *string   `json:"title_id,omitempty"`
	AvatarFrameID     *string   `json:"avatar_frame_id,omitempty"`
}

type UpdateLoadoutResponse struct {
	Success bool         `json:"success"`
	Loadout *UserLoadout `json:"loadout"`
}
