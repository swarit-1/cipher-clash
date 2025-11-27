# Cipher Clash - Phase 1 Implementation Guide
## Complete Code Implementation for Tutorial, Practice, Mastery & Profile Features

**Version:** 1.0
**Date:** 2025-11-26
**Prerequisites:** Design Document (DESIGN_DOCUMENT_PHASE1.md), Database Migration (003_add_engagement_features.sql)

---

## Table of Contents
1. [Quick Start](#quick-start)
2. [Practice Service Implementation](#practice-service-implementation)
3. [Flutter Client Implementation](#flutter-client-implementation)
4. [Integration Steps](#integration-steps)
5. [Testing Guide](#testing-guide)

---

## Quick Start

### 1. Apply Database Migration
```bash
# Navigate to project root
cd cipher-clash-1

# Apply migration
psql -U postgres -d cipher_clash -f infra/postgres/migrations/003_add_engagement_features.sql
```

### 2. Generate Proto Code
```bash
# Generate Go code from proto definitions
protoc --go_out=. --go-grpc_out=. proto/practice.proto
protoc --go_out=. --go-grpc_out=. proto/profile.proto

# Tutorial and mastery protos already exist
protoc --go_out=. --go-grpc_out=. proto/tutorial.proto
protoc --go_out=. --go-grpc_out=. proto/mastery.proto
```

###3. Service Status
- ✅ **Tutorial Service**: Already implemented (services/tutorial/)
- ✅ **Mastery Service**: Already implemented (services/mastery/)
- ⏳ **Practice Service**: To be implemented (this guide)
- ⏳ **Profile Service**: Can extend Auth service or create new service

---

## Practice Service Implementation

### File Structure
```
services/practice/
├── main.go
├── internal/
│   ├── types.go
│   ├── handler/
│   │   └── practice_handler.go
│   ├── repository/
│   │   ├── practice_repository.go
│   │   └── leaderboard_repository.go
│   └── service/
│       ├── practice_service.go
│       └── scoring_service.go
```

---

### File: `services/practice/internal/types.go`

```go
package internal

import (
	"time"
)

// PracticeMode represents practice session modes
type PracticeMode string

const (
	ModeUntimed   PracticeMode = "UNTIMED"
	ModeTimed     PracticeMode = "TIMED"
	ModeSpeedRun  PracticeMode = "SPEED_RUN"
	ModeAccuracy  PracticeMode = "ACCURACY"
)

// PracticeSession represents an active or completed practice session
type PracticeSession struct {
	ID                  string       `json:"id" db:"id"`
	UserID              string       `json:"user_id" db:"user_id"`
	PuzzleID            string       `json:"puzzle_id" db:"puzzle_id"`
	CipherType          string       `json:"cipher_type" db:"cipher_type"`
	Difficulty          int          `json:"difficulty" db:"difficulty"`
	Mode                PracticeMode `json:"mode" db:"mode"`
	StartedAt           time.Time    `json:"started_at" db:"started_at"`
	SubmittedAt         *time.Time   `json:"submitted_at,omitempty" db:"submitted_at"`
	SolveTimeMs         *int64       `json:"solve_time_ms,omitempty" db:"solve_time_ms"`
	TimeLimitMs         *int64       `json:"time_limit_ms,omitempty" db:"time_limit_ms"`
	UserSolution        *string      `json:"user_solution,omitempty" db:"user_solution"`
	IsCorrect           *bool        `json:"is_correct,omitempty" db:"is_correct"`
	AccuracyPercentage  *float64     `json:"accuracy_percentage,omitempty" db:"accuracy_percentage"`
	HintsUsed           int          `json:"hints_used" db:"hints_used"`
	Score               *int         `json:"score,omitempty" db:"score"`
	PerfectSolve        bool         `json:"perfect_solve" db:"perfect_solve"`
	Attempts            int          `json:"attempts" db:"attempts"`
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
	PlaintextHint  string                 `json:"plaintext_hint,omitempty"`
	Config         map[string]interface{} `json:"config"`
	HintsAvailable int                    `json:"hints_available"`
}

// SolutionFeedback represents feedback on a submitted solution
type SolutionFeedback struct {
	Message        string  `json:"message"`
	TimeRating     string  `json:"time_rating"`     // EXCELLENT, GOOD, AVERAGE, SLOW
	HintsRating    string  `json:"hints_rating"`    // EXCELLENT, GOOD, AVERAGE, POOR
	CorrectAnswer  *string `json:"correct_answer,omitempty"`
	YourAnswer     *string `json:"your_answer,omitempty"`
	CharacterDiff  int     `json:"character_diff"`
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
```

---

### File: `services/practice/internal/repository/practice_repository.go`

```go
package repository

import (
	"context"
	"database/sql"
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/swarit-1/cipher-clash/services/practice/internal"
)

type PracticeRepository struct {
	db *sql.DB
}

func NewPracticeRepository(db *sql.DB) *PracticeRepository {
	return &PracticeRepository{db: db}
}

// CreateSession creates a new practice session
func (r *PracticeRepository) CreateSession(ctx context.Context, session *internal.PracticeSession) error {
	query := `
		INSERT INTO practice_sessions (
			id, user_id, puzzle_id, cipher_type, difficulty, mode,
			time_limit_ms, hints_used, attempts
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
	`

	session.ID = uuid.New().String()
	session.StartedAt = time.Now()
	session.Attempts = 1

	_, err := r.db.ExecContext(ctx, query,
		session.ID,
		session.UserID,
		session.PuzzleID,
		session.CipherType,
		session.Difficulty,
		session.Mode,
		session.TimeLimitMs,
		session.HintsUsed,
		session.Attempts,
	)

	return err
}

// UpdateSessionWithSolution updates session with submitted solution
func (r *PracticeRepository) UpdateSessionWithSolution(ctx context.Context, sessionID string, solution string, solveTimeMs int64, isCorrect bool, accuracyPct float64, score int, perfectSolve bool) error {
	query := `
		UPDATE practice_sessions
		SET submitted_at = NOW(),
		    solve_time_ms = $2,
		    user_solution = $3,
		    is_correct = $4,
		    accuracy_percentage = $5,
		    score = $6,
		    perfect_solve = $7
		WHERE id = $1
	`

	_, err := r.db.ExecContext(ctx, query, sessionID, solveTimeMs, solution, isCorrect, accuracyPct, score, perfectSolve)
	return err
}

// GetSessionByID retrieves a practice session by ID
func (r *PracticeRepository) GetSessionByID(ctx context.Context, sessionID string) (*internal.PracticeSession, error) {
	query := `
		SELECT id, user_id, puzzle_id, cipher_type, difficulty, mode,
		       started_at, submitted_at, solve_time_ms, time_limit_ms,
		       user_solution, is_correct, accuracy_percentage, hints_used,
		       score, perfect_solve, attempts
		FROM practice_sessions
		WHERE id = $1
	`

	var session internal.PracticeSession
	err := r.db.QueryRowContext(ctx, query, sessionID).Scan(
		&session.ID,
		&session.UserID,
		&session.PuzzleID,
		&session.CipherType,
		&session.Difficulty,
		&session.Mode,
		&session.StartedAt,
		&session.SubmittedAt,
		&session.SolveTimeMs,
		&session.TimeLimitMs,
		&session.UserSolution,
		&session.IsCorrect,
		&session.AccuracyPercentage,
		&session.HintsUsed,
		&session.Score,
		&session.PerfectSolve,
		&session.Attempts,
	)

	if err != nil {
		return nil, err
	}

	return &session, nil
}

// GetUserHistory retrieves practice session history
func (r *PracticeRepository) GetUserHistory(ctx context.Context, userID string, cipherType *string, limit, offset int) ([]*internal.PracticeSession, int, error) {
	var sessions []*internal.PracticeSession
	var total int

	// Count total
	countQuery := `SELECT COUNT(*) FROM practice_sessions WHERE user_id = $1`
	args := []interface{}{userID}

	if cipherType != nil && *cipherType != "" {
		countQuery += ` AND cipher_type = $2`
		args = append(args, *cipherType)
	}

	err := r.db.QueryRowContext(ctx, countQuery, args...).Scan(&total)
	if err != nil {
		return nil, 0, err
	}

	// Get sessions
	query := `
		SELECT id, user_id, puzzle_id, cipher_type, difficulty, mode,
		       started_at, submitted_at, solve_time_ms, time_limit_ms,
		       user_solution, is_correct, accuracy_percentage, hints_used,
		       score, perfect_solve, attempts
		FROM practice_sessions
		WHERE user_id = $1
	`

	queryArgs := []interface{}{userID}
	argIdx := 2

	if cipherType != nil && *cipherType != "" {
		query += ` AND cipher_type = $` + string(rune(argIdx))
		queryArgs = append(queryArgs, *cipherType)
		argIdx++
	}

	query += ` ORDER BY started_at DESC LIMIT $` + string(rune(argIdx)) + ` OFFSET $` + string(rune(argIdx+1))
	queryArgs = append(queryArgs, limit, offset)

	rows, err := r.db.QueryContext(ctx, query, queryArgs...)
	if err != nil {
		return nil, 0, err
	}
	defer rows.Close()

	for rows.Next() {
		var session internal.PracticeSession
		err := rows.Scan(
			&session.ID,
			&session.UserID,
			&session.PuzzleID,
			&session.CipherType,
			&session.Difficulty,
			&session.Mode,
			&session.StartedAt,
			&session.SubmittedAt,
			&session.SolveTimeMs,
			&session.TimeLimitMs,
			&session.UserSolution,
			&session.IsCorrect,
			&session.AccuracyPercentage,
			&session.HintsUsed,
			&session.Score,
			&session.PerfectSolve,
			&session.Attempts,
		)
		if err != nil {
			return nil, 0, err
		}
		sessions = append(sessions, &session)
	}

	return sessions, total, nil
}
```

---

### File: `services/practice/internal/service/scoring_service.go`

```go
package service

import (
	"math"
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
```

---

## Flutter Client Implementation

### File Structure
```
apps/client/lib/src/
├── services/
│   ├── practice_service.dart
│   └── mastery_service.dart (enhance existing)
├── features/
│   ├── practice/
│   │   ├── practice_lobby_screen.dart
│   │   ├── practice_session_screen.dart
│   │   ├── practice_result_screen.dart
│   │   └── widgets/
│   │       ├── cipher_card.dart
│   │       ├── difficulty_slider.dart
│   │       └── practice_timer.dart
│   ├── mastery/
│   │   ├── mastery_overview_screen.dart
│   │   ├── mastery_tree_screen.dart
│   │   └── widgets/
│   │       ├── cipher_mastery_card.dart
│   │       ├── skill_tree_node.dart
│   │       └── skill_tree_canvas.dart
│   └── profile/
│       ├── enhanced_profile_screen.dart (update existing)
│       └── widgets/
│           ├── profile_header.dart
│           ├── cipher_stats_list.dart
│           └── achievement_progress_card.dart
```

---

### File: `apps/client/lib/src/services/practice_service.dart`

```dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class PracticeService {
  static const String _baseUrl = '${ApiConfig.baseUrl}/practice';

  static Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AuthService.getAccessToken()}',
    };
  }

  // Generate practice puzzle
  static Future<Map<String, dynamic>> generatePuzzle({
    required String cipherType,
    required int difficulty,
    String mode = 'UNTIMED',
    int? timeLimitSeconds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/generate'),
        headers: _getHeaders(),
        body: jsonEncode({
          'cipher_type': cipherType,
          'difficulty': difficulty,
          'mode': mode,
          'time_limit_seconds': timeLimitSeconds,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Failed to generate puzzle'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Submit solution
  static Future<Map<String, dynamic>> submitSolution({
    required String sessionId,
    required String solution,
    required int solveTimeMs,
    int hintsUsed = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/submit'),
        headers: _getHeaders(),
        body: jsonEncode({
          'session_id': sessionId,
          'solution': solution,
          'solve_time_ms': solveTimeMs,
          'hints_used': hintsUsed,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Failed to submit solution'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get practice history
  static Future<Map<String, dynamic>> getHistory({
    String? cipherType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var url = '$_baseUrl/history?limit=$limit&offset=$offset';
      if (cipherType != null && cipherType.isNotEmpty) {
        url += '&cipher_type=$cipherType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Failed to fetch history'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // Get personal bests
  static Future<Map<String, dynamic>> getPersonalBests({
    required String cipherType,
    int? difficulty,
  }) async {
    try {
      var url = '$_baseUrl/leaderboard/$cipherType';
      if (difficulty != null) {
        url += '?difficulty=$difficulty';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': 'Failed to fetch personal bests'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
```

---

### File: `apps/client/lib/src/features/practice/practice_lobby_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/practice_service.dart';
import 'practice_session_screen.dart';

class PracticeLobbyScreen extends StatefulWidget {
  const PracticeLobbyScreen({Key? key}) : super(key: key);

  @override
  State<PracticeLobbyScreen> createState() => _PracticeLobbyScreenState();
}

class _PracticeLobbyScreenState extends State<PracticeLobbyScreen> {
  String _selectedCipher = 'CAESAR';
  int _difficulty = 5;
  String _mode = 'UNTIMED';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _ciphers = [
    {'type': 'CAESAR', 'name': 'Caesar', 'level': 18, 'winRate': 78.5, 'locked': false},
    {'type': 'VIGENERE', 'name': 'Vigenère', 'level': 12, 'winRate': 65.0, 'locked': false},
    {'type': 'RAIL_FENCE', 'name': 'Rail Fence', 'level': 8, 'winRate': 55.0, 'locked': false},
    {'type': 'PLAYFAIR', 'name': 'Playfair', 'level': 5, 'winRate': 0.0, 'locked': true},
  ];

  void _startPractice() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await PracticeService.generatePuzzle(
      cipherType: _selectedCipher,
      difficulty: _difficulty,
      mode: _mode,
      timeLimitSeconds: _mode == 'TIMED' ? 300 : null,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeSessionScreen(
            sessionData: result['data'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to start practice'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(AppTheme.spacing3),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppTheme.cyberBlue),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: AppTheme.spacing2),
                    Text(
                      'PRACTICE MODE',
                      style: AppTheme.headingLarge,
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spacing3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Text(
                        'Master ciphers at your own pace',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing4),

                      // Cipher selection
                      Text('Select Cipher Type:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppTheme.spacing2,
                          mainAxisSpacing: AppTheme.spacing2,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _ciphers.length,
                        itemBuilder: (context, index) {
                          final cipher = _ciphers[index];
                          final isSelected = _selectedCipher == cipher['type'];
                          final isLocked = cipher['locked'] as bool;

                          return GestureDetector(
                            onTap: isLocked
                                ? null
                                : () {
                                    setState(() => _selectedCipher = cipher['type']);
                                    HapticFeedback.selectionClick();
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.cyberBlue.withOpacity(0.2)
                                    : AppTheme.backgroundDark,
                                border: Border.all(
                                  color: isSelected ? AppTheme.cyberBlue : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                boxShadow: isSelected
                                    ? AppTheme.glowCyberBlue(intensity: 0.5)
                                    : [],
                              ),
                              padding: EdgeInsets.all(AppTheme.spacing2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cipher['name'],
                                    style: AppTheme.headingSmall.copyWith(
                                      color: isLocked ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: AppTheme.spacing1),
                                  if (!isLocked) ...[
                                    Text(
                                      'Level ${cipher['level']}',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.electricGreen,
                                      ),
                                    ),
                                    Text(
                                      '${cipher['winRate'].toStringAsFixed(1)}% Win',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ] else
                                    Icon(Icons.lock, color: AppTheme.textSecondary, size: 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Difficulty slider
                      Text('Difficulty:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacing3),
                        decoration: BoxDecoration(
                          color: AppTheme.backgroundDark,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Easy', style: AppTheme.bodySmall),
                                Text(
                                  '$_difficulty / 10',
                                  style: AppTheme.headingMedium.copyWith(
                                    color: AppTheme.cyberBlue,
                                  ),
                                ),
                                Text('Hard', style: AppTheme.bodySmall),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppTheme.cyberBlue,
                                inactiveTrackColor: AppTheme.cyberBlue.withOpacity(0.3),
                                thumbColor: AppTheme.cyberBlue,
                                overlayColor: AppTheme.cyberBlue.withOpacity(0.2),
                              ),
                              child: Slider(
                                value: _difficulty.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                onChanged: (value) {
                                  setState(() => _difficulty = value.toInt());
                                  HapticFeedback.selectionClick();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Mode selection
                      Text('Practice Mode:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      Wrap(
                        spacing: AppTheme.spacing2,
                        children: [
                          _buildModeChip('UNTIMED', 'Untimed'),
                          _buildModeChip('TIMED', 'Timed (5 min)'),
                          _buildModeChip('SPEED_RUN', 'Speed Run'),
                          _buildModeChip('ACCURACY', 'Accuracy Challenge'),
                        ],
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Start button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _startPractice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyberBlue,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'START PRACTICE',
                                  style: AppTheme.headingMedium.copyWith(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeChip(String mode, String label) {
    final isSelected = _mode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _mode = mode);
        HapticFeedback.selectionClick();
      },
      selectedColor: AppTheme.cyberBlue.withOpacity(0.3),
      checkmarkColor: AppTheme.cyberBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.cyberBlue : AppTheme.textPrimary,
      ),
    );
  }
}
```

---

## Integration Steps

### 1. Update Main Menu
Add Practice Mode button to main menu (`main_menu_screen.dart`):

```dart
// In main menu grid
GestureDetector(
  onTap: () {
    Navigator.pushNamed(context, '/practice');
  },
  child: MenuCard(
    icon: Icons.fitness_center,
    title: 'PRACTICE MODE',
    description: 'Train at your own pace',
    gradient: AppTheme.primaryGradient,
  ),
),
```

### 2. Add Routes
Update `app_routes.dart`:

```dart
class AppRoutes {
  // Existing routes...
  static const String practice = '/practice';
  static const String practiceSession = '/practice/session';
  static const String practiceResult = '/practice/result';
  static const String mastery = '/mastery';
  static const String masteryTree = '/mastery/tree';
}

// In route generation
case AppRoutes.practice:
  return MaterialPageRoute(builder: (_) => PracticeLobbyScreen());
case AppRoutes.mastery:
  return MaterialPageRoute(builder: (_) => MasteryOverviewScreen());
```

### 3. Update API Config
Add new service URLs to `api_config.dart`:

```dart
static const String practiceBaseUrl = 'http://localhost:8090/api/v1';
static const String masteryBaseUrl = 'http://localhost:8091/api/v1';
static const String profileBaseUrl = 'http://localhost:8092/api/v1';
```

---

## Testing Guide

### Backend Testing

```bash
# Start practice service
cd services/practice
go run main.go

# Test endpoints
curl -X POST http://localhost:8090/api/v1/practice/generate \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"cipher_type":"CAESAR","difficulty":5,"mode":"UNTIMED"}'
```

### Flutter Testing

```dart
// Unit tests for PracticeService
test('generatePuzzle returns success', () async {
  final result = await PracticeService.generatePuzzle(
    cipherType: 'CAESAR',
    difficulty: 5,
  );
  expect(result['success'], true);
  expect(result['data'], isNotNull);
});
```

### Database Testing

```sql
-- Verify tables created
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND table_name LIKE 'practice%';

-- Test practice session insert
INSERT INTO practice_sessions (user_id, puzzle_id, cipher_type, difficulty, mode)
VALUES ('<user_id>', '<puzzle_id>', 'CAESAR', 5, 'UNTIMED');

-- Verify triggers work
SELECT * FROM practice_leaderboards WHERE user_id = '<user_id>';
```

---

## Next Steps

1. **Complete Practice Service**: Implement remaining handlers and service methods
2. **Build Mastery Tree UI**: Create skill tree visualization with Flutter CustomPainter
3. **Enhance Profile Dashboard**: Add per-cipher stats and match history
4. **Add Daily Missions**: Implement mission generation and tracking
5. **Create Cosmetics System**: Build reward distribution and equip functionality

---

**END OF IMPLEMENTATION GUIDE**
