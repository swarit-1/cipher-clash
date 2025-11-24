-- ============================================================================
-- CIPHER CLASH V2.0 - DATABASE SCHEMA
-- ============================================================================
-- This schema supports: authentication, matchmaking, gameplay, social features,
-- progression, achievements, and analytics for a competitive esports platform
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- USERS & AUTHENTICATION
-- ============================================================================

-- Users Table (Enhanced)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,

    -- Profile
    display_name VARCHAR(100),
    avatar_url VARCHAR(500),
    title VARCHAR(100), -- Unlockable titles like "Cipher Master", "Speed Demon"
    region VARCHAR(10) DEFAULT 'US', -- For regional matchmaking (US, EU, ASIA, etc.)

    -- Progression
    level INT DEFAULT 1,
    xp BIGINT DEFAULT 0,
    total_games INT DEFAULT 0,
    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    win_streak INT DEFAULT 0,
    best_win_streak INT DEFAULT 0,

    -- Rating (ELO/Glicko-2)
    elo_rating INT DEFAULT 1200,
    rating_deviation FLOAT DEFAULT 350.0, -- Glicko-2 RD
    volatility FLOAT DEFAULT 0.06, -- Glicko-2 volatility
    rank_tier VARCHAR(20) DEFAULT 'UNRANKED', -- UNRANKED, BRONZE, SILVER, GOLD, PLATINUM, DIAMOND, MASTER, GRANDMASTER

    -- Stats
    total_solve_time_ms BIGINT DEFAULT 0, -- Total milliseconds spent solving
    fastest_solve_ms INT, -- Fastest puzzle solve time
    puzzles_solved INT DEFAULT 0,
    hints_used INT DEFAULT 0,
    perfect_games INT DEFAULT 0, -- Games won without hints

    -- Account Status
    is_verified BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    banned_until TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Refresh Tokens Table (for JWT authentication)
CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45), -- Support IPv6
    user_agent TEXT
);

-- ============================================================================
-- SEASONS & COMPETITIVE
-- ============================================================================

CREATE TABLE seasons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT FALSE,
    rewards JSONB, -- Store season rewards configuration
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Seasonal Rankings (snapshot at end of season)
CREATE TABLE seasonal_rankings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    season_id INT NOT NULL REFERENCES seasons(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    final_elo INT NOT NULL,
    final_rank INT NOT NULL,
    total_games INT NOT NULL,
    wins INT NOT NULL,
    rank_tier VARCHAR(20) NOT NULL,
    rewards_claimed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(season_id, user_id)
);

-- ============================================================================
-- PUZZLES & GAME MODES
-- ============================================================================

-- Game Modes
CREATE TABLE game_modes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL, -- RANKED_1V1, QUICK_MATCH, TEAM_BATTLE, TOURNAMENT, DAILY_CHALLENGE, PRACTICE, BLITZ, SURVIVAL
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_ranked BOOLEAN DEFAULT FALSE,
    min_players INT DEFAULT 2,
    max_players INT DEFAULT 2,
    time_limit_seconds INT, -- NULL for unlimited
    config JSONB, -- Mode-specific configuration
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Puzzles Table (Enhanced)
CREATE TABLE puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cipher_type VARCHAR(50) NOT NULL, -- CAESAR, VIGENERE, RAIL_FENCE, PLAYFAIR, SUBSTITUTION, etc.
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),
    encrypted_text TEXT NOT NULL,
    plaintext TEXT NOT NULL,
    config JSONB, -- Cipher-specific params (key, shift, grid, etc.)

    -- Analytics
    times_used INT DEFAULT 0,
    times_solved INT DEFAULT 0,
    avg_solve_time_ms INT,
    success_rate FLOAT DEFAULT 0.0,

    -- Metadata
    tags TEXT[], -- Array of tags for categorization
    created_by UUID REFERENCES users(id), -- NULL for system-generated
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- MATCHES & GAMEPLAY
-- ============================================================================

CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_mode_id INT NOT NULL REFERENCES game_modes(id),
    season_id INT REFERENCES seasons(id),

    -- Players
    player1_id UUID NOT NULL REFERENCES users(id),
    player2_id UUID REFERENCES users(id), -- NULL for single-player modes
    winner_id UUID REFERENCES users(id),

    -- Match Data
    puzzle_id UUID REFERENCES puzzles(id),
    elo_change_p1 INT, -- ELO gained/lost by player 1
    elo_change_p2 INT, -- ELO gained/lost by player 2

    -- Timing
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    duration_ms INT, -- Total match duration

    -- Status
    status VARCHAR(20) DEFAULT 'WAITING', -- WAITING, IN_PROGRESS, COMPLETED, ABORTED, ABANDONED
    abort_reason TEXT,

    -- Replay
    replay_data JSONB, -- Store game events for replay
    replay_url VARCHAR(500), -- If stored externally

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Match Participants (for team modes)
CREATE TABLE match_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team INT NOT NULL, -- 1 or 2

    -- Performance
    solve_time_ms INT,
    hints_used INT DEFAULT 0,
    score INT DEFAULT 0,
    is_mvp BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Puzzle Attempts (track individual puzzle solves within matches)
CREATE TABLE puzzle_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    puzzle_id UUID NOT NULL REFERENCES puzzles(id),

    -- Attempt Data
    submitted_solution TEXT,
    is_correct BOOLEAN NOT NULL,
    solve_time_ms INT,
    hints_used INT DEFAULT 0,
    keystrokes INT DEFAULT 0,

    -- Timing
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- ACHIEVEMENTS & PROGRESSION
-- ============================================================================

-- Achievement Definitions
CREATE TABLE achievements (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL, -- e.g., "SPEED_DEMON_10"
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL, -- SPEED, MASTERY, STREAK, COLLECTION, SOCIAL, SPECIAL
    tier VARCHAR(20) DEFAULT 'BRONZE', -- BRONZE, SILVER, GOLD, PLATINUM, LEGENDARY

    -- Requirements
    requirement_type VARCHAR(50) NOT NULL, -- SOLVE_TIME, WIN_STREAK, TOTAL_WINS, CIPHER_MASTERY, etc.
    requirement_value INT NOT NULL,
    requirement_config JSONB, -- Additional requirements

    -- Rewards
    xp_reward INT DEFAULT 0,
    title_reward VARCHAR(100), -- Unlockable title
    avatar_reward VARCHAR(100), -- Unlockable avatar

    -- Display
    icon_url VARCHAR(500),
    badge_color VARCHAR(7), -- Hex color
    is_hidden BOOLEAN DEFAULT FALSE, -- Hidden until unlocked
    display_order INT DEFAULT 0,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- User Achievements (tracking)
CREATE TABLE user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id INT NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,

    -- Progress
    progress INT DEFAULT 0, -- Current progress towards achievement
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Metadata
    notified BOOLEAN DEFAULT FALSE, -- Whether user was notified
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, achievement_id)
);

-- Daily Quests
CREATE TABLE daily_quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quest_date DATE NOT NULL,

    -- Quest Definition
    quest_type VARCHAR(50) NOT NULL, -- WIN_GAMES, SOLVE_PUZZLES, PLAY_MODE, etc.
    quest_target INT NOT NULL, -- e.g., "Win 3 games"
    quest_config JSONB,

    -- Progress
    current_progress INT DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Reward
    xp_reward INT DEFAULT 100,
    is_claimed BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, quest_date, quest_type)
);

-- ============================================================================
-- SOCIAL FEATURES
-- ============================================================================

-- Friends
CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) DEFAULT 'PENDING', -- PENDING, ACCEPTED, BLOCKED

    -- Metadata
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,

    UNIQUE(user_id, friend_id),
    CHECK (user_id != friend_id)
);

-- Clans/Teams
CREATE TABLE clans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    tag VARCHAR(10) UNIQUE NOT NULL, -- e.g., [HACK]
    description TEXT,

    -- Settings
    owner_id UUID NOT NULL REFERENCES users(id),
    is_recruiting BOOLEAN DEFAULT TRUE,
    min_elo INT DEFAULT 0, -- Minimum ELO to join
    max_members INT DEFAULT 50,

    -- Stats
    total_members INT DEFAULT 1,
    total_wins INT DEFAULT 0,
    total_games INT DEFAULT 0,
    avg_elo INT DEFAULT 1200,

    -- Display
    logo_url VARCHAR(500),
    banner_url VARCHAR(500),
    primary_color VARCHAR(7), -- Hex color

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Clan Members
CREATE TABLE clan_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clan_id UUID NOT NULL REFERENCES clans(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(20) DEFAULT 'MEMBER', -- OWNER, ADMIN, MEMBER

    -- Stats
    games_played INT DEFAULT 0,
    contribution_score INT DEFAULT 0,

    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id) -- User can only be in one clan
);

-- Chat Messages (basic in-game chat)
CREATE TABLE chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Context
    match_id UUID REFERENCES matches(id) ON DELETE CASCADE, -- NULL for global/clan chat
    clan_id UUID REFERENCES clans(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES users(id) ON DELETE CASCADE, -- For direct messages

    -- Message
    message TEXT NOT NULL,
    is_system_message BOOLEAN DEFAULT FALSE,
    is_flagged BOOLEAN DEFAULT FALSE, -- Profanity/spam detection

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- ANALYTICS & METRICS
-- ============================================================================

-- Player Statistics (aggregated daily)
CREATE TABLE player_stats_daily (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    stat_date DATE NOT NULL,

    -- Daily Stats
    games_played INT DEFAULT 0,
    games_won INT DEFAULT 0,
    puzzles_solved INT DEFAULT 0,
    total_solve_time_ms BIGINT DEFAULT 0,
    hints_used INT DEFAULT 0,
    xp_gained INT DEFAULT 0,

    -- Performance
    avg_solve_time_ms INT,
    fastest_solve_ms INT,
    elo_change INT DEFAULT 0,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, stat_date)
);

-- Matchmaking Queue Metrics
CREATE TABLE queue_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    game_mode_id INT NOT NULL REFERENCES game_modes(id),

    -- Queue Data
    queued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    matched_at TIMESTAMP WITH TIME ZONE,
    queue_duration_ms INT,

    -- Matchmaking Details
    elo_at_queue INT,
    region VARCHAR(10),
    match_id UUID REFERENCES matches(id),

    -- Outcome
    was_matched BOOLEAN DEFAULT FALSE,
    cancel_reason VARCHAR(100) -- User cancelled, timeout, etc.
);

-- System Events (for monitoring and debugging)
CREATE TABLE system_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(100) NOT NULL, -- ERROR, WARNING, INFO, SECURITY
    service_name VARCHAR(50) NOT NULL, -- auth, matchmaker, game, etc.

    -- Event Data
    message TEXT NOT NULL,
    metadata JSONB,
    severity VARCHAR(20) DEFAULT 'INFO', -- INFO, WARNING, ERROR, CRITICAL

    -- Context
    user_id UUID REFERENCES users(id),
    match_id UUID REFERENCES matches(id),
    ip_address VARCHAR(45),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================

-- Users
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_elo_rating ON users(elo_rating DESC);
CREATE INDEX idx_users_region ON users(region);
CREATE INDEX idx_users_level ON users(level DESC);
CREATE INDEX idx_users_rank_tier ON users(rank_tier);
CREATE INDEX idx_users_created_at ON users(created_at DESC);

-- Refresh Tokens
CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_expires_at ON refresh_tokens(expires_at);
CREATE INDEX idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);

-- Matches
CREATE INDEX idx_matches_player1 ON matches(player1_id, created_at DESC);
CREATE INDEX idx_matches_player2 ON matches(player2_id, created_at DESC);
CREATE INDEX idx_matches_winner ON matches(winner_id);
CREATE INDEX idx_matches_status ON matches(status);
CREATE INDEX idx_matches_game_mode ON matches(game_mode_id);
CREATE INDEX idx_matches_season ON matches(season_id);
CREATE INDEX idx_matches_started_at ON matches(started_at DESC);

-- Puzzles
CREATE INDEX idx_puzzles_cipher_type ON puzzles(cipher_type);
CREATE INDEX idx_puzzles_difficulty ON puzzles(difficulty);
CREATE INDEX idx_puzzles_cipher_difficulty ON puzzles(cipher_type, difficulty);
CREATE INDEX idx_puzzles_active ON puzzles(is_active);

-- Achievements
CREATE INDEX idx_user_achievements_user_id ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_completed ON user_achievements(user_id, is_completed);

-- Friendships
CREATE INDEX idx_friendships_user_id ON friendships(user_id);
CREATE INDEX idx_friendships_friend_id ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);

-- Clans
CREATE INDEX idx_clan_members_clan_id ON clan_members(clan_id);
CREATE INDEX idx_clan_members_user_id ON clan_members(user_id);

-- Analytics
CREATE INDEX idx_player_stats_daily_user_date ON player_stats_daily(user_id, stat_date DESC);
CREATE INDEX idx_queue_metrics_user_id ON queue_metrics(user_id);
CREATE INDEX idx_queue_metrics_queued_at ON queue_metrics(queued_at DESC);

-- System Events
CREATE INDEX idx_system_events_type ON system_events(event_type);
CREATE INDEX idx_system_events_created_at ON system_events(created_at DESC);
CREATE INDEX idx_system_events_user_id ON system_events(user_id);

-- ============================================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================================

-- Update updated_at timestamp automatically
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clans_updated_at BEFORE UPDATE ON clans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Calculate rank tier based on ELO
CREATE OR REPLACE FUNCTION calculate_rank_tier(elo INT)
RETURNS VARCHAR(20) AS $$
BEGIN
    IF elo < 1200 THEN RETURN 'UNRANKED';
    ELSIF elo < 1400 THEN RETURN 'BRONZE';
    ELSIF elo < 1600 THEN RETURN 'SILVER';
    ELSIF elo < 1800 THEN RETURN 'GOLD';
    ELSIF elo < 2000 THEN RETURN 'PLATINUM';
    ELSIF elo < 2200 THEN RETURN 'DIAMOND';
    ELSIF elo < 2500 THEN RETURN 'MASTER';
    ELSE RETURN 'GRANDMASTER';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Auto-update rank tier when ELO changes
CREATE OR REPLACE FUNCTION update_rank_tier()
RETURNS TRIGGER AS $$
BEGIN
    NEW.rank_tier = calculate_rank_tier(NEW.elo_rating);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER auto_update_rank_tier BEFORE UPDATE ON users
    FOR EACH ROW
    WHEN (OLD.elo_rating IS DISTINCT FROM NEW.elo_rating)
    EXECUTE FUNCTION update_rank_tier();

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Insert default game modes
INSERT INTO game_modes (name, display_name, description, is_ranked, min_players, max_players, time_limit_seconds) VALUES
('RANKED_1V1', 'Ranked 1v1', 'Classic competitive mode with seasonal rankings', TRUE, 2, 2, 600),
('QUICK_MATCH', 'Quick Match', 'Fast 3-minute rounds for casual play', FALSE, 2, 2, 180),
('TEAM_BATTLE', 'Team Battle 2v2', 'Collaborative cipher solving in teams', TRUE, 4, 4, 600),
('TOURNAMENT', 'Tournament Mode', 'Bracket-style elimination tournaments', TRUE, 2, 64, NULL),
('DAILY_CHALLENGE', 'Daily Challenge', 'Single-player puzzle of the day', FALSE, 1, 1, 300),
('PRACTICE', 'Practice Mode', 'Unlimited practice with specific cipher types', FALSE, 1, 1, NULL),
('BLITZ', 'Blitz Mode', 'Rapid-fire 30-second puzzle sprints', FALSE, 2, 2, 30),
('SURVIVAL', 'Survival Mode', 'Continuous puzzles with increasing difficulty', FALSE, 1, 1, NULL);

-- Insert first season
INSERT INTO seasons (name, description, start_date, end_date, is_active) VALUES
('Season 1: Genesis', 'The first competitive season of Cipher Clash', NOW(), NOW() + INTERVAL '90 days', TRUE);

-- ============================================================================
-- VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Leaderboard View
CREATE OR REPLACE VIEW leaderboard AS
SELECT
    u.id,
    u.username,
    u.display_name,
    u.avatar_url,
    u.elo_rating,
    u.rank_tier,
    u.level,
    u.total_games,
    u.wins,
    u.losses,
    CASE WHEN u.total_games > 0 THEN ROUND((u.wins::FLOAT / u.total_games::FLOAT) * 100, 2) ELSE 0 END as win_rate,
    u.win_streak,
    u.best_win_streak,
    ROW_NUMBER() OVER (ORDER BY u.elo_rating DESC) as rank
FROM users u
WHERE u.is_banned = FALSE AND u.total_games >= 10
ORDER BY u.elo_rating DESC;

-- User Profile Stats View
CREATE OR REPLACE VIEW user_profile_stats AS
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
    u.total_games,
    u.wins,
    u.losses,
    u.win_streak,
    u.best_win_streak,
    u.puzzles_solved,
    u.fastest_solve_ms,
    CASE WHEN u.total_solve_time_ms > 0 AND u.puzzles_solved > 0
        THEN u.total_solve_time_ms / u.puzzles_solved
        ELSE 0 END as avg_solve_time_ms,
    (SELECT COUNT(*) FROM user_achievements ua WHERE ua.user_id = u.id AND ua.is_completed = TRUE) as achievements_unlocked,
    (SELECT COUNT(*) FROM friendships f WHERE f.user_id = u.id AND f.status = 'ACCEPTED') as friend_count,
    (SELECT c.name FROM clan_members cm JOIN clans c ON c.id = cm.clan_id WHERE cm.user_id = u.id) as clan_name
FROM users u;

COMMENT ON TABLE users IS 'Core user accounts with authentication, profile, and competitive stats';
COMMENT ON TABLE matches IS 'Individual matches/games with results and replay data';
COMMENT ON TABLE puzzles IS 'Cipher puzzles with difficulty ratings and analytics';
COMMENT ON TABLE achievements IS 'Achievement definitions and requirements';
COMMENT ON TABLE clans IS 'Player teams/guilds for social gameplay';
