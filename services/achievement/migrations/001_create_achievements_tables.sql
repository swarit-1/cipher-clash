-- Create achievements table
CREATE TABLE IF NOT EXISTS achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    icon VARCHAR(50) NOT NULL,
    rarity VARCHAR(20) NOT NULL CHECK (rarity IN ('COMMON', 'RARE', 'EPIC', 'LEGENDARY')),
    xp_reward INTEGER NOT NULL CHECK (xp_reward > 0),
    requirement JSONB NOT NULL,
    total INTEGER NOT NULL CHECK (total > 0),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Create user_achievements table
CREATE TABLE IF NOT EXISTS user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    progress INTEGER DEFAULT 0 CHECK (progress >= 0),
    unlocked BOOLEAN DEFAULT FALSE,
    unlocked_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

-- Create indexes for performance
CREATE INDEX idx_user_achievements_user ON user_achievements(user_id);
CREATE INDEX idx_user_achievements_unlocked ON user_achievements(unlocked);
CREATE INDEX idx_user_achievements_user_unlocked ON user_achievements(user_id, unlocked);
CREATE INDEX idx_achievements_rarity ON achievements(rarity);

-- Insert default achievements
INSERT INTO achievements (name, description, icon, rarity, xp_reward, requirement, total) VALUES
('First Steps', 'Complete your first match', 'directions_walk', 'COMMON', 50, '{"type": "matches_played"}', 1),
('Speed Demon', 'Solve a cipher in under 30 seconds', 'flash_on', 'EPIC', 200, '{"type": "fast_solve", "time": 30}', 1),
('Win Streak Master', 'Win 10 matches in a row', 'local_fire_department', 'LEGENDARY', 500, '{"type": "win_streak"}', 10),
('Caesar Champion', 'Solve 100 Caesar ciphers', 'emoji_events', 'RARE', 150, '{"type": "cipher_type", "cipher": "caesar"}', 100),
('Vigenere Virtuoso', 'Solve 50 Vigenere ciphers', 'workspace_premium', 'RARE', 150, '{"type": "cipher_type", "cipher": "vigenere"}', 50),
('RSA Master', 'Solve 25 RSA challenges', 'security', 'EPIC', 200, '{"type": "cipher_type", "cipher": "rsa"}', 25),
('Perfect Game', 'Win a match without any mistakes', 'stars', 'LEGENDARY', 500, '{"type": "perfect_accuracy"}', 1),
('Century Club', 'Win 100 total matches', 'military_tech', 'EPIC', 300, '{"type": "total_wins"}', 100),
('Dedicated Player', 'Play 30 days in a row', 'calendar_today', 'EPIC', 250, '{"type": "login_streak"}', 30),
('Social Butterfly', 'Add 10 friends', 'people', 'COMMON', 75, '{"type": "friends"}', 10);

-- Create updated_at trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers
CREATE TRIGGER update_achievements_updated_at BEFORE UPDATE ON achievements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_user_achievements_updated_at BEFORE UPDATE ON user_achievements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMENT ON TABLE achievements IS 'Stores all available achievements in the game';
COMMENT ON TABLE user_achievements IS 'Tracks user progress on achievements';
COMMENT ON COLUMN achievements.requirement IS 'JSON object defining achievement requirements';
COMMENT ON COLUMN user_achievements.progress IS 'Current progress towards achievement completion';
