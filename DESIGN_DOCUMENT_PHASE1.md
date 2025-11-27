# Cipher Clash - Phase 1 Feature Design Document
## Tutorial + Practice Mode + Mastery Tree + Player Profile

**Version:** 1.0
**Date:** 2025-11-26
**Sprint Focus:** Onboarding, Practice, and Progression Systems

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Data Model Design](#data-model-design)
3. [API Specifications](#api-specifications)
4. [UI/UX Wireframes](#uiux-wireframes)
5. [Implementation Roadmap](#implementation-roadmap)

---

## Executive Summary

This design document covers the first phase of engagement features:

- **Tutorial System**: Guided onboarding for new users with step-by-step cipher learning
- **Practice Mode**: Solo puzzle-solving with optional timers, no ELO impact
- **Mastery Tree**: Per-cipher skill progression with XP, levels, and unlockables
- **Player Profile Dashboard**: Comprehensive stats, achievements, and mastery visualization

### Design Principles
1. **Modular Architecture**: Each feature is independent but integrates seamlessly
2. **Type Safety**: Strong typing via proto definitions and database constraints
3. **Performance**: Redis caching for frequently accessed data
4. **UX Consistency**: Cyberpunk theme with smooth animations
5. **Extensibility**: JSONB fields for future feature additions

---

## Data Model Design

### 1. Tutorial System

#### Table: `tutorial_progress`
```sql
CREATE TABLE tutorial_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Overall tutorial state
    is_tutorial_completed BOOLEAN DEFAULT FALSE,
    current_step_id VARCHAR(100),
    total_steps_completed INT DEFAULT 0,

    -- Tutorial-specific cipher practice
    ciphers_introduced TEXT[] DEFAULT '{}',  -- e.g., ['CAESAR', 'VIGENERE']
    practice_puzzles_solved JSONB DEFAULT '{}',  -- { "CAESAR": 3, "VIGENERE": 1 }

    -- Timestamps
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    last_interaction_at TIMESTAMP DEFAULT NOW(),

    -- Metadata
    tutorial_version VARCHAR(20) DEFAULT 'v1.0',
    skipped BOOLEAN DEFAULT FALSE,

    UNIQUE(user_id)
);

CREATE INDEX idx_tutorial_progress_user ON tutorial_progress(user_id);
CREATE INDEX idx_tutorial_current_step ON tutorial_progress(user_id, current_step_id)
    WHERE is_tutorial_completed = FALSE;
```

#### Table: `tutorial_steps` (Static Configuration)
```sql
CREATE TABLE tutorial_steps (
    id VARCHAR(100) PRIMARY KEY,  -- e.g., 'intro_welcome', 'cipher_caesar_basics'
    step_number INT NOT NULL,
    category VARCHAR(50),  -- 'INTRODUCTION', 'CIPHER_BASICS', 'GAME_MECHANICS', 'PRACTICE'

    -- Content
    title VARCHAR(200) NOT NULL,
    description TEXT,
    instruction_text TEXT,

    -- Interactive elements
    cipher_type VARCHAR(50),  -- NULL for non-cipher steps
    practice_puzzle_id UUID REFERENCES puzzles(id),  -- Pre-generated practice puzzle
    requires_completion BOOLEAN DEFAULT TRUE,

    -- Flow control
    next_step_id VARCHAR(100),
    previous_step_id VARCHAR(100),
    is_optional BOOLEAN DEFAULT FALSE,

    -- Rewards
    xp_reward INT DEFAULT 10,
    unlock_feature VARCHAR(100),  -- e.g., 'MATCHMAKING', 'PRACTICE_MODE'

    -- Visualization
    visualization_type VARCHAR(50),  -- 'CIPHER_DEMO', 'INTERACTIVE', 'VIDEO', 'TEXT'
    animation_data JSONB,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tutorial_steps_order ON tutorial_steps(step_number);
CREATE INDEX idx_tutorial_steps_cipher ON tutorial_steps(cipher_type) WHERE cipher_type IS NOT NULL;

-- Insert initial tutorial flow
INSERT INTO tutorial_steps (id, step_number, category, title, description, cipher_type, requires_completion, xp_reward, next_step_id) VALUES
('intro_welcome', 1, 'INTRODUCTION', 'Welcome to Cipher Clash', 'Learn the basics of cipher battles', NULL, FALSE, 10, 'intro_game_overview'),
('intro_game_overview', 2, 'INTRODUCTION', 'How to Play', 'Understand matchmaking and gameplay', NULL, TRUE, 10, 'cipher_caesar_intro'),
('cipher_caesar_intro', 3, 'CIPHER_BASICS', 'Caesar Cipher', 'Your first cipher - the classic shift cipher', 'CAESAR', TRUE, 20, 'cipher_caesar_practice'),
('cipher_caesar_practice', 4, 'PRACTICE', 'Practice: Caesar', 'Solve your first Caesar cipher puzzle', 'CAESAR', TRUE, 50, 'cipher_vigenere_intro'),
('cipher_vigenere_intro', 5, 'CIPHER_BASICS', 'Vigenère Cipher', 'Learn the polyalphabetic keyword cipher', 'VIGENERE', TRUE, 20, 'cipher_vigenere_practice'),
('cipher_vigenere_practice', 6, 'PRACTICE', 'Practice: Vigenère', 'Crack a Vigenère cipher', 'VIGENERE', TRUE, 50, 'game_mechanics_intro'),
('game_mechanics_intro', 7, 'GAME_MECHANICS', 'Battle Mechanics', 'Learn about hints, timers, and power-ups', NULL, TRUE, 10, 'game_mechanics_matchmaking'),
('game_mechanics_matchmaking', 8, 'GAME_MECHANICS', 'Matchmaking System', 'Understand ELO ratings and ranks', NULL, TRUE, 10, 'tutorial_complete'),
('tutorial_complete', 9, 'COMPLETION', 'Tutorial Complete!', 'You are ready for your first match', NULL, FALSE, 100, NULL);
```

---

### 2. Practice Mode

#### Table: `practice_sessions`
```sql
CREATE TABLE practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    puzzle_id UUID NOT NULL REFERENCES puzzles(id),

    -- Session metadata
    cipher_type VARCHAR(50) NOT NULL,
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),
    mode VARCHAR(50) DEFAULT 'UNTIMED',  -- 'UNTIMED', 'TIMED', 'SPEED_RUN', 'ACCURACY'

    -- Timing
    started_at TIMESTAMP DEFAULT NOW(),
    submitted_at TIMESTAMP,
    solve_time_ms BIGINT,
    time_limit_ms BIGINT,  -- NULL for untimed

    -- Solution
    user_solution TEXT,
    is_correct BOOLEAN,
    accuracy_percentage DECIMAL(5,2),  -- Partial credit for close answers

    -- Assistance
    hints_used INT DEFAULT 0,
    hint_timestamps JSONB DEFAULT '[]',  -- [ {"hint_type": "LETTER", "timestamp": "2025-01-01T12:00:00Z"} ]
    visualizations_viewed INT DEFAULT 0,

    -- Scoring (no ELO, just practice metrics)
    score INT,  -- Based on time, accuracy, hints
    perfect_solve BOOLEAN DEFAULT FALSE,  -- Correct + No hints + Under time threshold

    -- Stats
    attempts INT DEFAULT 1,  -- Number of submission attempts in this session

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_practice_user ON practice_sessions(user_id);
CREATE INDEX idx_practice_cipher ON practice_sessions(user_id, cipher_type);
CREATE INDEX idx_practice_date ON practice_sessions(user_id, started_at DESC);
```

#### Table: `practice_leaderboards` (Per-Cipher Personal Bests)
```sql
CREATE TABLE practice_leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),

    -- Best times
    fastest_solve_ms BIGINT NOT NULL,
    fastest_session_id UUID REFERENCES practice_sessions(id),
    fastest_achieved_at TIMESTAMP DEFAULT NOW(),

    -- Best scores
    highest_score INT DEFAULT 0,
    highest_score_session_id UUID REFERENCES practice_sessions(id),

    -- Statistics
    total_practice_sessions INT DEFAULT 1,
    perfect_solves INT DEFAULT 0,
    average_solve_time_ms BIGINT,

    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(user_id, cipher_type, difficulty)
);

CREATE INDEX idx_practice_lb_user ON practice_leaderboards(user_id);
CREATE INDEX idx_practice_lb_cipher ON practice_leaderboards(cipher_type, difficulty, fastest_solve_ms);
```

---

### 3. Mastery Tree System

#### Table: `cipher_mastery`
```sql
CREATE TABLE cipher_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,

    -- Core progression
    mastery_level INT DEFAULT 0 CHECK (mastery_level BETWEEN 0 AND 100),
    mastery_xp INT DEFAULT 0,
    xp_to_next_level INT DEFAULT 100,

    -- Tier progression (5 tiers: Novice, Apprentice, Expert, Master, Grandmaster)
    mastery_tier VARCHAR(50) DEFAULT 'NOVICE',  -- NOVICE, APPRENTICE, EXPERT, MASTER, GRANDMASTER
    tier_progress_percentage DECIMAL(5,2) DEFAULT 0.00,

    -- Statistics (for XP calculation)
    puzzles_solved INT DEFAULT 0,
    puzzles_solved_ranked INT DEFAULT 0,
    puzzles_solved_practice INT DEFAULT 0,

    perfect_solves INT DEFAULT 0,  -- No hints, fast time
    average_solve_time_ms BIGINT,
    fastest_solve_ms BIGINT,

    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    win_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Skill tree nodes unlocked
    nodes_unlocked TEXT[] DEFAULT '{}',  -- e.g., ['CAESAR_NODE_1', 'CAESAR_NODE_SPEED']
    total_nodes_available INT DEFAULT 0,

    -- Rewards earned
    cosmetics_unlocked TEXT[] DEFAULT '{}',
    titles_unlocked TEXT[] DEFAULT '{}',

    -- Timestamps
    first_solved_at TIMESTAMP,
    last_solved_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(user_id, cipher_type)
);

CREATE INDEX idx_cipher_mastery_user ON cipher_mastery(user_id);
CREATE INDEX idx_cipher_mastery_tier ON cipher_mastery(cipher_type, mastery_tier, mastery_level DESC);
CREATE INDEX idx_cipher_mastery_level ON cipher_mastery(user_id, mastery_level DESC);

-- Function to calculate mastery tier
CREATE OR REPLACE FUNCTION calculate_mastery_tier(level INT) RETURNS VARCHAR(50) AS $$
BEGIN
    IF level < 10 THEN RETURN 'NOVICE';
    ELSIF level < 25 THEN RETURN 'APPRENTICE';
    ELSIF level < 50 THEN RETURN 'EXPERT';
    ELSIF level < 80 THEN RETURN 'MASTER';
    ELSE RETURN 'GRANDMASTER';
    END IF;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Trigger to auto-update mastery tier
CREATE OR REPLACE FUNCTION update_mastery_tier() RETURNS TRIGGER AS $$
BEGIN
    NEW.mastery_tier = calculate_mastery_tier(NEW.mastery_level);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_mastery_tier
    BEFORE UPDATE OF mastery_level ON cipher_mastery
    FOR EACH ROW
    EXECUTE FUNCTION update_mastery_tier();
```

#### Table: `mastery_nodes` (Skill Tree Configuration)
```sql
CREATE TABLE mastery_nodes (
    id VARCHAR(100) PRIMARY KEY,  -- e.g., 'CAESAR_NODE_SPEED_1'
    cipher_type VARCHAR(50) NOT NULL,

    -- Tree structure
    node_type VARCHAR(50) NOT NULL,  -- 'CORE', 'SPEED', 'ACCURACY', 'REWARD', 'ULTIMATE'
    tier INT NOT NULL CHECK (tier BETWEEN 1 AND 5),  -- Corresponds to mastery tiers
    position_x INT,  -- For UI visualization
    position_y INT,

    -- Unlock requirements
    required_mastery_level INT NOT NULL,
    prerequisite_nodes TEXT[] DEFAULT '{}',  -- Must unlock these nodes first
    required_puzzles_solved INT DEFAULT 0,
    required_perfect_solves INT DEFAULT 0,

    -- Node effects/rewards
    title VARCHAR(200) NOT NULL,
    description TEXT,

    -- Passive bonuses (for future features)
    bonus_type VARCHAR(50),  -- 'XP_MULTIPLIER', 'HINT_COST_REDUCTION', 'TIME_BONUS'
    bonus_value DECIMAL(5,2),

    -- Cosmetic unlocks
    unlocks_cosmetic_id VARCHAR(100),
    unlocks_title VARCHAR(100),
    unlocks_avatar_frame VARCHAR(100),

    -- Metadata
    icon_url TEXT,
    is_ultimate BOOLEAN DEFAULT FALSE,  -- Special capstone node

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mastery_nodes_cipher ON mastery_nodes(cipher_type, tier);
CREATE INDEX idx_mastery_nodes_level ON mastery_nodes(required_mastery_level);

-- Sample nodes for Caesar cipher
INSERT INTO mastery_nodes (id, cipher_type, node_type, tier, title, description, required_mastery_level, bonus_type, bonus_value) VALUES
('CAESAR_CORE_1', 'CAESAR', 'CORE', 1, 'Caesar Initiate', 'Master the basics of shift ciphers', 0, 'XP_MULTIPLIER', 1.1),
('CAESAR_SPEED_1', 'CAESAR', 'SPEED', 1, 'Quick Shifter', 'Solve Caesar ciphers 10% faster', 5, 'TIME_BONUS', 1.1),
('CAESAR_CORE_2', 'CAESAR', 'CORE', 2, 'Caesar Adept', 'Advanced shift cipher techniques', 10, 'XP_MULTIPLIER', 1.2),
('CAESAR_ACCURACY_1', 'CAESAR', 'ACCURACY', 2, 'Precision Decoder', 'Reduce hint usage', 15, 'HINT_COST_REDUCTION', 0.8),
('CAESAR_ULTIMATE', 'CAESAR', 'ULTIMATE', 5, 'Caesar Grandmaster', 'Ultimate mastery of shift ciphers', 80, NULL, NULL);
```

#### Table: `mastery_xp_events` (Audit log for XP gains)
```sql
CREATE TABLE mastery_xp_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,

    -- Event details
    event_type VARCHAR(50) NOT NULL,  -- 'PUZZLE_SOLVED', 'PERFECT_SOLVE', 'RANKED_WIN', 'NODE_UNLOCKED'
    xp_gained INT NOT NULL,
    multiplier DECIMAL(5,2) DEFAULT 1.0,  -- From bonuses/events

    -- Context
    session_id UUID,  -- Link to practice_session or match_id
    context JSONB,  -- Additional metadata

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mastery_xp_user ON mastery_xp_events(user_id, cipher_type, created_at DESC);
```

---

### 4. Player Profile & Stats Dashboard

#### Enhanced User Stats (Extend existing `users` table via view)
```sql
-- Create comprehensive stats view
CREATE OR REPLACE VIEW user_comprehensive_stats AS
SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.title,
    u.level,
    u.xp,
    u.elo_rating,
    u.rank_tier,

    -- Match statistics
    u.total_games,
    u.wins,
    u.losses,
    CASE WHEN u.total_games > 0
        THEN ROUND((u.wins::DECIMAL / u.total_games::DECIMAL * 100), 2)
        ELSE 0
    END as win_rate_percentage,
    u.win_streak,
    u.best_win_streak,

    -- Puzzle statistics
    u.puzzles_solved,
    u.total_solve_time_ms,
    CASE WHEN u.puzzles_solved > 0
        THEN u.total_solve_time_ms / u.puzzles_solved
        ELSE 0
    END as avg_solve_time_ms,
    u.fastest_solve_ms,
    u.perfect_games,
    u.hints_used,

    -- Achievement progress
    (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = u.id AND ua.is_completed = TRUE) as achievements_unlocked,
    (SELECT COUNT(*) FROM achievements) as total_achievements,

    -- Mastery summary
    (SELECT COUNT(*) FROM cipher_mastery cm WHERE cm.user_id = u.id AND cm.mastery_tier = 'GRANDMASTER') as grandmaster_ciphers,
    (SELECT COUNT(*) FROM cipher_mastery cm WHERE cm.user_id = u.id AND cm.mastery_tier = 'MASTER') as master_ciphers,
    (SELECT AVG(cm.mastery_level) FROM cipher_mastery cm WHERE cm.user_id = u.id) as avg_mastery_level,

    -- Activity
    u.last_login_at,
    u.created_at as account_created_at

FROM users u;
```

#### Table: `player_cipher_stats` (Detailed per-cipher statistics)
```sql
CREATE TABLE player_cipher_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,

    -- Game statistics
    games_played INT DEFAULT 0,
    games_won INT DEFAULT 0,
    games_lost INT DEFAULT 0,
    win_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Practice statistics
    practice_sessions INT DEFAULT 0,
    practice_perfect_solves INT DEFAULT 0,

    -- Combined puzzle statistics
    total_puzzles_solved INT DEFAULT 0,
    total_solve_time_ms BIGINT DEFAULT 0,
    average_solve_time_ms BIGINT,
    fastest_solve_ms BIGINT,
    median_solve_time_ms BIGINT,

    -- Difficulty breakdown
    difficulty_breakdown JSONB DEFAULT '{}',  -- { "1": {"solved": 10, "avg_time": 5000}, ... }

    -- Accuracy
    perfect_solves INT DEFAULT 0,
    hints_used INT DEFAULT 0,
    hints_per_puzzle DECIMAL(5,2) DEFAULT 0.00,

    -- Rankings
    global_rank INT,  -- Rank among all players for this cipher
    percentile DECIMAL(5,2),  -- Top X% of players

    -- Timestamps
    first_played_at TIMESTAMP,
    last_played_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),

    UNIQUE(user_id, cipher_type)
);

CREATE INDEX idx_player_cipher_stats_user ON player_cipher_stats(user_id);
CREATE INDEX idx_player_cipher_stats_cipher ON player_cipher_stats(cipher_type, win_rate DESC);
CREATE INDEX idx_player_cipher_stats_global_rank ON player_cipher_stats(cipher_type, global_rank);
```

#### Table: `match_history` (Enhanced match records for profile)
```sql
-- This extends the existing matches table with a view
CREATE OR REPLACE VIEW match_history_detailed AS
SELECT
    m.id as match_id,
    m.player1_id,
    m.player2_id,
    m.winner_id,

    -- Match details
    m.started_at,
    m.ended_at,
    m.duration_ms,
    m.status,

    -- Puzzle
    p.cipher_type,
    p.difficulty,
    p.encrypted_text,

    -- Game mode
    gm.name as game_mode,
    gm.display_name as game_mode_display,

    -- ELO changes
    m.elo_change_p1,
    m.elo_change_p2,

    -- Replay
    m.replay_data,
    m.replay_url

FROM matches m
LEFT JOIN puzzles p ON m.puzzle_id = p.id
LEFT JOIN game_modes gm ON m.game_mode_id = gm.id
WHERE m.status = 'COMPLETED';

CREATE INDEX idx_match_history_player1 ON matches(player1_id, started_at DESC);
CREATE INDEX idx_match_history_player2 ON matches(player2_id, started_at DESC);
```

---

## API Specifications

### Base URL Conventions
```
Tutorial Service:   http://localhost:8089/api/v1/tutorial
Practice Service:   http://localhost:8090/api/v1/practice
Mastery Service:    http://localhost:8091/api/v1/mastery
Profile Service:    http://localhost:8092/api/v1/profile
```

---

### 1. Tutorial API Endpoints

#### `POST /api/v1/tutorial/start`
**Description**: Initialize tutorial for a new user

**Request Headers**:
```
Authorization: Bearer <JWT_TOKEN>
Content-Type: application/json
```

**Request Body**:
```json
{
  "tutorial_version": "v1.0"  // Optional, defaults to latest
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "progress_id": "uuid",
    "current_step": {
      "id": "intro_welcome",
      "step_number": 1,
      "category": "INTRODUCTION",
      "title": "Welcome to Cipher Clash",
      "description": "Learn the basics of cipher battles",
      "instruction_text": "Welcome! Let's get you started...",
      "requires_completion": false,
      "xp_reward": 10,
      "next_step_id": "intro_game_overview",
      "visualization_type": "TEXT"
    },
    "total_steps": 9,
    "completed_steps": 0
  }
}
```

---

#### `GET /api/v1/tutorial/progress`
**Description**: Get user's tutorial progress

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "is_completed": false,
    "current_step_id": "cipher_caesar_practice",
    "total_steps_completed": 3,
    "total_steps": 9,
    "completion_percentage": 33.33,
    "ciphers_introduced": ["CAESAR", "VIGENERE"],
    "practice_puzzles_solved": {
      "CAESAR": 3,
      "VIGENERE": 1
    },
    "started_at": "2025-01-15T10:30:00Z",
    "last_interaction_at": "2025-01-15T11:00:00Z"
  }
}
```

---

#### `POST /api/v1/tutorial/step/complete`
**Description**: Mark a tutorial step as completed

**Request Body**:
```json
{
  "step_id": "cipher_caesar_intro",
  "time_spent_seconds": 45,
  "context": {
    "puzzle_solved": true,
    "attempts": 2
  }
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "step_completed": true,
    "xp_gained": 20,
    "next_step": {
      "id": "cipher_caesar_practice",
      "title": "Practice: Caesar",
      "cipher_type": "CAESAR"
    },
    "unlocked_features": [],
    "total_progress": 4,
    "completion_percentage": 44.44
  }
}
```

---

#### `POST /api/v1/tutorial/skip`
**Description**: Skip the tutorial (with confirmation)

**Response** (200 OK):
```json
{
  "success": true,
  "message": "Tutorial skipped. You can restart it anytime from Settings.",
  "xp_granted": 50  // Partial XP for skipping
}
```

---

#### `GET /api/v1/tutorial/cipher-visualization/:cipher_type`
**Description**: Get interactive cipher visualization data

**Path Parameters**:
- `cipher_type`: CAESAR, VIGENERE, etc.

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "cipher_type": "CAESAR",
    "visualization": {
      "type": "INTERACTIVE",
      "steps": [
        {
          "step": 1,
          "title": "Choose a shift value",
          "description": "Caesar cipher shifts each letter by a fixed amount",
          "example_plaintext": "HELLO",
          "example_shift": 3,
          "example_ciphertext": "KHOOR",
          "animation_frames": [...]
        }
      ]
    }
  }
}
```

---

### 2. Practice Mode API Endpoints

#### `POST /api/v1/practice/generate`
**Description**: Generate a practice puzzle

**Request Body**:
```json
{
  "cipher_type": "CAESAR",
  "difficulty": 5,
  "mode": "TIMED",  // UNTIMED, TIMED, SPEED_RUN, ACCURACY
  "time_limit_seconds": 300  // Optional, for TIMED mode
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "session_id": "uuid",
    "puzzle": {
      "id": "uuid",
      "cipher_type": "CAESAR",
      "difficulty": 5,
      "encrypted_text": "KHOOR ZRUOG",
      "config": {
        "shift": 3
      },
      "hints_available": 3
    },
    "mode": "TIMED",
    "time_limit_ms": 300000,
    "started_at": "2025-01-15T12:00:00Z"
  }
}
```

---

#### `POST /api/v1/practice/submit`
**Description**: Submit solution for a practice puzzle

**Request Body**:
```json
{
  "session_id": "uuid",
  "solution": "HELLO WORLD",
  "solve_time_ms": 45230,
  "hints_used": 1
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "is_correct": true,
    "accuracy_percentage": 100.0,
    "score": 850,
    "perfect_solve": false,
    "feedback": {
      "message": "Correct! Great job!",
      "time_rating": "EXCELLENT",  // EXCELLENT, GOOD, AVERAGE, SLOW
      "hints_rating": "GOOD"
    },
    "personal_best": {
      "is_new_record": true,
      "previous_fastest_ms": 52000,
      "improvement_ms": 6770
    },
    "xp_gained": {
      "base_xp": 50,
      "speed_bonus": 20,
      "accuracy_bonus": 10,
      "mastery_multiplier": 1.2,
      "total_xp": 96
    },
    "mastery_update": {
      "cipher_type": "CAESAR",
      "xp_gained": 96,
      "new_mastery_xp": 1250,
      "level_up": false,
      "current_level": 8
    }
  }
}
```

**Response** (200 OK - Incorrect):
```json
{
  "success": true,
  "data": {
    "is_correct": false,
    "accuracy_percentage": 67.5,
    "score": 200,
    "feedback": {
      "message": "Not quite right. Keep trying!",
      "correct_answer": "HELLO WORLD",
      "your_answer": "JELLO VORLD",
      "character_diff": 3
    },
    "retry_allowed": true,
    "attempts_remaining": 2
  }
}
```

---

#### `GET /api/v1/practice/leaderboard/:cipher_type`
**Description**: Get personal best times for a cipher

**Path Parameters**:
- `cipher_type`: CAESAR, VIGENERE, etc.

**Query Parameters**:
- `difficulty` (optional): Filter by difficulty (1-10)

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "cipher_type": "CAESAR",
    "leaderboards": [
      {
        "difficulty": 3,
        "fastest_solve_ms": 12450,
        "fastest_achieved_at": "2025-01-10T14:30:00Z",
        "highest_score": 980,
        "total_sessions": 25,
        "perfect_solves": 8,
        "average_solve_time_ms": 18200
      },
      {
        "difficulty": 5,
        "fastest_solve_ms": 28900,
        "highest_score": 850,
        "total_sessions": 12,
        "perfect_solves": 2
      }
    ]
  }
}
```

---

#### `GET /api/v1/practice/history`
**Description**: Get practice session history

**Query Parameters**:
- `cipher_type` (optional): Filter by cipher
- `limit` (default: 20): Number of sessions
- `offset` (default: 0): Pagination

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "sessions": [
      {
        "id": "uuid",
        "cipher_type": "VIGENERE",
        "difficulty": 6,
        "mode": "TIMED",
        "started_at": "2025-01-15T11:00:00Z",
        "solve_time_ms": 145230,
        "is_correct": true,
        "score": 720,
        "perfect_solve": false,
        "hints_used": 2
      }
    ],
    "pagination": {
      "total": 134,
      "limit": 20,
      "offset": 0,
      "has_more": true
    }
  }
}
```

---

### 3. Mastery Tree API Endpoints

#### `GET /api/v1/mastery/overview`
**Description**: Get user's overall mastery across all ciphers

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "ciphers": [
      {
        "cipher_type": "CAESAR",
        "mastery_level": 18,
        "mastery_tier": "APPRENTICE",
        "mastery_xp": 1250,
        "xp_to_next_level": 400,
        "tier_progress_percentage": 72.0,
        "puzzles_solved": 45,
        "perfect_solves": 12,
        "wins": 28,
        "win_rate": 73.68,
        "nodes_unlocked": 5,
        "total_nodes_available": 15,
        "fastest_solve_ms": 8230
      },
      {
        "cipher_type": "VIGENERE",
        "mastery_level": 12,
        "mastery_tier": "APPRENTICE",
        "mastery_xp": 850,
        "xp_to_next_level": 300,
        "puzzles_solved": 28,
        "nodes_unlocked": 3
      }
    ],
    "summary": {
      "total_mastery_xp": 5420,
      "average_mastery_level": 14.2,
      "grandmaster_ciphers": 0,
      "master_ciphers": 0,
      "expert_ciphers": 2,
      "apprentice_ciphers": 6,
      "novice_ciphers": 10
    }
  }
}
```

---

#### `GET /api/v1/mastery/cipher/:cipher_type`
**Description**: Get detailed mastery tree for a specific cipher

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "cipher_type": "CAESAR",
    "mastery_level": 18,
    "mastery_tier": "APPRENTICE",
    "mastery_xp": 1250,
    "xp_to_next_level": 400,
    "tier_progress_percentage": 72.0,

    "statistics": {
      "puzzles_solved": 45,
      "puzzles_solved_ranked": 28,
      "puzzles_solved_practice": 17,
      "perfect_solves": 12,
      "wins": 28,
      "losses": 10,
      "win_rate": 73.68,
      "average_solve_time_ms": 18450,
      "fastest_solve_ms": 8230
    },

    "skill_tree": {
      "nodes": [
        {
          "id": "CAESAR_CORE_1",
          "title": "Caesar Initiate",
          "description": "Master the basics of shift ciphers",
          "node_type": "CORE",
          "tier": 1,
          "is_unlocked": true,
          "unlocked_at": "2025-01-10T09:00:00Z",
          "required_mastery_level": 0,
          "bonus_type": "XP_MULTIPLIER",
          "bonus_value": 1.1,
          "position": {"x": 0, "y": 0}
        },
        {
          "id": "CAESAR_SPEED_1",
          "title": "Quick Shifter",
          "description": "Solve Caesar ciphers 10% faster",
          "node_type": "SPEED",
          "tier": 1,
          "is_unlocked": true,
          "required_mastery_level": 5,
          "prerequisite_nodes": ["CAESAR_CORE_1"],
          "bonus_type": "TIME_BONUS",
          "bonus_value": 1.1,
          "position": {"x": -1, "y": 1}
        },
        {
          "id": "CAESAR_CORE_2",
          "title": "Caesar Adept",
          "description": "Advanced shift cipher techniques",
          "node_type": "CORE",
          "tier": 2,
          "is_unlocked": false,
          "can_unlock": true,
          "required_mastery_level": 10,
          "prerequisite_nodes": ["CAESAR_CORE_1"],
          "position": {"x": 0, "y": 2}
        }
      ],
      "total_nodes": 15,
      "unlocked_nodes": 5,
      "completion_percentage": 33.33
    },

    "unlocked_rewards": {
      "cosmetics": ["caesar_bronze_badge", "shift_cipher_icon"],
      "titles": ["Shift Decoder", "Caesar's Apprentice"],
      "avatar_frames": []
    }
  }
}
```

---

#### `POST /api/v1/mastery/unlock-node`
**Description**: Unlock a mastery tree node

**Request Body**:
```json
{
  "cipher_type": "CAESAR",
  "node_id": "CAESAR_CORE_2"
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "node_unlocked": true,
    "node": {
      "id": "CAESAR_CORE_2",
      "title": "Caesar Adept",
      "bonus_type": "XP_MULTIPLIER",
      "bonus_value": 1.2
    },
    "rewards": {
      "cosmetics": [],
      "titles": ["Caesar Adept"],
      "xp_bonus": 100
    },
    "updated_mastery": {
      "nodes_unlocked": 6,
      "total_nodes": 15
    }
  }
}
```

**Response** (400 Bad Request - Requirements not met):
```json
{
  "success": false,
  "error": {
    "code": "REQUIREMENTS_NOT_MET",
    "message": "You must reach mastery level 10 to unlock this node",
    "requirements": {
      "required_mastery_level": 10,
      "current_mastery_level": 8,
      "missing_prerequisite_nodes": []
    }
  }
}
```

---

#### `POST /api/v1/mastery/award-xp`
**Description**: Award mastery XP (internal endpoint, called by game/practice services)

**Request Body**:
```json
{
  "user_id": "uuid",
  "cipher_type": "CAESAR",
  "event_type": "PUZZLE_SOLVED",
  "base_xp": 50,
  "multiplier": 1.2,
  "context": {
    "session_id": "uuid",
    "difficulty": 5,
    "perfect_solve": false
  }
}
```

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "xp_awarded": 60,
    "new_mastery_xp": 1310,
    "new_mastery_level": 19,
    "level_up": true,
    "previous_level": 18,
    "xp_to_next_level": 450,
    "tier_changed": false,
    "current_tier": "APPRENTICE",
    "new_nodes_available": ["CAESAR_ACCURACY_2"]
  }
}
```

---

### 4. Player Profile & Stats API Endpoints

#### `GET /api/v1/profile/:user_id`
**Description**: Get comprehensive player profile

**Path Parameters**:
- `user_id`: UUID or "me" for current user

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "user": {
      "id": "uuid",
      "username": "cipher_master_92",
      "display_name": "Cipher Master",
      "avatar_url": "https://...",
      "title": "Caesar's Apprentice",
      "region": "NA",
      "account_created_at": "2024-12-01T10:00:00Z",
      "last_login_at": "2025-01-15T14:30:00Z"
    },

    "progression": {
      "level": 28,
      "xp": 15420,
      "xp_to_next_level": 2000,
      "elo_rating": 1547,
      "rank_tier": "GOLD",
      "rank_tier_display": "Gold III"
    },

    "match_statistics": {
      "total_games": 142,
      "wins": 87,
      "losses": 55,
      "win_rate_percentage": 61.27,
      "win_streak": 4,
      "best_win_streak": 12
    },

    "puzzle_statistics": {
      "puzzles_solved": 256,
      "total_solve_time_ms": 4680000,
      "average_solve_time_ms": 18281,
      "fastest_solve_ms": 6420,
      "perfect_games": 34,
      "hints_used": 128,
      "hints_per_puzzle": 0.5
    },

    "achievements": {
      "unlocked": 24,
      "total": 87,
      "completion_percentage": 27.59,
      "recent_unlocks": [
        {
          "id": "uuid",
          "name": "Speed Demon",
          "description": "Solve 10 puzzles under 10 seconds",
          "rarity": "EPIC",
          "unlocked_at": "2025-01-14T16:20:00Z"
        }
      ]
    },

    "mastery_summary": {
      "grandmaster_ciphers": 1,
      "master_ciphers": 2,
      "expert_ciphers": 4,
      "average_mastery_level": 18.4,
      "total_mastery_xp": 8940,
      "top_ciphers": [
        {
          "cipher_type": "CAESAR",
          "mastery_tier": "MASTER",
          "mastery_level": 52,
          "win_rate": 78.5
        },
        {
          "cipher_type": "VIGENERE",
          "mastery_tier": "EXPERT",
          "mastery_level": 38
        }
      ]
    }
  }
}
```

---

#### `GET /api/v1/profile/:user_id/cipher-stats`
**Description**: Get detailed per-cipher statistics

**Query Parameters**:
- `cipher_type` (optional): Filter specific cipher

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "cipher_stats": [
      {
        "cipher_type": "CAESAR",
        "games_played": 42,
        "games_won": 33,
        "games_lost": 9,
        "win_rate": 78.57,
        "practice_sessions": 28,
        "total_puzzles_solved": 70,
        "average_solve_time_ms": 15230,
        "fastest_solve_ms": 6420,
        "perfect_solves": 18,
        "hints_used": 24,
        "hints_per_puzzle": 0.34,
        "difficulty_breakdown": {
          "3": {"solved": 15, "avg_time_ms": 8500},
          "5": {"solved": 28, "avg_time_ms": 14200},
          "7": {"solved": 18, "avg_time_ms": 22100},
          "9": {"solved": 9, "avg_time_ms": 35600}
        },
        "global_rank": 234,
        "percentile": 8.5,
        "first_played_at": "2024-12-05T10:00:00Z",
        "last_played_at": "2025-01-15T12:30:00Z"
      }
    ]
  }
}
```

---

#### `GET /api/v1/profile/:user_id/match-history`
**Description**: Get match history with detailed results

**Query Parameters**:
- `limit` (default: 20)
- `offset` (default: 0)
- `cipher_type` (optional)
- `game_mode` (optional)
- `result` (optional): "win", "loss", "all"

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "matches": [
      {
        "match_id": "uuid",
        "opponent": {
          "id": "uuid",
          "username": "rival_decoder",
          "display_name": "Rival Decoder",
          "avatar_url": "https://...",
          "elo_rating": 1520
        },
        "result": "WIN",
        "cipher_type": "VIGENERE",
        "difficulty": 6,
        "game_mode": "RANKED_1V1",
        "duration_ms": 185400,
        "elo_change": +18,
        "new_elo": 1547,
        "started_at": "2025-01-15T12:00:00Z",
        "ended_at": "2025-01-15T12:03:05Z",
        "perfect_game": false,
        "hints_used": 1
      }
    ],
    "pagination": {
      "total": 142,
      "limit": 20,
      "offset": 0,
      "has_more": true
    },
    "summary": {
      "recent_win_rate": 65.0,
      "recent_avg_elo_change": +8.5,
      "current_streak": 4,
      "streak_type": "WIN"
    }
  }
}
```

---

#### `GET /api/v1/profile/:user_id/achievements`
**Description**: Get user achievements with progress

**Query Parameters**:
- `category` (optional): SPEED, MASTERY, STREAK, etc.
- `status` (optional): "unlocked", "in_progress", "locked"

**Response** (200 OK):
```json
{
  "success": true,
  "data": {
    "achievements": [
      {
        "achievement": {
          "id": "uuid",
          "name": "First Blood",
          "description": "Win your first ranked match",
          "category": "STREAK",
          "tier": "BRONZE",
          "xp_reward": 50,
          "icon_url": "https://..."
        },
        "progress": {
          "current": 1,
          "required": 1,
          "percentage": 100.0,
          "is_completed": true,
          "completed_at": "2024-12-05T14:30:00Z"
        }
      },
      {
        "achievement": {
          "id": "uuid",
          "name": "Win Streak Master",
          "description": "Win 10 matches in a row",
          "category": "STREAK",
          "tier": "GOLD",
          "xp_reward": 200
        },
        "progress": {
          "current": 7,
          "required": 10,
          "percentage": 70.0,
          "is_completed": false
        }
      }
    ],
    "summary": {
      "total_unlocked": 24,
      "total_achievements": 87,
      "by_tier": {
        "LEGENDARY": 0,
        "EPIC": 3,
        "GOLD": 6,
        "SILVER": 8,
        "BRONZE": 7
      },
      "total_xp_earned": 1840
    }
  }
}
```

---

## UI/UX Wireframes

### 1. Tutorial Flow Screens

#### Screen 1: Tutorial Welcome
```
┌─────────────────────────────────────────┐
│  ╔═══════════════════════════════════╗  │
│  ║   WELCOME TO CIPHER CLASH         ║  │
│  ║   🔐                              ║  │
│  ╚═══════════════════════════════════╝  │
│                                         │
│  [Animated Cipher Visualization]        │
│   A → B → C → D  (Rotating letters)    │
│                                         │
│  Ready to become a Cipher Master?       │
│  This tutorial will teach you:          │
│                                         │
│  ✓ How to decode ciphers                │
│  ✓ Battle mechanics & strategies        │
│  ✓ Your first cipher types              │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [START TUTORIAL] (Neon button) │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Skip Tutorial]  (Small link)          │
│                                         │
│  Progress: ░░░░░░░░░░ 0/9               │
└─────────────────────────────────────────┘
```

**Features**:
- Animated cyber background with matrix rain effect
- Glowing neon button with pulse animation
- Tutorial version indicator (v1.0)
- Dismissible via skip (with confirmation dialog)

---

#### Screen 2: Cipher Introduction (Interactive)
```
┌─────────────────────────────────────────┐
│  ← Back    CAESAR CIPHER    Step 3/9   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [Interactive Visualization]    │   │
│  │                                 │   │
│  │   Plaintext:  H E L L O         │   │
│  │      Shift:   ↓ ↓ ↓ ↓ ↓  [3]  │   │
│  │  Ciphertext:  K H O O R         │   │
│  │                                 │   │
│  │  [Slider: Shift Amount 1-25]   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Caesar Cipher shifts each letter       │
│  by a fixed number of positions.        │
│                                         │
│  Example:                               │
│  • Shift = 3                            │
│  • A → D, B → E, C → F                 │
│  • "HELLO" → "KHOOR"                   │
│                                         │
│  💡 TIP: Try different shift values!    │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [CONTINUE] →                   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ◉ ○ ○ ○ ○ ○ ○ ○ ○  (Step indicator)  │
└─────────────────────────────────────────┘
```

**Features**:
- Interactive slider to adjust shift value
- Real-time cipher transformation
- Animated letter shifting
- "Try it yourself" interactive area
- XP reward indicator (+20 XP)

---

#### Screen 3: Practice Challenge
```
┌─────────────────────────────────────────┐
│  PRACTICE: CAESAR CIPHER    Step 4/9   │
│                                         │
│  Time to decode your first cipher!      │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Encrypted Message:             │   │
│  │                                 │   │
│  │   WKLV LV D VHFUHW              │   │
│  │                                 │   │
│  │  Hint: Shift = 3                │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Your Answer:                           │
│  ┌─────────────────────────────────┐   │
│  │  THIS IS A SECRET_______________│   │
│  └─────────────────────────────────┘   │
│                                         │
│  Tools:                                 │
│  [💡 Get Hint (3 left)]  [🔄 Reset]   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [SUBMIT ANSWER] →              │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Attempts: 1/3                          │
│                                         │
│  ◉ ◉ ◉ ◉ ○ ○ ○ ○ ○                     │
└─────────────────────────────────────────┘
```

**Features**:
- Input field for solution
- Hint system (show one letter, show shift, show pattern)
- Attempt counter
- Success animation on correct answer
- XP reward (+50 XP) with celebration confetti

---

#### Screen 4: Tutorial Complete
```
┌─────────────────────────────────────────┐
│  ╔═══════════════════════════════════╗  │
│  ║  🎉 TUTORIAL COMPLETE! 🎉         ║  │
│  ╚═══════════════════════════════════╝  │
│                                         │
│  [Confetti Animation]                   │
│                                         │
│  You've mastered the basics!            │
│                                         │
│  Rewards Earned:                        │
│  ┌─────────────────────────────────┐   │
│  │  ⭐ +250 XP                      │   │
│  │  🏆 Achievement: "Cipher Rookie" │   │
│  │  🎨 Title: "Apprentice Decoder"  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Unlocked Features:                     │
│  ✅ Matchmaking                         │
│  ✅ Practice Mode                       │
│  ✅ Mastery System                      │
│                                         │
│  Ciphers Learned:                       │
│  • Caesar Cipher                        │
│  • Vigenère Cipher                     │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [START YOUR FIRST MATCH] →     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Go to Practice Mode]                  │
└─────────────────────────────────────────┘
```

**Features**:
- Confetti/particle effects
- Achievement unlock animation
- Summary of unlocked features
- Direct navigation to first match or practice

---

### 2. Practice Mode Screens

#### Screen 1: Practice Mode Lobby
```
┌─────────────────────────────────────────┐
│  ← Menu      PRACTICE MODE              │
│                                         │
│  Master ciphers at your own pace        │
│                                         │
│  Select Cipher Type:                    │
│  ┌─────────────────────────────────┐   │
│  │  [CAESAR]    [VIGENERE]         │   │
│  │  Level 18    Level 12           │   │
│  │  78% Win     65% Win            │   │
│  │                                 │   │
│  │  [RAIL FENCE] [PLAYFAIR]       │   │
│  │  Level 8      Level 5 🔒        │   │
│  │  55% Win     (Locked)           │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Difficulty:   [━━━━━●━━━━] 5/10       │
│                                         │
│  Practice Mode:                         │
│  ◉ Untimed    ○ Timed (5 min)          │
│  ○ Speed Run  ○ Accuracy Challenge      │
│                                         │
│  Personal Bests (Caesar - Difficulty 5):│
│  🥇 Fastest: 28.9s   🏆 Score: 850      │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [START PRACTICE] →             │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [View History] [Personal Records]      │
└─────────────────────────────────────────┘
```

**Features**:
- Grid layout of cipher cards with mastery levels
- Locked ciphers with unlock requirements tooltip
- Difficulty slider with visual feedback
- Mode selector (radio buttons)
- Personal best display for selected cipher+difficulty
- Cyber-themed card animations on hover

---

#### Screen 2: Practice Session (Active)
```
┌─────────────────────────────────────────┐
│  [X] Exit    PRACTICE: VIGENÈRE    ⏱️   │
│                                         │
│  Time: 02:34.5    Mode: Timed (5:00)    │
│  ┌─────────────────────────────────┐   │
│  │  Progress: ███████░░░░░ 68%     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Encrypted Text:                        │
│  ┌─────────────────────────────────┐   │
│  │  LXFOPV EF GGOSR PF...          │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Your Solution:                         │
│  ┌─────────────────────────────────┐   │
│  │  ATTACK AT DAWN ON___________   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Tools & Hints:                         │
│  [💡 Reveal Letter] [🔍 Show Pattern]  │
│  [📊 Frequency Analysis] [⏸️ Pause]    │
│                                         │
│  Hints Used: 0/3                        │
│  Current Score: 720 pts                 │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [SUBMIT SOLUTION] →            │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Give Up] (Show answer)                │
└─────────────────────────────────────────┘
```

**Features**:
- Live timer for timed mode
- Progress bar showing completion percentage
- Solution input field with auto-uppercase
- Hint buttons with usage counter
- Score calculator (decreases with hints/time)
- Pause button for timed mode
- Exit confirmation dialog

---

#### Screen 3: Practice Result
```
┌─────────────────────────────────────────┐
│  ✅ CORRECT! EXCELLENT WORK!            │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  Solution: ATTACK AT DAWN       │   │
│  │  Your Answer: ATTACK AT DAWN    │   │
│  │  ✓ 100% Accuracy                │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Performance:                           │
│  ┌─────────────────────────────────┐   │
│  │  Time:     02:34.5  [EXCELLENT] │   │
│  │  Hints:    1/3      [GOOD]      │   │
│  │  Score:    720 pts              │   │
│  │                                 │   │
│  │  🆕 NEW PERSONAL BEST! 🎉       │   │
│  │  Previous: 02:48.2 (-13.7s)    │   │
│  └─────────────────────────────────┘   │
│                                         │
│  XP Gained:                             │
│  ┌─────────────────────────────────┐   │
│  │  Base XP:         50            │   │
│  │  Speed Bonus:     +20           │   │
│  │  Mastery Bonus:   ×1.2          │   │
│  │  ─────────────────────          │   │
│  │  Total XP:        96            │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Mastery Progress:                      │
│  Vigenère: Lvl 12 ███████░░░ +96 XP    │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [PRACTICE AGAIN] [CHANGE CIPHER]│  │
│  └─────────────────────────────────┘   │
│                                         │
│  [Return to Lobby]                      │
└─────────────────────────────────────────┘
```

**Features**:
- Success/failure indicator
- Performance breakdown with ratings
- Personal best notification with confetti
- XP calculation breakdown
- Mastery progress bar animation
- Quick retry or change cipher options

---

### 3. Mastery Tree Screen

#### Main Mastery Overview
```
┌─────────────────────────────────────────┐
│  ← Back     MASTERY TREE                │
│                                         │
│  Overall Progress:                      │
│  ┌─────────────────────────────────┐   │
│  │  Total Mastery XP: 8,940        │   │
│  │  Avg Level: 18.4                │   │
│  │  🏆 1 Grandmaster  ⭐ 2 Masters  │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Cipher Mastery:                        │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ CAESAR         [MASTER] Lvl 52   │  │
│  │ ████████████████░░ 82%           │  │
│  │ 5/15 nodes  •  Win Rate: 78%    │  │
│  │                   [VIEW TREE →] │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ VIGENERE       [EXPERT] Lvl 38   │  │
│  │ ████████████░░░░ 76%             │  │
│  │ 3/12 nodes  •  Win Rate: 65%    │  │
│  │                   [VIEW TREE →] │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ PLAYFAIR    [NOVICE] Lvl 5  🔒  │  │
│  │ ██░░░░░░░░░░░░ 50%               │  │
│  │ 0/10 nodes  •  Unlock at Lvl 10 │  │
│  │                   [VIEW INFO →] │  │
│  └──────────────────────────────────┘  │
│                                         │
│  [Sort by: Level ▼] [Filter: All]      │
└─────────────────────────────────────────┘
```

**Features**:
- Summary statistics at top
- Cipher cards with tier badges
- Progress bars with tier color coding
- Quick stats (nodes, win rate)
- Sorting and filtering options
- Tier icons (bronze, silver, gold crowns)

---

#### Detailed Skill Tree View
```
┌─────────────────────────────────────────┐
│  ← Mastery   CAESAR CIPHER TREE         │
│                                         │
│  Mastery Level: 52  [MASTER]            │
│  ████████████████░░ 82% to Grandmaster  │
│  XP: 5,240 / 6,400                      │
│                                         │
│  Statistics:                            │
│  Puzzles: 70  •  Wins: 33  •  78% WR   │
│  Fastest: 6.4s  •  Avg: 15.2s          │
│                                         │
│  Skill Tree:  [5/15 Nodes Unlocked]     │
│                                         │
│       [ULTIMATE: Grandmaster] 🔒        │
│              Lvl 80                     │
│                 │                       │
│        ┌────────┼────────┐              │
│        │        │        │              │
│     [SPEED]  [CORE]  [ACCURACY] ✅      │
│      Lvl 60   Lvl 50   Lvl 50          │
│        │        │        │              │
│        ├────────┼────────┤              │
│        │        │        │              │
│     [SPEED]  [CORE]  [ACCURACY] ✅      │
│      Lvl 30 ✅ Lvl 25 ✅ Lvl 30 🔒     │
│        │        │        │              │
│        ├────────┼────────┤              │
│        │        │        │              │
│     [SPEED]  [CORE]  [REWARD] ✅        │
│      Lvl 10 ✅ Lvl 10 ✅ Lvl 15 ✅     │
│                 │                       │
│             [INITIATE] ✅               │
│               Lvl 0                     │
│                                         │
│  Selected Node: Caesar Adept            │
│  ┌─────────────────────────────────┐   │
│  │  Lvl 25  •  CORE  •  Tier 2     │   │
│  │  "Advanced shift techniques"    │   │
│  │                                 │   │
│  │  Bonus: +20% XP Multiplier      │   │
│  │  Unlocked: Jan 10, 2025         │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Close]                                │
└─────────────────────────────────────────┘
```

**Features**:
- Visual tree with connecting lines
- Node states: ✅ Unlocked, 🔒 Locked, ⭕ Available
- Color coding by node type (CORE=blue, SPEED=green, ACCURACY=purple)
- Interactive nodes (tap to view details)
- Unlock button for available nodes
- Prerequisites shown with lines
- Tier progression path visualization

---

### 4. Player Profile Dashboard

#### Main Profile Screen
```
┌─────────────────────────────────────────┐
│  ← Menu      PLAYER PROFILE             │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  [Avatar]   cipher_master_92    │   │
│  │    🖼️      Cipher Master        │   │
│  │            Caesar's Apprentice   │   │
│  │                                 │   │
│  │  Level 28  ████░░ 15,420/17,000│   │
│  │  ELO: 1547  [GOLD III] 🥇       │   │
│  └─────────────────────────────────┘   │
│                                         │
│  Tabs: [Overview] [Stats] [Achievements]│
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  MATCH STATISTICS               │   │
│  │  ─────────────────────          │   │
│  │  Total Games:      142          │   │
│  │  Wins / Losses:    87 / 55      │   │
│  │  Win Rate:         61.3% 📈     │   │
│  │  Current Streak:   🔥 4 wins    │   │
│  │  Best Streak:      🏆 12 wins   │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  PUZZLE STATISTICS              │   │
│  │  ─────────────────────          │   │
│  │  Total Solved:     256          │   │
│  │  Fastest Solve:    6.4s ⚡      │   │
│  │  Average Time:     18.3s        │   │
│  │  Perfect Games:    34 🌟        │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  MASTERY OVERVIEW               │   │
│  │  ─────────────────────          │   │
│  │  🏆 Grandmaster: 1 cipher       │   │
│  │  ⭐ Master: 2 ciphers           │   │
│  │  💎 Expert: 4 ciphers           │   │
│  │  Avg Level: 18.4                │   │
│  │                                 │   │
│  │  [View Mastery Tree →]          │   │
│  └─────────────────────────────────┘   │
│                                         │
│  [Edit Profile] [Settings]              │
└─────────────────────────────────────────┘
```

---

#### Stats Tab (Per-Cipher Breakdown)
```
┌─────────────────────────────────────────┐
│  PROFILE  >  CIPHER STATISTICS          │
│                                         │
│  [Overview] [Stats] [Achievements]      │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ CAESAR                           │  │
│  │ ────────────────────             │  │
│  │ Games: 42  •  Win Rate: 78.6%   │  │
│  │ Practice: 28 sessions            │  │
│  │ Total Solved: 70 puzzles         │  │
│  │ Fastest: 6.4s  •  Avg: 15.2s    │  │
│  │ Perfect Solves: 18               │  │
│  │                                  │  │
│  │ Difficulty Breakdown:            │  │
│  │ ┌─────────────────────────────┐ │  │
│  │ │ Diff 3: 15 solved  8.5s avg │ │  │
│  │ │ Diff 5: 28 solved 14.2s avg │ │  │
│  │ │ Diff 7: 18 solved 22.1s avg │ │  │
│  │ │ Diff 9: 9 solved  35.6s avg │ │  │
│  │ └─────────────────────────────┘ │  │
│  │                                  │  │
│  │ Global Rank: #234 (Top 8.5%) 🏅│  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ VIGENÈRE                         │  │
│  │ ────────────────────             │  │
│  │ Games: 31  •  Win Rate: 64.5%   │  │
│  │ Fastest: 18.2s  •  Avg: 28.4s   │  │
│  │ ...                              │  │
│  └──────────────────────────────────┘  │
│                                         │
│  [Export Stats CSV]                     │
└─────────────────────────────────────────┘
```

---

#### Achievements Tab
```
┌─────────────────────────────────────────┐
│  PROFILE  >  ACHIEVEMENTS               │
│                                         │
│  [Overview] [Stats] [Achievements]      │
│                                         │
│  Progress: 24/87 (27.6%) ████░░░░░░     │
│  Total XP Earned: 1,840                 │
│                                         │
│  Filter: [All ▼] [Category ▼] [Tier ▼] │
│                                         │
│  Recently Unlocked:                     │
│  ┌──────────────────────────────────┐  │
│  │ ⚡ Speed Demon         [EPIC]    │  │
│  │ Solve 10 puzzles under 10s       │  │
│  │ +200 XP  •  Unlocked: Jan 14     │  │
│  └──────────────────────────────────┘  │
│                                         │
│  In Progress:                           │
│  ┌──────────────────────────────────┐  │
│  │ 🏆 Win Streak Master   [GOLD]    │  │
│  │ Win 10 matches in a row          │  │
│  │ Progress: ███████░░░ 7/10        │  │
│  │ +200 XP                          │  │
│  └──────────────────────────────────┘  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ 🎯 Perfect Solver     [SILVER]   │  │
│  │ Solve 50 puzzles with no hints   │  │
│  │ Progress: ████████░░ 34/50       │  │
│  │ +100 XP                          │  │
│  └──────────────────────────────────┘  │
│                                         │
│  Locked:                                │
│  ┌──────────────────────────────────┐  │
│  │ 👑 Grandmaster       [LEGENDARY] │  │
│  │ Reach Grandmaster tier           │  │
│  │ Progress: ░░░░░░░░░░ 0/1  🔒    │  │
│  │ +1000 XP  •  Title Reward        │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
```

---

## Implementation Roadmap

### Phase 1A: Database & Backend Foundation (Week 1)
**Priority: HIGH**

1. **Database Migrations**
   - Create tutorial_progress, tutorial_steps tables
   - Create practice_sessions, practice_leaderboards tables
   - Create cipher_mastery, mastery_nodes, mastery_xp_events tables
   - Create player_cipher_stats table
   - Create views: user_comprehensive_stats, match_history_detailed
   - Add triggers and functions

2. **Proto Definitions**
   - tutorial.proto (TutorialService RPCs)
   - practice.proto (PracticeService RPCs)
   - mastery.proto (MasteryService RPCs)
   - profile.proto (ProfileService RPCs)
   - Generate Go code: `protoc --go_out=. --go-grpc_out=. proto/*.proto`

3. **Service Scaffolding**
   - Create services/tutorial/ (main.go, internal/ structure)
   - Create services/practice/ (same structure)
   - Create services/mastery/ (same structure)
   - Create services/profile/ (extends existing auth service patterns)
   - Set up shared packages: db connections, auth middleware, caching

---

### Phase 1B: Tutorial System (Week 2)
**Priority: HIGH**

1. **Backend Implementation**
   - `/api/v1/tutorial/start` - Initialize tutorial
   - `/api/v1/tutorial/progress` - Get current progress
   - `/api/v1/tutorial/step/complete` - Mark step complete
   - `/api/v1/tutorial/skip` - Skip tutorial
   - `/api/v1/tutorial/cipher-visualization/:type` - Get visualization data
   - Seed tutorial_steps table with initial flow

2. **Flutter Client**
   - Create `lib/src/features/tutorial/`
   - `tutorial_service.dart` - API client
   - `tutorial_screen.dart` - Main tutorial flow screen
   - `widgets/tutorial_step_card.dart` - Step content widget
   - `widgets/cipher_visualization_widget.dart` - Interactive cipher demo
   - `widgets/tutorial_progress_bar.dart` - Progress indicator
   - Add route: `/tutorial` in app_routes.dart
   - Auto-redirect new users to tutorial on first login

3. **Integration**
   - Update auth service to set `is_new_user` flag
   - Redirect to tutorial after registration
   - Award XP on tutorial completion
   - Unlock features progressively

---

### Phase 1C: Practice Mode (Week 3)
**Priority: HIGH**

1. **Backend Implementation**
   - `/api/v1/practice/generate` - Generate practice puzzle
   - `/api/v1/practice/submit` - Submit solution
   - `/api/v1/practice/leaderboard/:cipher_type` - Personal bests
   - `/api/v1/practice/history` - Session history
   - Integrate with existing puzzle engine
   - Implement scoring algorithm (time + accuracy - hints)

2. **Flutter Client**
   - Create `lib/src/features/practice/`
   - `practice_service.dart` - API client
   - `practice_lobby_screen.dart` - Cipher selection + settings
   - `practice_session_screen.dart` - Active practice session
   - `practice_result_screen.dart` - Results + stats
   - `widgets/cipher_card.dart` - Cipher selection card
   - `widgets/difficulty_slider.dart` - Difficulty selector
   - `widgets/practice_timer.dart` - Timer component
   - Add route: `/practice` in app_routes.dart
   - Add "Practice Mode" button to main menu

3. **Integration**
   - Link to mastery system (award mastery XP)
   - Update player_cipher_stats on each session
   - Cache personal bests in Redis
   - Track practice sessions in analytics

---

### Phase 1D: Mastery Tree System (Week 4)
**Priority: HIGH**

1. **Backend Implementation**
   - `/api/v1/mastery/overview` - All cipher mastery overview
   - `/api/v1/mastery/cipher/:type` - Detailed skill tree
   - `/api/v1/mastery/unlock-node` - Unlock tree node
   - `/api/v1/mastery/award-xp` - Internal XP award endpoint
   - Seed mastery_nodes table with all cipher trees
   - Implement XP calculation logic (base + multipliers)
   - Auto-level-up logic with tier progression

2. **Flutter Client**
   - Create `lib/src/features/mastery/`
   - `mastery_service.dart` - API client
   - `mastery_overview_screen.dart` - All ciphers overview
   - `mastery_tree_screen.dart` - Detailed skill tree view
   - `widgets/cipher_mastery_card.dart` - Cipher card with progress
   - `widgets/skill_tree_node.dart` - Tree node widget
   - `widgets/skill_tree_canvas.dart` - Tree visualization (CustomPainter)
   - Add route: `/mastery` in app_routes.dart
   - Add "Mastery Tree" button to main menu

3. **Integration**
   - Call mastery XP award from game service (on match win)
   - Call mastery XP award from practice service (on solve)
   - Trigger achievement checks on level-up
   - Display mastery level on profile

---

### Phase 1E: Player Profile Dashboard (Week 5)
**Priority: MEDIUM**

1. **Backend Implementation**
   - `/api/v1/profile/:user_id` - Comprehensive profile
   - `/api/v1/profile/:user_id/cipher-stats` - Per-cipher stats
   - `/api/v1/profile/:user_id/match-history` - Match history
   - `/api/v1/profile/:user_id/achievements` - Achievement progress
   - Implement stats aggregation (use views)
   - Cache profile data in Redis (5min TTL)

2. **Flutter Client**
   - Enhance `lib/src/features/profile/`
   - `enhanced_profile_screen.dart` - Tabbed profile UI
   - `widgets/profile_header.dart` - Avatar + stats header
   - `widgets/match_stats_card.dart` - Match statistics
   - `widgets/cipher_stats_list.dart` - Per-cipher breakdown
   - `widgets/achievement_progress_card.dart` - Achievement display
   - Update route: `/profile` in app_routes.dart
   - Add "Profile" button to main menu

3. **Integration**
   - Link to mastery tree ("View Mastery" button)
   - Link to match history (detailed match view)
   - Real-time stats updates after matches
   - Export stats to CSV/JSON

---

### Phase 2: Additional Features (Week 6+)
**Priority: MEDIUM-LOW** (Post Phase 1)

1. **Daily Missions System**
2. **Replay/Spectator Mode**
3. **Cosmetics & Rewards**
4. **Social Features (Friends, Private Matches)**
5. **New Cipher Algorithms (Affine, Hill, Autokey)**
6. **Solo Game Modes (Survival, Time Attack)**

---

## Technical Considerations

### Performance Optimizations
- **Caching Strategy**: Redis for user profiles, mastery data, leaderboards (5-15min TTL)
- **Database Indexing**: All foreign keys, composite indexes for queries
- **Lazy Loading**: Paginate match history, practice sessions
- **Denormalized Stats**: Use player_cipher_stats for quick lookups

### Security
- **JWT Authentication**: All endpoints require valid JWT
- **Rate Limiting**: 100 req/min per user for practice/tutorial endpoints
- **Input Validation**: Sanitize all user inputs (solution text, cipher types)
- **Authorization**: Users can only access their own data (except public profiles)

### Error Handling
- **Graceful Failures**: Return user-friendly error messages
- **Retry Logic**: Client retries failed API calls (3 attempts with exponential backoff)
- **Offline Support**: Cache tutorial content for offline viewing

### Analytics & Monitoring
- **Event Tracking**: Log tutorial completions, practice sessions, node unlocks
- **Performance Metrics**: Track API response times, error rates
- **User Engagement**: Monitor tutorial skip rate, practice session duration
- **A/B Testing**: Test different XP reward values, tutorial flows

---

## Success Metrics

### Tutorial System
- **Completion Rate**: >70% of new users complete tutorial
- **Skip Rate**: <20% of users skip tutorial
- **Time to Complete**: Avg 8-12 minutes
- **Feature Unlock**: 90% unlock matchmaking after tutorial

### Practice Mode
- **Engagement**: Avg 5+ practice sessions per week per active user
- **Skill Improvement**: Measurable decrease in solve times over time
- **Mode Distribution**: Balanced usage across Untimed, Timed, Speed Run modes

### Mastery System
- **Progression**: Avg 2+ mastery levels gained per week
- **Node Unlocks**: Avg 1+ node unlocked per cipher per month
- **Retention**: Users with mastery progress have 2x higher retention

### Player Profile
- **Profile Views**: Avg 3+ profile views per session
- **Stats Engagement**: Users check stats after 80% of matches
- **Sharing**: 15% of users export/share stats

---

## Next Steps After Phase 1

1. **User Testing**: Conduct playtests with 10-20 beta users
2. **Feedback Iteration**: Adjust XP values, difficulty curves, tutorial flow
3. **Performance Tuning**: Optimize database queries, cache hit rates
4. **Phase 2 Planning**: Prioritize Daily Missions, Replay, or Cosmetics based on feedback
5. **Documentation**: API documentation, developer guides, user tutorials

---

**End of Design Document**
