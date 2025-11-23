package game

import (
	"sync"
	"time"
)

type RateLimiter struct {
	mu       sync.Mutex
	requests map[string][]time.Time
	limit    int
	window   time.Duration
}

func NewRateLimiter(limit int, window time.Duration) *RateLimiter {
	return &RateLimiter{
		requests: make(map[string][]time.Time),
		limit:    limit,
		window:   window,
	}
}

func (rl *RateLimiter) Allow(clientID string) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	now := time.Now()
	windowStart := now.Add(-rl.window)

	// Filter out old requests
	validRequests := make([]time.Time, 0)
	if reqs, ok := rl.requests[clientID]; ok {
		for _, t := range reqs {
			if t.After(windowStart) {
				validRequests = append(validRequests, t)
			}
		}
	}

	if len(validRequests) >= rl.limit {
		rl.requests[clientID] = validRequests
		return false
	}

	validRequests = append(validRequests, now)
	rl.requests[clientID] = validRequests
	return true
}
