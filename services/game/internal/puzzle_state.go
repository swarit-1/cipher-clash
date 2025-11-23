package game

type PuzzleState struct {
	EncryptedText string `json:"encrypted_text"`
	CipherType    string `json:"cipher_type"`
	Difficulty    int    `json:"difficulty"`
	Length        int    `json:"length"`
}

type GameEvent struct {
	Type    string      `json:"type"` // "MATCH_STARTED", "OPPONENT_PROGRESS", "GAME_RESULT"
	Payload interface{} `json:"payload"`
}

type OpponentProgressPayload struct {
	Progress float64 `json:"progress"` // 0.0 to 1.0
}

type GameResultPayload struct {
	WinnerID     string `json:"winner_id"`
	RatingChange int    `json:"rating_change"`
}
