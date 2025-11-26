package repository

import (
	"context"
	"database/sql"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/mastery/internal/models"
)

type UserMasteryRepository interface {
	CreateUserMastery(ctx context.Context, userMastery *models.UserMasteryNode) error
	GetUserMastery(ctx context.Context, userID uuid.UUID) ([]*models.UserMasteryNode, error)
	GetUserCipherMastery(ctx context.Context, userID uuid.UUID, cipherType string) ([]*models.UserMasteryNode, error)
	GetUserNode(ctx context.Context, userID uuid.UUID, nodeID string) (*models.UserMasteryNode, error)
}

type userMasteryRepository struct {
	db *sql.DB
}

func NewUserMasteryRepository(db *sql.DB) UserMasteryRepository {
	return &userMasteryRepository{db: db}
}

func (r *userMasteryRepository) CreateUserMastery(ctx context.Context, userMastery *models.UserMasteryNode) error {
	query := `
		INSERT INTO user_mastery (id, user_id, node_id, unlocked_at, points_spent)
		VALUES ($1, $2, $3, $4, $5)
	`

	_, err := r.db.ExecContext(ctx, query,
		userMastery.ID,
		userMastery.UserID,
		userMastery.NodeID,
		userMastery.UnlockedAt,
		userMastery.PointsSpent,
	)

	return err
}

func (r *userMasteryRepository) GetUserMastery(ctx context.Context, userID uuid.UUID) ([]*models.UserMasteryNode, error) {
	query := `
		SELECT id, user_id, node_id, unlocked_at, points_spent
		FROM user_mastery
		WHERE user_id = $1
		ORDER BY unlocked_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanUserMastery(rows)
}

func (r *userMasteryRepository) GetUserCipherMastery(ctx context.Context, userID uuid.UUID, cipherType string) ([]*models.UserMasteryNode, error) {
	query := `
		SELECT um.id, um.user_id, um.node_id, um.unlocked_at, um.points_spent
		FROM user_mastery um
		JOIN mastery_nodes mn ON um.node_id = mn.id
		WHERE um.user_id = $1 AND mn.cipher_type = $2
		ORDER BY um.unlocked_at DESC
	`

	rows, err := r.db.QueryContext(ctx, query, userID, cipherType)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanUserMastery(rows)
}

func (r *userMasteryRepository) GetUserNode(ctx context.Context, userID uuid.UUID, nodeID string) (*models.UserMasteryNode, error) {
	query := `
		SELECT id, user_id, node_id, unlocked_at, points_spent
		FROM user_mastery
		WHERE user_id = $1 AND node_id = $2
	`

	userNode := &models.UserMasteryNode{}

	err := r.db.QueryRowContext(ctx, query, userID, nodeID).Scan(
		&userNode.ID,
		&userNode.UserID,
		&userNode.NodeID,
		&userNode.UnlockedAt,
		&userNode.PointsSpent,
	)

	if err == sql.ErrNoRows {
		return nil, nil
	}

	if err != nil {
		return nil, err
	}

	return userNode, nil
}

func (r *userMasteryRepository) scanUserMastery(rows *sql.Rows) ([]*models.UserMasteryNode, error) {
	var userNodes []*models.UserMasteryNode

	for rows.Next() {
		userNode := &models.UserMasteryNode{}

		err := rows.Scan(
			&userNode.ID,
			&userNode.UserID,
			&userNode.NodeID,
			&userNode.UnlockedAt,
			&userNode.PointsSpent,
		)

		if err != nil {
			return nil, err
		}

		userNodes = append(userNodes, userNode)
	}

	return userNodes, rows.Err()
}
