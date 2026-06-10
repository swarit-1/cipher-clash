-- Reverse of 0002_seed
DELETE FROM users WHERE is_bot = TRUE;
DELETE FROM cosmetics;
DELETE FROM mastery_nodes;
DELETE FROM mission_templates;
DELETE FROM tutorial_steps;
DELETE FROM achievements;
DELETE FROM seasons;
DELETE FROM game_modes;
