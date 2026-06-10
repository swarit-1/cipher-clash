-- ============================================================================
-- 0001_baseline — Cipher Clash consolidated schema
-- ============================================================================
-- Replaces the former schema_v2.sql + 001/003 migrations, which contradicted
-- each other and the service code. Every table here matches the columns the
-- Go services actually query.
-- ============================================================================

-- ============================================================================
-- USERS & AUTHENTICATION (pkg/repository, services/auth)
-- ============================================================================

CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,

    -- Profile
    display_name VARCHAR(100),
    avatar_url VARCHAR(500),
    title VARCHAR(100),
    region VARCHAR(10) DEFAULT 'US',

    -- Progression
    level INT DEFAULT 1,
    xp BIGINT DEFAULT 0,
    coins INT DEFAULT 0,
    total_games INT DEFAULT 0,
    wins INT DEFAULT 0,
    losses INT DEFAULT 0,
    win_streak INT DEFAULT 0,
    best_win_streak INT DEFAULT 0,

    -- Rating
    elo_rating INT DEFAULT 1200,
    rating_deviation FLOAT DEFAULT 350.0,
    volatility FLOAT DEFAULT 0.06,
    rank_tier VARCHAR(20) DEFAULT 'UNRANKED',

    -- Stats
    total_solve_time_ms BIGINT DEFAULT 0,
    fastest_solve_ms INT,
    puzzles_solved INT DEFAULT 0,
    hints_used INT DEFAULT 0,
    perfect_games INT DEFAULT 0,

    -- Account status
    is_bot BOOLEAN DEFAULT FALSE,
    is_verified BOOLEAN DEFAULT FALSE,
    is_banned BOOLEAN DEFAULT FALSE,
    ban_reason TEXT,
    banned_until TIMESTAMP WITH TIME ZONE,
    last_login_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    revoked_at TIMESTAMP WITH TIME ZONE,
    ip_address VARCHAR(45),
    user_agent TEXT
);

-- ============================================================================
-- SEASONS, GAME MODES, PUZZLES (services/matchmaker, services/puzzle_engine)
-- ============================================================================

CREATE TABLE seasons (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    start_date TIMESTAMP WITH TIME ZONE NOT NULL,
    end_date TIMESTAMP WITH TIME ZONE NOT NULL,
    is_active BOOLEAN DEFAULT FALSE,
    rewards JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE game_modes (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    display_name VARCHAR(100) NOT NULL,
    description TEXT,
    is_ranked BOOLEAN DEFAULT FALSE,
    min_players INT DEFAULT 2,
    max_players INT DEFAULT 2,
    time_limit_seconds INT,
    config JSONB,
    is_enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE puzzles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    cipher_type VARCHAR(50) NOT NULL,
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),
    encrypted_text TEXT NOT NULL,
    plaintext TEXT NOT NULL,
    config JSONB,

    times_used INT DEFAULT 0,
    times_solved INT DEFAULT 0,
    avg_solve_time_ms INT,
    success_rate FLOAT DEFAULT 0.0,

    tags TEXT[],
    created_by UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- MATCHES & GAMEPLAY (services/matchmaker, services/game)
-- ============================================================================

CREATE TABLE matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_mode_id INT NOT NULL REFERENCES game_modes(id),
    season_id INT REFERENCES seasons(id),

    player1_id UUID NOT NULL REFERENCES users(id),
    player2_id UUID REFERENCES users(id),
    winner_id UUID REFERENCES users(id),

    puzzle_id UUID REFERENCES puzzles(id),
    elo_change_p1 INT,
    elo_change_p2 INT,

    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    duration_ms INT,

    status VARCHAR(20) DEFAULT 'WAITING', -- WAITING, IN_PROGRESS, COMPLETED, ABORTED, ABANDONED
    abort_reason TEXT,

    replay_data JSONB,
    replay_url VARCHAR(500),

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE match_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    team INT NOT NULL,

    solve_time_ms INT,
    hints_used INT DEFAULT 0,
    score INT DEFAULT 0,
    is_mvp BOOLEAN DEFAULT FALSE,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE puzzle_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    puzzle_id UUID NOT NULL REFERENCES puzzles(id),

    submitted_solution TEXT,
    is_correct BOOLEAN NOT NULL,
    solve_time_ms INT,
    hints_used INT DEFAULT 0,
    keystrokes INT DEFAULT 0,

    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE queue_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    game_mode_id INT NOT NULL REFERENCES game_modes(id),

    queued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    matched_at TIMESTAMP WITH TIME ZONE,
    queue_duration_ms INT,

    elo_at_queue INT,
    region VARCHAR(10),
    match_id UUID REFERENCES matches(id),

    was_matched BOOLEAN DEFAULT FALSE,
    cancel_reason VARCHAR(100)
);

-- ============================================================================
-- ACHIEVEMENTS (services/achievement: string ids, icon/rarity/requirement/total)
-- ============================================================================

CREATE TABLE achievements (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    icon VARCHAR(100) NOT NULL DEFAULT '🏆',
    rarity VARCHAR(20) NOT NULL DEFAULT 'COMMON', -- COMMON, RARE, EPIC, LEGENDARY
    xp_reward INT NOT NULL DEFAULT 0,
    requirement TEXT NOT NULL, -- JSON criteria, e.g. {"type":"TOTAL_WINS"}
    total INT NOT NULL DEFAULT 1, -- progress target
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id VARCHAR(100) NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    progress INT DEFAULT 0,
    unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

-- ============================================================================
-- TUTORIAL (services/tutorial: tutorial_steps + user_tutorial_progress)
-- ============================================================================

CREATE TABLE tutorial_steps (
    id VARCHAR(100) PRIMARY KEY,
    step_number INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    type VARCHAR(50) NOT NULL DEFAULT 'TEXT', -- INTERACTIVE, VIDEO, TEXT, QUIZ, PRACTICE
    content TEXT NOT NULL DEFAULT '{}', -- JSON content based on type
    cipher_type VARCHAR(50),
    required BOOLEAN NOT NULL DEFAULT TRUE,
    order_index INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE user_tutorial_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    step_id VARCHAR(100) NOT NULL REFERENCES tutorial_steps(id) ON DELETE CASCADE,
    completed BOOLEAN NOT NULL DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    time_spent_secs INT NOT NULL DEFAULT 0,
    score INT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, step_id)
);

-- ============================================================================
-- MISSIONS (services/missions: title/frequency/claimed_at shape)
-- ============================================================================

CREATE TABLE mission_templates (
    id VARCHAR(100) PRIMARY KEY,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL, -- WINS, PUZZLES, CIPHER_SPECIFIC, STREAK, PLAY
    frequency VARCHAR(20) NOT NULL DEFAULT 'daily', -- daily, weekly
    target INT NOT NULL DEFAULT 1,
    xp_reward INT NOT NULL DEFAULT 100,
    coin_reward INT NOT NULL DEFAULT 0,
    difficulty_level INT NOT NULL DEFAULT 1,
    icon VARCHAR(100) NOT NULL DEFAULT '🎯',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE user_missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id VARCHAR(100) NOT NULL REFERENCES mission_templates(id),
    progress INT NOT NULL DEFAULT 0,
    target INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, completed, claimed, expired
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    claimed_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, template_id, assigned_date)
);

-- ============================================================================
-- MASTERY (services/mastery: mastery_nodes/user_mastery/cipher_mastery_points)
-- ============================================================================

CREATE TABLE mastery_nodes (
    id VARCHAR(100) PRIMARY KEY,
    cipher_type VARCHAR(50) NOT NULL,
    tier INT NOT NULL CHECK (tier BETWEEN 1 AND 5),
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    unlock_cost INT NOT NULL DEFAULT 100,
    prerequisite_node_id VARCHAR(100) REFERENCES mastery_nodes(id),
    bonus_type VARCHAR(50), -- XP_MULTIPLIER, TIME_BONUS, HINT_COST_REDUCTION
    bonus_value DECIMAL(5,2),
    icon VARCHAR(100) NOT NULL DEFAULT '⭐',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE user_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    node_id VARCHAR(100) NOT NULL REFERENCES mastery_nodes(id),
    unlocked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    points_spent INT NOT NULL DEFAULT 0,
    UNIQUE(user_id, node_id)
);

CREATE TABLE cipher_mastery_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,
    total_points INT NOT NULL DEFAULT 0,
    available_points INT NOT NULL DEFAULT 0,
    spent_points INT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 1,
    puzzles_solved INT NOT NULL DEFAULT 0,
    total_solve_time_ms BIGINT NOT NULL DEFAULT 0,
    fastest_solve_ms BIGINT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, cipher_type)
);

-- ============================================================================
-- PRACTICE (services/practice — incl. auto-updating personal bests)
-- ============================================================================

CREATE TABLE practice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    puzzle_id UUID NOT NULL REFERENCES puzzles(id),

    cipher_type VARCHAR(50) NOT NULL,
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),
    mode VARCHAR(50) DEFAULT 'UNTIMED', -- UNTIMED, TIMED, SPEED_RUN, ACCURACY

    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    submitted_at TIMESTAMP WITH TIME ZONE,
    solve_time_ms BIGINT,
    time_limit_ms BIGINT,

    user_solution TEXT,
    is_correct BOOLEAN,
    accuracy_percentage DECIMAL(5,2),

    hints_used INT DEFAULT 0,
    score INT,
    perfect_solve BOOLEAN DEFAULT FALSE,
    attempts INT DEFAULT 1,

    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE practice_leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,
    difficulty INT NOT NULL CHECK (difficulty BETWEEN 1 AND 10),

    fastest_solve_ms BIGINT NOT NULL,
    fastest_session_id UUID REFERENCES practice_sessions(id),
    fastest_achieved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    highest_score INT DEFAULT 0,
    highest_score_session_id UUID REFERENCES practice_sessions(id),

    total_practice_sessions INT DEFAULT 1,
    perfect_solves INT DEFAULT 0,
    average_solve_time_ms BIGINT,

    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, cipher_type, difficulty)
);

-- ============================================================================
-- SOCIAL (services/social: user1/user2, from/to shapes)
-- ============================================================================

CREATE TABLE friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user1_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    user2_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, accepted, blocked
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    accepted_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user1_id, user2_id),
    CHECK (user1_id != user2_id)
);

CREATE TABLE match_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    to_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_mode VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, accepted, declined, expired
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL
);

CREATE TABLE spectator_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    joined_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    left_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- COSMETICS & ECONOMY (services/cosmetics: string ids + updated_at)
-- ============================================================================

CREATE TABLE cosmetics (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    category VARCHAR(50) NOT NULL, -- background, particle_effect, title, avatar_frame, cipher_skin
    rarity VARCHAR(20) NOT NULL DEFAULT 'common', -- common, rare, epic, legendary, mythic
    asset_url VARCHAR(500) NOT NULL DEFAULT '',
    metadata JSONB NOT NULL DEFAULT '{}',
    unlock_requirement VARCHAR(100),
    coin_cost INT NOT NULL DEFAULT 0,
    is_premium BOOLEAN NOT NULL DEFAULT FALSE,
    is_tradable BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE user_cosmetics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cosmetic_id VARCHAR(100) NOT NULL REFERENCES cosmetics(id),
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    is_equipped BOOLEAN NOT NULL DEFAULT FALSE,
    source VARCHAR(50), -- purchase, achievement_unlock, mission_reward, grant
    UNIQUE(user_id, cosmetic_id)
);

CREATE TABLE user_loadouts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    background_id VARCHAR(100) REFERENCES cosmetics(id),
    particle_effect_id VARCHAR(100) REFERENCES cosmetics(id),
    title_id VARCHAR(100) REFERENCES cosmetics(id),
    avatar_frame_id VARCHAR(100) REFERENCES cosmetics(id),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL, -- earn, spend, grant, refund
    amount INT NOT NULL,
    source VARCHAR(100) NOT NULL, -- mission_claim, cosmetic_purchase, match_reward, ...
    reference_id VARCHAR(100),
    balance_after INT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_elo_rating ON users(elo_rating DESC);
CREATE INDEX idx_users_region ON users(region);

CREATE INDEX idx_refresh_tokens_user_id ON refresh_tokens(user_id);
CREATE INDEX idx_refresh_tokens_token_hash ON refresh_tokens(token_hash);

CREATE INDEX idx_matches_player1 ON matches(player1_id, created_at DESC);
CREATE INDEX idx_matches_player2 ON matches(player2_id, created_at DESC);
CREATE INDEX idx_matches_status ON matches(status);

CREATE INDEX idx_puzzles_cipher_difficulty ON puzzles(cipher_type, difficulty);
CREATE INDEX idx_puzzle_attempts_match ON puzzle_attempts(match_id);
CREATE INDEX idx_match_participants_match ON match_participants(match_id);
CREATE INDEX idx_match_participants_user ON match_participants(user_id);

CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_tutorial_progress_user ON user_tutorial_progress(user_id);
CREATE INDEX idx_user_missions_user_date ON user_missions(user_id, assigned_date DESC);
CREATE INDEX idx_user_mastery_user ON user_mastery(user_id);
CREATE INDEX idx_cipher_mastery_points_user ON cipher_mastery_points(user_id);

CREATE INDEX idx_practice_sessions_user ON practice_sessions(user_id, started_at DESC);
CREATE INDEX idx_practice_lb_cipher ON practice_leaderboards(cipher_type, difficulty, fastest_solve_ms);

CREATE INDEX idx_friendships_user1 ON friendships(user1_id);
CREATE INDEX idx_friendships_user2 ON friendships(user2_id);
CREATE INDEX idx_match_invitations_to ON match_invitations(to_user_id, status);
CREATE INDEX idx_spectator_sessions_match ON spectator_sessions(match_id) WHERE left_at IS NULL;

CREATE INDEX idx_user_cosmetics_user ON user_cosmetics(user_id);
CREATE INDEX idx_wallet_transactions_user ON wallet_transactions(user_id, created_at DESC);

-- ============================================================================
-- TRIGGERS & FUNCTIONS
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Rank tier derived from ELO
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

-- Practice personal bests auto-update on correct solves
CREATE OR REPLACE FUNCTION update_practice_leaderboard() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_correct = TRUE THEN
        INSERT INTO practice_leaderboards (
            user_id, cipher_type, difficulty,
            fastest_solve_ms, fastest_session_id,
            highest_score, highest_score_session_id,
            total_practice_sessions, perfect_solves, average_solve_time_ms
        ) VALUES (
            NEW.user_id, NEW.cipher_type, NEW.difficulty,
            NEW.solve_time_ms, NEW.id,
            COALESCE(NEW.score, 0), NEW.id,
            1, CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END, NEW.solve_time_ms
        )
        ON CONFLICT (user_id, cipher_type, difficulty) DO UPDATE SET
            fastest_solve_ms = LEAST(practice_leaderboards.fastest_solve_ms, NEW.solve_time_ms),
            fastest_session_id = CASE
                WHEN NEW.solve_time_ms < practice_leaderboards.fastest_solve_ms THEN NEW.id
                ELSE practice_leaderboards.fastest_session_id END,
            highest_score = GREATEST(practice_leaderboards.highest_score, COALESCE(NEW.score, 0)),
            highest_score_session_id = CASE
                WHEN COALESCE(NEW.score, 0) > practice_leaderboards.highest_score THEN NEW.id
                ELSE practice_leaderboards.highest_score_session_id END,
            total_practice_sessions = practice_leaderboards.total_practice_sessions + 1,
            perfect_solves = practice_leaderboards.perfect_solves
                + CASE WHEN NEW.perfect_solve THEN 1 ELSE 0 END,
            average_solve_time_ms = (
                (COALESCE(practice_leaderboards.average_solve_time_ms, 0)
                    * practice_leaderboards.total_practice_sessions + NEW.solve_time_ms)
                / (practice_leaderboards.total_practice_sessions + 1)
            ),
            updated_at = NOW();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Fires on the submit UPDATE (sessions are inserted unsolved, then updated)
CREATE TRIGGER trg_update_practice_leaderboard
    AFTER UPDATE OF is_correct ON practice_sessions
    FOR EACH ROW
    WHEN (NEW.is_correct = TRUE)
    EXECUTE FUNCTION update_practice_leaderboard();
