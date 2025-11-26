package internal

import "time"

// TutorialStep represents a single step in the tutorial
type TutorialStep struct {
	ID          string    `json:"id" db:"id"`
	StepNumber  int       `json:"step_number" db:"step_number"`
	Title       string    `json:"title" db:"title"`
	Description string    `json:"description" db:"description"`
	Type        string    `json:"type" db:"type"` // INTERACTIVE, VIDEO, TEXT, QUIZ, PRACTICE
	Content     string    `json:"content" db:"content"` // JSON content based on type
	CipherType  *string   `json:"cipher_type,omitempty" db:"cipher_type"` // For cipher-specific tutorials
	Required    bool      `json:"required" db:"required"`
	OrderIndex  int       `json:"order_index" db:"order_index"`
	CreatedAt   time.Time `json:"created_at" db:"created_at"`
	UpdatedAt   time.Time `json:"updated_at" db:"updated_at"`
}

// UserProgress represents a user's progress through the tutorial
type UserProgress struct {
	ID             string     `json:"id" db:"id"`
	UserID         string     `json:"user_id" db:"user_id"`
	StepID         string     `json:"step_id" db:"step_id"`
	Completed      bool       `json:"completed" db:"completed"`
	CompletedAt    *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	TimeSpentSecs  int        `json:"time_spent_secs" db:"time_spent_secs"`
	Score          *int       `json:"score,omitempty" db:"score"` // For quizzes/practice
	CreatedAt      time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at" db:"updated_at"`
}

// TutorialStepWithProgress combines step and user progress
type TutorialStepWithProgress struct {
	TutorialStep
	Completed     bool       `json:"completed"`
	CompletedAt   *time.Time `json:"completed_at,omitempty"`
	TimeSpentSecs int        `json:"time_spent_secs"`
	Score         *int       `json:"score,omitempty"`
}

// UserTutorialStats represents overall tutorial statistics for a user
type UserTutorialStats struct {
	UserID             string  `json:"user_id"`
	TotalSteps         int     `json:"total_steps"`
	CompletedSteps     int     `json:"completed_steps"`
	CompletionRate     float64 `json:"completion_rate"` // Percentage
	TotalTimeSpentSecs int     `json:"total_time_spent_secs"`
	TutorialCompleted  bool    `json:"tutorial_completed"` // All required steps done
}

// UpdateProgressRequest represents a request to update tutorial progress
type UpdateProgressRequest struct {
	UserID        string `json:"user_id" validate:"required,uuid"`
	StepID        string `json:"step_id" validate:"required,uuid"`
	TimeSpentSecs int    `json:"time_spent_secs" validate:"min=0"`
	Score         *int   `json:"score,omitempty" validate:"omitempty,min=0,max=100"`
}

// CompleteStepRequest represents a request to complete a tutorial step
type CompleteStepRequest struct {
	UserID        string `json:"user_id" validate:"required,uuid"`
	StepID        string `json:"step_id" validate:"required,uuid"`
	TimeSpentSecs int    `json:"time_spent_secs" validate:"min=0"`
	Score         *int   `json:"score,omitempty" validate:"omitempty,min=0,max=100"`
}

// SkipTutorialRequest represents a request to skip the entire tutorial
type SkipTutorialRequest struct {
	UserID string `json:"user_id" validate:"required,uuid"`
}

// CipherVisualization represents visualization data for a cipher
type CipherVisualization struct {
	CipherType  string                 `json:"cipher_type"`
	Steps       []VisualizationStep    `json:"steps"`
	Example     CipherExample          `json:"example"`
	Interactive bool                   `json:"interactive"`
	Metadata    map[string]interface{} `json:"metadata"`
}

// VisualizationStep represents a single step in cipher visualization
type VisualizationStep struct {
	StepNumber  int                    `json:"step_number"`
	Title       string                 `json:"title"`
	Description string                 `json:"description"`
	Input       string                 `json:"input"`
	Output      string                 `json:"output"`
	Explanation string                 `json:"explanation"`
	Highlight   []int                  `json:"highlight,omitempty"` // Character positions to highlight
	Metadata    map[string]interface{} `json:"metadata,omitempty"`
}

// CipherExample represents an example for cipher visualization
type CipherExample struct {
	PlainText  string `json:"plain_text"`
	CipherText string `json:"cipher_text"`
	Key        string `json:"key,omitempty"`
	Difficulty int    `json:"difficulty"`
}

// BotBattle represents a practice battle against a bot (first match)
type BotBattle struct {
	ID              string     `json:"id" db:"id"`
	UserID          string     `json:"user_id" db:"user_id"`
	PuzzleID        string     `json:"puzzle_id" db:"puzzle_id"`
	CipherType      string     `json:"cipher_type" db:"cipher_type"`
	Difficulty      int        `json:"difficulty" db:"difficulty"`
	StartedAt       time.Time  `json:"started_at" db:"started_at"`
	CompletedAt     *time.Time `json:"completed_at,omitempty" db:"completed_at"`
	Won             *bool      `json:"won,omitempty" db:"won"`
	UserSolveTime   *int       `json:"user_solve_time,omitempty" db:"user_solve_time"` // seconds
	BotSolveTime    int        `json:"bot_solve_time" db:"bot_solve_time"` // seconds
	Score           *int       `json:"score,omitempty" db:"score"`
	CreatedAt       time.Time  `json:"created_at" db:"created_at"`
	UpdatedAt       time.Time  `json:"updated_at" db:"updated_at"`
}

// StartBotBattleRequest represents a request to start a bot battle
type StartBotBattleRequest struct {
	UserID     string `json:"user_id" validate:"required,uuid"`
	CipherType string `json:"cipher_type" validate:"required"`
	Difficulty int    `json:"difficulty" validate:"required,min=1,max=10"`
}

// SubmitBotBattleSolutionRequest represents a request to submit bot battle solution
type SubmitBotBattleSolutionRequest struct {
	BattleID     string `json:"battle_id" validate:"required,uuid"`
	UserID       string `json:"user_id" validate:"required,uuid"`
	Solution     string `json:"solution" validate:"required"`
	SolveTimeSec int    `json:"solve_time_sec" validate:"required,min=1"`
}
