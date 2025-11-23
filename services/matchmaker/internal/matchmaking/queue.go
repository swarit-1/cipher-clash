package matchmaking

import (
	"context"
	"fmt"

	"github.com/redis/go-redis/v9"
)

type MatchQueue struct {
	client *redis.Client
}

func NewMatchQueue(addr string) *MatchQueue {
	rdb := redis.NewClient(&redis.Options{
		Addr: addr,
	})
	return &MatchQueue{client: rdb}
}

func (q *MatchQueue) AddPlayer(ctx context.Context, playerID string, rating int) error {
	// Add player to a sorted set based on rating
	member := redis.Z{
		Score:  float64(rating),
		Member: playerID,
	}
	return q.client.ZAdd(ctx, "matchmaking_queue", member).Err()
}

func (q *MatchQueue) FindMatch(ctx context.Context, playerID string, rating int, rangeVal int) (string, error) {
	// Find opponents within rating range
	minScore := fmt.Sprintf("%d", rating-rangeVal)
	maxScore := fmt.Sprintf("%d", rating+rangeVal)

	opponents, err := q.client.ZRangeByScore(ctx, "matchmaking_queue", &redis.ZRangeBy{
		Min: minScore,
		Max: maxScore,
	}).Result()

	if err != nil {
		return "", err
	}

	for _, opp := range opponents {
		if opp != playerID {
			// Found a match! Remove both from queue
			pipe := q.client.TxPipeline()
			pipe.ZRem(ctx, "matchmaking_queue", playerID)
			pipe.ZRem(ctx, "matchmaking_queue", opp)
			_, err := pipe.Exec(ctx)
			if err == nil {
				return opp, nil
			}
		}
	}

	return "", nil // No match found yet
}
