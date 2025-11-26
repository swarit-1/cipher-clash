package service

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/models"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/repository"
)

type MasteryService struct {
	masteryNodesRepo repository.MasteryNodesRepository
	userMasteryRepo  repository.UserMasteryRepository
	cipherPointsRepo repository.CipherMasteryPointsRepository
	log              *logger.Logger
}

func NewMasteryService(
	masteryNodesRepo repository.MasteryNodesRepository,
	userMasteryRepo repository.UserMasteryRepository,
	cipherPointsRepo repository.CipherMasteryPointsRepository,
	log *logger.Logger,
) *MasteryService {
	return &MasteryService{
		masteryNodesRepo: masteryNodesRepo,
		userMasteryRepo:  userMasteryRepo,
		cipherPointsRepo: cipherPointsRepo,
		log:              log,
	}
}

// GetMasteryTree retrieves the complete mastery tree for a cipher
func (s *MasteryService) GetMasteryTree(ctx context.Context, cipherType string) (*models.MasteryTree, error) {
	nodes, err := s.masteryNodesRepo.GetNodesByCipher(ctx, cipherType)
	if err != nil {
		s.log.LogError("Failed to get mastery tree", "cipher_type", cipherType, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve mastery tree")
	}

	if len(nodes) == 0 {
		return nil, errors.NewNotFoundError("No mastery tree found for cipher type")
	}

	// Organize nodes by tier
	tree := &models.MasteryTree{
		CipherType: cipherType,
		Tiers:      make(map[int][]*models.MasteryNode),
		TotalNodes: len(nodes),
	}

	for _, node := range nodes {
		tree.Tiers[node.Tier] = append(tree.Tiers[node.Tier], node)
	}

	return tree, nil
}

// GetAllNodes retrieves all mastery nodes
func (s *MasteryService) GetAllNodes(ctx context.Context) ([]*models.MasteryNode, error) {
	nodes, err := s.masteryNodesRepo.GetAllNodes(ctx)
	if err != nil {
		s.log.LogError("Failed to get all nodes", "error", err)
		return nil, errors.NewInternalError("Failed to retrieve mastery nodes")
	}

	return nodes, nil
}

// GetNode retrieves a specific mastery node
func (s *MasteryService) GetNode(ctx context.Context, nodeID string) (*models.MasteryNode, error) {
	node, err := s.masteryNodesRepo.GetNodeByID(ctx, nodeID)
	if err != nil {
		s.log.LogError("Failed to get node", "node_id", nodeID, "error", err)
		return nil, errors.NewNotFoundError("Mastery node not found")
	}

	return node, nil
}

// GetUserMastery retrieves all unlocked nodes for a user
func (s *MasteryService) GetUserMastery(ctx context.Context, userID uuid.UUID) ([]*models.UserMasteryNode, error) {
	userNodes, err := s.userMasteryRepo.GetUserMastery(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get user mastery", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve user mastery")
	}

	// Populate node details
	for _, userNode := range userNodes {
		node, err := s.masteryNodesRepo.GetNodeByID(ctx, userNode.NodeID)
		if err == nil {
			userNode.Node = node
		}
	}

	return userNodes, nil
}

// GetUserCipherMastery retrieves mastery progress for a specific cipher
func (s *MasteryService) GetUserCipherMastery(ctx context.Context, userID uuid.UUID, cipherType string) (map[string]interface{}, error) {
	// Get cipher points/stats
	points, err := s.cipherPointsRepo.GetCipherPoints(ctx, userID, cipherType)
	if err != nil {
		// Create default if doesn't exist
		points = &models.CipherMasteryPoints{
			UserID:          userID,
			CipherType:      cipherType,
			TotalPoints:     0,
			AvailablePoints: 0,
			SpentPoints:     0,
			Level:           1,
		}
	}

	// Get unlocked nodes for this cipher
	userNodes, err := s.userMasteryRepo.GetUserCipherMastery(ctx, userID, cipherType)
	if err != nil {
		s.log.LogError("Failed to get user cipher mastery", "error", err)
		return nil, errors.NewInternalError("Failed to retrieve cipher mastery")
	}

	// Populate node details
	for _, userNode := range userNodes {
		node, err := s.masteryNodesRepo.GetNodeByID(ctx, userNode.NodeID)
		if err == nil {
			userNode.Node = node
		}
	}

	return map[string]interface{}{
		"points":         points,
		"unlocked_nodes": userNodes,
		"nodes_count":    len(userNodes),
	}, nil
}

// UnlockNode unlocks a mastery node for a user
func (s *MasteryService) UnlockNode(ctx context.Context, userID uuid.UUID, nodeID string) (*models.UserMasteryNode, error) {
	// Get the node details
	node, err := s.masteryNodesRepo.GetNodeByID(ctx, nodeID)
	if err != nil {
		return nil, errors.NewNotFoundError("Mastery node not found")
	}

	// Check if already unlocked
	existing, _ := s.userMasteryRepo.GetUserNode(ctx, userID, nodeID)
	if existing != nil {
		return nil, errors.NewInvalidInputError("Node already unlocked")
	}

	// Check prerequisite if exists
	if node.PrerequisiteNode != nil && *node.PrerequisiteNode != "" {
		prereq, _ := s.userMasteryRepo.GetUserNode(ctx, userID, *node.PrerequisiteNode)
		if prereq == nil {
			return nil, errors.NewInvalidInputError("Prerequisite node not unlocked")
		}
	}

	// Get user's available points for this cipher
	points, err := s.cipherPointsRepo.GetCipherPoints(ctx, userID, node.CipherType)
	if err != nil || points == nil {
		return nil, errors.NewInvalidInputError("Insufficient mastery points")
	}

	if points.AvailablePoints < node.UnlockCost {
		return nil, errors.NewInvalidInputError("Insufficient mastery points")
	}

	// Create user mastery node
	userNode := &models.UserMasteryNode{
		ID:          uuid.New(),
		UserID:      userID,
		NodeID:      nodeID,
		UnlockedAt:  time.Now(),
		PointsSpent: node.UnlockCost,
	}

	if err := s.userMasteryRepo.CreateUserMastery(ctx, userNode); err != nil {
		s.log.LogError("Failed to unlock node", "error", err)
		return nil, errors.NewInternalError("Failed to unlock node")
	}

	// Update cipher points
	points.AvailablePoints -= node.UnlockCost
	points.SpentPoints += node.UnlockCost

	if err := s.cipherPointsRepo.UpdateCipherPoints(ctx, points); err != nil {
		s.log.LogError("Failed to update cipher points", "error", err)
		// Rollback if needed (in production, use transactions)
	}

	userNode.Node = node
	s.log.LogInfo("Node unlocked", "user_id", userID, "node_id", nodeID, "cipher", node.CipherType)
	return userNode, nil
}

// GetUserMasteryPoints retrieves mastery points for all ciphers
func (s *MasteryService) GetUserMasteryPoints(ctx context.Context, userID uuid.UUID) ([]*models.CipherMasteryPoints, error) {
	points, err := s.cipherPointsRepo.GetAllUserPoints(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get user mastery points", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve mastery points")
	}

	return points, nil
}

// AwardMasteryPoints awards mastery points to a user for a cipher
func (s *MasteryService) AwardMasteryPoints(ctx context.Context, userID uuid.UUID, cipherType string, points int, reason string) (*models.CipherMasteryPoints, error) {
	// Get existing points or create new
	cipherPoints, err := s.cipherPointsRepo.GetCipherPoints(ctx, userID, cipherType)
	if err != nil {
		// Create new entry
		cipherPoints = &models.CipherMasteryPoints{
			UserID:          userID,
			CipherType:      cipherType,
			TotalPoints:     0,
			AvailablePoints: 0,
			SpentPoints:     0,
			Level:           1,
			PuzzlesSolved:   0,
		}
	}

	// Award points
	cipherPoints.TotalPoints += points
	cipherPoints.AvailablePoints += points

	// Calculate level (100 points per level)
	cipherPoints.Level = (cipherPoints.TotalPoints / 100) + 1

	// Update or create
	if err == nil {
		err = s.cipherPointsRepo.UpdateCipherPoints(ctx, cipherPoints)
	} else {
		err = s.cipherPointsRepo.CreateCipherPoints(ctx, cipherPoints)
	}

	if err != nil {
		s.log.LogError("Failed to award mastery points", "error", err)
		return nil, errors.NewInternalError("Failed to award points")
	}

	s.log.LogInfo("Mastery points awarded", "user_id", userID, "cipher", cipherType, "points", points, "reason", reason)
	return cipherPoints, nil
}

// GetMasteryLeaderboard retrieves top players for a cipher
func (s *MasteryService) GetMasteryLeaderboard(ctx context.Context, cipherType string, limit int) ([]*models.LeaderboardEntry, error) {
	entries, err := s.cipherPointsRepo.GetLeaderboard(ctx, cipherType, limit)
	if err != nil {
		s.log.LogError("Failed to get mastery leaderboard", "cipher_type", cipherType, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve leaderboard")
	}

	// Add rankings
	for i, entry := range entries {
		entry.Rank = i + 1
	}

	return entries, nil
}
