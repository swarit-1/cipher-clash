-- Migration: Add Engagement Features (Tutorial, Practice, Mastery, Profile)
-- Version: 003
-- Date: 2025-01-26
-- Description: Adds tables and views for tutorial system, practice mode, mastery tree, and enhanced player profiles

-- ============================================================================
-- 1. TUTORIAL SYSTEM
-- ============================================================================

-- Table: tutorial_progress
-- Tracks user progress through the tutorial system
CREATE TABLE IF NOT EXISTS tutorial_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Overall tutorial state
    is_tutorial_completed BOOLEAN DEFAULT FALSE,
    current_step_id VARCHAR(100),
    total_steps_completed INT DEFAULT 0,

    -- Tutorial-specific cipher practice
    ciphers_introduced TEXT[] DEFAULT '{}',
    practice_puzzles_solved JSONB DEFAULT '{}',

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

-- Table: tutorial_steps
-- Configuration for tutorial flow (static data)
CREATE TABLE IF NOT EXISTS tutorial_steps (
    id VARCHAR(100) PRIMARY KEY,
    step_number INT NOT NULL,
    category VARCHAR(50),

    -- Content
    title VARCHAR(200) NOT NULL,
    description TEXT,
    instruction_text TEXT,

    -- Interactive elements
    cipher_type VARCHAR(50),
    practice_puzzle_id UUID REFERENCES puzzles(id),
    requires_completion BOOLEAN DEFAULT TRUE,

    -- Flow control
    next_step_id VARCHAR(100),
    previous_step_id VARCHAR(100),
    is_optional BOOLEAN DEFAULT FALSE,

    -- Rewards
    xp_reward INT DEFAULT 10,
    unlock_feature VARCHAR(100),

    -- Visualization
    visualization_type VARCHAR(50),
    animation_data JSONB,

    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tutorial_steps_order ON tutorial_steps(step_number);
CREATE INDEX idx_tutorial_steps_cipher ON tutorial_steps(cipher_type) WHERE cipher_type IS NOT NULL;

-- ============================================================================
-- 2. PRACTICE MODE
-- ============================================================================

-- Table: practice_sessions
-- Tracks individual practice puzzle sessions
CREATE TABLE IF NOT EXISTS practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    puzzle_id UUID NOT NULL REFERENCES puzzles(id),

    -- Session metadata
    cipher_type VARCHAR(50) NOT NULL,
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),
    mode VARCHAR(50) DEFAULT 'UNTIMED',

    -- Timing
    started_at TIMESTAMP DEFAULT NOW(),
    submitted_at TIMESTAMP,
    solve_time_ms BIGINT,
    time_limit_ms BIGINT,

    -- Solution
    user_solution TEXT,
    is_correct BOOLEAN,
    accuracy_percentage DECIMAL(5,2),

    -- Assistance
    hints_used INT DEFAULT 0,
    hint_timestamps JSONB DEFAULT '[]',
    visualizations_viewed INT DEFAULT 0,

    -- Scoring
    score INT,
    perfect_solve BOOLEAN DEFAULT FALSE,

    -- Stats
    attempts INT DEFAULT 1,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_practice_user ON practice_sessions(user_id);
CREATE INDEX idx_practice_cipher ON practice_sessions(user_id, cipher_type);
CREATE INDEX idx_practice_date ON practice_sessions(user_id, started_at DESC);
CREATE INDEX idx_practice_completed ON practice_sessions(user_id, is_correct) WHERE is_correct = TRUE;

-- Table: practice_leaderboards
-- Per-cipher personal best records
CREATE TABLE IF NOT EXISTS practice_leaderboards (
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

-- ============================================================================
-- 3. MASTERY TREE SYSTEM
-- ============================================================================

-- Table: cipher_mastery
-- Per-cipher mastery progression for each user
CREATE TABLE IF NOT EXISTS cipher_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,

    -- Core progression
    mastery_level INT DEFAULT 0 CHECK (mastery_level BETWEEN 0 AND 100),
    mastery_xp INT DEFAULT 0,
    xp_to_next_level INT DEFAULT 100,

    -- Tier progression
    mastery_tier VARCHAR(50) DEFAULT 'NOVICE',
    tier_progress_percentage DECIMAL(5,2) DEFAULT 0.00,

    -- Statistics
    puzzles_solved INT DEFAULT 0,
    puzzles_solved_ranked INT DEFAULT 0,
    puzzles_solved_practice INT DEFAULT 0,

    perfect_solves INT DEFAULT 0,
    average_solve_time_ms BIGINT,
    fastest_solve_ms BIGINT,

    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    win_rate DECIMAL(5,2) DEFAULT 0.00,

    -- Skill tree nodes unlocked
    nodes_unlocked TEXT[] DEFAULT '{}',
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

-- Function: calculate_mastery_tier
-- Determines mastery tier based on level
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

-- Trigger: update_mastery_tier
-- Auto-updates mastery tier when level changes
CREATE OR REPLACE FUNCTION update_mastery_tier() RETURNS TRIGGER AS $$
BEGIN
    NEW.mastery_tier = calculate_mastery_tier(NEW.mastery_level);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_mastery_tier
    BEFORE INSERT OR UPDATE OF mastery_level ON cipher_mastery
    FOR EACH ROW
    EXECUTE FUNCTION update_mastery_tier();

-- Table: mastery_nodes
-- Skill tree node definitions (configuration)
CREATE TABLE IF NOT EXISTS mastery_nodes (
    id VARCHAR(100) PRIMARY KEY,
    cipher_type VARCHAR(50) NOT NULL,

    -- Tree structure
    node_type VARCHAR(50) NOT NULL,
    tier INT NOT NULL CHECK (tier BETWEEN 1 AND 5),
    position_x INT,
    position_y INT,

    -- Unlock requirements
    required_mastery_level INT NOT NULL,
    prerequisite_nodes TEXT[] DEFAULT '{}',
    required_puzzles_solved INT DEFAULT 0,
    required_perfect_solves INT DEFAULT 0,

    -- Node effects/rewards
    title VARCHAR(200) NOT NULL,
    description TEXT,

    -- Passive bonuses
    bonus_type VARCHAR(50),
    bonus_value DECIMAL(5,2),

    -- Cosmetic unlocks
    unlocks_cosmetic_id VARCHAR(100),
    unlocks_title VARCHAR(100),
    unlocks_avatar_frame VARCHAR(100),

    -- Metadata
    icon_url TEXT,
    is_ultimate BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mastery_nodes_cipher ON mastery_nodes(cipher_type, tier);
CREATE INDEX idx_mastery_nodes_level ON mastery_nodes(required_mastery_level);

-- Table: mastery_xp_events
-- Audit log for XP gains
CREATE TABLE IF NOT EXISTS mastery_xp_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,

    -- Event details
    event_type VARCHAR(50) NOT NULL,
    xp_gained INT NOT NULL,
    multiplier DECIMAL(5,2) DEFAULT 1.0,

    -- Context
    session_id UUID,
    context JSONB,

    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mastery_xp_user ON mastery_xp_events(user_id, cipher_type, created_at DESC);

-- ============================================================================
-- 4. PLAYER PROFILE & STATS
-- ============================================================================

-- Table: player_cipher_stats
-- Detailed per-cipher statistics for profiles
CREATE TABLE IF NOT EXISTS player_cipher_stats (
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
    difficulty_breakdown JSONB DEFAULT '{}',

    -- Accuracy
    perfect_solves INT DEFAULT 0,
    hints_used INT DEFAULT 0,
    hints_per_puzzle DECIMAL(5,2) DEFAULT 0.00,

    -- Rankings
    global_rank INT,
    percentile DECIMAL(5,2),

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

-- View: user_comprehensive_stats
-- Comprehensive user statistics for profile dashboard
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
    (SELECT COALESCE(AVG(cm.mastery_level), 0) FROM cipher_mastery cm WHERE cm.user_id = u.id) as avg_mastery_level,

    -- Activity
    u.last_login_at,
    u.created_at as account_created_at

FROM users u;

-- View: match_history_detailed
-- Enhanced match records for profile
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

-- ============================================================================
-- 5. SEED DATA
-- ============================================================================

-- Seed tutorial steps
INSERT INTO tutorial_steps (id, step_number, category, title, description, cipher_type, requires_completion, xp_reward, next_step_id) VALUES
('intro_welcome', 1, 'INTRODUCTION', 'Welcome to Cipher Clash', 'Learn the basics of cipher battles', NULL, FALSE, 10, 'intro_game_overview'),
('intro_game_overview', 2, 'INTRODUCTION', 'How to Play', 'Understand matchmaking and gameplay', NULL, TRUE, 10, 'cipher_caesar_intro'),
('cipher_caesar_intro', 3, 'CIPHER_BASICS', 'Caesar Cipher', 'Your first cipher - the classic shift cipher', 'CAESAR', TRUE, 20, 'cipher_caesar_practice'),
('cipher_caesar_practice', 4, 'PRACTICE', 'Practice: Caesar', 'Solve your first Caesar cipher puzzle', 'CAESAR', TRUE, 50, 'cipher_vigenere_intro'),
('cipher_vigenere_intro', 5, 'CIPHER_BASICS', 'Vigenère Cipher', 'Learn the polyalphabetic keyword cipher', 'VIGENERE', TRUE, 20, 'cipher_vigenere_practice'),
('cipher_vigenere_practice', 6, 'PRACTICE', 'Practice: Vigenère', 'Crack a Vigenère cipher', 'VIGENERE', TRUE, 50, 'game_mechanics_intro'),
('game_mechanics_intro', 7, 'GAME_MECHANICS', 'Battle Mechanics', 'Learn about hints, timers, and power-ups', NULL, TRUE, 10, 'game_mechanics_matchmaking'),
('game_mechanics_matchmaking', 8, 'GAME_MECHANICS', 'Matchmaking System', 'Understand ELO ratings and ranks', NULL, TRUE, 10, 'tutorial_complete'),
('tutorial_complete', 9, 'COMPLETION', 'Tutorial Complete!', 'You are ready for your first match', NULL, FALSE, 100, NULL)
ON CONFLICT (id) DO NOTHING;

-- Seed mastery nodes for Caesar cipher
INSERT INTO mastery_nodes (id, cipher_type, node_type, tier, title, description, required_mastery_level, prerequisite_nodes, bonus_type, bonus_value, position_x, position_y) VALUES
('CAESAR_CORE_1', 'CAESAR', 'CORE', 1, 'Caesar Initiate', 'Master the basics of shift ciphers', 0, '{}', 'XP_MULTIPLIER', 1.1, 0, 0),
('CAESAR_SPEED_1', 'CAESAR', 'SPEED', 1, 'Quick Shifter', 'Solve Caesar ciphers 10% faster', 5, ARRAY['CAESAR_CORE_1'], 'TIME_BONUS', 1.1, -1, 1),
('CAESAR_ACCURACY_1', 'CAESAR', 'ACCURACY', 1, 'Careful Decoder', 'Improved accuracy with Caesar ciphers', 5, ARRAY['CAESAR_CORE_1'], 'HINT_COST_REDUCTION', 0.9, 1, 1),
('CAESAR_CORE_2', 'CAESAR', 'CORE', 2, 'Caesar Adept', 'Advanced shift cipher techniques', 10, ARRAY['CAESAR_CORE_1'], 'XP_MULTIPLIER', 1.2, 0, 2),
('CAESAR_REWARD_1', 'CAESAR', 'REWARD', 2, 'Shift Master Badge', 'Unlock Caesar mastery cosmetic', 15, ARRAY['CAESAR_CORE_2'], NULL, NULL, 0, 3),
('CAESAR_SPEED_2', 'CAESAR', 'SPEED', 3, 'Lightning Shifter', 'Solve Caesar ciphers 25% faster', 30, ARRAY['CAESAR_SPEED_1', 'CAESAR_CORE_2'], 'TIME_BONUS', 1.25, -1, 3),
('CAESAR_ACCURACY_2', 'CAESAR', 'ACCURACY', 3, 'Precision Decoder', 'Near-perfect Caesar decryption', 30, ARRAY['CAESAR_ACCURACY_1', 'CAESAR_CORE_2'], 'HINT_COST_REDUCTION', 0.7, 1, 3),
('CAESAR_CORE_3', 'CAESAR', 'CORE', 3, 'Caesar Expert', 'Expert-level shift cipher mastery', 50, ARRAY['CAESAR_CORE_2'], 'XP_MULTIPLIER', 1.5, 0, 4),
('CAESAR_ULTIMATE', 'CAESAR', 'ULTIMATE', 5, 'Caesar Grandmaster', 'Ultimate mastery of shift ciphers', 80, ARRAY['CAESAR_CORE_3'], 'XP_MULTIPLIER', 2.0, 0, 5)
ON CONFLICT (id) DO NOTHING;

-- Seed mastery nodes for Vigenere cipher
INSERT INTO mastery_nodes (id, cipher_type, node_type, tier, title, description, required_mastery_level, prerequisite_nodes, bonus_type, bonus_value, position_x, position_y) VALUES
('VIGENERE_CORE_1', 'VIGENERE', 'CORE', 1, 'Vigenère Initiate', 'Learn keyword-based encryption', 0, '{}', 'XP_MULTIPLIER', 1.1, 0, 0),
('VIGENERE_SPEED_1', 'VIGENERE', 'SPEED', 1, 'Quick Keyword', 'Faster Vigenère solving', 5, ARRAY['VIGENERE_CORE_1'], 'TIME_BONUS', 1.1, -1, 1),
('VIGENERE_ACCURACY_1', 'VIGENERE', 'ACCURACY', 1, 'Pattern Recognition', 'Identify repeating patterns', 5, ARRAY['VIGENERE_CORE_1'], 'HINT_COST_REDUCTION', 0.9, 1, 1),
('VIGENERE_CORE_2', 'VIGENERE', 'CORE', 2, 'Vigenère Adept', 'Advanced polyalphabetic techniques', 10, ARRAY['VIGENERE_CORE_1'], 'XP_MULTIPLIER', 1.2, 0, 2),
('VIGENERE_CORE_3', 'VIGENERE', 'CORE', 3, 'Vigenère Expert', 'Expert keyword cryptanalysis', 50, ARRAY['VIGENERE_CORE_2'], 'XP_MULTIPLIER', 1.5, 0, 4),
('VIGENERE_ULTIMATE', 'VIGENERE', 'ULTIMATE', 5, 'Vigenère Grandmaster', 'Master of polyalphabetic ciphers', 80, ARRAY['VIGENERE_CORE_3'], 'XP_MULTIPLIER', 2.0, 0, 5)
ON CONFLICT (id) DO NOTHING;

-- ============================================================================
-- 6. HELPER FUNCTIONS
-- ============================================================================

-- Function: update_practice_leaderboard
-- Updates personal best records after practice session
CREATE OR REPLACE FUNCTION update_practice_leaderboard() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_correct = TRUE THEN
        INSERT INTO practice_leaderboards (
            user_id,
            cipher_type,
            difficulty,
            fastest_solve_ms,
            fastest_session_id,
            highest_score,
            highest_score_session_id,
            total_practice_sessions,
            perfect_solves,
            average_solve_time_ms
        ) VALUES (
            NEW.user_id,
            NEW.cipher_type,
            NEW.difficulty,
            NEW.solve_time_ms,
            NEW.id,
            NEW.score,
            NEW.id,
            1,
            CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            NEW.solve_time_ms
        )
        ON CONFLICT (user_id, cipher_type, difficulty) DO UPDATE SET
            fastest_solve_ms = CASE
                WHEN NEW.solve_time_ms < practice_leaderboards.fastest_solve_ms
                THEN NEW.solve_time_ms
                ELSE practice_leaderboards.fastest_solve_ms
            END,
            fastest_session_id = CASE
                WHEN NEW.solve_time_ms < practice_leaderboards.fastest_solve_ms
                THEN NEW.id
                ELSE practice_leaderboards.fastest_session_id
            END,
            highest_score = CASE
                WHEN NEW.score > practice_leaderboards.highest_score
                THEN NEW.score
                ELSE practice_leaderboards.highest_score
            END,
            highest_score_session_id = CASE
                WHEN NEW.score > practice_leaderboards.highest_score
                THEN NEW.id
                ELSE practice_leaderboards.highest_score_session_id
            END,
            total_practice_sessions = practice_leaderboards.total_practice_sessions + 1,
            perfect_solves = practice_leaderboards.perfect_solves + CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            average_solve_time_ms = (
                (practice_leaderboards.average_solve_time_ms * practice_leaderboards.total_practice_sessions + NEW.solve_time_ms)
                / (practice_leaderboards.total_practice_sessions + 1)
            ),
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_practice_leaderboard
    AFTER INSERT ON practice_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_practice_leaderboard();

-- Function: update_player_cipher_stats
-- Updates player cipher stats after practice or match
CREATE OR REPLACE FUNCTION update_player_cipher_stats_from_practice() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_correct = TRUE THEN
        INSERT INTO player_cipher_stats (
            user_id,
            cipher_type,
            practice_sessions,
            practice_perfect_solves,
            total_puzzles_solved,
            total_solve_time_ms,
            average_solve_time_ms,
            fastest_solve_ms,
            perfect_solves,
            hints_used,
            hints_per_puzzle,
            first_played_at,
            last_played_at
        ) VALUES (
            NEW.user_id,
            NEW.cipher_type,
            1,
            CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            1,
            NEW.solve_time_ms,
            NEW.solve_time_ms,
            NEW.solve_time_ms,
            CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            NEW.hints_used,
            NEW.hints_used,
            NOW(),
            NOW()
        )
        ON CONFLICT (user_id, cipher_type) DO UPDATE SET
            practice_sessions = player_cipher_stats.practice_sessions + 1,
            practice_perfect_solves = player_cipher_stats.practice_perfect_solves + CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            total_puzzles_solved = player_cipher_stats.total_puzzles_solved + 1,
            total_solve_time_ms = player_cipher_stats.total_solve_time_ms + NEW.solve_time_ms,
            average_solve_time_ms = (
                (player_cipher_stats.total_solve_time_ms + NEW.solve_time_ms)
                / (player_cipher_stats.total_puzzles_solved + 1)
            ),
            fastest_solve_ms = CASE
                WHEN NEW.solve_time_ms < player_cipher_stats.fastest_solve_ms OR player_cipher_stats.fastest_solve_ms IS NULL
                THEN NEW.solve_time_ms
                ELSE player_cipher_stats.fastest_solve_ms
            END,
            perfect_solves = player_cipher_stats.perfect_solves + CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            hints_used = player_cipher_stats.hints_used + NEW.hints_used,
            hints_per_puzzle = (
                (player_cipher_stats.hints_used + NEW.hints_used)::DECIMAL
                / (player_cipher_stats.total_puzzles_solved + 1)::DECIMAL
            ),
            last_played_at = NOW(),
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_player_cipher_stats_practice
    AFTER INSERT ON practice_sessions
    FOR EACH ROW
    EXECUTE FUNCTION update_player_cipher_stats_from_practice();

-- ============================================================================
-- 7. COMMENTS
-- ============================================================================

COMMENT ON TABLE tutorial_progress IS 'Tracks user progress through the tutorial system';
COMMENT ON TABLE tutorial_steps IS 'Static configuration for tutorial flow';
COMMENT ON TABLE practice_sessions IS 'Individual practice puzzle sessions';
COMMENT ON TABLE practice_leaderboards IS 'Per-cipher personal best records';
COMMENT ON TABLE cipher_mastery IS 'Per-cipher mastery progression';
COMMENT ON TABLE mastery_nodes IS 'Skill tree node definitions';
COMMENT ON TABLE mastery_xp_events IS 'Audit log for mastery XP gains';
COMMENT ON TABLE player_cipher_stats IS 'Detailed per-cipher statistics';
COMMENT ON VIEW user_comprehensive_stats IS 'Comprehensive user stats for profile dashboard';
COMMENT ON VIEW match_history_detailed IS 'Enhanced match records with puzzle and mode details';

-- Migration complete
