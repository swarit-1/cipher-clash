package service

import (
	"context"
	"database/sql"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/pkg/messaging"
	"github.com/swarit-1/cipher-clash/services/social/internal/models"
	"github.com/swarit-1/cipher-clash/services/social/internal/repository"
)

type SocialService struct {
	friendsRepo   repository.FriendsRepository
	invitesRepo   repository.InvitesRepository
	spectatorRepo repository.SpectatorRepository
	db            *db.DB
	cache         *cache.Cache
	publisher     *messaging.Publisher
	log           *logger.Logger
}

func NewSocialService(
	friendsRepo repository.FriendsRepository,
	invitesRepo repository.InvitesRepository,
	spectatorRepo repository.SpectatorRepository,
	database *db.DB,
	cacheClient *cache.Cache,
	publisher *messaging.Publisher,
	log *logger.Logger,
) *SocialService {
	return &SocialService{
		friendsRepo:   friendsRepo,
		invitesRepo:   invitesRepo,
		spectatorRepo: spectatorRepo,
		db:            database,
		cache:         cacheClient,
		publisher:     publisher,
		log:           log,
	}
}

// GetFriends retrieves all friends for a user
func (s *SocialService) GetFriends(ctx context.Context, userID uuid.UUID) ([]*models.Friendship, error) {
	friends, err := s.friendsRepo.GetFriends(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get friends", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve friends")
	}
	return friends, nil
}

// SendFriendRequest sends a friend request
func (s *SocialService) SendFriendRequest(ctx context.Context, fromUserID, toUserID uuid.UUID) (*models.Friendship, error) {
	if fromUserID == toUserID {
		return nil, errors.NewInvalidInputError("Cannot send friend request to yourself")
	}

	// Check if already friends or pending
	existing, _ := s.friendsRepo.GetFriendship(ctx, fromUserID, toUserID)
	if existing != nil {
		return nil, errors.NewInvalidInputError("Friend request already exists")
	}

	friendship := &models.Friendship{
		ID:        uuid.New(),
		User1ID:   fromUserID,
		User2ID:   toUserID,
		Status:    "pending",
		CreatedAt: time.Now(),
	}

	if err := s.friendsRepo.CreateFriendship(ctx, friendship); err != nil {
		s.log.LogError("Failed to create friendship", "error", err)
		return nil, errors.NewInternalError("Failed to send friend request")
	}

	s.log.LogInfo("Friend request sent", "from", fromUserID, "to", toUserID)
	return friendship, nil
}

// AcceptFriendRequest accepts a friend request
func (s *SocialService) AcceptFriendRequest(ctx context.Context, userID, friendID uuid.UUID) (*models.Friendship, error) {
	friendship, err := s.friendsRepo.GetFriendship(ctx, friendID, userID)
	if err != nil || friendship == nil {
		return nil, errors.NewNotFoundError("Friend request not found")
	}

	if friendship.Status != "pending" {
		return nil, errors.NewInvalidInputError("Friend request already processed")
	}

	friendship.Status = "accepted"
	now := time.Now()
	friendship.AcceptedAt = &now

	if err := s.friendsRepo.UpdateFriendship(ctx, friendship); err != nil {
		return nil, errors.NewInternalError("Failed to accept friend request")
	}

	s.log.LogInfo("Friend request accepted", "user", userID, "friend", friendID)
	return friendship, nil
}

// RejectFriendRequest rejects a friend request
func (s *SocialService) RejectFriendRequest(ctx context.Context, userID, friendID uuid.UUID) error {
	friendship, err := s.friendsRepo.GetFriendship(ctx, friendID, userID)
	if err != nil || friendship == nil {
		return errors.NewNotFoundError("Friend request not found")
	}

	if err := s.friendsRepo.DeleteFriendship(ctx, friendship.ID); err != nil {
		return errors.NewInternalError("Failed to reject friend request")
	}

	s.log.LogInfo("Friend request rejected", "user", userID, "friend", friendID)
	return nil
}

// RemoveFriend removes a friend
func (s *SocialService) RemoveFriend(ctx context.Context, userID, friendID uuid.UUID) error {
	friendship, err := s.friendsRepo.GetFriendship(ctx, userID, friendID)
	if err != nil || friendship == nil {
		return errors.NewNotFoundError("Friendship not found")
	}

	if err := s.friendsRepo.DeleteFriendship(ctx, friendship.ID); err != nil {
		return errors.NewInternalError("Failed to remove friend")
	}

	s.log.LogInfo("Friend removed", "user", userID, "friend", friendID)
	return nil
}

// GetPendingRequests returns pending friend requests
func (s *SocialService) GetPendingRequests(ctx context.Context, userID uuid.UUID) ([]*models.Friendship, error) {
	requests, err := s.friendsRepo.GetPendingRequests(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get pending requests", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve pending requests")
	}
	return requests, nil
}

// SendMatchInvite sends a match invite
func (s *SocialService) SendMatchInvite(ctx context.Context, fromUserID, toUserID uuid.UUID, gameMode string) (*models.MatchInvite, error) {
	invite := &models.MatchInvite{
		ID:         uuid.New(),
		FromUserID: fromUserID,
		ToUserID:   toUserID,
		GameMode:   gameMode,
		Status:     "pending",
		CreatedAt:  time.Now(),
		ExpiresAt:  time.Now().Add(5 * time.Minute),
	}

	if err := s.invitesRepo.CreateInvite(ctx, invite); err != nil {
		s.log.LogError("Failed to create invite", "error", err)
		return nil, errors.NewInternalError("Failed to send match invite")
	}

	s.log.LogInfo("Match invite sent", "from", fromUserID, "to", toUserID, "mode", gameMode)
	return invite, nil
}

// AcceptMatchInvite accepts a match invite
func (s *SocialService) AcceptMatchInvite(ctx context.Context, inviteID uuid.UUID) (*models.MatchInvite, error) {
	invite, err := s.invitesRepo.GetInvite(ctx, inviteID)
	if err != nil || invite == nil {
		return nil, errors.NewNotFoundError("Match invite not found")
	}

	if invite.Status != "pending" {
		return nil, errors.NewInvalidInputError("Invite already processed")
	}

	if time.Now().After(invite.ExpiresAt) {
		return nil, errors.NewInvalidInputError("Invite has expired")
	}

	invite.Status = "accepted"
	if err := s.invitesRepo.UpdateInvite(ctx, invite); err != nil {
		return nil, errors.NewInternalError("Failed to accept invite")
	}

	// An accepted invite becomes a real match: both players learn about it
	// through the matchmaker status poll (shared Redis assignment keys),
	// and the game service builds the room from match.created.
	matchID, err := s.createMatchForInvite(ctx, invite)
	if err != nil {
		s.log.LogError("Failed to create match for invite", "invite_id", inviteID, "error", err)
		return nil, errors.NewInternalError("Failed to start the invited match")
	}
	invite.MatchID = matchID

	s.log.LogInfo("Match invite accepted", "invite_id", inviteID, "match_id", matchID)
	return invite, nil
}

type invitePlayer struct {
	ID       string `json:"user_id"`
	Username string `json:"username"`
	ELO      int    `json:"elo"`
}

// createMatchForInvite mirrors the matchmaker's handoff for friend matches:
// insert the match row, cache per-player assignments, publish match.created.
func (s *SocialService) createMatchForInvite(ctx context.Context, invite *models.MatchInvite) (string, error) {
	gameMode := invite.GameMode
	if gameMode != "RANKED_1V1" && gameMode != "CASUAL_1V1" {
		gameMode = "CASUAL_1V1" // friend matches default to casual
	}

	var gameModeID int
	var isRanked bool
	if err := s.db.QueryRowContext(ctx,
		`SELECT id, is_ranked FROM game_modes WHERE name = $1`, gameMode,
	).Scan(&gameModeID, &isRanked); err != nil {
		return "", fmt.Errorf("unknown game mode %s: %w", gameMode, err)
	}

	loadPlayer := func(id uuid.UUID) (invitePlayer, error) {
		var p invitePlayer
		err := s.db.QueryRowContext(ctx,
			`SELECT id, username, elo_rating FROM users WHERE id = $1`, id,
		).Scan(&p.ID, &p.Username, &p.ELO)
		return p, err
	}
	from, err := loadPlayer(invite.FromUserID)
	if err != nil {
		return "", err
	}
	to, err := loadPlayer(invite.ToUserID)
	if err != nil {
		return "", err
	}

	matchID := uuid.New().String()
	var seasonID sql.NullInt64
	_ = s.db.QueryRowContext(ctx, `SELECT id FROM seasons WHERE is_active = TRUE ORDER BY start_date DESC LIMIT 1`).Scan(&seasonID)

	if _, err := s.db.ExecContext(ctx, `
		INSERT INTO matches (id, player1_id, player2_id, game_mode_id, season_id, status)
		VALUES ($1, $2, $3, $4, $5, 'WAITING')`,
		matchID, from.ID, to.ID, gameModeID, seasonID,
	); err != nil {
		return "", err
	}

	// Same assignment shape the matchmaker writes, so the existing
	// /matchmaker/status poll surfaces this match to both clients.
	type assignment struct {
		MatchID  string       `json:"match_id"`
		GameMode string       `json:"game_mode"`
		IsRanked bool         `json:"is_ranked"`
		Opponent invitePlayer `json:"opponent"`
	}
	s.cache.Set(ctx, "match_assignment:"+from.ID, assignment{
		MatchID: matchID, GameMode: gameMode, IsRanked: isRanked, Opponent: to,
	}, 2*time.Minute)
	s.cache.Set(ctx, "match_assignment:"+to.ID, assignment{
		MatchID: matchID, GameMode: gameMode, IsRanked: isRanked, Opponent: from,
	}, 2*time.Minute)

	return matchID, s.publisher.Publish(ctx, messaging.ExchangeMatches, "match.created", messaging.Event{
		Type: messaging.EventMatchCreated,
		Data: map[string]interface{}{
			"match_id":         matchID,
			"game_mode":        gameMode,
			"is_ranked":        isRanked,
			"player1_id":       from.ID,
			"player1_username": from.Username,
			"player1_elo":      from.ELO,
			"player2_id":       to.ID,
			"player2_username": to.Username,
			"player2_elo":      to.ELO,
		},
	})
}

// RejectMatchInvite rejects a match invite
func (s *SocialService) RejectMatchInvite(ctx context.Context, inviteID uuid.UUID) error {
	invite, err := s.invitesRepo.GetInvite(ctx, inviteID)
	if err != nil || invite == nil {
		return errors.NewNotFoundError("Match invite not found")
	}

	invite.Status = "rejected"
	if err := s.invitesRepo.UpdateInvite(ctx, invite); err != nil {
		return errors.NewInternalError("Failed to reject invite")
	}

	s.log.LogInfo("Match invite rejected", "invite_id", inviteID)
	return nil
}

// GetMatchInvites returns match invites for a user
func (s *SocialService) GetMatchInvites(ctx context.Context, userID uuid.UUID) ([]*models.MatchInvite, error) {
	invites, err := s.invitesRepo.GetUserInvites(ctx, userID)
	if err != nil {
		s.log.LogError("Failed to get invites", "user_id", userID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve invites")
	}
	return invites, nil
}

// JoinAsSpectator allows a user to join as spectator
func (s *SocialService) JoinAsSpectator(ctx context.Context, userID, matchID uuid.UUID) (*models.SpectatorSession, error) {
	session := &models.SpectatorSession{
		ID:       uuid.New(),
		UserID:   userID,
		MatchID:  matchID,
		JoinedAt: time.Now(),
	}

	if err := s.spectatorRepo.CreateSession(ctx, session); err != nil {
		s.log.LogError("Failed to create spectator session", "error", err)
		return nil, errors.NewInternalError("Failed to join as spectator")
	}

	s.log.LogInfo("User joined as spectator", "user_id", userID, "match_id", matchID)
	return session, nil
}

// LeaveSpectatorMode removes a user from spectator mode
func (s *SocialService) LeaveSpectatorMode(ctx context.Context, sessionID uuid.UUID) error {
	if err := s.spectatorRepo.EndSession(ctx, sessionID); err != nil {
		return errors.NewInternalError("Failed to leave spectator mode")
	}

	s.log.LogInfo("User left spectator mode", "session_id", sessionID)
	return nil
}

// GetSpectators returns all spectators for a match
func (s *SocialService) GetSpectators(ctx context.Context, matchID uuid.UUID) ([]*models.SpectatorSession, error) {
	spectators, err := s.spectatorRepo.GetMatchSpectators(ctx, matchID)
	if err != nil {
		s.log.LogError("Failed to get spectators", "match_id", matchID, "error", err)
		return nil, errors.NewInternalError("Failed to retrieve spectators")
	}
	return spectators, nil
}
