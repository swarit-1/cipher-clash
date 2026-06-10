// Package queue implements priority-queue matchmaking with dynamic
// ELO-range expansion.
//
// Each game mode owns a container/heap min-heap keyed by queue time, so the
// longest-waiting player always has matching priority. Every tick the queue
// pairs players whose ELO difference fits inside both players' search
// ranges; ranges start at ±100 and widen by +50 every 15 seconds waited,
// capped at ±500.
package queue

import (
	"container/heap"
	"context"
	"fmt"
	"sort"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/logger"
)

const (
	initialSearchRange   = 100
	rangeExpansionStep   = 50
	rangeExpansionPeriod = 15 * time.Second
	maxSearchRange       = 500
	crossRegionAfter     = 30 * time.Second
	matchmakingTick      = 2 * time.Second
)

// QueueEntry represents a player waiting in the matchmaking queue.
type QueueEntry struct {
	UserID      string    `json:"user_id"`
	Username    string    `json:"username"`
	ELO         int       `json:"elo"`
	Region      string    `json:"region"`
	GameMode    string    `json:"game_mode"`
	QueuedAt    time.Time `json:"queued_at"`
	SearchRange int       `json:"search_range"`

	index int // heap index, maintained by playerHeap
}

// Match represents a matched pair of players.
type Match struct {
	MatchID  string      `json:"match_id"`
	Player1  *QueueEntry `json:"player1"`
	Player2  *QueueEntry `json:"player2"`
	GameMode string      `json:"game_mode"`
}

// playerHeap is a min-heap of queue entries ordered by QueuedAt: the
// longest-waiting player sits at the root and is matched first.
type playerHeap []*QueueEntry

func (h playerHeap) Len() int           { return len(h) }
func (h playerHeap) Less(i, j int) bool { return h[i].QueuedAt.Before(h[j].QueuedAt) }
func (h playerHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i]; h[i].index = i; h[j].index = j }
func (h *playerHeap) Push(x interface{}) {
	entry := x.(*QueueEntry)
	entry.index = len(*h)
	*h = append(*h, entry)
}
func (h *playerHeap) Pop() interface{} {
	old := *h
	n := len(old)
	entry := old[n-1]
	old[n-1] = nil
	entry.index = -1
	*h = old[:n-1]
	return entry
}

// MatchmakingQueue pairs players using per-mode priority queues.
type MatchmakingQueue struct {
	queues  map[string]*playerHeap // gameMode -> priority queue
	byUser  map[string]*QueueEntry // userID -> entry (O(1) lookup)
	mu      sync.Mutex
	cache   *cache.Cache
	log     *logger.Logger
	matches chan *Match
	ticker  *time.Ticker
	ctx     context.Context
	cancel  context.CancelFunc
}

// NewMatchmakingQueue creates a queue and starts its matchmaking loop.
func NewMatchmakingQueue(cacheClient *cache.Cache, log *logger.Logger) *MatchmakingQueue {
	ctx, cancel := context.WithCancel(context.Background())

	mq := &MatchmakingQueue{
		queues:  make(map[string]*playerHeap),
		byUser:  make(map[string]*QueueEntry),
		cache:   cacheClient,
		log:     log,
		matches: make(chan *Match, 100),
		ticker:  time.NewTicker(matchmakingTick),
		ctx:     ctx,
		cancel:  cancel,
	}

	go mq.matchmakingLoop()
	return mq
}

// AddPlayer enqueues a player.
func (mq *MatchmakingQueue) AddPlayer(entry *QueueEntry) error {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	if _, exists := mq.byUser[entry.UserID]; exists {
		return fmt.Errorf("player already in queue")
	}

	entry.SearchRange = initialSearchRange
	entry.QueuedAt = time.Now()

	h, ok := mq.queues[entry.GameMode]
	if !ok {
		h = &playerHeap{}
		heap.Init(h)
		mq.queues[entry.GameMode] = h
	}
	heap.Push(h, entry)
	mq.byUser[entry.UserID] = entry

	if mq.cache != nil {
		mq.cache.Set(context.Background(), fmt.Sprintf("queue:%s", entry.UserID), entry, 15*time.Minute)
	}

	mq.log.Info("Player added to queue", map[string]interface{}{
		"user_id":   entry.UserID,
		"game_mode": entry.GameMode,
		"elo":       entry.ELO,
		"region":    entry.Region,
	})
	return nil
}

// RemovePlayer dequeues a player (cancel / matched elsewhere).
func (mq *MatchmakingQueue) RemovePlayer(userID string) bool {
	mq.mu.Lock()
	defer mq.mu.Unlock()
	return mq.removeLocked(userID)
}

func (mq *MatchmakingQueue) removeLocked(userID string) bool {
	entry, ok := mq.byUser[userID]
	if !ok {
		return false
	}
	if h, ok := mq.queues[entry.GameMode]; ok && entry.index >= 0 {
		heap.Remove(h, entry.index)
	}
	delete(mq.byUser, userID)
	if mq.cache != nil {
		mq.cache.Delete(context.Background(), fmt.Sprintf("queue:%s", userID))
	}
	return true
}

// GetQueueStatus returns the player's entry, their priority position
// (1-based, by wait time), and the queue size for their mode.
func (mq *MatchmakingQueue) GetQueueStatus(userID string) (*QueueEntry, int, int, error) {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	entry, ok := mq.byUser[userID]
	if !ok {
		return nil, 0, 0, fmt.Errorf("player not in queue")
	}

	h := mq.queues[entry.GameMode]
	position := 1
	for _, e := range *h {
		if e.UserID != userID && e.QueuedAt.Before(entry.QueuedAt) {
			position++
		}
	}
	return entry, position, h.Len(), nil
}

// GetMatches returns the channel of formed matches.
func (mq *MatchmakingQueue) GetMatches() <-chan *Match {
	return mq.matches
}

// Stop terminates the matchmaking loop. The loop goroutine closes the
// matches channel itself, so an in-flight tick can never send on a closed
// channel.
func (mq *MatchmakingQueue) Stop() {
	mq.ticker.Stop()
	mq.cancel()
}

func (mq *MatchmakingQueue) matchmakingLoop() {
	defer close(mq.matches)
	for {
		select {
		case <-mq.ctx.Done():
			return
		case <-mq.ticker.C:
			mq.expandSearchRanges()
			mq.findMatches()
		}
	}
}

// findMatches pairs players in priority order: the longest-waiting player
// is matched against the longest-waiting compatible opponent.
func (mq *MatchmakingQueue) findMatches() {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	for gameMode, h := range mq.queues {
		if h.Len() < 2 {
			continue
		}

		// Snapshot in priority order (heap order is partial; sort the copy).
		candidates := make([]*QueueEntry, h.Len())
		copy(candidates, *h)
		sort.Slice(candidates, func(i, j int) bool {
			return candidates[i].QueuedAt.Before(candidates[j].QueuedAt)
		})

		matched := make(map[string]bool)
		for i := 0; i < len(candidates)-1; i++ {
			p1 := candidates[i]
			if matched[p1.UserID] {
				continue
			}
			for j := i + 1; j < len(candidates); j++ {
				p2 := candidates[j]
				if matched[p2.UserID] || !mq.canMatch(p1, p2) {
					continue
				}

				match := &Match{
					MatchID:  uuid.New().String(),
					Player1:  p1,
					Player2:  p2,
					GameMode: gameMode,
				}
				matched[p1.UserID] = true
				matched[p2.UserID] = true
				mq.removeLocked(p1.UserID)
				mq.removeLocked(p2.UserID)

				select {
				case mq.matches <- match:
					mq.log.Info("Match created", map[string]interface{}{
						"match_id":   match.MatchID,
						"player1_id": p1.UserID,
						"player2_id": p2.UserID,
						"elo_diff":   abs(p1.ELO - p2.ELO),
						"p1_wait_s":  int(time.Since(p1.QueuedAt).Seconds()),
					})
				default:
					mq.log.Warn("Matches channel full, dropping match")
				}
				break
			}
		}
	}
}

// canMatch checks mode, region, and mutual ELO-range compatibility.
func (mq *MatchmakingQueue) canMatch(p1, p2 *QueueEntry) bool {
	if p1.GameMode != p2.GameMode {
		return false
	}

	// Prefer same region; allow cross-region once both have waited 30s.
	if p1.Region != p2.Region {
		if time.Since(p1.QueuedAt) < crossRegionAfter || time.Since(p2.QueuedAt) < crossRegionAfter {
			return false
		}
	}

	eloDiff := abs(p1.ELO - p2.ELO)
	return eloDiff <= p1.SearchRange && eloDiff <= p2.SearchRange
}

// expandSearchRanges widens the ELO window of waiting players:
// ±100 base, +50 per 15s waited, capped at ±500.
func (mq *MatchmakingQueue) expandSearchRanges() {
	mq.mu.Lock()
	defer mq.mu.Unlock()

	now := time.Now()
	for _, entry := range mq.byUser {
		waited := now.Sub(entry.QueuedAt)
		newRange := initialSearchRange + int(waited/rangeExpansionPeriod)*rangeExpansionStep
		if newRange > maxSearchRange {
			newRange = maxSearchRange
		}
		if newRange != entry.SearchRange {
			entry.SearchRange = newRange
			mq.log.Debug("Expanded search range", map[string]interface{}{
				"user_id":      entry.UserID,
				"search_range": newRange,
				"wait_time_s":  int(waited.Seconds()),
			})
		}
	}
}

func abs(n int) int {
	if n < 0 {
		return -n
	}
	return n
}
