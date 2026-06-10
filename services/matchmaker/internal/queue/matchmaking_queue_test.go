package queue

import (
	"testing"
	"time"

	"github.com/swarit-1/cipher-clash/pkg/logger"
)

func newTestQueue() *MatchmakingQueue {
	// No Redis, no ticker loop: findMatches/expandSearchRanges are driven
	// directly by the tests.
	return &MatchmakingQueue{
		queues:  make(map[string]*playerHeap),
		byUser:  make(map[string]*QueueEntry),
		log:     logger.New("queue-test"),
		matches: make(chan *Match, 100),
	}
}

func TestMatchWithinRange(t *testing.T) {
	mq := newTestQueue()

	if err := mq.AddPlayer(&QueueEntry{UserID: "a", Username: "alice", ELO: 1200, Region: "US", GameMode: "RANKED_1V1"}); err != nil {
		t.Fatalf("add alice: %v", err)
	}
	if err := mq.AddPlayer(&QueueEntry{UserID: "b", Username: "bob", ELO: 1250, Region: "US", GameMode: "RANKED_1V1"}); err != nil {
		t.Fatalf("add bob: %v", err)
	}

	mq.findMatches()

	select {
	case m := <-mq.matches:
		if m.Player1.UserID != "a" || m.Player2.UserID != "b" {
			t.Fatalf("unexpected pairing: %s vs %s", m.Player1.UserID, m.Player2.UserID)
		}
	default:
		t.Fatal("expected a match for players within ±100 ELO")
	}

	if _, _, _, err := mq.GetQueueStatus("a"); err == nil {
		t.Fatal("matched player should be removed from queue")
	}
}

func TestNoMatchOutsideRange(t *testing.T) {
	mq := newTestQueue()

	mq.AddPlayer(&QueueEntry{UserID: "a", ELO: 1200, Region: "US", GameMode: "RANKED_1V1"})
	mq.AddPlayer(&QueueEntry{UserID: "b", ELO: 1600, Region: "US", GameMode: "RANKED_1V1"})

	mq.findMatches()

	select {
	case <-mq.matches:
		t.Fatal("players 400 ELO apart must not match at the initial ±100 range")
	default:
	}
}

func TestRangeExpansionEnablesMatch(t *testing.T) {
	mq := newTestQueue()

	mq.AddPlayer(&QueueEntry{UserID: "a", ELO: 1200, Region: "US", GameMode: "RANKED_1V1"})
	mq.AddPlayer(&QueueEntry{UserID: "b", ELO: 1600, Region: "US", GameMode: "RANKED_1V1"})

	// Simulate 95 seconds of waiting: range = 100 + 6*50 = 400 (≥ the gap).
	mq.mu.Lock()
	for _, e := range mq.byUser {
		e.QueuedAt = time.Now().Add(-95 * time.Second)
	}
	mq.mu.Unlock()

	mq.expandSearchRanges()
	mq.mu.Lock()
	gotRange := mq.byUser["a"].SearchRange
	mq.mu.Unlock()
	if gotRange != 400 {
		t.Fatalf("after 95s want range 400, got %d", gotRange)
	}

	mq.findMatches()
	select {
	case <-mq.matches:
	default:
		t.Fatal("expanded ranges should allow the 400-ELO-gap match")
	}
}

func TestRangeCapsAt500(t *testing.T) {
	mq := newTestQueue()
	mq.AddPlayer(&QueueEntry{UserID: "a", ELO: 1200, Region: "US", GameMode: "RANKED_1V1"})

	mq.mu.Lock()
	mq.byUser["a"].QueuedAt = time.Now().Add(-10 * time.Minute)
	mq.mu.Unlock()

	mq.expandSearchRanges()
	mq.mu.Lock()
	gotRange := mq.byUser["a"].SearchRange
	mq.mu.Unlock()
	if gotRange != maxSearchRange {
		t.Fatalf("want capped range %d, got %d", maxSearchRange, gotRange)
	}
}

func TestPriorityOrder(t *testing.T) {
	mq := newTestQueue()

	mq.AddPlayer(&QueueEntry{UserID: "late", ELO: 1200, Region: "US", GameMode: "RANKED_1V1"})
	mq.AddPlayer(&QueueEntry{UserID: "early", ELO: 1210, Region: "US", GameMode: "RANKED_1V1"})
	mq.AddPlayer(&QueueEntry{UserID: "mid", ELO: 1220, Region: "US", GameMode: "RANKED_1V1"})

	// Backdate to invert insertion order: early has waited longest.
	mq.mu.Lock()
	mq.byUser["early"].QueuedAt = time.Now().Add(-60 * time.Second)
	mq.byUser["mid"].QueuedAt = time.Now().Add(-30 * time.Second)
	mq.mu.Unlock()

	mq.findMatches()

	m := <-mq.matches
	if m.Player1.UserID != "early" {
		t.Fatalf("longest-waiting player should match first, got %s", m.Player1.UserID)
	}
	if m.Player2.UserID != "mid" {
		t.Fatalf("second-longest-waiting compatible player should be chosen, got %s", m.Player2.UserID)
	}

	if _, pos, total, err := mq.GetQueueStatus("late"); err != nil || pos != 1 || total != 1 {
		t.Fatalf("remaining player should be position 1 of 1 (pos=%d total=%d err=%v)", pos, total, err)
	}
}

func TestCrossRegionDelay(t *testing.T) {
	mq := newTestQueue()

	mq.AddPlayer(&QueueEntry{UserID: "us", ELO: 1200, Region: "US", GameMode: "RANKED_1V1"})
	mq.AddPlayer(&QueueEntry{UserID: "eu", ELO: 1200, Region: "EU", GameMode: "RANKED_1V1"})

	mq.findMatches()
	select {
	case <-mq.matches:
		t.Fatal("cross-region match must wait 30s")
	default:
	}

	mq.mu.Lock()
	for _, e := range mq.byUser {
		e.QueuedAt = time.Now().Add(-35 * time.Second)
	}
	mq.mu.Unlock()

	mq.findMatches()
	select {
	case <-mq.matches:
	default:
		t.Fatal("cross-region match should form after both waited 30s")
	}
}
