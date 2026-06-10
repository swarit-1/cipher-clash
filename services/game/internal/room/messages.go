package room

import "encoding/json"

// Envelope is the wire format for every WebSocket message in both directions.
type Envelope struct {
	Type    string          `json:"type"`
	Payload json.RawMessage `json:"payload,omitempty"`
}

// NewEnvelope marshals payload into an Envelope. Marshal errors are
// programming errors (all payloads are local structs), so they panic.
func NewEnvelope(msgType string, payload interface{}) Envelope {
	if payload == nil {
		return Envelope{Type: msgType}
	}
	raw, err := json.Marshal(payload)
	if err != nil {
		panic("room: unmarshalable payload for " + msgType + ": " + err.Error())
	}
	return Envelope{Type: msgType, Payload: raw}
}

// Server → client message types.
const (
	TypeRoomState            = "ROOM_STATE"
	TypeMatchStarted         = "MATCH_STARTED"
	TypePuzzleSet            = "PUZZLE_SET"
	TypeSubmitResult         = "SUBMIT_RESULT"
	TypeOpponentProgress     = "OPPONENT_PROGRESS"
	TypeOpponentSolved       = "OPPONENT_SOLVED"
	TypeOpponentDisconnected = "OPPONENT_DISCONNECTED"
	TypeOpponentReconnected  = "OPPONENT_RECONNECTED"
	TypeMatchEnd             = "MATCH_END"
	TypeError                = "ERROR"
	TypePong                 = "PONG"
	// Spectator-only stream.
	TypeSpectatorState = "SPECTATOR_STATE"
	TypePlayerProgress = "PLAYER_PROGRESS"
	TypePlayerSolved   = "PLAYER_SOLVED"
)

// Client → server message types.
const (
	TypeSubmit   = "SUBMIT"
	TypeProgress = "PROGRESS"
	TypeForfeit  = "FORFEIT"
	TypePing     = "PING"
)

// Match end reasons.
const (
	ReasonCompleted = "COMPLETED"
	ReasonForfeit   = "FORFEIT"
	ReasonTimeout   = "TIMEOUT"
	ReasonAborted   = "ABORTED"
	ReasonDraw      = "DRAW"
)

// PuzzleView is a puzzle as the client sees it: never includes the solution.
type PuzzleView struct {
	Index         int    `json:"index"`
	CipherType    string `json:"cipher_type"`
	Difficulty    int    `json:"difficulty"`
	EncryptedText string `json:"encrypted_text"`
}

// PlayerView describes a player in ROOM_STATE / SPECTATOR_STATE.
type PlayerView struct {
	UserID      string  `json:"user_id"`
	Username    string  `json:"username"`
	ELO         int     `json:"elo"`
	IsBot       bool    `json:"is_bot"`
	Connected   bool    `json:"connected"`
	SolvedCount int     `json:"solved_count"`
	PuzzleIndex int     `json:"puzzle_index"`
	Progress    float64 `json:"progress"`
}

// RoomStatePayload fully resyncs a (re)connecting player.
type RoomStatePayload struct {
	MatchID        string      `json:"match_id"`
	Status         string      `json:"status"` // WAITING, COUNTDOWN, IN_PROGRESS, COMPLETED
	GameMode       string      `json:"game_mode"`
	IsRanked       bool        `json:"is_ranked"`
	You            PlayerView  `json:"you"`
	Opponent       PlayerView  `json:"opponent"`
	Puzzle         *PuzzleView `json:"puzzle,omitempty"` // your current puzzle
	TotalPuzzles   int         `json:"total_puzzles"`
	TargetSolves   int         `json:"target_solves"`
	StartsAtMs     int64       `json:"starts_at_ms,omitempty"`
	DeadlineMs     int64       `json:"deadline_ms,omitempty"`
	ServerNowMs    int64       `json:"server_now_ms"`
	OpponentGoneMs int64       `json:"opponent_gone_ms,omitempty"` // >0 if opponent disconnected
}

// SpectatorStatePayload resyncs a spectator with both players' state.
type SpectatorStatePayload struct {
	MatchID      string       `json:"match_id"`
	Status       string       `json:"status"`
	GameMode     string       `json:"game_mode"`
	Players      []PlayerView `json:"players"`
	TotalPuzzles int          `json:"total_puzzles"`
	TargetSolves int          `json:"target_solves"`
	DeadlineMs   int64        `json:"deadline_ms,omitempty"`
	ServerNowMs  int64        `json:"server_now_ms"`
}

// MatchStartedPayload announces the synchronized start.
type MatchStartedPayload struct {
	StartsAtMs  int64 `json:"starts_at_ms"`
	DeadlineMs  int64 `json:"deadline_ms"`
	ServerNowMs int64 `json:"server_now_ms"`
}

// PuzzleSetPayload advances a player to their next puzzle.
type PuzzleSetPayload struct {
	Puzzle       PuzzleView `json:"puzzle"`
	TotalPuzzles int        `json:"total_puzzles"`
}

// SubmitPayload is a solution submission from the client.
type SubmitPayload struct {
	PuzzleIndex int    `json:"puzzle_index"`
	Solution    string `json:"solution"`
}

// SubmitResultPayload answers a SUBMIT.
type SubmitResultPayload struct {
	PuzzleIndex int   `json:"puzzle_index"`
	Correct     bool  `json:"correct"`
	SolveTimeMs int64 `json:"solve_time_ms,omitempty"`
	SolvedCount int   `json:"solved_count"`
}

// ProgressPayload reports typing progress (0.0–1.0).
type ProgressPayload struct {
	Progress float64 `json:"progress"`
}

// OpponentProgressPayload mirrors opponent progress to the other player.
type OpponentProgressPayload struct {
	Progress    float64 `json:"progress"`
	PuzzleIndex int     `json:"puzzle_index"`
}

// OpponentSolvedPayload notifies that the opponent solved their puzzle.
type OpponentSolvedPayload struct {
	PuzzleIndex int   `json:"puzzle_index"`
	SolvedCount int   `json:"solved_count"`
	SolveTimeMs int64 `json:"solve_time_ms"`
}

// OpponentDisconnectedPayload starts the forfeit countdown client-side.
type OpponentDisconnectedPayload struct {
	ForfeitInSeconds int `json:"forfeit_in_seconds"`
}

// PlayerEventPayload is the spectator-stream variant of progress/solve events.
type PlayerEventPayload struct {
	UserID      string  `json:"user_id"`
	Progress    float64 `json:"progress,omitempty"`
	PuzzleIndex int     `json:"puzzle_index"`
	SolvedCount int     `json:"solved_count"`
}

// MatchEndPayload carries the final result.
type MatchEndPayload struct {
	WinnerID      string         `json:"winner_id,omitempty"`
	Reason        string         `json:"reason"`
	YourScore     int            `json:"your_score"`
	OpponentScore int            `json:"opponent_score"`
	EloChange     int            `json:"elo_change"`
	NewElo        int            `json:"new_elo,omitempty"`
	DurationMs    int64          `json:"duration_ms"`
	SolveTimes    map[string]any `json:"solve_times,omitempty"` // user_id -> []ms
}

// ErrorPayload reports a recoverable protocol error.
type ErrorPayload struct {
	Code    string `json:"code"`
	Message string `json:"message"`
}
