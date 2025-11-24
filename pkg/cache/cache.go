package cache

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
	"github.com/swarit-1/cipher-clash/pkg/config"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

// Cache wraps Redis client for caching operations
type Cache struct {
	client *redis.Client
	log    *logger.Logger
}

// TTL constants for common cache types
const (
	TTLSession      = 24 * time.Hour  // User sessions
	TTLActiveGame   = 5 * time.Minute // Active game states
	TTLLeaderboard  = 1 * time.Minute // Leaderboard data
	TTLUserProfile  = 15 * time.Minute // User profile data
	TTLPuzzle       = 1 * time.Hour   // Puzzle data
	TTLRateLimit    = 1 * time.Minute // Rate limiting
)

// New creates a new Redis cache client
func New(cfg config.RedisConfig, log *logger.Logger) (*Cache, error) {
	client := redis.NewClient(&redis.Options{
		Addr:     cfg.Addr,
		Password: cfg.Password,
		DB:       cfg.DB,
	})

	// Test connection
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := client.Ping(ctx).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %w", err)
	}

	log.Info("Redis connected successfully", map[string]interface{}{
		"addr": cfg.Addr,
		"db":   cfg.DB,
	})

	return &Cache{
		client: client,
		log:    log,
	}, nil
}

// Close closes the Redis connection
func (c *Cache) Close() error {
	c.log.Info("Closing Redis connection")
	return c.client.Close()
}

// Set stores a value with TTL
func (c *Cache) Set(ctx context.Context, key string, value interface{}, ttl time.Duration) error {
	data, err := json.Marshal(value)
	if err != nil {
		return fmt.Errorf("failed to marshal value: %w", err)
	}

	return c.client.Set(ctx, key, data, ttl).Err()
}

// Get retrieves a value
func (c *Cache) Get(ctx context.Context, key string, dest interface{}) error {
	data, err := c.client.Get(ctx, key).Bytes()
	if err != nil {
		if err == redis.Nil {
			return fmt.Errorf("key not found: %s", key)
		}
		return fmt.Errorf("failed to get key: %w", err)
	}

	if err := json.Unmarshal(data, dest); err != nil {
		return fmt.Errorf("failed to unmarshal value: %w", err)
	}

	return nil
}

// Delete removes a key
func (c *Cache) Delete(ctx context.Context, keys ...string) error {
	return c.client.Del(ctx, keys...).Err()
}

// Exists checks if a key exists
func (c *Cache) Exists(ctx context.Context, key string) (bool, error) {
	count, err := c.client.Exists(ctx, key).Result()
	if err != nil {
		return false, err
	}
	return count > 0, nil
}

// Increment increments a counter
func (c *Cache) Increment(ctx context.Context, key string) (int64, error) {
	return c.client.Incr(ctx, key).Result()
}

// IncrementWithExpiry increments a counter and sets expiry if it's a new key
func (c *Cache) IncrementWithExpiry(ctx context.Context, key string, ttl time.Duration) (int64, error) {
	count, err := c.client.Incr(ctx, key).Result()
	if err != nil {
		return 0, err
	}

	// Set expiry only if it's a new key (count == 1)
	if count == 1 {
		c.client.Expire(ctx, key, ttl)
	}

	return count, nil
}

// SetNX sets a value only if the key doesn't exist (distributed lock)
func (c *Cache) SetNX(ctx context.Context, key string, value interface{}, ttl time.Duration) (bool, error) {
	data, err := json.Marshal(value)
	if err != nil {
		return false, fmt.Errorf("failed to marshal value: %w", err)
	}

	return c.client.SetNX(ctx, key, data, ttl).Result()
}

// GetMultiple retrieves multiple keys
func (c *Cache) GetMultiple(ctx context.Context, keys []string) ([]interface{}, error) {
	if len(keys) == 0 {
		return []interface{}{}, nil
	}

	results, err := c.client.MGet(ctx, keys...).Result()
	if err != nil {
		return nil, fmt.Errorf("failed to get multiple keys: %w", err)
	}

	return results, nil
}

// ZAdd adds a member to a sorted set
func (c *Cache) ZAdd(ctx context.Context, key string, score float64, member interface{}) error {
	return c.client.ZAdd(ctx, key, redis.Z{
		Score:  score,
		Member: member,
	}).Err()
}

// ZRangeByScore retrieves members from a sorted set by score range
func (c *Cache) ZRangeByScore(ctx context.Context, key string, min, max string, offset, count int64) ([]string, error) {
	return c.client.ZRangeByScore(ctx, key, &redis.ZRangeBy{
		Min:    min,
		Max:    max,
		Offset: offset,
		Count:  count,
	}).Result()
}

// ZRevRange retrieves members from a sorted set in reverse order
func (c *Cache) ZRevRange(ctx context.Context, key string, start, stop int64) ([]string, error) {
	return c.client.ZRevRange(ctx, key, start, stop).Result()
}

// ZRemRangeByScore removes members from a sorted set by score range
func (c *Cache) ZRemRangeByScore(ctx context.Context, key string, min, max string) error {
	return c.client.ZRemRangeByScore(ctx, key, min, max).Err()
}

// Health checks Redis health
func (c *Cache) Health(ctx context.Context) error {
	return c.client.Ping(ctx).Err()
}

// RateLimitCheck checks and increments rate limit counter
func (c *Cache) RateLimitCheck(ctx context.Context, key string, limit int64, window time.Duration) (bool, error) {
	count, err := c.IncrementWithExpiry(ctx, key, window)
	if err != nil {
		return false, err
	}

	return count <= limit, nil
}
