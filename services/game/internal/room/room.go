package room

import (
	"encoding/json"
	"strings"
	"sync/atomic"
	"time"

	"github.com/swarit-1/cipher-clash/pkg/logger"
)

const (
	// TargetSolves puzzles solved first wins the match.
	TargetSolves = 3
	// DefaultPuzzleCount is the size of the match puzzle set.
	DefaultPuzzleCount = 5

	progressSampleP = 2 * time.Second
)

// Timing knobs (vars so tests can shorten them).
var (
	waitingWindow = 60 * time.Second
	countdownLen  = 3 * time.Second
	matchDuration = 5 * time.Minute
	forfeitWindow = 45 * time.Second
)

// Match statuses (mirror the matches.status column).
const (
	StatusWaiting    = "WAITING"
	StatusCountdown  = "COUNTDOWN"
	StatusInProgress = "IN_PROGRESS"
	StatusCompleted  = "COMPLETED"
	StatusAborted    = "ABORTED"
)

// MatchResult is handed to the ResultSink when a match finishes.
type MatchResult struct {
	MatchID    string
	GameMode   string
	IsRanked   bool
	Player1    PlayerInfo
	Player2    PlayerInfo
	WinnerID   string // empty on draw/abort
	Reason     string
	Status     string // COMPLETED or ABORTED
	DurationMs int64
	Scores     map[string]int     // userID -> solved count
	SolveTimes map[string][]int64 // userID -> per-puzzle ms
	Attempts   []AttemptRecord
	Replay     json.RawMessage
}

// AttemptRecord is one solution submission for puzzle_attempts.
type AttemptRecord struct {
	UserID      string
	PuzzleID    string
	CipherType  string
	Solution    string
	IsCorrect   bool
	SolveTimeMs int64
}

// RatingOutcome carries ELO changes back for the MATCH_END broadcast.
type RatingOutcome struct {
	Changes map[string]int // userID -> delta
	NewElos map[string]int // userID -> new rating
}

// ResultSink persists results and applies ratings. Implemented by the
// manager so the room stays free of DB/HTTP dependencies.
type ResultSink interface {
	// MatchStarted is called once when gameplay begins.
	MatchStarted(matchID string)
	// MatchFinished persists the result; for ranked PvP it returns the
	// applied ELO changes (nil otherwise).
	MatchFinished(result MatchResult) *RatingOutcome
}

// ---------------------------------------------------------------------------
// Commands: every external input is funneled through one channel so a single
// goroutine owns all room state. No locks, no data races.
// ---------------------------------------------------------------------------

type cmdJoin struct {
	userID    string
	p         Participant
	spectator bool
	reply     chan error
}

type cmdLeave struct {
	userID string
	p      Participant
}

type cmdMessage struct {
	userID string
	env    Envelope
}

type cmdTimer struct {
	kind string // "waiting", "countdown", "deadline", "forfeit"
	seq  uint64 // guards against stale forfeit timers
}

type replayEvent struct {
	TMs  int64                  `json:"t_ms"`
	UID  string                 `json:"uid,omitempty"`
	Type string                 `json:"type"`
	Data map[string]interface{} `json:"data,omitempty"`
}

type playerState struct {
	info        PlayerInfo
	participant Participant // nil while disconnected
	puzzleIndex int
	solvedCount int
	progress    float64
	puzzleStart time.Time
	solveTimes  []int64
	attempts    []AttemptRecord
	lastSample  time.Time
	forfeitSeq  uint64
	goneSince   time.Time
}

// Room runs one match. All state is owned by the run() goroutine.
type Room struct {
	info MatchInfo
	sink ResultSink
	log  *logger.Logger

	inbox  chan interface{}
	closed atomic.Bool

	status     string
	players    map[string]*playerState
	order      []string // [player1ID, player2ID]
	spectators map[Participant]bool

	startedAt time.Time
	deadline  time.Time
	timerSeq  uint64

	replayEvents []replayEvent
	epoch        time.Time
}

// New creates a room and starts its goroutine.
func New(info MatchInfo, sink ResultSink, log *logger.Logger) *Room {
	r := &Room{
		info:       info,
		sink:       sink,
		log:        log,
		inbox:      make(chan interface{}, 256),
		status:     StatusWaiting,
		players:    make(map[string]*playerState, 2),
		order:      []string{info.Player1.UserID, info.Player2.UserID},
		spectators: make(map[Participant]bool),
		epoch:      time.Now(),
	}
	r.players[info.Player1.UserID] = &playerState{info: info.Player1}
	r.players[info.Player2.UserID] = &playerState{info: info.Player2}

	go r.run()
	r.afterFunc(waitingWindow, cmdTimer{kind: "waiting"})
	return r
}

// MatchID returns the room's match id.
func (r *Room) MatchID() string { return r.info.MatchID }

// Join attaches a participant. Spectators may join any room; players must
// be match participants. Safe to call from any goroutine.
func (r *Room) Join(userID string, p Participant, spectator bool) error {
	reply := make(chan error, 1)
	if !r.post(cmdJoin{userID: userID, p: p, spectator: spectator, reply: reply}) {
		return ErrRoomClosed
	}
	return <-reply
}

// Leave detaches a participant (socket closed).
func (r *Room) Leave(userID string, p Participant) {
	r.post(cmdLeave{userID: userID, p: p})
}

// HandleMessage feeds a client/bot message into the room.
func (r *Room) HandleMessage(userID string, env Envelope) {
	r.post(cmdMessage{userID: userID, env: env})
}

// ErrRoomClosed is returned when joining a finished, garbage-collected room.
var ErrRoomClosed = errRoomClosed{}

type errRoomClosed struct{}

func (errRoomClosed) Error() string { return "room closed" }

func (r *Room) post(cmd interface{}) bool {
	if r.closed.Load() {
		return false
	}
	select {
	case r.inbox <- cmd:
		return true
	default:
		r.log.Warn("Room inbox full, dropping command", map[string]interface{}{"match_id": r.info.MatchID})
		return false
	}
}

func (r *Room) afterFunc(d time.Duration, cmd cmdTimer) {
	time.AfterFunc(d, func() { r.post(cmd) })
}

// ---------------------------------------------------------------------------
// Run loop
// ---------------------------------------------------------------------------

func (r *Room) run() {
	for cmd := range r.inbox {
		switch c := cmd.(type) {
		case cmdJoin:
			c.reply <- r.handleJoin(c)
		case cmdLeave:
			r.handleLeave(c)
		case cmdMessage:
			r.handleMessage(c)
		case cmdTimer:
			r.handleTimer(c)
		case cmdShutdown:
			r.closed.Store(true)
			for _, ps := range r.players {
				if ps.participant != nil {
					ps.participant.Close()
				}
			}
			for sp := range r.spectators {
				sp.Close()
			}
			return
		}
	}
}

type cmdShutdown struct{}

// Shutdown stops the room goroutine and closes all participants.
func (r *Room) Shutdown() {
	r.post(cmdShutdown{})
}

func (r *Room) handleJoin(c cmdJoin) error {
	if c.spectator {
		r.spectators[c.p] = true
		c.p.Send(NewEnvelope(TypeSpectatorState, r.spectatorState()))
		return nil
	}

	ps, ok := r.players[c.userID]
	if !ok {
		return errNotParticipant{}
	}

	// Replace any previous connection (reconnect).
	if ps.participant != nil {
		ps.participant.Close()
	}
	wasGone := !ps.goneSince.IsZero()
	ps.participant = c.p
	ps.goneSince = time.Time{}
	ps.forfeitSeq++ // invalidate any pending forfeit timer

	r.recordEvent(c.userID, "JOIN", nil)
	c.p.Send(NewEnvelope(TypeRoomState, r.roomState(c.userID)))

	if wasGone {
		r.sendToOpponent(c.userID, NewEnvelope(TypeOpponentReconnected, nil))
		r.recordEvent(c.userID, "RECONNECT", nil)
	}

	// Start the countdown once both players are present.
	if r.status == StatusWaiting && r.allConnected() {
		r.beginCountdown()
	}
	return nil
}

type errNotParticipant struct{}

func (errNotParticipant) Error() string { return "not a participant of this match" }

func (r *Room) handleLeave(c cmdLeave) {
	if r.spectators[c.p] {
		delete(r.spectators, c.p)
		return
	}

	ps, ok := r.players[c.userID]
	if !ok || ps.participant != c.p {
		return // stale connection already replaced by a reconnect
	}
	ps.participant = nil
	ps.goneSince = time.Now()
	r.recordEvent(c.userID, "DISCONNECT", nil)

	if r.status != StatusInProgress && r.status != StatusCountdown {
		return
	}

	// Opponent gets a forfeit countdown; reconnect cancels it via forfeitSeq.
	r.sendToOpponent(c.userID, NewEnvelope(TypeOpponentDisconnected, OpponentDisconnectedPayload{
		ForfeitInSeconds: int(forfeitWindow.Seconds()),
	}))
	ps.forfeitSeq++
	seq := ps.forfeitSeq
	r.afterFunc(forfeitWindow, cmdTimer{kind: "forfeit:" + c.userID, seq: seq})
}

func (r *Room) handleTimer(c cmdTimer) {
	switch {
	case c.kind == "waiting":
		if r.status == StatusWaiting {
			r.endMatch("", ReasonAborted)
		}
	case c.kind == "countdown":
		if r.status == StatusCountdown {
			r.beginPlay()
		}
	case c.kind == "deadline":
		if r.status == StatusInProgress {
			r.endByTimeout()
		}
	case strings.HasPrefix(c.kind, "forfeit:"):
		userID := strings.TrimPrefix(c.kind, "forfeit:")
		ps, ok := r.players[userID]
		if !ok || ps.forfeitSeq != c.seq || r.status != StatusInProgress {
			return // reconnected or match already over
		}
		r.recordEvent(userID, "FORFEIT_TIMEOUT", nil)
		r.endMatch(r.opponentID(userID), ReasonForfeit)
	}
}

func (r *Room) handleMessage(c cmdMessage) {
	ps, ok := r.players[c.userID]
	if !ok {
		return
	}

	switch c.env.Type {
	case TypePing:
		if ps.participant != nil {
			ps.participant.Send(NewEnvelope(TypePong, nil))
		}

	case TypeProgress:
		if r.status != StatusInProgress {
			return
		}
		var p ProgressPayload
		if err := json.Unmarshal(c.env.Payload, &p); err != nil || p.Progress < 0 || p.Progress > 1 {
			return
		}
		ps.progress = p.Progress
		r.sendToOpponent(c.userID, NewEnvelope(TypeOpponentProgress, OpponentProgressPayload{
			Progress:    p.Progress,
			PuzzleIndex: ps.puzzleIndex,
		}))
		r.broadcastSpectators(NewEnvelope(TypePlayerProgress, PlayerEventPayload{
			UserID: c.userID, Progress: p.Progress, PuzzleIndex: ps.puzzleIndex, SolvedCount: ps.solvedCount,
		}))
		if time.Since(ps.lastSample) >= progressSampleP {
			ps.lastSample = time.Now()
			r.recordEvent(c.userID, "PROGRESS", map[string]interface{}{"pct": p.Progress, "puzzle": ps.puzzleIndex})
		}

	case TypeSubmit:
		r.handleSubmit(c.userID, ps, c.env)

	case TypeForfeit:
		if r.status == StatusInProgress || r.status == StatusCountdown {
			r.recordEvent(c.userID, "FORFEIT", nil)
			r.endMatch(r.opponentID(c.userID), ReasonForfeit)
		}
	}
}

func (r *Room) handleSubmit(userID string, ps *playerState, env Envelope) {
	if r.status != StatusInProgress {
		r.sendTo(ps, NewEnvelope(TypeError, ErrorPayload{Code: "NOT_IN_PROGRESS", Message: "Match is not in progress"}))
		return
	}

	var sub SubmitPayload
	if err := json.Unmarshal(env.Payload, &sub); err != nil {
		r.sendTo(ps, NewEnvelope(TypeError, ErrorPayload{Code: "BAD_PAYLOAD", Message: "Malformed SUBMIT payload"}))
		return
	}
	if sub.PuzzleIndex != ps.puzzleIndex {
		r.sendTo(ps, NewEnvelope(TypeError, ErrorPayload{Code: "STALE_PUZZLE", Message: "Submission for a puzzle that is not current"}))
		return
	}
	if len(sub.Solution) == 0 || len(sub.Solution) > 2048 {
		r.sendTo(ps, NewEnvelope(TypeError, ErrorPayload{Code: "BAD_SOLUTION", Message: "Solution length out of bounds"}))
		return
	}

	puzzle := r.info.Puzzles[ps.puzzleIndex]
	correct := Normalize(sub.Solution) == Normalize(puzzle.Plaintext)
	solveMs := time.Since(ps.puzzleStart).Milliseconds()

	ps.attempts = append(ps.attempts, AttemptRecord{
		UserID:      userID,
		PuzzleID:    puzzle.ID,
		CipherType:  puzzle.CipherType,
		Solution:    truncate(sub.Solution, 256),
		IsCorrect:   correct,
		SolveTimeMs: solveMs,
	})

	if !correct {
		r.recordEvent(userID, "SUBMIT_WRONG", map[string]interface{}{"puzzle": ps.puzzleIndex})
		r.sendTo(ps, NewEnvelope(TypeSubmitResult, SubmitResultPayload{
			PuzzleIndex: ps.puzzleIndex, Correct: false, SolvedCount: ps.solvedCount,
		}))
		return
	}

	ps.solvedCount++
	ps.solveTimes = append(ps.solveTimes, solveMs)
	ps.progress = 0
	r.recordEvent(userID, "SOLVED", map[string]interface{}{"puzzle": ps.puzzleIndex, "ms": solveMs})

	r.sendTo(ps, NewEnvelope(TypeSubmitResult, SubmitResultPayload{
		PuzzleIndex: ps.puzzleIndex, Correct: true, SolveTimeMs: solveMs, SolvedCount: ps.solvedCount,
	}))
	r.sendToOpponent(userID, NewEnvelope(TypeOpponentSolved, OpponentSolvedPayload{
		PuzzleIndex: ps.puzzleIndex, SolvedCount: ps.solvedCount, SolveTimeMs: solveMs,
	}))
	r.broadcastSpectators(NewEnvelope(TypePlayerSolved, PlayerEventPayload{
		UserID: userID, PuzzleIndex: ps.puzzleIndex, SolvedCount: ps.solvedCount,
	}))

	if ps.solvedCount >= TargetSolves {
		r.endMatch(userID, ReasonCompleted)
		return
	}

	// Advance to the next puzzle if any remain.
	if ps.puzzleIndex+1 < len(r.info.Puzzles) {
		ps.puzzleIndex++
		ps.puzzleStart = time.Now()
		r.sendTo(ps, NewEnvelope(TypePuzzleSet, PuzzleSetPayload{
			Puzzle:       r.puzzleView(ps.puzzleIndex),
			TotalPuzzles: len(r.info.Puzzles),
		}))
	} else if r.bothExhausted() {
		r.endByTimeout() // both ran out of puzzles: score what we have
	}
}

// ---------------------------------------------------------------------------
// Lifecycle transitions
// ---------------------------------------------------------------------------

func (r *Room) beginCountdown() {
	r.status = StatusCountdown
	r.startedAt = time.Now().Add(countdownLen)
	r.deadline = r.startedAt.Add(matchDuration)

	payload := MatchStartedPayload{
		StartsAtMs:  r.startedAt.UnixMilli(),
		DeadlineMs:  r.deadline.UnixMilli(),
		ServerNowMs: time.Now().UnixMilli(),
	}
	r.broadcastPlayers(NewEnvelope(TypeMatchStarted, payload))
	r.broadcastSpectators(NewEnvelope(TypeMatchStarted, payload))
	r.afterFunc(countdownLen, cmdTimer{kind: "countdown"})
}

func (r *Room) beginPlay() {
	r.status = StatusInProgress
	now := time.Now()
	for _, ps := range r.players {
		ps.puzzleStart = now
	}
	r.recordEvent("", "MATCH_STARTED", nil)
	r.sink.MatchStarted(r.info.MatchID)

	for _, ps := range r.players {
		r.sendTo(ps, NewEnvelope(TypePuzzleSet, PuzzleSetPayload{
			Puzzle:       r.puzzleView(ps.puzzleIndex),
			TotalPuzzles: len(r.info.Puzzles),
		}))
	}
	r.afterFunc(time.Until(r.deadline), cmdTimer{kind: "deadline"})
}

// endByTimeout scores the match when the clock runs out: more solves wins,
// then lower total solve time, else draw.
func (r *Room) endByTimeout() {
	p1 := r.players[r.order[0]]
	p2 := r.players[r.order[1]]

	switch {
	case p1.solvedCount > p2.solvedCount:
		r.endMatch(r.order[0], ReasonTimeout)
	case p2.solvedCount > p1.solvedCount:
		r.endMatch(r.order[1], ReasonTimeout)
	case p1.solvedCount == 0 && p2.solvedCount == 0:
		r.endMatch("", ReasonDraw)
	default:
		if totalMs(p1.solveTimes) <= totalMs(p2.solveTimes) {
			r.endMatch(r.order[0], ReasonTimeout)
		} else {
			r.endMatch(r.order[1], ReasonTimeout)
		}
	}
}

func (r *Room) endMatch(winnerID, reason string) {
	if r.status == StatusCompleted || r.status == StatusAborted {
		return
	}
	status := StatusCompleted
	if reason == ReasonAborted {
		status = StatusAborted
	}
	r.status = status

	var durationMs int64
	if !r.startedAt.IsZero() {
		durationMs = time.Since(r.startedAt).Milliseconds()
	}

	p1 := r.players[r.order[0]]
	p2 := r.players[r.order[1]]
	scores := map[string]int{r.order[0]: p1.solvedCount, r.order[1]: p2.solvedCount}
	solveTimes := map[string][]int64{r.order[0]: p1.solveTimes, r.order[1]: p2.solveTimes}

	r.recordEvent(winnerID, "MATCH_END", map[string]interface{}{"reason": reason})

	result := MatchResult{
		MatchID:    r.info.MatchID,
		GameMode:   r.info.GameMode,
		IsRanked:   r.info.IsRanked,
		Player1:    r.info.Player1,
		Player2:    r.info.Player2,
		WinnerID:   winnerID,
		Reason:     reason,
		Status:     status,
		DurationMs: durationMs,
		Scores:     scores,
		SolveTimes: solveTimes,
		Attempts:   append(append([]AttemptRecord{}, p1.attempts...), p2.attempts...),
		Replay:     r.buildReplay(winnerID, reason, durationMs),
	}

	outcome := r.sink.MatchFinished(result)

	for _, id := range r.order {
		ps := r.players[id]
		opp := r.players[r.opponentID(id)]
		payload := MatchEndPayload{
			WinnerID:      winnerID,
			Reason:        reason,
			YourScore:     ps.solvedCount,
			OpponentScore: opp.solvedCount,
			DurationMs:    durationMs,
			SolveTimes: map[string]any{
				id:               ps.solveTimes,
				r.opponentID(id): opp.solveTimes,
			},
		}
		if outcome != nil {
			payload.EloChange = outcome.Changes[id]
			payload.NewElo = outcome.NewElos[id]
		}
		r.sendTo(ps, NewEnvelope(TypeMatchEnd, payload))
	}
	r.broadcastSpectators(NewEnvelope(TypeMatchEnd, MatchEndPayload{
		WinnerID: winnerID, Reason: reason, DurationMs: durationMs,
	}))
}

// ---------------------------------------------------------------------------
// Views & helpers (all called from the run goroutine)
// ---------------------------------------------------------------------------

func (r *Room) puzzleView(index int) PuzzleView {
	p := r.info.Puzzles[index]
	return PuzzleView{
		Index:         index,
		CipherType:    p.CipherType,
		Difficulty:    p.Difficulty,
		EncryptedText: p.EncryptedText,
	}
}

func (r *Room) playerView(id string) PlayerView {
	ps := r.players[id]
	return PlayerView{
		UserID:      ps.info.UserID,
		Username:    ps.info.Username,
		ELO:         ps.info.ELO,
		IsBot:       ps.info.IsBot,
		Connected:   ps.participant != nil,
		SolvedCount: ps.solvedCount,
		PuzzleIndex: ps.puzzleIndex,
		Progress:    ps.progress,
	}
}

func (r *Room) roomState(forUserID string) RoomStatePayload {
	ps := r.players[forUserID]
	oppID := r.opponentID(forUserID)
	opp := r.players[oppID]

	state := RoomStatePayload{
		MatchID:      r.info.MatchID,
		Status:       r.status,
		GameMode:     r.info.GameMode,
		IsRanked:     r.info.IsRanked,
		You:          r.playerView(forUserID),
		Opponent:     r.playerView(oppID),
		TotalPuzzles: len(r.info.Puzzles),
		TargetSolves: TargetSolves,
		ServerNowMs:  time.Now().UnixMilli(),
	}
	if !r.startedAt.IsZero() {
		state.StartsAtMs = r.startedAt.UnixMilli()
		state.DeadlineMs = r.deadline.UnixMilli()
	}
	if r.status == StatusInProgress {
		pv := r.puzzleView(ps.puzzleIndex)
		state.Puzzle = &pv
	}
	if !opp.goneSince.IsZero() {
		state.OpponentGoneMs = time.Since(opp.goneSince).Milliseconds()
	}
	return state
}

func (r *Room) spectatorState() SpectatorStatePayload {
	state := SpectatorStatePayload{
		MatchID:      r.info.MatchID,
		Status:       r.status,
		GameMode:     r.info.GameMode,
		Players:      []PlayerView{r.playerView(r.order[0]), r.playerView(r.order[1])},
		TotalPuzzles: len(r.info.Puzzles),
		TargetSolves: TargetSolves,
		ServerNowMs:  time.Now().UnixMilli(),
	}
	if !r.deadline.IsZero() {
		state.DeadlineMs = r.deadline.UnixMilli()
	}
	return state
}

func (r *Room) opponentID(userID string) string {
	if r.order[0] == userID {
		return r.order[1]
	}
	return r.order[0]
}

func (r *Room) allConnected() bool {
	for _, ps := range r.players {
		if ps.participant == nil {
			return false
		}
	}
	return true
}

func (r *Room) bothExhausted() bool {
	for _, ps := range r.players {
		if ps.puzzleIndex+1 < len(r.info.Puzzles) || ps.solvedCount >= TargetSolves {
			return false
		}
	}
	return true
}

func (r *Room) sendTo(ps *playerState, env Envelope) {
	if ps.participant != nil {
		ps.participant.Send(env)
	}
}

func (r *Room) sendToOpponent(userID string, env Envelope) {
	r.sendTo(r.players[r.opponentID(userID)], env)
}

func (r *Room) broadcastPlayers(env Envelope) {
	for _, ps := range r.players {
		r.sendTo(ps, env)
	}
}

func (r *Room) broadcastSpectators(env Envelope) {
	for sp := range r.spectators {
		sp.Send(env)
	}
}

func (r *Room) recordEvent(uid, eventType string, data map[string]interface{}) {
	r.replayEvents = append(r.replayEvents, replayEvent{
		TMs:  time.Since(r.epoch).Milliseconds(),
		UID:  uid,
		Type: eventType,
		Data: data,
	})
}

func (r *Room) buildReplay(winnerID, reason string, durationMs int64) json.RawMessage {
	type replayPlayer struct {
		UserID   string `json:"user_id"`
		Username string `json:"username"`
		ELO      int    `json:"elo_before"`
		IsBot    bool   `json:"is_bot"`
	}
	type replayPuzzle struct {
		CipherType    string `json:"cipher_type"`
		Difficulty    int    `json:"difficulty"`
		EncryptedText string `json:"encrypted_text"`
		Solution      string `json:"solution"`
	}
	puzzles := make([]replayPuzzle, len(r.info.Puzzles))
	for i, p := range r.info.Puzzles {
		puzzles[i] = replayPuzzle{
			CipherType:    p.CipherType,
			Difficulty:    p.Difficulty,
			EncryptedText: p.EncryptedText,
			Solution:      p.Plaintext,
		}
	}
	doc := map[string]interface{}{
		"version": 1,
		"players": []replayPlayer{
			{UserID: r.info.Player1.UserID, Username: r.info.Player1.Username, ELO: r.info.Player1.ELO, IsBot: r.info.Player1.IsBot},
			{UserID: r.info.Player2.UserID, Username: r.info.Player2.Username, ELO: r.info.Player2.ELO, IsBot: r.info.Player2.IsBot},
		},
		"puzzles": puzzles,
		"events":  r.replayEvents,
		"result": map[string]interface{}{
			"winner_id":   winnerID,
			"reason":      reason,
			"duration_ms": durationMs,
		},
	}
	raw, err := json.Marshal(doc)
	if err != nil {
		r.log.Error("Failed to marshal replay", map[string]interface{}{"error": err.Error()})
		return json.RawMessage(`{}`)
	}
	return raw
}

// Normalize canonicalizes a solution for comparison: uppercase, strip
// non-alphanumerics. Mirrors the puzzle engine's comparison semantics.
func Normalize(s string) string {
	var b strings.Builder
	b.Grow(len(s))
	for _, c := range s {
		switch {
		case c >= 'a' && c <= 'z':
			b.WriteRune(c - 32)
		case (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9'):
			b.WriteRune(c)
		}
	}
	return b.String()
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n]
}

func totalMs(ts []int64) int64 {
	var sum int64
	for _, t := range ts {
		sum += t
	}
	return sum
}
