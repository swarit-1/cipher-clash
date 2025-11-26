package repository

import (
	"context"
	"database/sql"

	"github.com/swarit-1/cipher-clash/services/mastery/internal/models"
)

type MasteryNodesRepository interface {
	GetAllNodes(ctx context.Context) ([]*models.MasteryNode, error)
	GetNodesByCipher(ctx context.Context, cipherType string) ([]*models.MasteryNode, error)
	GetNodeByID(ctx context.Context, nodeID string) (*models.MasteryNode, error)
}

type masteryNodesRepository struct {
	db *sql.DB
}

func NewMasteryNodesRepository(db *sql.DB) MasteryNodesRepository {
	return &masteryNodesRepository{db: db}
}

func (r *masteryNodesRepository) GetAllNodes(ctx context.Context) ([]*models.MasteryNode, error) {
	query := `
		SELECT id, cipher_type, tier, name, description, unlock_cost,
		       prerequisite_node_id, bonus_type, bonus_value, icon
		FROM mastery_nodes
		ORDER BY cipher_type, tier, id
	`

	rows, err := r.db.QueryContext(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanNodes(rows)
}

func (r *masteryNodesRepository) GetNodesByCipher(ctx context.Context, cipherType string) ([]*models.MasteryNode, error) {
	query := `
		SELECT id, cipher_type, tier, name, description, unlock_cost,
		       prerequisite_node_id, bonus_type, bonus_value, icon
		FROM mastery_nodes
		WHERE cipher_type = $1
		ORDER BY tier, id
	`

	rows, err := r.db.QueryContext(ctx, query, cipherType)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanNodes(rows)
}

func (r *masteryNodesRepository) GetNodeByID(ctx context.Context, nodeID string) (*models.MasteryNode, error) {
	query := `
		SELECT id, cipher_type, tier, name, description, unlock_cost,
		       prerequisite_node_id, bonus_type, bonus_value, icon
		FROM mastery_nodes
		WHERE id = $1
	`

	node := &models.MasteryNode{}
	var prerequisiteNode sql.NullString

	err := r.db.QueryRowContext(ctx, query, nodeID).Scan(
		&node.ID,
		&node.CipherType,
		&node.Tier,
		&node.Name,
		&node.Description,
		&node.UnlockCost,
		&prerequisiteNode,
		&node.BonusType,
		&node.BonusValue,
		&node.Icon,
	)

	if err != nil {
		return nil, err
	}

	if prerequisiteNode.Valid {
		node.PrerequisiteNode = &prerequisiteNode.String
	}

	return node, nil
}

func (r *masteryNodesRepository) scanNodes(rows *sql.Rows) ([]*models.MasteryNode, error) {
	var nodes []*models.MasteryNode

	for rows.Next() {
		node := &models.MasteryNode{}
		var prerequisiteNode sql.NullString

		err := rows.Scan(
			&node.ID,
			&node.CipherType,
			&node.Tier,
			&node.Name,
			&node.Description,
			&node.UnlockCost,
			&prerequisiteNode,
			&node.BonusType,
			&node.BonusValue,
			&node.Icon,
		)

		if err != nil {
			return nil, err
		}

		if prerequisiteNode.Valid {
			node.PrerequisiteNode = &prerequisiteNode.String
		}

		nodes = append(nodes, node)
	}

	return nodes, rows.Err()
}
