package service

import (
	"context"
	"encoding/json"
	"fmt"
	"math/rand"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/pkg/cache"
	"github.com/swarit-1/cipher-clash/pkg/db"
	"github.com/swarit-1/cipher-clash/pkg/errors"
	"github.com/swarit-1/cipher-clash/pkg/logger"
	"github.com/swarit-1/cipher-clash/services/puzzle_engine/internal/ciphers"
)

// PuzzleService handles puzzle generation and validation
type PuzzleService struct {
	db    *db.DB
	cache *cache.Cache
	log   *logger.Logger
}

// NewPuzzleService creates a new puzzle service
func NewPuzzleService(database *db.DB, cacheClient *cache.Cache, log *logger.Logger) *PuzzleService {
	return &PuzzleService{
		db:    database,
		cache: cacheClient,
		log:   log,
	}
}

// Puzzle represents a puzzle
type Puzzle struct {
	ID            string                 `json:"id"`
	CipherType    string                 `json:"cipher_type"`
	Difficulty    int                    `json:"difficulty"`
	EncryptedText string                 `json:"encrypted_text"`
	Plaintext     string                 `json:"plaintext,omitempty"` // Only for server-side
	Config        map[string]interface{} `json:"config,omitempty"`
	Hint          string                 `json:"hint,omitempty"`
}

// GeneratePuzzleRequest represents puzzle generation input
type GeneratePuzzleRequest struct {
	CipherType string `json:"cipher_type"` // Empty for random
	Difficulty int    `json:"difficulty"`  // 1-10
	PlayerELO  int    `json:"player_elo"`  // For auto-difficulty
}

// ValidateSolutionRequest represents solution validation input
type ValidateSolutionRequest struct {
	PuzzleID  string `json:"puzzle_id"`
	Solution  string `json:"solution"`
	SolveTime int    `json:"solve_time_ms"`
}

// ValidateSolutionResponse represents validation result
type ValidateSolutionResponse struct {
	IsCorrect bool    `json:"is_correct"`
	Score     int     `json:"score"`
	Accuracy  float64 `json:"accuracy"`
}

// Sample plaintexts for puzzle generation
var sampleTexts = []string{
	"THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG",
	"CRYPTOGRAPHY IS THE ART OF SECURE COMMUNICATION",
	"HELLO WORLD THIS IS A SECRET MESSAGE",
	"NEVER GONNA GIVE YOU UP NEVER GONNA LET YOU DOWN",
	"TO BE OR NOT TO BE THAT IS THE QUESTION",
	"ALL YOUR BASE ARE BELONG TO US",
	"THE CAKE IS A LIE",
	"MAY THE FORCE BE WITH YOU",
	"I SEE DEAD PEOPLE",
	"SHOW ME THE MONEY",
	"WINTER IS COMING",
	"I AM YOUR FATHER",
	"ELEMENTARY MY DEAR WATSON",
	"HOUSTON WE HAVE A PROBLEM",
	"ET PHONE HOME",
}

// GeneratePuzzle creates a new puzzle
func (s *PuzzleService) GeneratePuzzle(ctx context.Context, req *GeneratePuzzleRequest) (*Puzzle, error) {
	// Auto-adjust difficulty based on ELO if difficulty is 0
	difficulty := req.Difficulty
	if difficulty == 0 && req.PlayerELO > 0 {
		difficulty = s.calculateDifficultyFromELO(req.PlayerELO)
	}
	if difficulty < 1 {
		difficulty = 1
	}
	if difficulty > 10 {
		difficulty = 10
	}

	// Select cipher type (random if not specified)
	cipherType := req.CipherType
	if cipherType == "" {
		allTypes := ciphers.GetAllCipherTypes()
		cipherType = allTypes[rand.Intn(len(allTypes))]
	}

	// Get cipher implementation
	cipher := ciphers.GetCipher(cipherType)
	if cipher == nil {
		return nil, errors.NewInvalidInputError(fmt.Sprintf("Invalid cipher type: %s", cipherType))
	}

	// Generate key based on difficulty
	config := cipher.GenerateKey(difficulty)

	// Select random plaintext
	plaintext := sampleTexts[rand.Intn(len(sampleTexts))]

	// Encrypt
	encryptedText, err := cipher.Encrypt(plaintext, config)
	if err != nil {
		return nil, errors.NewInternalServerError(err)
	}

	// Create puzzle
	puzzleID := uuid.New().String()
	puzzle := &Puzzle{
		ID:            puzzleID,
		CipherType:    cipherType,
		Difficulty:    difficulty,
		EncryptedText: encryptedText,
		Plaintext:     plaintext,
		Config:        config,
	}

	// Save to database
	if err := s.savePuzzle(ctx, puzzle); err != nil {
		s.log.Error("Failed to save puzzle", map[string]interface{}{
			"error": err.Error(),
		})
		// Continue anyway - puzzle can still be used
	}

	// Cache the puzzle for quick lookup
	cacheKey := fmt.Sprintf("puzzle:%s", puzzleID)
	s.cache.Set(ctx, cacheKey, puzzle, cache.TTLPuzzle)

	s.log.Info("Puzzle generated", map[string]interface{}{
		"puzzle_id":   puzzleID,
		"cipher_type": cipherType,
		"difficulty":  difficulty,
	})

	// Return puzzle without plaintext for client
	clientPuzzle := *puzzle
	clientPuzzle.Plaintext = "" // Don't send plaintext to client!
	clientPuzzle.Config = nil   // Don't send config to client!

	return &clientPuzzle, nil
}

// GenerateMultiplePuzzles creates multiple puzzles for a match
func (s *PuzzleService) GenerateMultiplePuzzles(ctx context.Context, count, minDiff, maxDiff, avgELO int, cipherTypes []string) ([]*Puzzle, error) {
	puzzles := make([]*Puzzle, 0, count)

	for i := 0; i < count; i++ {
		// Progressive difficulty
		difficulty := minDiff + ((maxDiff - minDiff) * i / count)

		// Select cipher type
		cipherType := ""
		if len(cipherTypes) > 0 {
			cipherType = cipherTypes[rand.Intn(len(cipherTypes))]
		}

		puzzle, err := s.GeneratePuzzle(ctx, &GeneratePuzzleRequest{
			CipherType: cipherType,
			Difficulty: difficulty,
			PlayerELO:  avgELO,
		})
		if err != nil {
			return nil, err
		}

		puzzles = append(puzzles, puzzle)
	}

	return puzzles, nil
}

// ValidateSolution validates a puzzle solution
func (s *PuzzleService) ValidateSolution(ctx context.Context, req *ValidateSolutionRequest) (*ValidateSolutionResponse, error) {
	// Get puzzle from cache or database
	puzzle, err := s.getPuzzle(ctx, req.PuzzleID)
	if err != nil {
		return nil, err
	}

	// Compare solutions (case-insensitive, trimmed)
	submittedSolution := normalizeText(req.Solution)
	correctSolution := normalizeText(puzzle.Plaintext)

	isCorrect := submittedSolution == correctSolution

	// Calculate score based on difficulty and solve time
	score := 0
	if isCorrect {
		baseScore := 100 * puzzle.Difficulty
		// Bonus for fast solving (max 2x multiplier)
		timeBonus := 1.0
		if req.SolveTime < 30000 { // Under 30 seconds
			timeBonus = 2.0
		} else if req.SolveTime < 60000 { // Under 1 minute
			timeBonus = 1.5
		}
		score = int(float64(baseScore) * timeBonus)
	}

	// Calculate accuracy (simple character match percentage)
	accuracy := calculateAccuracy(submittedSolution, correctSolution)

	// Update puzzle statistics
	go s.updatePuzzleStats(context.Background(), req.PuzzleID, isCorrect, req.SolveTime)

	s.log.Info("Solution validated", map[string]interface{}{
		"puzzle_id":  req.PuzzleID,
		"is_correct": isCorrect,
		"score":      score,
		"solve_time": req.SolveTime,
	})

	return &ValidateSolutionResponse{
		IsCorrect: isCorrect,
		Score:     score,
		Accuracy:  accuracy,
	}, nil
}

// GetPuzzle retrieves a puzzle by ID
func (s *PuzzleService) GetPuzzle(ctx context.Context, puzzleID string) (*Puzzle, error) {
	puzzle, err := s.getPuzzle(ctx, puzzleID)
	if err != nil {
		return nil, err
	}

	// Return without plaintext
	clientPuzzle := *puzzle
	clientPuzzle.Plaintext = ""
	clientPuzzle.Config = nil

	return &clientPuzzle, nil
}

// Helper functions

func (s *PuzzleService) calculateDifficultyFromELO(elo int) int {
	// ELO to difficulty mapping
	// 1200 (starting) -> difficulty 3
	// 1400 -> 4
	// 1600 -> 5
	// etc.
	if elo < 1200 {
		return 1
	}
	difficulty := ((elo - 1200) / 200) + 3
	if difficulty > 10 {
		difficulty = 10
	}
	return difficulty
}

func (s *PuzzleService) savePuzzle(ctx context.Context, puzzle *Puzzle) error {
	configJSON, err := json.Marshal(puzzle.Config)
	if err != nil {
		return err
	}

	query := `
		INSERT INTO puzzles (id, cipher_type, difficulty, encrypted_text, plaintext, config)
		VALUES ($1, $2, $3, $4, $5, $6)
	`
	_, err = s.db.ExecContext(ctx, query,
		puzzle.ID,
		puzzle.CipherType,
		puzzle.Difficulty,
		puzzle.EncryptedText,
		puzzle.Plaintext,
		configJSON,
	)
	return err
}

func (s *PuzzleService) getPuzzle(ctx context.Context, puzzleID string) (*Puzzle, error) {
	// Try cache first
	cacheKey := fmt.Sprintf("puzzle:%s", puzzleID)
	var cachedPuzzle Puzzle
	if err := s.cache.Get(ctx, cacheKey, &cachedPuzzle); err == nil {
		return &cachedPuzzle, nil
	}

	// Fetch from database
	var puzzle Puzzle
	var configJSON []byte

	query := `
		SELECT id, cipher_type, difficulty, encrypted_text, plaintext, config
		FROM puzzles
		WHERE id = $1
	`
	err := s.db.QueryRowContext(ctx, query, puzzleID).Scan(
		&puzzle.ID,
		&puzzle.CipherType,
		&puzzle.Difficulty,
		&puzzle.EncryptedText,
		&puzzle.Plaintext,
		&configJSON,
	)
	if err != nil {
		return nil, errors.NewPuzzleNotFoundError()
	}

	// Parse config
	if err := json.Unmarshal(configJSON, &puzzle.Config); err != nil {
		s.log.Error("Failed to parse puzzle config", map[string]interface{}{
			"error": err.Error(),
		})
	}

	// Cache for future requests
	s.cache.Set(ctx, cacheKey, &puzzle, cache.TTLPuzzle)

	return &puzzle, nil
}

func (s *PuzzleService) updatePuzzleStats(ctx context.Context, puzzleID string, solved bool, solveTime int) {
	query := `
		UPDATE puzzles
		SET
			times_used = times_used + 1,
			times_solved = times_solved + CASE WHEN $2 THEN 1 ELSE 0 END,
			avg_solve_time_ms = CASE
				WHEN times_solved = 0 THEN $3
				ELSE (avg_solve_time_ms * times_solved + $3) / (times_solved + 1)
			END,
			success_rate = CASE
				WHEN times_used = 0 THEN CASE WHEN $2 THEN 1.0 ELSE 0.0 END
				ELSE (times_solved::FLOAT + CASE WHEN $2 THEN 1 ELSE 0 END) / (times_used + 1)
			END
		WHERE id = $1
	`
	if _, err := s.db.ExecContext(ctx, query, puzzleID, solved, solveTime); err != nil {
		s.log.Error("Failed to update puzzle stats", map[string]interface{}{
			"error": err.Error(),
		})
	}
}

func normalizeText(text string) string {
	// Remove spaces, convert to uppercase
	result := ""
	for _, char := range text {
		if char != ' ' && char != '\n' && char != '\r' && char != '\t' {
			if char >= 'a' && char <= 'z' {
				result += string(char - 32)
			} else {
				result += string(char)
			}
		}
	}
	return result
}

func calculateAccuracy(submitted, correct string) float64 {
	if len(correct) == 0 {
		return 0.0
	}

	matches := 0
	maxLen := len(submitted)
	if len(correct) < maxLen {
		maxLen = len(correct)
	}

	for i := 0; i < maxLen; i++ {
		if submitted[i] == correct[i] {
			matches++
		}
	}

	return float64(matches) / float64(len(correct))
}
