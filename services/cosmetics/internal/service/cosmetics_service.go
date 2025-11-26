package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/models"
	"github.com/swarit-1/cipher-clash/services/cosmetics/internal/repository"
)

type CosmeticsService struct {
	catalogRepo   repository.CatalogRepository
	inventoryRepo repository.InventoryRepository
	loadoutRepo   repository.LoadoutRepository
	log           *logger.Logger
}

func NewCosmeticsService(
	catalogRepo repository.CatalogRepository,
	inventoryRepo repository.InventoryRepository,
	loadoutRepo repository.LoadoutRepository,
	log *logger.Logger,
) *CosmeticsService {
	return &CosmeticsService{
		catalogRepo:   catalogRepo,
		inventoryRepo: inventoryRepo,
		loadoutRepo:   loadoutRepo,
		log:           log,
	}
}

// GetCatalog retrieves cosmetics catalog with optional filters
func (s *CosmeticsService) GetCatalog(ctx context.Context, category, rarity string, purchasableOnly bool) ([]*models.Cosmetic, error) {
	cosmetics, err := s.catalogRepo.GetAllCosmetics(ctx, category, rarity, purchasableOnly)
	if err != nil {
		s.log.LogError("Failed to get cosmetics catalog", "error", err)
		return nil, errors.NewInternalError("Failed to retrieve cosmetics catalog")
	}

	return cosmetics, nil
}

// GetCosmeticItem retrieves a specific cosmetic item
func (s *CosmeticsService) GetCosmeticItem(ctx context.Context, cosmeticID string) (*models.Cosmetic, error) {
	cosmetic, err := s.catalogRepo.GetCosmeticByID(ctx, cosmeticID)
	if err != nil {
		s.log.LogError("Failed to get cosmetic item", "cosmetic_id", cosmeticID, "error", err)
		return nil, errors.NewNotFoundError("Cosmetic item not found")
	}

	return cosmetic, nil
}

// GetInventory retrieves a user's cosmetic inventory
func (s *CosmeticsService) GetInventory(ctx context.Context, userID uuid.UUID, category string) ([]*models.UserCosmetic, int, int, error) {
	inventory, err := s.inventoryRepo.GetUserInventory(ctx, userID, category)
	if err != nil {
		s.log.LogError("Failed to get user inventory", "user_id", userID, "error", err)
		return nil, 0, 0, errors.NewInternalError("Failed to retrieve inventory")
	}

	// Populate cosmetic details
	cosmeticIDs := make([]string, len(inventory))
	for i, item := range inventory {
		cosmeticIDs[i] = item.CosmeticID
	}

	cosmeticsMap, err := s.catalogRepo.GetCosmeticsByIDs(ctx, cosmeticIDs)
	if err == nil {
		for _, item := range inventory {
			if cosmetic, ok := cosmeticsMap[item.CosmeticID]; ok {
				item.CosmeticDetails = cosmetic
			}
		}
	}

	// Get stats
	totalOwned, totalEquipped, _ := s.inventoryRepo.GetInventoryStats(ctx, userID)

	return inventory, totalOwned, totalEquipped, nil
}

// PurchaseCosmetic allows a user to purchase a cosmetic item
func (s *CosmeticsService) PurchaseCosmetic(ctx context.Context, userID uuid.UUID, cosmeticID string) (*models.UserCosmetic, int, error) {
	// Check if cosmetic exists
	cosmetic, err := s.catalogRepo.GetCosmeticByID(ctx, cosmeticID)
	if err != nil {
		return nil, 0, errors.NewNotFoundError("Cosmetic item not found")
	}

	// Check if user already owns it
	hasCosmetic, err := s.inventoryRepo.HasCosmetic(ctx, userID, cosmeticID)
	if err != nil {
		s.log.LogError("Failed to check cosmetic ownership", "error", err)
		return nil, 0, errors.NewInternalError("Failed to verify ownership")
	}

	if hasCosmetic {
		return nil, 0, errors.NewInvalidInputError("You already own this cosmetic")
	}

	// Check if it's purchasable
	if cosmetic.CoinCost <= 0 {
		return nil, 0, errors.NewInvalidInputError("This cosmetic is not available for purchase")
	}

	// TODO: Check user's coin balance and deduct coins
	// For now, we'll assume the purchase is successful
	newCoinBalance := 0 // Replace with actual balance after deduction

	// Add to inventory
	userCosmetic := &models.UserCosmetic{
		ID:              uuid.New(),
		UserID:          userID,
		CosmeticID:      cosmeticID,
		CosmeticDetails: cosmetic,
		AcquiredAt:      time.Now(),
		IsEquipped:      false,
		Source:          "purchase",
	}

	if err := s.inventoryRepo.AddCosmetic(ctx, userCosmetic); err != nil {
		s.log.LogError("Failed to add cosmetic to inventory", "error", err)
		return nil, 0, errors.NewInternalError("Failed to complete purchase")
	}

	s.log.LogInfo("Cosmetic purchased", "user_id", userID, "cosmetic_id", cosmeticID)
	return userCosmetic, newCoinBalance, nil
}

// GrantCosmetic grants a cosmetic to a user (from rewards, achievements, etc.)
func (s *CosmeticsService) GrantCosmetic(ctx context.Context, userID uuid.UUID, cosmeticID, source string) (*models.UserCosmetic, error) {
	// Check if cosmetic exists
	cosmetic, err := s.catalogRepo.GetCosmeticByID(ctx, cosmeticID)
	if err != nil {
		return nil, errors.NewNotFoundError("Cosmetic item not found")
	}

	// Check if user already owns it
	hasCosmetic, err := s.inventoryRepo.HasCosmetic(ctx, userID, cosmeticID)
	if err != nil {
		s.log.LogError("Failed to check cosmetic ownership", "error", err)
		return nil, errors.NewInternalError("Failed to verify ownership")
	}

	if hasCosmetic {
		return nil, errors.NewInvalidInputError("User already owns this cosmetic")
	}

	// Add to inventory
	userCosmetic := &models.UserCosmetic{
		ID:              uuid.New(),
		UserID:          userID,
		CosmeticID:      cosmeticID,
		CosmeticDetails: cosmetic,
		AcquiredAt:      time.Now(),
		IsEquipped:      false,
		Source:          source,
	}

	if err := s.inventoryRepo.AddCosmetic(ctx, userCosmetic); err != nil {
		s.log.LogError("Failed to grant cosmetic", "error", err)
		return nil, errors.NewInternalError("Failed to grant cosmetic")
	}

	s.log.LogInfo("Cosmetic granted", "user_id", userID, "cosmetic_id", cosmeticID, "source", source)
	return userCosmetic, nil
}

// GetLoadout retrieves a user's current loadout
func (s *CosmeticsService) GetLoadout(ctx context.Context, userID uuid.UUID) (*models.UserLoadout, error) {
	loadout, err := s.loadoutRepo.GetUserLoadout(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get user loadout", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve loadout")
	}

	// If no loadout exists, create one
	if loadout == nil {
		loadout = &models.UserLoadout{
			ID:        uuid.New(),
			UserID:    userID,
			UpdatedAt: time.Now(),
		}
		if err := s.loadoutRepo.CreateLoadout(ctx, loadout); err != nil {
			s.log.LogError("Failed to create loadout", "error", err)
			return nil, errors.NewInternalError("Failed to create loadout")
		}
	}

	// Populate cosmetic details
	cosmeticIDs := []string{}
	if loadout.BackgroundID != nil {
		cosmeticIDs = append(cosmeticIDs, *loadout.BackgroundID)
	}
	if loadout.ParticleEffectID != nil {
		cosmeticIDs = append(cosmeticIDs, *loadout.ParticleEffectID)
	}
	if loadout.TitleID != nil {
		cosmeticIDs = append(cosmeticIDs, *loadout.TitleID)
	}
	if loadout.AvatarFrameID != nil {
		cosmeticIDs = append(cosmeticIDs, *loadout.AvatarFrameID)
	}

	if len(cosmeticIDs) > 0 {
		cosmeticsMap, err := s.catalogRepo.GetCosmeticsByIDs(ctx, cosmeticIDs)
		if err == nil {
			if loadout.BackgroundID != nil {
				if cosmetic, ok := cosmeticsMap[*loadout.BackgroundID]; ok {
					loadout.Background = cosmetic
				}
			}
			if loadout.ParticleEffectID != nil {
				if cosmetic, ok := cosmeticsMap[*loadout.ParticleEffectID]; ok {
					loadout.ParticleEffect = cosmetic
				}
			}
			if loadout.TitleID != nil {
				if cosmetic, ok := cosmeticsMap[*loadout.TitleID]; ok {
					loadout.Title = cosmetic
				}
			}
			if loadout.AvatarFrameID != nil {
				if cosmetic, ok := cosmeticsMap[*loadout.AvatarFrameID]; ok {
					loadout.AvatarFrame = cosmetic
				}
			}
		}
	}

	return loadout, nil
}

// EquipCosmetic equips a cosmetic item
func (s *CosmeticsService) EquipCosmetic(ctx context.Context, userID uuid.UUID, cosmeticID string) (*models.UserLoadout, error) {
	// Verify user owns the cosmetic
	userCosmetic, err := s.inventoryRepo.GetUserCosmeticByID(ctx, userID, cosmeticID)
	if err != nil {
		s.log.LogError("Failed to get user cosmetic", "error", err)
		return nil, errors.NewInternalError("Failed to verify cosmetic ownership")
	}

	if userCosmetic == nil {
		return nil, errors.NewInvalidInputError("You do not own this cosmetic")
	}

	// Get cosmetic details to determine category
	cosmetic, err := s.catalogRepo.GetCosmeticByID(ctx, cosmeticID)
	if err != nil {
		return nil, errors.NewNotFoundError("Cosmetic not found")
	}

	// Ensure loadout exists
	loadout, _ := s.loadoutRepo.GetUserLoadout(ctx, userID)
	if loadout == nil {
		loadout = &models.UserLoadout{
			ID:        uuid.New(),
			UserID:    userID,
			UpdatedAt: time.Now(),
		}
		if err := s.loadoutRepo.CreateLoadout(ctx, loadout); err != nil {
			return nil, errors.NewInternalError("Failed to create loadout")
		}
	}

	// Unequip any item in the same category
	if err := s.inventoryRepo.UnequipAllInCategory(ctx, userID, cosmetic.Category); err != nil {
		s.log.LogError("Failed to unequip category items", "error", err)
	}

	// Equip the cosmetic
	if err := s.loadoutRepo.EquipCosmetic(ctx, userID, cosmetic.Category, cosmeticID); err != nil {
		s.log.LogError("Failed to equip cosmetic", "error", err)
		return nil, errors.NewInternalError("Failed to equip cosmetic")
	}

	// Update inventory equipped status
	if err := s.inventoryRepo.UpdateEquippedStatus(ctx, userCosmetic.ID, true); err != nil {
		s.log.LogError("Failed to update equipped status", "error", err)
	}

	s.log.LogInfo("Cosmetic equipped", "user_id", userID, "cosmetic_id", cosmeticID, "category", cosmetic.Category)

	// Return updated loadout
	return s.GetLoadout(ctx, userID)
}

// UnequipCosmetic unequips a cosmetic item from a category
func (s *CosmeticsService) UnequipCosmetic(ctx context.Context, userID uuid.UUID, category string) (*models.UserLoadout, error) {
	// Unequip from loadout
	if err := s.loadoutRepo.UnequipCosmetic(ctx, userID, category); err != nil {
		s.log.LogError("Failed to unequip cosmetic", "error", err)
		return nil, errors.NewInternalError("Failed to unequip cosmetic")
	}

	// Update inventory equipped status
	if err := s.inventoryRepo.UnequipAllInCategory(ctx, userID, category); err != nil {
		s.log.LogError("Failed to update equipped status", "error", err)
	}

	s.log.LogInfo("Cosmetic unequipped", "user_id", userID, "category", category)

	// Return updated loadout
	return s.GetLoadout(ctx, userID)
}

// UpdateLoadout updates multiple slots in the loadout
func (s *CosmeticsService) UpdateLoadout(ctx context.Context, userID uuid.UUID, backgroundID, particleEffectID, titleID, avatarFrameID *string) (*models.UserLoadout, error) {
	// Get or create loadout
	loadout, _ := s.loadoutRepo.GetUserLoadout(ctx, userID)
	if loadout == nil {
		loadout = &models.UserLoadout{
			ID:        uuid.New(),
			UserID:    userID,
			UpdatedAt: time.Now(),
		}
		if err := s.loadoutRepo.CreateLoadout(ctx, loadout); err != nil {
			return nil, errors.NewInternalError("Failed to create loadout")
		}
	}

	// Verify ownership of all specified cosmetics
	cosmeticIDs := []string{}
	if backgroundID != nil && *backgroundID != "" {
		cosmeticIDs = append(cosmeticIDs, *backgroundID)
	}
	if particleEffectID != nil && *particleEffectID != "" {
		cosmeticIDs = append(cosmeticIDs, *particleEffectID)
	}
	if titleID != nil && *titleID != "" {
		cosmeticIDs = append(cosmeticIDs, *titleID)
	}
	if avatarFrameID != nil && *avatarFrameID != "" {
		cosmeticIDs = append(cosmeticIDs, *avatarFrameID)
	}

	for _, cosmeticID := range cosmeticIDs {
		hasCosmetic, err := s.inventoryRepo.HasCosmetic(ctx, userID, cosmeticID)
		if err != nil || !hasCosmetic {
			return nil, errors.NewInvalidInputError("You do not own one or more of the specified cosmetics")
		}
	}

	// Update loadout
	loadout.BackgroundID = backgroundID
	loadout.ParticleEffectID = particleEffectID
	loadout.TitleID = titleID
	loadout.AvatarFrameID = avatarFrameID
	loadout.UpdatedAt = time.Now()

	if err := s.loadoutRepo.UpdateLoadout(ctx, loadout); err != nil {
		s.log.LogError("Failed to update loadout", "error", err)
		return nil, errors.NewInternalError("Failed to update loadout")
	}

	s.log.LogInfo("Loadout updated", "user_id", userID)

	// Return updated loadout with details
	return s.GetLoadout(ctx, userID)
}
