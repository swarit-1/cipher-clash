package internal

import (
	"time"
)

// PracticeMode represents practice session modes
type PracticeMode string

const (
	ModeUntimed  PracticeMode = "UNTIMED"
	ModeTimed    PracticeMode = "TIMED"
	ModeSpeedRun PracticeMode = "SPEED_RUN"
	ModeAccuracy PracticeMode = "ACCURACY"
)

// PracticeSession represents an active or completed practice session
type PracticeSession struct {
	ID                 string       `json:"id" db:"id"`
	UserID             string       `json:"user_id" db:"user_id"`
	PuzzleID           string       `json:"puzzle_id" db:"puzzle_id"`
	CipherType         string       `json:"cipher_type" db:"cipher_type"`
	Difficulty         int          `json:"difficulty" db:"difficulty"`
	Mode               PracticeMode `json:"mode" db:"mode"`
	StartedAt          time.Time    `json:"started_at" db:"started_at"`
	SubmittedAt        *time.Time   `json:"submitted_at,omitempty" db:"submitted_at"`
	SolveTimeMs        *int64       `json:"solve_time_ms,omitempty" db:"solve_time_ms"`
	TimeLimitMs        *int64       `json:"time_limit_ms,omitempty" db:"time_limit_ms"`
	UserSolution       *string      `json:"user_solution,omitempty" db:"user_solution"`
	IsCorrect          *bool        `json:"is_correct,omitempty" db:"is_correct"`
	AccuracyPercentage *float64     `json:"accuracy_percentage,omitempty" db:"accuracy_percentage"`
	HintsUsed          int          `json:"hints_used" db:"hints_used"`
	Score              *int         `json:"score,omitempty" db:"score"`
	PerfectSolve       bool         `json:"perfect_solve" db:"perfect_solve"`
	Attempts           int          `json:"attempts" db:"attempts"`
}

// PersonalBest represents a user's best performance for a cipher/difficulty
type PersonalBest struct {
	ID                    string    `json:"id" db:"id"`
	UserID                string    `json:"user_id" db:"user_id"`
	CipherType            string    `json:"cipher_type" db:"cipher_type"`
	Difficulty            int       `json:"difficulty" db:"difficulty"`
	FastestSolveMs        int64     `json:"fastest_solve_ms" db:"fastest_solve_ms"`
	FastestSessionID      string    `json:"fastest_session_id" db:"fastest_session_id"`
	FastestAchievedAt     time.Time `json:"fastest_achieved_at" db:"fastest_achieved_at"`
	HighestScore          int       `json:"highest_score" db:"highest_score"`
	HighestScoreSessionID string    `json:"highest_score_session_id" db:"highest_score_session_id"`
	TotalPracticeSessions int       `json:"total_practice_sessions" db:"total_practice_sessions"`
	PerfectSolves         int       `json:"perfect_solves" db:"perfect_solves"`
	AverageSolveTimeMs    int64     `json:"average_solve_time_ms" db:"average_solve_time_ms"`
	UpdatedAt             time.Time `json:"updated_at" db:"updated_at"`
}

// PracticePuzzle represents a generated puzzle for practice
type PracticePuzzle struct {
	ID             string                 `json:"id"`
	CipherType     string                 `json:"cipher_type"`
	Difficulty     int                    `json:"difficulty"`
	EncryptedText  string                 `json:"encrypted_text"`
	Plaintext      string                 `json:"-"` // Not sent to client
	PlaintextHint  string                 `json:"plaintext_hint,omitempty"`
	Config         map[string]interface{} `json:"config"`
	HintsAvailable int                    `json:"hints_available"`
}

// SolutionFeedback represents feedback on a submitted solution
type SolutionFeedback struct {
	Message       string  `json:"message"`
	TimeRating    string  `json:"time_rating"`  // EXCELLENT, GOOD, AVERAGE, SLOW
	HintsRating   string  `json:"hints_rating"` // EXCELLENT, GOOD, AVERAGE, POOR
	CorrectAnswer *string `json:"correct_answer,omitempty"`
	YourAnswer    *string `json:"your_answer,omitempty"`
	CharacterDiff int     `json:"character_diff"`
}

// PersonalBestUpdate represents whether a new record was achieved
type PersonalBestUpdate struct {
	IsNewRecord       bool   `json:"is_new_record"`
	RecordType        string `json:"record_type,omitempty"` // FASTEST_TIME, HIGHEST_SCORE
	PreviousFastestMs *int64 `json:"previous_fastest_ms,omitempty"`
	ImprovementMs     *int64 `json:"improvement_ms,omitempty"`
}

// MasteryXPGained represents XP earned for cipher mastery
type MasteryXPGained struct {
	CipherType        string  `json:"cipher_type"`
	BaseXP            int     `json:"base_xp"`
	SpeedBonus        int     `json:"speed_bonus"`
	AccuracyBonus     int     `json:"accuracy_bonus"`
	MasteryMultiplier float64 `json:"mastery_multiplier"`
	TotalXP           int     `json:"total_xp"`
	NewMasteryXP      int     `json:"new_mastery_xp"`
	CurrentLevel      int     `json:"current_level"`
	LevelUp           bool    `json:"level_up"`
}

// GeneratePuzzleRequest is the request for generating a practice puzzle
type GeneratePuzzleRequest struct {
	CipherType       string `json:"cipher_type"`
	Difficulty       int    `json:"difficulty"`
	Mode             string `json:"mode"`
	TimeLimitSeconds *int   `json:"time_limit_seconds,omitempty"`
}

// SubmitSolutionRequest is the request for submitting a solution
type SubmitSolutionRequest struct {
	SessionID   string `json:"session_id"`
	Solution    string `json:"solution"`
	SolveTimeMs int64  `json:"solve_time_ms"`
	HintsUsed   int    `json:"hints_used"`
}
