package room

import (
	"encoding/json"
	"sync"
	"testing"
	"time"

	"github.com/swarit-1/cipher-clash/pkg/logger"
)

// fakeParticipant records every envelope it receives.
type fakeParticipant struct {
	mu   sync.Mutex
	msgs []Envelope
	c    chan Envelope
}

func newFake() *fakeParticipant {
	return &fakeParticipant{c: make(chan Envelope, 128)}
}

func (f *fakeParticipant) Send(env Envelope) {
	f.mu.Lock()
	f.msgs = append(f.msgs, env)
	f.mu.Unlock()
	select {
	case f.c <- env:
	default:
	}
}

func (f *fakeParticipant) Close() {}

// wait blocks until an envelope of the given type arrives.
func (f *fakeParticipant) wait(t *testing.T, msgType string) Envelope {
	t.Helper()
	deadline := time.After(5 * time.Second)
	for {
		select {
		case env := <-f.c:
			if env.Type == msgType {
				return env
			}
		case <-deadline:
			t.Fatalf("timed out waiting for %s", msgType)
		}
	}
}

// fakeSink records lifecycle calls.
type fakeSink struct {
	mu       sync.Mutex
	started  []string
	finished []MatchResult
}

func (s *fakeSink) MatchStarted(matchID string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.started = append(s.started, matchID)
}

func (s *fakeSink) MatchFinished(result MatchResult) *RatingOutcome {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.finished = append(s.finished, result)
	return &RatingOutcome{
		Changes: map[string]int{result.Player1.UserID: 16, result.Player2.UserID: -16},
		NewElos: map[string]int{result.Player1.UserID: 1216, result.Player2.UserID: 1184},
	}
}

func (s *fakeSink) lastResult(t *testing.T) MatchResult {
	t.Helper()
	s.mu.Lock()
	defer s.mu.Unlock()
	if len(s.finished) == 0 {
		t.Fatal("no finished match recorded")
	}
	return s.finished[len(s.finished)-1]
}

func testMatchInfo() MatchInfo {
	puzzles := make([]Puzzle, 5)
	for i := range puzzles {
		puzzles[i] = Puzzle{
			ID:            "p" + string(rune('1'+i)),
			CipherType:    "CAESAR",
			Difficulty:    3,
			EncryptedText: "KHOOR",
			Plaintext:     "HELLO",
		}
	}
	return MatchInfo{
		MatchID:  "m1",
		GameMode: "RANKED_1V1",
		IsRanked: true,
		Player1:  PlayerInfo{UserID: "alice", Username: "alice", ELO: 1200},
		Player2:  PlayerInfo{UserID: "bob", Username: "bob", ELO: 1200},
		Puzzles:  puzzles,
	}
}

func shortTimers(t *testing.T) {
	t.Helper()
	oldW, oldC, oldM, oldF := waitingWindow, countdownLen, matchDuration, forfeitWindow
	waitingWindow = 2 * time.Second
	countdownLen = 50 * time.Millisecond
	matchDuration = 10 * time.Second
	forfeitWindow = 300 * time.Millisecond
	t.Cleanup(func() {
		waitingWindow, countdownLen, matchDuration, forfeitWindow = oldW, oldC, oldM, oldF
	})
}

func submit(r *Room, userID string, index int, solution string) {
	r.HandleMessage(userID, NewEnvelope(TypeSubmit, SubmitPayload{PuzzleIndex: index, Solution: solution}))
}

func TestFullMatchFirstToThreeWins(t *testing.T) {
	shortTimers(t)
	sink := &fakeSink{}
	r := New(testMatchInfo(), sink, logger.New("room-test"))
	defer r.Shutdown()

	alice, bob := newFake(), newFake()
	if err := r.Join("alice", alice, false); err != nil {
		t.Fatalf("alice join: %v", err)
	}
	if err := r.Join("bob", bob, false); err != nil {
		t.Fatalf("bob join: %v", err)
	}

	alice.wait(t, TypeMatchStarted)
	alice.wait(t, TypePuzzleSet)
	bob.wait(t, TypePuzzleSet)

	// Alice solves three puzzles (with one wrong attempt in between).
	submit(r, "alice", 0, "hello") // case-insensitive
	env := alice.wait(t, TypeSubmitResult)
	var res SubmitResultPayload
	json.Unmarshal(env.Payload, &res)
	if !res.Correct || res.SolvedCount != 1 {
		t.Fatalf("first solve: %+v", res)
	}
	bob.wait(t, TypeOpponentSolved)

	alice.wait(t, TypePuzzleSet)
	submit(r, "alice", 1, "WRONG")
	env = alice.wait(t, TypeSubmitResult)
	json.Unmarshal(env.Payload, &res)
	if res.Correct {
		t.Fatal("wrong answer accepted")
	}

	submit(r, "alice", 1, "HELLO")
	alice.wait(t, TypePuzzleSet)
	submit(r, "alice", 2, "H E L L O") // whitespace-insensitive

	end := alice.wait(t, TypeMatchEnd)
	var endPayload MatchEndPayload
	json.Unmarshal(end.Payload, &endPayload)
	if endPayload.WinnerID != "alice" || endPayload.Reason != ReasonCompleted {
		t.Fatalf("unexpected end: %+v", endPayload)
	}
	if endPayload.EloChange != 16 || endPayload.NewElo != 1216 {
		t.Fatalf("elo not propagated: %+v", endPayload)
	}
	bob.wait(t, TypeMatchEnd)

	result := sink.lastResult(t)
	if result.WinnerID != "alice" || result.Scores["alice"] != 3 {
		t.Fatalf("sink result wrong: %+v", result)
	}
	if len(result.Attempts) != 4 {
		t.Fatalf("want 4 attempts recorded, got %d", len(result.Attempts))
	}
	if result.Replay == nil {
		t.Fatal("replay missing")
	}
}

func TestReconnectResyncsAndCancelsForfeit(t *testing.T) {
	shortTimers(t)
	sink := &fakeSink{}
	r := New(testMatchInfo(), sink, logger.New("room-test"))
	defer r.Shutdown()

	alice, bob := newFake(), newFake()
	r.Join("alice", alice, false)
	r.Join("bob", bob, false)
	alice.wait(t, TypePuzzleSet)

	submit(r, "alice", 0, "HELLO")
	alice.wait(t, TypeSubmitResult)

	// Bob drops; alice is told; bob reconnects within the forfeit window.
	r.Leave("bob", bob)
	alice.wait(t, TypeOpponentDisconnected)

	bob2 := newFake()
	if err := r.Join("bob", bob2, false); err != nil {
		t.Fatalf("reconnect: %v", err)
	}
	env := bob2.wait(t, TypeRoomState)
	var state RoomStatePayload
	json.Unmarshal(env.Payload, &state)
	if state.Status != StatusInProgress || state.Opponent.SolvedCount != 1 {
		t.Fatalf("resync state wrong: %+v", state)
	}
	alice.wait(t, TypeOpponentReconnected)

	// The forfeit window passes without ending the match.
	time.Sleep(500 * time.Millisecond)
	sink.mu.Lock()
	finished := len(sink.finished)
	sink.mu.Unlock()
	if finished != 0 {
		t.Fatal("match ended despite reconnect")
	}
}

func TestDisconnectForfeit(t *testing.T) {
	shortTimers(t)
	sink := &fakeSink{}
	r := New(testMatchInfo(), sink, logger.New("room-test"))
	defer r.Shutdown()

	alice, bob := newFake(), newFake()
	r.Join("alice", alice, false)
	r.Join("bob", bob, false)
	alice.wait(t, TypePuzzleSet)

	r.Leave("bob", bob)
	end := alice.wait(t, TypeMatchEnd)
	var payload MatchEndPayload
	json.Unmarshal(end.Payload, &payload)
	if payload.WinnerID != "alice" || payload.Reason != ReasonForfeit {
		t.Fatalf("expected alice forfeit win, got %+v", payload)
	}
}

func TestTimeoutScoring(t *testing.T) {
	shortTimers(t)
	matchDuration = 700 * time.Millisecond
	sink := &fakeSink{}
	r := New(testMatchInfo(), sink, logger.New("room-test"))
	defer r.Shutdown()

	alice, bob := newFake(), newFake()
	r.Join("alice", alice, false)
	r.Join("bob", bob, false)
	alice.wait(t, TypePuzzleSet)

	// Bob solves one; alice none. Clock runs out.
	submit(r, "bob", 0, "HELLO")
	bob.wait(t, TypeSubmitResult)

	end := bob.wait(t, TypeMatchEnd)
	var payload MatchEndPayload
	json.Unmarshal(end.Payload, &payload)
	if payload.WinnerID != "bob" || payload.Reason != ReasonTimeout {
		t.Fatalf("expected bob timeout win, got %+v", payload)
	}
}

func TestWaitingAbort(t *testing.T) {
	shortTimers(t)
	waitingWindow = 200 * time.Millisecond
	sink := &fakeSink{}
	r := New(testMatchInfo(), sink, logger.New("room-test"))
	defer r.Shutdown()

	alice := newFake()
	r.Join("alice", alice, false)

	end := alice.wait(t, TypeMatchEnd)
	var payload MatchEndPayload
	json.Unmarshal(end.Payload, &payload)
	if payload.Reason != ReasonAborted {
		t.Fatalf("expected abort, got %+v", payload)
	}
	if sink.lastResult(t).Status != StatusAborted {
		t.Fatal("status not ABORTED")
	}
}

func TestSpectatorReceivesStream(t *testing.T) {
	shortTimers(t)
	sink := &fakeSink{}
	r := New(testMatchInfo(), sink, logger.New("room-test"))
	defer r.Shutdown()

	alice, bob, spec := newFake(), newFake(), newFake()
	r.Join("alice", alice, false)
	r.Join("bob", bob, false)
	if err := r.Join("ghost", spec, true); err != nil {
		t.Fatalf("spectator join: %v", err)
	}
	spec.wait(t, TypeSpectatorState)
	alice.wait(t, TypePuzzleSet)

	submit(r, "alice", 0, "HELLO")
	env := spec.wait(t, TypePlayerSolved)
	var ev PlayerEventPayload
	json.Unmarshal(env.Payload, &ev)
	if ev.UserID != "alice" || ev.SolvedCount != 1 {
		t.Fatalf("spectator event wrong: %+v", ev)
	}
}

func TestNonParticipantRejected(t *testing.T) {
	shortTimers(t)
	r := New(testMatchInfo(), &fakeSink{}, logger.New("room-test"))
	defer r.Shutdown()

	if err := r.Join("mallory", newFake(), false); err == nil {
		t.Fatal("non-participant join must fail")
	}
}
