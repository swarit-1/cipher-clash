package service

import (
	"math"
	"strings"
)

type ScoringService struct{}

func NewScoringService() *ScoringService {
	return &ScoringService{}
}

// CalculateScore calculates score based on time, accuracy, hints, and difficulty
func (s *ScoringService) CalculateScore(solveTimeMs int64, difficulty int, hintsUsed int, accuracyPct float64, timeLimitMs int64) int {
	baseScore := float64(difficulty * 100)

	// Time multiplier (faster = higher score)
	timeMultiplier := 1.0
	if timeLimitMs > 0 {
		timeRatio := float64(solveTimeMs) / float64(timeLimitMs)
		timeMultiplier = math.Max(0.5, 2.0-timeRatio) // 0.5x to 2.0x
	} else {
		// For untimed, use difficulty-based target times
		targetTime := int64(difficulty * 30000) // 30s per difficulty level
		timeRatio := float64(solveTimeMs) / float64(targetTime)
		timeMultiplier = math.Max(0.5, 1.5-timeRatio*0.5)
	}

	// Accuracy multiplier
	accuracyMultiplier := accuracyPct / 100.0

	// Hint penalty
	hintPenalty := math.Pow(0.9, float64(hintsUsed)) // 10% penalty per hint

	score := baseScore * timeMultiplier * accuracyMultiplier * hintPenalty

	return int(math.Round(score))
}

// GetTimeRating returns a rating for solve time
func (s *ScoringService) GetTimeRating(solveTimeMs int64, difficulty int, timeLimitMs int64) string {
	targetTime := int64(difficulty * 20000) // 20s per difficulty level
	if timeLimitMs > 0 {
		targetTime = timeLimitMs / 2 // Half of time limit is "good"
	}

	if solveTimeMs <= targetTime {
		return "EXCELLENT"
	} else if solveTimeMs <= targetTime*2 {
		return "GOOD"
	} else if solveTimeMs <= targetTime*3 {
		return "AVERAGE"
	}
	return "SLOW"
}

// GetHintsRating returns a rating for hint usage
func (s *ScoringService) GetHintsRating(hintsUsed int) string {
	switch hintsUsed {
	case 0:
		return "EXCELLENT"
	case 1:
		return "GOOD"
	case 2:
		return "AVERAGE"
	default:
		return "POOR"
	}
}

// IsPerfectSolve determines if solve is perfect
func (s *ScoringService) IsPerfectSolve(hintsUsed int, accuracyPct float64, solveTimeMs int64, difficulty int) bool {
	targetTime := int64(difficulty * 30000)
	return hintsUsed == 0 && accuracyPct == 100.0 && solveTimeMs <= targetTime
}

// CalculateAccuracy calculates accuracy percentage between two strings
func (s *ScoringService) CalculateAccuracy(expected, actual string) (float64, int) {
	expected = strings.ToUpper(strings.TrimSpace(expected))
	actual = strings.ToUpper(strings.TrimSpace(actual))

	if expected == actual {
		return 100.0, 0
	}

	// Calculate Levenshtein distance
	diff := s.levenshteinDistance(expected, actual)
	maxLen := math.Max(float64(len(expected)), float64(len(actual)))

	if maxLen == 0 {
		return 0.0, 0
	}

	accuracy := (1.0 - float64(diff)/maxLen) * 100.0
	accuracy = math.Max(0, accuracy)

	return accuracy, diff
}

// levenshteinDistance calculates the edit distance between two strings
func (s *ScoringService) levenshteinDistance(s1, s2 string) int {
	if len(s1) == 0 {
		return len(s2)
	}
	if len(s2) == 0 {
		return len(s1)
	}

	matrix := make([][]int, len(s1)+1)
	for i := range matrix {
		matrix[i] = make([]int, len(s2)+1)
		matrix[i][0] = i
	}
	for j := range matrix[0] {
		matrix[0][j] = j
	}

	for i := 1; i <= len(s1); i++ {
		for j := 1; j <= len(s2); j++ {
			cost := 0
			if s1[i-1] != s2[j-1] {
				cost = 1
			}

			matrix[i][j] = min(
				matrix[i-1][j]+1,      // deletion
				matrix[i][j-1]+1,      // insertion
				matrix[i-1][j-1]+cost, // substitution
			)
		}
	}

	return matrix[len(s1)][len(s2)]
}

func min(a, b, c int) int {
	if a < b {
		if a < c {
			return a
		}
		return c
	}
	if b < c {
		return b
	}
	return c
}
