package repository

import (
	"context"
	"database/sql"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/social/internal/models"
)

// ============================================================================
// FRIENDS REPOSITORY
// ============================================================================

type FriendsRepository interface {
	CreateFriendship(ctx context.Context, friendship *models.Friendship) error
	GetFriendship(ctx context.Context, user1ID, user2ID uuid.UUID) (*models.Friendship, error)
	GetFriends(ctx context.Context, userID uuid.UUID) ([]*models.Friendship, error)
	GetPendingRequests(ctx context.Context, userID uuid.UUID) ([]*models.Friendship, error)
	UpdateFriendship(ctx context.Context, friendship *models.Friendship) error
	DeleteFriendship(ctx context.Context, friendshipID uuid.UUID) error
}

type friendsRepository struct {
	db *sql.DB
}

func NewFriendsRepository(db *sql.DB) FriendsRepository {
	return &friendsRepository{db: db}
}

func (r *friendsRepository) CreateFriendship(ctx context.Context, friendship *models.Friendship) error {
	query := `
		INSERT INTO friendships (id, user1_id, user2_id, status, created_at)
		VALUES ($1, $2, $3, $4, $5)
	`
	_, err := r.db.ExecContext(ctx, query, friendship.ID, friendship.User1ID, friendship.User2ID, friendship.Status, friendship.CreatedAt)
	return err
}

func (r *friendsRepository) GetFriendship(ctx context.Context, user1ID, user2ID uuid.UUID) (*models.Friendship, error) {
	query := `
		SELECT id, user1_id, user2_id, status, created_at, accepted_at
		FROM friendships
		WHERE (user1_id = $1 AND user2_id = $2) OR (user1_id = $2 AND user2_id = $1)
		LIMIT 1
	`
	friendship := &models.Friendship{}
	var acceptedAt sql.NullTime
	err := r.db.QueryRowContext(ctx, query, user1ID, user2ID).Scan(
		&friendship.ID, &friendship.User1ID, &friendship.User2ID,
		&friendship.Status, &friendship.CreatedAt, &acceptedAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	if acceptedAt.Valid {
		friendship.AcceptedAt = &acceptedAt.Time
	}
	return friendship, nil
}

func (r *friendsRepository) GetFriends(ctx context.Context, userID uuid.UUID) ([]*models.Friendship, error) {
	query := `
		SELECT id, user1_id, user2_id, status, created_at, accepted_at
		FROM friendships
		WHERE (user1_id = $1 OR user2_id = $1) AND status = 'accepted'
		ORDER BY accepted_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []*models.Friendship
	for rows.Next() {
		friendship := &models.Friendship{}
		var acceptedAt sql.NullTime
		if err := rows.Scan(&friendship.ID, &friendship.User1ID, &friendship.User2ID, &friendship.Status, &friendship.CreatedAt, &acceptedAt); err != nil {
			return nil, err
		}
		if acceptedAt.Valid {
			friendship.AcceptedAt = &acceptedAt.Time
		}
		friends = append(friends, friendship)
	}
	return friends, rows.Err()
}

func (r *friendsRepository) GetPendingRequests(ctx context.Context, userID uuid.UUID) ([]*models.Friendship, error) {
	query := `
		SELECT id, user1_id, user2_id, status, created_at, accepted_at
		FROM friendships
		WHERE user2_id = $1 AND status = 'pending'
		ORDER BY created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []*models.Friendship
	for rows.Next() {
		friendship := &models.Friendship{}
		var acceptedAt sql.NullTime
		if err := rows.Scan(&friendship.ID, &friendship.User1ID, &friendship.User2ID, &friendship.Status, &friendship.CreatedAt, &acceptedAt); err != nil {
			return nil, err
		}
		requests = append(requests, friendship)
	}
	return requests, rows.Err()
}

func (r *friendsRepository) UpdateFriendship(ctx context.Context, friendship *models.Friendship) error {
	query := `
		UPDATE friendships
		SET status = $1, accepted_at = $2
		WHERE id = $3
	`
	_, err := r.db.ExecContext(ctx, query, friendship.Status, friendship.AcceptedAt, friendship.ID)
	return err
}

func (r *friendsRepository) DeleteFriendship(ctx context.Context, friendshipID uuid.UUID) error {
	query := `DELETE FROM friendships WHERE id = $1`
	_, err := r.db.ExecContext(ctx, query, friendshipID)
	return err
}

// ============================================================================
// INVITES REPOSITORY
// ============================================================================

type InvitesRepository interface {
	CreateInvite(ctx context.Context, invite *models.MatchInvite) error
	GetInvite(ctx context.Context, inviteID uuid.UUID) (*models.MatchInvite, error)
	GetUserInvites(ctx context.Context, userID uuid.UUID) ([]*models.MatchInvite, error)
	UpdateInvite(ctx context.Context, invite *models.MatchInvite) error
}

type invitesRepository struct {
	db *sql.DB
}

func NewInvitesRepository(db *sql.DB) InvitesRepository {
	return &invitesRepository{db: db}
}

func (r *invitesRepository) CreateInvite(ctx context.Context, invite *models.MatchInvite) error {
	query := `
		INSERT INTO match_invitations (id, from_user_id, to_user_id, game_mode, status, created_at, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
	`
	_, err := r.db.ExecContext(ctx, query,
		invite.ID, invite.FromUserID, invite.ToUserID, invite.GameMode,
		invite.Status, invite.CreatedAt, invite.ExpiresAt,
	)
	return err
}

func (r *invitesRepository) GetInvite(ctx context.Context, inviteID uuid.UUID) (*models.MatchInvite, error) {
	query := `
		SELECT id, from_user_id, to_user_id, game_mode, status, created_at, expires_at
		FROM match_invitations
		WHERE id = $1
	`
	invite := &models.MatchInvite{}
	err := r.db.QueryRowContext(ctx, query, inviteID).Scan(
		&invite.ID, &invite.FromUserID, &invite.ToUserID, &invite.GameMode,
		&invite.Status, &invite.CreatedAt, &invite.ExpiresAt,
	)
	if err == sql.ErrNoRows {
		return nil, nil
	}
	return invite, err
}

func (r *invitesRepository) GetUserInvites(ctx context.Context, userID uuid.UUID) ([]*models.MatchInvite, error) {
	query := `
		SELECT id, from_user_id, to_user_id, game_mode, status, created_at, expires_at
		FROM match_invitations
		WHERE to_user_id = $1 AND status = 'pending' AND expires_at > NOW()
		ORDER BY created_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var invites []*models.MatchInvite
	for rows.Next() {
		invite := &models.MatchInvite{}
		if err := rows.Scan(&invite.ID, &invite.FromUserID, &invite.ToUserID, &invite.GameMode, &invite.Status, &invite.CreatedAt, &invite.ExpiresAt); err != nil {
			return nil, err
		}
		invites = append(invites, invite)
	}
	return invites, rows.Err()
}

func (r *invitesRepository) UpdateInvite(ctx context.Context, invite *models.MatchInvite) error {
	query := `UPDATE match_invitations SET status = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, invite.Status, invite.ID)
	return err
}

// ============================================================================
// SPECTATOR REPOSITORY
// ============================================================================

type SpectatorRepository interface {
	CreateSession(ctx context.Context, session *models.SpectatorSession) error
	GetMatchSpectators(ctx context.Context, matchID uuid.UUID) ([]*models.SpectatorSession, error)
	EndSession(ctx context.Context, sessionID uuid.UUID) error
}

type spectatorRepository struct {
	db *sql.DB
}

func NewSpectatorRepository(db *sql.DB) SpectatorRepository {
	return &spectatorRepository{db: db}
}

func (r *spectatorRepository) CreateSession(ctx context.Context, session *models.SpectatorSession) error {
	query := `
		INSERT INTO spectator_sessions (id, user_id, match_id, joined_at)
		VALUES ($1, $2, $3, $4)
	`
	_, err := r.db.ExecContext(ctx, query, session.ID, session.UserID, session.MatchID, session.JoinedAt)
	return err
}

func (r *spectatorRepository) GetMatchSpectators(ctx context.Context, matchID uuid.UUID) ([]*models.SpectatorSession, error) {
	query := `
		SELECT id, user_id, match_id, joined_at, left_at
		FROM spectator_sessions
		WHERE match_id = $1 AND left_at IS NULL
		ORDER BY joined_at DESC
	`
	rows, err := r.db.QueryContext(ctx, query, matchID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var spectators []*models.SpectatorSession
	for rows.Next() {
		session := &models.SpectatorSession{}
		var leftAt sql.NullTime
		if err := rows.Scan(&session.ID, &session.UserID, &session.MatchID, &session.JoinedAt, &leftAt); err != nil {
			return nil, err
		}
		if leftAt.Valid {
			session.LeftAt = &leftAt.Time
		}
		spectators = append(spectators, session)
	}
	return spectators, rows.Err()
}

func (r *spectatorRepository) EndSession(ctx context.Context, sessionID uuid.UUID) error {
	query := `UPDATE spectator_sessions SET left_at = $1 WHERE id = $2`
	_, err := r.db.ExecContext(ctx, query, time.Now(), sessionID)
	return err
}
