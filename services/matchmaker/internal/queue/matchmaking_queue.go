package queue

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

// QueueEntry represents a player in matchmaking queue
type QueueEntry struct {
	UserID     string    `json:"user_id"`
	Username   string    `json:"username"`
	ELO        int       `json:"elo"`
	Region     string    `json:"region"`
	GameMode   string    `json:"game_mode"`
	QueuedAt   time.Time `json:"queued_at"`
	SearchRange int       `json:"search_range"` // ELO range to search
}

// Match represents a matched pair of players
type Match struct {
	MatchID  string   `json:"match_id"`
	Player1  *QueueEntry `json:"player1"`
	Player2  *QueueEntry `json:"player2"`
	GameMode string   `json:"game_mode"`
}

// MatchmakingQueue handles player matching
type MatchmakingQueue struct {
	queue      map[string][]*QueueEntry // gameMode -> entries
	mu         sync.RWMutex
	cache      *cache.Cache
	log        *logger.Logger
	matches    chan *Match
	ticker     *time.Ticker
	ctx        context.Context
	cancel     context.CancelFunc
}

// NewMatchmakingQueue creates a new matchmaking queue
func NewMatchmakingQueue(cacheClient *cache.Cache, log *logger.Logger) *MatchmakingQueue {
	ctx, cancel := context.WithCancel(context.Background())

	mq := &MatchmakingQueue{
		queue:   make(map[string][]*QueueEntry),
		cache:   cacheClient,
		log:     log,
		matches: make(chan *Match, 100),
		ticker:  time.NewTicker(2 * time.Second),
		ctx:     ctx,
		cancel:  cancel,
	}

	// Start matchmaking loop
	go mq.matchmakingLoop()

	return mq
}

// AddPlayer adds a player to the queue
func (mq *MatchmakingQueue) AddPlayer(entry *QueueEntry) error {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	// Check if already in queue
	for _, entries := range mq.queue {
		for _, e := range entries {
			if e.UserID == entry.UserID {
				return fmt.Errorf("player already in queue")
			}
		}
	}

	// Initialize search range
	entry.SearchRange = 100 // Start with ±100 ELO
	entry.QueuedAt = time.Now()

	// Add to queue for game mode
	mq.queue[entry.GameMode] = append(mq.queue[entry.GameMode], entry)

	// Cache queue entry
	cacheKey := fmt.Sprintf("queue:%s", entry.UserID)
	mq.cache.Set(context.Background(), cacheKey, entry, 15*time.Minute)

	mq.log.Info("Player added to queue", map[string]interface{}{
		"user_id":   entry.UserID,
		"game_mode": entry.GameMode,
		"elo":       entry.ELO,
		"region":    entry.Region,
	})

	return nil
}

// RemovePlayer removes a player from the queue
func (mq *MatchmakingQueue) RemovePlayer(userID string) bool {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	for gameMode, entries := range mq.queue {
		for i, entry := range entries {
			if entry.UserID == userID {
				// Remove from queue
				mq.queue[gameMode] = append(entries[:i], entries[i+1:]...)

				// Remove from cache
				cacheKey := fmt.Sprintf("queue:%s", userID)
				mq.cache.Delete(context.Background(), cacheKey)

				mq.log.Info("Player removed from queue", map[string]interface{}{
					"user_id": userID,
				})
				return true
			}
		}
	}
	return false
}

// GetQueueStatus returns queue info for a player
func (mq *MatchmakingQueue) GetQueueStatus(userID string) (*QueueEntry, int, error) {
	mq.mu.RLock()
	defer mq.mu.RUnlock()

	for gameMode, entries := range mq.queue {
		for _, entry := range entries {
			if entry.UserID == userID {
				return entry, len(mq.queue[gameMode]), nil
			}
		}
	}
	return nil, 0, fmt.Errorf("player not in queue")
}

// GetMatches returns the matches channel
func (mq *MatchmakingQueue) GetMatches() <-chan *Match {
	return mq.matches
}

// Stop stops the matchmaking loop
func (mq *MatchmakingQueue) Stop() {
	mq.ticker.Stop()
	mq.cancel()
	close(mq.matches)
}

// matchmakingLoop runs periodically to find matches
func (mq *MatchmakingQueue) matchmakingLoop() {
	for {
		select {
		case <-mq.ctx.Done():
			return
		case <-mq.ticker.C:
			mq.findMatches()
			mq.expandSearchRanges()
		}
	}
}

// findMatches attempts to match players
func (mq *MatchmakingQueue) findMatches() {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	for gameMode, entries := range mq.queue {
		if len(entries) < 2 {
			continue
		}

		// Sort by queue time (FIFO within ELO range)
		// Try to match oldest players first

		i := 0
		for i < len(entries)-1 {
			player1 := entries[i]

			// Find a suitable opponent
			for j := i + 1; j < len(entries); j++ {
				player2 := entries[j]

				if mq.canMatch(player1, player2) {
					// Create match
					match := &Match{
						MatchID:  uuid.New().String(),
						Player1:  player1,
						Player2:  player2,
						GameMode: gameMode,
					}

					// Remove both players from queue
					entries = append(entries[:j], entries[j+1:]...) // Remove player2
					entries = append(entries[:i], entries[i+1:]...) // Remove player1
					mq.queue[gameMode] = entries

					// Remove from cache
					mq.cache.Delete(context.Background(), fmt.Sprintf("queue:%s", player1.UserID))
					mq.cache.Delete(context.Background(), fmt.Sprintf("queue:%s", player2.UserID))

					// Send match
					select {
					case mq.matches <- match:
						mq.log.Info("Match created", map[string]interface{}{
							"match_id":   match.MatchID,
							"player1_id": player1.UserID,
							"player2_id": player2.UserID,
							"elo_diff":   abs(player1.ELO - player2.ELO),
						})
					default:
						mq.log.Warn("Matches channel full, dropping match")
					}

					// Don't increment i, check the same position again
					goto nextIteration
				}
			}
			i++
		nextIteration:
		}
	}
}

// canMatch checks if two players can be matched
func (mq *MatchmakingQueue) canMatch(p1, p2 *QueueEntry) bool {
	// Same game mode
	if p1.GameMode != p2.GameMode {
		return false
	}

	// Regional preference (but allow cross-region after 30s)
	if p1.Region != p2.Region {
		if time.Since(p1.QueuedAt) < 30*time.Second || time.Since(p2.QueuedAt) < 30*time.Second {
			return false
		}
	}

	// ELO range check
	eloDiff := abs(p1.ELO - p2.ELO)
	if eloDiff > p1.SearchRange || eloDiff > p2.SearchRange {
		return false
	}

	return true
}

// expandSearchRanges expands search ranges for players waiting too long
func (mq *MatchmakingQueue) expandSearchRanges() {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	now := time.Now()
	for _, entries := range mq.queue {
		for _, entry := range entries {
			waitTime := now.Sub(entry.QueuedAt).Seconds()

			// Expand range every 15 seconds
			if waitTime > 15 {
				newRange := 100 + int(waitTime/15)*50
				if newRange > 500 {
					newRange = 500 // Max range
				}
				if newRange != entry.SearchRange {
					entry.SearchRange = newRange
					mq.log.Debug("Expanded search range", map[string]interface{}{
						"user_id":      entry.UserID,
						"search_range": newRange,
						"wait_time":    waitTime,
					})
				}
			}
		}
	}
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
