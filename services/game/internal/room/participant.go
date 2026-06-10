package room

// Participant is anything that can receive room messages: a WebSocket
// client or a bot. The Room never blocks on a participant — Send must be
// non-blocking (buffered or drop-on-full).
type Participant interface {
	// Send delivers an envelope to the participant. Implementations must
	// not block the caller.
	Send(env Envelope)
	// Close releases the participant (closes the socket / stops the bot).
	// Idempotent.
	Close()
}

// Puzzle is the server-side puzzle including its solution.
type Puzzle struct {
	ID            string `json:"id"`
	CipherType    string `json:"cipher_type"`
	Difficulty    int    `json:"difficulty"`
	EncryptedText string `json:"encrypted_text"`
	Plaintext     string `json:"plaintext"`
}

// PlayerInfo identifies one side of a match.
type PlayerInfo struct {
	UserID   string
	Username string
	ELO      int
	IsBot    bool
}

// MatchInfo is everything a room needs to run a match.
type MatchInfo struct {
	MatchID  string
	GameMode string
	IsRanked bool
	Player1  PlayerInfo
	Player2  PlayerInfo
	Puzzles  []Puzzle
}
