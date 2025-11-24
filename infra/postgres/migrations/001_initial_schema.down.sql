-- Migration Rollback: 001 - Initial V2.0 Schema
-- This rollback drops all V2.0 tables in reverse dependency order

-- Drop views
DROP VIEW IF EXISTS user_profile_stats CASCADE;
DROP VIEW IF EXISTS leaderboard CASCADE;

-- Drop triggers
DROP TRIGGER IF EXISTS auto_update_rank_tier ON users;
DROP TRIGGER IF EXISTS update_clans_updated_at ON clans;
DROP TRIGGER IF EXISTS update_users_updated_at ON users;

-- Drop functions
DROP FUNCTION IF EXISTS update_rank_tier() CASCADE;
DROP FUNCTION IF EXISTS calculate_rank_tier(INT) CASCADE;
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS system_events CASCADE;
DROP TABLE IF EXISTS queue_metrics CASCADE;
DROP TABLE IF EXISTS player_stats_daily CASCADE;
DROP TABLE IF EXISTS chat_messages CASCADE;
DROP TABLE IF EXISTS clan_members CASCADE;
DROP TABLE IF EXISTS clans CASCADE;
DROP TABLE IF EXISTS friendships CASCADE;
DROP TABLE IF EXISTS daily_quests CASCADE;
DROP TABLE IF EXISTS user_achievements CASCADE;
DROP TABLE IF EXISTS achievements CASCADE;
DROP TABLE IF EXISTS puzzle_attempts CASCADE;
DROP TABLE IF EXISTS match_participants CASCADE;
DROP TABLE IF EXISTS matches CASCADE;
DROP TABLE IF EXISTS puzzles CASCADE;
DROP TABLE IF EXISTS game_modes CASCADE;
DROP TABLE IF EXISTS seasonal_rankings CASCADE;
DROP TABLE IF EXISTS seasons CASCADE;
DROP TABLE IF EXISTS refresh_tokens CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop extensions (optional - may be used by other databases)
-- DROP EXTENSION IF EXISTS "pgcrypto";
-- DROP EXTENSION IF EXISTS "uuid-ossp";
