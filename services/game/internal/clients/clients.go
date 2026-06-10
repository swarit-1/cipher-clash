// Package clients holds the game service's HTTP clients for sibling
// services (puzzle engine, matchmaker). All calls carry the shared
// X-Internal-Token.
package clients

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"

	"github.com/swarit-1/cipher-clash/services/game/internal/room"
)

const requestTimeout = 10 * time.Second

// PuzzleClient fetches match puzzle sets from the puzzle engine.
type PuzzleClient struct {
	baseURL       string
	internalToken string
	http          *http.Client
}

// NewPuzzleClient creates a PuzzleClient.
func NewPuzzleClient(baseURL, internalToken string) *PuzzleClient {
	return &PuzzleClient{
		baseURL:       baseURL,
		internalToken: internalToken,
		http:          &http.Client{Timeout: requestTimeout},
	}
}

// MatchSet returns count puzzles (with solutions) scaled to avgELO.
func (c *PuzzleClient) MatchSet(ctx context.Context, count, avgELO int) ([]room.Puzzle, error) {
	body, _ := json.Marshal(map[string]int{"count": count, "player_elo": avgELO})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.baseURL+"/internal/v1/puzzle/match-set", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Token", c.internalToken)

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("puzzle engine unreachable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("puzzle engine returned %d", resp.StatusCode)
	}

	var out struct {
		Puzzles []struct {
			ID            string `json:"id"`
			CipherType    string `json:"cipher_type"`
			Difficulty    int    `json:"difficulty"`
			EncryptedText string `json:"encrypted_text"`
			Plaintext     string `json:"plaintext"`
		} `json:"puzzles"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&out); err != nil {
		return nil, fmt.Errorf("decode puzzle set: %w", err)
	}
	if len(out.Puzzles) == 0 {
		return nil, fmt.Errorf("puzzle engine returned empty set")
	}

	puzzles := make([]room.Puzzle, len(out.Puzzles))
	for i, p := range out.Puzzles {
		puzzles[i] = room.Puzzle{
			ID:            p.ID,
			CipherType:    p.CipherType,
			Difficulty:    p.Difficulty,
			EncryptedText: p.EncryptedText,
			Plaintext:     p.Plaintext,
		}
	}
	return puzzles, nil
}

// RatingsClient applies ELO updates via the matchmaker.
type RatingsClient struct {
	baseURL       string
	internalToken string
	http          *http.Client
}

// NewRatingsClient creates a RatingsClient.
func NewRatingsClient(baseURL, internalToken string) *RatingsClient {
	return &RatingsClient{
		baseURL:       baseURL,
		internalToken: internalToken,
		http:          &http.Client{Timeout: requestTimeout},
	}
}

// RatingResult mirrors the matchmaker's response.
type RatingResult struct {
	Player1ID     string `json:"player1_id"`
	Player2ID     string `json:"player2_id"`
	Player1Change int    `json:"player1_change"`
	Player2Change int    `json:"player2_change"`
	Player1New    int    `json:"player1_new"`
	Player2New    int    `json:"player2_new"`
}

// UpdateRatings applies the ELO update for a finished ranked match.
func (c *RatingsClient) UpdateRatings(ctx context.Context, matchID, winnerID, player1ID, player2ID string) (*RatingResult, error) {
	body, _ := json.Marshal(map[string]string{
		"match_id":   matchID,
		"winner_id":  winnerID,
		"player1_id": player1ID,
		"player2_id": player2ID,
	})
	req, err := http.NewRequestWithContext(ctx, http.MethodPost,
		c.baseURL+"/internal/v1/ratings/update", bytes.NewReader(body))
	if err != nil {
		return nil, err
	}
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("X-Internal-Token", c.internalToken)

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("matchmaker unreachable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("matchmaker returned %d", resp.StatusCode)
	}

	var result RatingResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("decode rating result: %w", err)
	}
	return &result, nil
}
