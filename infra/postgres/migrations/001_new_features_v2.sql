-- Cipher Clash V2.0 Feature Expansion Migration
-- Adds support for: Tutorials, Missions, Mastery Trees, Cosmetics, Social Features, Boss Battles
-- Created: 2025-01-25

-- ============================================
-- 1. TUTORIAL & ONBOARDING SYSTEM
-- ============================================

-- Tutorial progress tracking
CREATE TABLE IF NOT EXISTS tutorial_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    step_id VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'not_started', -- not_started, in_progress, completed, skipped
    completed_at TIMESTAMP,
    attempts INT DEFAULT 0,
    hints_used INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, step_id)
);

CREATE INDEX idx_tutorial_progress_user ON tutorial_progress(user_id);
CREATE INDEX idx_tutorial_progress_status ON tutorial_progress(status);

-- Tutorial definitions (seeded data)
CREATE TABLE IF NOT EXISTS tutorial_steps (
    id VARCHAR(100) PRIMARY KEY,
    order_index INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL, -- intro, cipher_basics, combat, advanced
    cipher_type VARCHAR(50), -- NULL for non-cipher steps
    difficulty INT DEFAULT 1,
    required_for_completion BOOLEAN DEFAULT TRUE,
    xp_reward INT DEFAULT 50,
    unlock_requirement VARCHAR(100), -- NULL or step_id that must be completed first
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_tutorial_steps_category ON tutorial_steps(category);
CREATE INDEX idx_tutorial_steps_order ON tutorial_steps(order_index);

-- ============================================
-- 2. DAILY MISSIONS SYSTEM
-- ============================================

-- Mission templates (reusable mission definitions)
CREATE TABLE IF NOT EXISTS mission_templates (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL, -- daily, weekly, special
    objective_type VARCHAR(50) NOT NULL, -- win_matches, solve_ciphers, use_cipher_type, reach_streak
    target_count INT NOT NULL DEFAULT 1,
    cipher_type VARCHAR(50), -- NULL for non-cipher-specific missions
    difficulty_min INT,
    difficulty_max INT,
    xp_reward INT NOT NULL DEFAULT 100,
    coin_reward INT DEFAULT 0,
    cosmetic_reward_id UUID,
    priority INT DEFAULT 0, -- Higher = more likely to appear
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_mission_templates_category ON mission_templates(category);
CREATE INDEX idx_mission_templates_active ON mission_templates(is_active);

-- User-assigned missions (daily rotation)
CREATE TABLE IF NOT EXISTS user_missions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    template_id VARCHAR(100) NOT NULL REFERENCES mission_templates(id),
    assigned_date DATE NOT NULL DEFAULT CURRENT_DATE,
    progress INT DEFAULT 0,
    target INT NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- active, completed, expired, abandoned
    completed_at TIMESTAMP,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, template_id, assigned_date)
);

CREATE INDEX idx_user_missions_user ON user_missions(user_id);
CREATE INDEX idx_user_missions_status ON user_missions(status);
CREATE INDEX idx_user_missions_date ON user_missions(assigned_date);
CREATE INDEX idx_user_missions_expires ON user_missions(expires_at);

-- ============================================
-- 3. CIPHER MASTERY TREE SYSTEM
-- ============================================

-- Mastery nodes (skill tree structure)
CREATE TABLE IF NOT EXISTS mastery_nodes (
    id VARCHAR(100) PRIMARY KEY,
    cipher_type VARCHAR(50) NOT NULL,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    tier INT NOT NULL DEFAULT 1, -- 1-5 tiers per cipher
    position_x INT NOT NULL, -- For UI rendering
    position_y INT NOT NULL,
    unlock_cost INT NOT NULL DEFAULT 100, -- Points needed
    prerequisite_node_id VARCHAR(100), -- NULL for root nodes
    bonus_type VARCHAR(50) NOT NULL, -- speed_boost, hint_discount, score_multiplier, auto_decrypt
    bonus_value DECIMAL(5,2) NOT NULL, -- e.g., 1.10 for 10% boost
    icon_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    FOREIGN KEY (prerequisite_node_id) REFERENCES mastery_nodes(id)
);

CREATE INDEX idx_mastery_nodes_cipher ON mastery_nodes(cipher_type);
CREATE INDEX idx_mastery_nodes_tier ON mastery_nodes(tier);

-- User mastery progress
CREATE TABLE IF NOT EXISTS user_mastery (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    node_id VARCHAR(100) NOT NULL REFERENCES mastery_nodes(id),
    unlocked_at TIMESTAMP DEFAULT NOW(),
    points_spent INT NOT NULL,
    UNIQUE(user_id, node_id)
);

CREATE INDEX idx_user_mastery_user ON user_mastery(user_id);

-- Cipher-specific mastery points
CREATE TABLE IF NOT EXISTS cipher_mastery_points (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,
    total_points INT DEFAULT 0,
    spent_points INT DEFAULT 0,
    available_points INT DEFAULT 0,
    puzzles_solved INT DEFAULT 0,
    total_solve_time_ms BIGINT DEFAULT 0,
    average_solve_time_ms INT DEFAULT 0,
    fastest_solve_time_ms INT,
    accuracy_rate DECIMAL(5,2) DEFAULT 0.00, -- 0-100%
    mastery_level INT DEFAULT 1, -- 1-10
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, cipher_type)
);

CREATE INDEX idx_cipher_mastery_user ON cipher_mastery_points(user_id);
CREATE INDEX idx_cipher_mastery_type ON cipher_mastery_points(cipher_type);

-- ============================================
-- 4. COSMETICS & COLLECTION SYSTEM
-- ============================================

-- Cosmetic items catalog
CREATE TABLE IF NOT EXISTS cosmetics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200) NOT NULL,
    description TEXT,
    category VARCHAR(50) NOT NULL, -- background, particle_effect, title, avatar_frame, cipher_skin
    rarity VARCHAR(20) NOT NULL DEFAULT 'common', -- common, rare, epic, legendary, mythic
    asset_url VARCHAR(500), -- Path or URL to asset file
    metadata JSONB, -- Custom properties (colors, animations, etc.)
    unlock_requirement VARCHAR(100), -- achievement_id, mission_id, or NULL if purchasable
    coin_cost INT DEFAULT 0, -- 0 if not purchasable with coins
    is_premium BOOLEAN DEFAULT FALSE,
    is_tradable BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_cosmetics_category ON cosmetics(category);
CREATE INDEX idx_cosmetics_rarity ON cosmetics(rarity);
CREATE INDEX idx_cosmetics_active ON cosmetics(is_active);

-- User cosmetic inventory
CREATE TABLE IF NOT EXISTS user_cosmetics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cosmetic_id UUID NOT NULL REFERENCES cosmetics(id),
    acquired_at TIMESTAMP DEFAULT NOW(),
    is_equipped BOOLEAN DEFAULT FALSE,
    source VARCHAR(50), -- mission_reward, achievement_unlock, purchase, gift
    UNIQUE(user_id, cosmetic_id)
);

CREATE INDEX idx_user_cosmetics_user ON user_cosmetics(user_id);
CREATE INDEX idx_user_cosmetics_equipped ON user_cosmetics(is_equipped);

-- User loadout (currently equipped items)
CREATE TABLE IF NOT EXISTS user_loadout (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    background_id UUID REFERENCES cosmetics(id),
    particle_effect_id UUID REFERENCES cosmetics(id),
    title_id UUID REFERENCES cosmetics(id),
    avatar_frame_id UUID REFERENCES cosmetics(id),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- ============================================
-- 5. SOCIAL FEATURES
-- ============================================

-- Friends system
CREATE TABLE IF NOT EXISTS friendships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    friend_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, accepted, blocked
    requester_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMP DEFAULT NOW(),
    accepted_at TIMESTAMP,
    UNIQUE(user_id, friend_id),
    CHECK (user_id != friend_id)
);

CREATE INDEX idx_friendships_user ON friendships(user_id);
CREATE INDEX idx_friendships_friend ON friendships(friend_id);
CREATE INDEX idx_friendships_status ON friendships(status);

-- Match invitations
CREATE TABLE IF NOT EXISTS match_invitations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_mode VARCHAR(50) NOT NULL, -- ranked, casual, speed_solve, gauntlet
    message TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- pending, accepted, declined, expired
    match_id UUID, -- Populated when accepted
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    responded_at TIMESTAMP
);

CREATE INDEX idx_match_invitations_recipient ON match_invitations(recipient_id);
CREATE INDEX idx_match_invitations_status ON match_invitations(status);
CREATE INDEX idx_match_invitations_expires ON match_invitations(expires_at);

-- Spectator sessions
CREATE TABLE IF NOT EXISTS spectator_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    match_id UUID NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
    spectator_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT NOW(),
    left_at TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE,
    UNIQUE(match_id, spectator_id)
);

CREATE INDEX idx_spectator_sessions_match ON spectator_sessions(match_id);
CREATE INDEX idx_spectator_sessions_spectator ON spectator_sessions(spectator_id);
CREATE INDEX idx_spectator_sessions_active ON spectator_sessions(is_active);

-- ============================================
-- 6. NEW GAME MODES
-- ============================================

-- Game mode definitions
CREATE TABLE IF NOT EXISTS game_modes (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50) NOT NULL, -- ranked, casual, special
    time_limit_seconds INT NOT NULL,
    puzzles_per_match INT NOT NULL DEFAULT 3,
    difficulty_scaling VARCHAR(50) DEFAULT 'fixed', -- fixed, progressive, adaptive
    min_difficulty INT DEFAULT 1,
    max_difficulty INT DEFAULT 10,
    base_xp_reward INT DEFAULT 100,
    base_coin_reward INT DEFAULT 10,
    required_level INT DEFAULT 1,
    is_active BOOLEAN DEFAULT TRUE,
    metadata JSONB, -- Mode-specific settings
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_game_modes_category ON game_modes(category);
CREATE INDEX idx_game_modes_active ON game_modes(is_active);

-- Boss battle definitions
CREATE TABLE IF NOT EXISTS boss_battles (
    id VARCHAR(100) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    title VARCHAR(200) NOT NULL, -- "The Enigma Master", "Caesar's Ghost"
    description TEXT NOT NULL,
    difficulty INT NOT NULL,
    cipher_specialty VARCHAR(50), -- Boss focuses on this cipher
    health_points INT NOT NULL DEFAULT 1000,
    ability_cooldown_seconds INT DEFAULT 30,
    abilities JSONB NOT NULL, -- Array of special abilities
    weakness_cipher VARCHAR(50), -- Cipher type that deals bonus damage
    loot_table JSONB, -- Rewards on defeat
    unlock_requirement VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_boss_battles_difficulty ON boss_battles(difficulty);
CREATE INDEX idx_boss_battles_active ON boss_battles(is_active);

-- Boss battle sessions
CREATE TABLE IF NOT EXISTS boss_battle_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    boss_id VARCHAR(100) NOT NULL REFERENCES boss_battles(id),
    started_at TIMESTAMP DEFAULT NOW(),
    ended_at TIMESTAMP,
    status VARCHAR(20) NOT NULL DEFAULT 'in_progress', -- in_progress, victory, defeat, abandoned
    boss_health_remaining INT NOT NULL,
    player_health_remaining INT DEFAULT 100,
    puzzles_solved INT DEFAULT 0,
    abilities_used JSONB DEFAULT '[]',
    score INT DEFAULT 0,
    time_elapsed_seconds INT DEFAULT 0,
    rewards_granted JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_boss_sessions_user ON boss_battle_sessions(user_id);
CREATE INDEX idx_boss_sessions_boss ON boss_battle_sessions(boss_id);
CREATE INDEX idx_boss_sessions_status ON boss_battle_sessions(status);

-- ============================================
-- 7. ENHANCED ACHIEVEMENTS SYSTEM
-- ============================================

-- Achievement categories
CREATE TABLE IF NOT EXISTS achievement_categories (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(200) NOT NULL,
    description TEXT,
    icon_name VARCHAR(100),
    display_order INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Update existing achievements table structure
ALTER TABLE achievements ADD COLUMN IF NOT EXISTS category_id VARCHAR(50) REFERENCES achievement_categories(id);
ALTER TABLE achievements ADD COLUMN IF NOT EXISTS is_secret BOOLEAN DEFAULT FALSE;
ALTER TABLE achievements ADD COLUMN IF NOT EXISTS progression_steps INT DEFAULT 1;
ALTER TABLE achievements ADD COLUMN IF NOT EXISTS coin_reward INT DEFAULT 0;
ALTER TABLE achievements ADD COLUMN IF NOT EXISTS cosmetic_reward_id UUID REFERENCES cosmetics(id);

-- Achievement progression tracking
CREATE TABLE IF NOT EXISTS achievement_progression (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id),
    current_progress INT DEFAULT 0,
    target_progress INT NOT NULL,
    milestone_reached INT DEFAULT 0, -- For multi-tier achievements
    last_updated TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

CREATE INDEX idx_achievement_progression_user ON achievement_progression(user_id);

-- ============================================
-- 8. MULTI-STAGE PUZZLES
-- ============================================

-- Puzzle chains (multi-layer puzzles)
CREATE TABLE IF NOT EXISTS puzzle_chains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(200),
    description TEXT,
    total_stages INT NOT NULL DEFAULT 2,
    difficulty INT NOT NULL,
    is_story_mode BOOLEAN DEFAULT FALSE,
    category VARCHAR(50) DEFAULT 'standard', -- standard, gauntlet, boss_battle
    created_at TIMESTAMP DEFAULT NOW()
);

-- Puzzle stages within a chain
CREATE TABLE IF NOT EXISTS puzzle_stages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    chain_id UUID NOT NULL REFERENCES puzzle_chains(id) ON DELETE CASCADE,
    stage_number INT NOT NULL,
    puzzle_id UUID NOT NULL REFERENCES puzzles(id),
    time_limit_seconds INT DEFAULT 60,
    hint_text TEXT,
    success_message TEXT,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(chain_id, stage_number)
);

CREATE INDEX idx_puzzle_stages_chain ON puzzle_stages(chain_id);

-- User progress through puzzle chains
CREATE TABLE IF NOT EXISTS user_puzzle_chain_progress (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    chain_id UUID NOT NULL REFERENCES puzzle_chains(id),
    current_stage INT DEFAULT 1,
    stages_completed INT DEFAULT 0,
    total_time_ms BIGINT DEFAULT 0,
    status VARCHAR(20) DEFAULT 'in_progress', -- in_progress, completed, abandoned
    started_at TIMESTAMP DEFAULT NOW(),
    completed_at TIMESTAMP,
    UNIQUE(user_id, chain_id)
);

CREATE INDEX idx_user_chain_progress_user ON user_puzzle_chain_progress(user_id);
CREATE INDEX idx_user_chain_progress_status ON user_puzzle_chain_progress(status);

-- ============================================
-- 9. PLAYER STATISTICS ENHANCEMENTS
-- ============================================

-- Detailed solve statistics per cipher
CREATE TABLE IF NOT EXISTS cipher_solve_stats (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    cipher_type VARCHAR(50) NOT NULL,
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    puzzles_attempted INT DEFAULT 0,
    puzzles_solved INT DEFAULT 0,
    total_solve_time_ms BIGINT DEFAULT 0,
    fastest_solve_ms INT,
    hints_used INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, cipher_type, date)
);

CREATE INDEX idx_cipher_solve_stats_user ON cipher_solve_stats(user_id);
CREATE INDEX idx_cipher_solve_stats_date ON cipher_solve_stats(date);

-- Daily activity heatmap data
CREATE TABLE IF NOT EXISTS user_activity (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL,
    matches_played INT DEFAULT 0,
    puzzles_solved INT DEFAULT 0,
    time_played_seconds INT DEFAULT 0,
    xp_earned INT DEFAULT 0,
    missions_completed INT DEFAULT 0,
    achievements_unlocked INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, activity_date)
);

CREATE INDEX idx_user_activity_user ON user_activity(user_id);
CREATE INDEX idx_user_activity_date ON user_activity(activity_date);

-- ============================================
-- 10. CURRENCY & ECONOMY
-- ============================================

-- User wallet
CREATE TABLE IF NOT EXISTS user_wallet (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
    coins INT DEFAULT 0,
    premium_currency INT DEFAULT 0, -- Future use
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Transaction log
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    transaction_type VARCHAR(50) NOT NULL, -- earn, spend, grant, refund
    amount INT NOT NULL,
    currency_type VARCHAR(20) DEFAULT 'coins', -- coins, premium
    source VARCHAR(100) NOT NULL, -- mission_complete, achievement_unlock, purchase, etc.
    reference_id UUID, -- ID of mission, achievement, cosmetic, etc.
    balance_after INT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_wallet_transactions_user ON wallet_transactions(user_id);
CREATE INDEX idx_wallet_transactions_created ON wallet_transactions(created_at);

-- ============================================
-- 11. SEED DATA FOR INITIAL SETUP
-- ============================================

-- Insert game mode definitions
INSERT INTO game_modes (id, name, description, category, time_limit_seconds, puzzles_per_match, difficulty_scaling, min_difficulty, max_difficulty, base_xp_reward, base_coin_reward, metadata) VALUES
('ranked', 'Ranked Match', 'Competitive ELO-based matchmaking', 'ranked', 180, 3, 'adaptive', 1, 10, 150, 25, '{"affects_rating": true}'),
('casual', 'Casual Match', 'Relaxed practice matches', 'casual', 180, 3, 'fixed', 3, 7, 75, 10, '{"affects_rating": false}'),
('speed_solve', 'Speed Solve', '60-second rapid-fire micro puzzles', 'special', 60, 1, 'fixed', 2, 5, 50, 5, '{"timer_visible": true, "no_hints": true}'),
('cipher_gauntlet', 'Cipher Gauntlet', 'Progressive difficulty escalation', 'special', 300, 5, 'progressive', 1, 10, 200, 40, '{"difficulty_increment": 2, "fail_on_wrong": false}'),
('boss_battle', 'Boss Battle', 'Face AI opponents with special abilities', 'special', 600, 10, 'adaptive', 5, 10, 300, 50, '{"has_boss_abilities": true, "health_system": true}');

-- Insert achievement categories
INSERT INTO achievement_categories (id, name, description, display_order) VALUES
('beginner', 'Beginner', 'First steps in Cipher Clash', 1),
('cipher_master', 'Cipher Mastery', 'Master individual cipher types', 2),
('competitive', 'Competitive', 'Ranked play achievements', 3),
('social', 'Social', 'Friends and community', 4),
('collection', 'Collection', 'Cosmetics and collectibles', 5),
('special', 'Special Events', 'Limited-time achievements', 6);

-- Insert tutorial steps
INSERT INTO tutorial_steps (id, order_index, title, description, category, cipher_type, difficulty, xp_reward) VALUES
('tutorial_welcome', 1, 'Welcome to Cipher Clash', 'Learn the basics of cryptography combat', 'intro', NULL, 1, 25),
('tutorial_caesar_intro', 2, 'Caesar Cipher Basics', 'Master the classic shift cipher', 'cipher_basics', 'CAESAR', 1, 50),
('tutorial_vigenere_intro', 3, 'Vigenère Cipher', 'Learn polyalphabetic encryption', 'cipher_basics', 'VIGENERE', 2, 75),
('tutorial_first_match', 4, 'Your First Match', 'Face the training bot', 'combat', NULL, 1, 100),
('tutorial_rail_fence_intro', 5, 'Rail Fence Cipher', 'Understand transposition ciphers', 'cipher_basics', 'RAIL_FENCE', 2, 75),
('tutorial_playfair_intro', 6, 'Playfair Cipher', 'Master digraph substitution', 'cipher_basics', 'PLAYFAIR', 3, 100),
('tutorial_powerups', 7, 'Using Power-Ups', 'Learn tactical advantages', 'advanced', NULL, 2, 75),
('tutorial_mastery_tree', 8, 'Cipher Mastery Trees', 'Unlock cipher-specific bonuses', 'advanced', NULL, 1, 50);

-- Insert mission templates
INSERT INTO mission_templates (id, name, description, category, objective_type, target_count, xp_reward, coin_reward, priority) VALUES
('daily_win_2', 'Victory Lap', 'Win 2 matches today', 'daily', 'win_matches', 2, 100, 15, 10),
('daily_solve_5', 'Puzzle Master', 'Solve 5 puzzles today', 'daily', 'solve_ciphers', 5, 75, 10, 10),
('daily_caesar_3', 'Caesar Day', 'Solve 3 Caesar ciphers', 'daily', 'use_cipher_type', 3, 50, 8, 7),
('daily_speed_1', 'Speed Demon', 'Complete 1 Speed Solve mode', 'daily', 'complete_game_mode', 1, 80, 12, 8),
('daily_streak_3', 'Win Streak', 'Win 3 matches in a row', 'daily', 'reach_streak', 3, 150, 20, 5),
('weekly_ranked_10', 'Ranked Warrior', 'Play 10 ranked matches', 'weekly', 'play_mode', 10, 500, 100, 10),
('weekly_gauntlet_3', 'Gauntlet Runner', 'Complete 3 Cipher Gauntlets', 'weekly', 'complete_game_mode', 3, 300, 50, 8);

-- ============================================
-- 12. TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================

-- Auto-update tutorial progress timestamp
CREATE OR REPLACE FUNCTION update_tutorial_progress_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_tutorial_progress_update
    BEFORE UPDATE ON tutorial_progress
    FOR EACH ROW
    EXECUTE FUNCTION update_tutorial_progress_timestamp();

-- Auto-update user missions timestamp
CREATE OR REPLACE FUNCTION update_user_missions_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_missions_update
    BEFORE UPDATE ON user_missions
    FOR EACH ROW
    EXECUTE FUNCTION update_user_missions_timestamp();

-- Auto-calculate available mastery points
CREATE OR REPLACE FUNCTION update_cipher_mastery_available_points()
RETURNS TRIGGER AS $$
BEGIN
    NEW.available_points = NEW.total_points - NEW.spent_points;
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cipher_mastery_points_update
    BEFORE INSERT OR UPDATE ON cipher_mastery_points
    FOR EACH ROW
    EXECUTE FUNCTION update_cipher_mastery_available_points();

-- ============================================
-- 13. VIEWS FOR COMMON QUERIES
-- ============================================

-- User profile summary view
CREATE OR REPLACE VIEW user_profile_summary AS
SELECT
    u.id,
    u.username,
    u.email,
    u.rating AS elo_rating,
    u.created_at,
    COALESCE(uw.coins, 0) AS coins,
    COUNT(DISTINCT ua.achievement_id) AS achievements_unlocked,
    COUNT(DISTINCT uc.cosmetic_id) AS cosmetics_owned,
    COUNT(DISTINCT f.friend_id) FILTER (WHERE f.status = 'accepted') AS friend_count,
    (SELECT COUNT(*) FROM matches m WHERE (m.player1_id = u.id OR m.player2_id = u.id) AND m.status = 'COMPLETED') AS total_matches,
    (SELECT COUNT(*) FROM matches m WHERE m.winner_id = u.id) AS total_wins
FROM users u
LEFT JOIN user_wallet uw ON u.id = uw.user_id
LEFT JOIN user_achievements ua ON u.id = ua.user_id
LEFT JOIN user_cosmetics uc ON u.id = uc.user_id
LEFT JOIN friendships f ON u.id = f.user_id
GROUP BY u.id, uw.coins;

-- Cipher mastery leaderboard view
CREATE OR REPLACE VIEW cipher_mastery_leaderboard AS
SELECT
    cmp.cipher_type,
    u.username,
    cmp.mastery_level,
    cmp.puzzles_solved,
    cmp.average_solve_time_ms,
    cmp.accuracy_rate,
    ROW_NUMBER() OVER (PARTITION BY cmp.cipher_type ORDER BY cmp.mastery_level DESC, cmp.accuracy_rate DESC) AS rank
FROM cipher_mastery_points cmp
JOIN users u ON cmp.user_id = u.id
WHERE cmp.puzzles_solved > 0;

-- Active missions view
CREATE OR REPLACE VIEW active_user_missions AS
SELECT
    um.id,
    um.user_id,
    mt.name,
    mt.description,
    mt.objective_type,
    um.progress,
    um.target,
    ROUND((um.progress::DECIMAL / um.target) * 100, 2) AS completion_percentage,
    mt.xp_reward,
    mt.coin_reward,
    um.expires_at,
    EXTRACT(EPOCH FROM (um.expires_at - NOW())) AS seconds_remaining
FROM user_missions um
JOIN mission_templates mt ON um.template_id = mt.id
WHERE um.status = 'active' AND um.expires_at > NOW();

-- ============================================
-- MIGRATION COMPLETE
-- ============================================

COMMENT ON TABLE tutorial_progress IS 'Tracks user progress through tutorial steps';
COMMENT ON TABLE mission_templates IS 'Reusable mission definitions for daily/weekly rotation';
COMMENT ON TABLE user_missions IS 'User-assigned mission instances with progress tracking';
COMMENT ON TABLE mastery_nodes IS 'Skill tree nodes for cipher-specific upgrades';
COMMENT ON TABLE cipher_mastery_points IS 'Per-cipher mastery points and statistics';
COMMENT ON TABLE cosmetics IS 'Catalog of unlockable cosmetic items';
COMMENT ON TABLE boss_battles IS 'AI opponents with special abilities';
COMMENT ON TABLE game_modes IS 'Available game mode configurations';
COMMENT ON TABLE puzzle_chains IS 'Multi-stage puzzle sequences';
COMMENT ON TABLE user_activity IS 'Daily activity data for heatmap visualization';
