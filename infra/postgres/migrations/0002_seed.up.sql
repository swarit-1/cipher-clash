-- ============================================================================
-- 0002_seed — reference data: game modes, season, achievements, tutorial,
-- missions, mastery nodes, cosmetics catalog, and bot opponents.
-- ============================================================================

-- Game modes (matchmaker resolves game_mode_id by name)
INSERT INTO game_modes (name, display_name, description, is_ranked, min_players, max_players, time_limit_seconds) VALUES
('RANKED_1V1',     'Ranked 1v1',      'Competitive head-to-head with seasonal ELO rankings', TRUE,  2, 2, 300),
('CASUAL_1V1',     'Casual 1v1',      'Head-to-head without rating changes',                 FALSE, 2, 2, 300),
('BOT_MATCH',      'Vs. Bot',         'Unranked match against an AI opponent',               FALSE, 2, 2, 300),
('PRACTICE',       'Practice',        'Solo cipher training',                                FALSE, 1, 1, NULL),
('DAILY_CHALLENGE','Daily Challenge', 'Single-player puzzle of the day',                     FALSE, 1, 1, 300);

-- First season
INSERT INTO seasons (name, description, start_date, end_date, is_active) VALUES
('Season 1: Genesis', 'The first competitive season of Cipher Clash', NOW(), NOW() + INTERVAL '90 days', TRUE);

-- ============================================================================
-- Achievements (requirement JSON consumed by the achievement evaluator)
-- ============================================================================
INSERT INTO achievements (id, name, description, icon, rarity, xp_reward, requirement, total) VALUES
('FIRST_WIN',        'First Blood',        'Win your first match',                          '🥇', 'COMMON',     100, '{"type":"TOTAL_WINS"}',          1),
('WINS_10',          'Code Breaker',       'Win 10 matches',                                '⚔️', 'COMMON',     250, '{"type":"TOTAL_WINS"}',          10),
('WINS_50',          'Cipher Veteran',     'Win 50 matches',                                '🛡️', 'RARE',       750, '{"type":"TOTAL_WINS"}',          50),
('WINS_200',         'Cryptic Conqueror',  'Win 200 matches',                               '👑', 'LEGENDARY', 2500, '{"type":"TOTAL_WINS"}',          200),
('STREAK_3',         'Hat Trick',          'Win 3 matches in a row',                        '🔥', 'COMMON',     200, '{"type":"WIN_STREAK"}',          3),
('STREAK_7',         'Unstoppable',        'Win 7 matches in a row',                        '⚡', 'EPIC',      1000, '{"type":"WIN_STREAK"}',          7),
('PUZZLES_25',       'Apprentice Analyst', 'Solve 25 puzzles',                              '🧩', 'COMMON',     150, '{"type":"PUZZLES_SOLVED"}',      25),
('PUZZLES_100',      'Master Decoder',     'Solve 100 puzzles',                             '🔍', 'RARE',       500, '{"type":"PUZZLES_SOLVED"}',      100),
('PUZZLES_500',      'Human Enigma',       'Solve 500 puzzles',                             '🧠', 'LEGENDARY', 2000, '{"type":"PUZZLES_SOLVED"}',      500),
('SPEED_30S',        'Speed Demon',        'Solve a puzzle in under 30 seconds',            '⏱️', 'RARE',       400, '{"type":"FASTEST_SOLVE_MS","under_ms":30000}', 1),
('SPEED_10S',        'Lightning Reflexes', 'Solve a puzzle in under 10 seconds',            '🌩️', 'EPIC',      1200, '{"type":"FASTEST_SOLVE_MS","under_ms":10000}', 1),
('PERFECT_MATCH',    'Flawless Victory',   'Win a match solving every puzzle correctly',    '💎', 'RARE',       500, '{"type":"PERFECT_MATCHES"}',     1),
('GAMES_25',         'Regular',            'Play 25 matches',                               '🎮', 'COMMON',     200, '{"type":"TOTAL_GAMES"}',         25),
('BOT_SLAYER',       'Bot Slayer',         'Defeat a bot opponent',                         '🤖', 'COMMON',     100, '{"type":"BOT_WINS"}',            1),
('RANKED_CLIMBER',   'Silver Tongue',      'Reach 1400 ELO',                                '📈', 'RARE',       600, '{"type":"ELO_RATING"}',          1400),
('RANKED_ELITE',     'Golden Mind',        'Reach 1800 ELO',                                '🏅', 'EPIC',      1500, '{"type":"ELO_RATING"}',          1800);

-- ============================================================================
-- Tutorial steps (content is JSON consumed by the client explainers)
-- ============================================================================
INSERT INTO tutorial_steps (id, step_number, title, description, type, content, cipher_type, required, order_index) VALUES
('intro_welcome',           1, 'Welcome to Cipher Clash',  'Learn the basics of competitive codebreaking',          'TEXT',        '{"body":"Cipher Clash pits you against another codebreaker in a race to decrypt classical ciphers. Win matches, climb the ELO ladder, and master 15+ cipher systems."}', NULL,       FALSE, 1),
('intro_how_to_play',       2, 'How a Match Works',        'Understand matchmaking, puzzles, and scoring',          'TEXT',        '{"body":"Each ranked match is a best-of-five puzzle race. Both players receive the same ciphertexts. Solve three before your opponent to win. Difficulty scales with your ELO rating."}', NULL,       TRUE,  2),
('cipher_caesar_intro',     3, 'Caesar Cipher',            'The classic shift cipher used by Julius Caesar',        'INTERACTIVE', '{"explainer":"Every letter is shifted a fixed number of places down the alphabet. A shift of 3 turns A into D.","example_plain":"ATTACK AT DAWN","example_key":"shift 3","example_cipher":"DWWDFN DW GDZQ"}', 'CAESAR',   TRUE,  3),
('cipher_caesar_practice',  4, 'Practice: Caesar',         'Decrypt your first Caesar cipher',                      'PRACTICE',    '{"difficulty":1}',                                                                  'CAESAR',   TRUE,  4),
('cipher_vigenere_intro',   5, 'Vigenère Cipher',          'Polyalphabetic substitution with a keyword',            'INTERACTIVE', '{"explainer":"A keyword determines a different Caesar shift for every letter position, defeating simple frequency analysis.","example_plain":"HELLO","example_key":"KEY","example_cipher":"RIJVS"}', 'VIGENERE', TRUE,  5),
('cipher_vigenere_practice',6, 'Practice: Vigenère',       'Crack a Vigenère cipher with the key provided',         'PRACTICE',    '{"difficulty":2}',                                                                  'VIGENERE', TRUE,  6),
('cipher_railfence_intro',  7, 'Rail Fence Cipher',        'Transposition along zigzag rails',                      'INTERACTIVE', '{"explainer":"Letters are written in a zigzag across N rails, then read row by row. The message is scrambled, not substituted.","example_plain":"WE ARE DISCOVERED","example_key":"3 rails","example_cipher":"WECRD EAEIVRE RDSOE"}', 'RAIL_FENCE', TRUE, 7),
('cipher_playfair_intro',   8, 'Playfair Cipher',          'Digraph substitution on a 5x5 key grid',                'INTERACTIVE', '{"explainer":"Letters are encrypted in pairs using a 5x5 grid built from a keyword - the first practical digraph cipher, used in WWI.","example_plain":"HIDE THE GOLD","example_key":"PLAYFAIR","example_cipher":"BMODZBXDNABEKUDM"}', 'PLAYFAIR', TRUE, 8),
('game_elo_explained',      9, 'ELO & Ranks',              'How ratings, ranks, and adaptive difficulty work',      'TEXT',        '{"body":"You start at 1200 ELO. Wins take rating from your opponent; upsets pay more. Puzzle difficulty adapts to your rating, and matchmaking widens its search range the longer you wait."}', NULL, TRUE, 9),
('tutorial_complete',      10, 'Ready for Battle',         'You are ready for your first match',                    'TEXT',        '{"body":"That is everything you need. Queue up for a ranked match, or warm up against a bot. Good luck, operator."}', NULL, FALSE, 10);

-- ============================================================================
-- Mission templates
-- ============================================================================
INSERT INTO mission_templates (id, title, description, category, frequency, target, xp_reward, coin_reward, difficulty_level, icon) VALUES
('daily_play_1',    'Warm Up',         'Play 1 match',                       'PLAY',            'daily',  1,  50,  10, 1, '🎮'),
('daily_win_2',     'Victory Lap',     'Win 2 matches',                      'WINS',            'daily',  2, 100,  20, 2, '🏆'),
('daily_solve_5',   'Puzzle Hunter',   'Solve 5 puzzles',                    'PUZZLES',         'daily',  5,  75,  15, 1, '🧩'),
('daily_caesar_3',  'Et Tu, Brute?',   'Solve 3 Caesar ciphers',             'CIPHER_SPECIFIC', 'daily',  3,  60,  12, 1, '🏛️'),
('daily_vigenere_2','Keyword Crusher', 'Solve 2 Vigenère ciphers',           'CIPHER_SPECIFIC', 'daily',  2,  70,  14, 2, '🗝️'),
('daily_practice_3','Training Montage','Complete 3 practice sessions',       'PLAY',            'daily',  3,  60,  12, 1, '🥋'),
('weekly_win_10',   'Ranked Warrior',  'Win 10 matches this week',           'WINS',            'weekly', 10, 500, 100, 3, '⚔️'),
('weekly_solve_25', 'Cipher Marathon', 'Solve 25 puzzles this week',         'PUZZLES',         'weekly', 25, 400,  80, 2, '🏃'),
('weekly_streak_3', 'Momentum',        'Reach a 3-win streak this week',     'STREAK',          'weekly',  3, 350,  70, 3, '🔥');

-- ============================================================================
-- Mastery nodes (Caesar + Vigenère trees)
-- ============================================================================
INSERT INTO mastery_nodes (id, cipher_type, tier, name, description, unlock_cost, prerequisite_node_id, bonus_type, bonus_value, icon) VALUES
('CAESAR_CORE_1',     'CAESAR',   1, 'Caesar Initiate',     'Master the basics of shift ciphers',       50,  NULL,             'XP_MULTIPLIER',       1.10, '🏛️'),
('CAESAR_SPEED_1',    'CAESAR',   2, 'Quick Shifter',       'Solve Caesar ciphers 10% faster',          100, 'CAESAR_CORE_1',  'TIME_BONUS',          1.10, '⚡'),
('CAESAR_ACCURACY_1', 'CAESAR',   2, 'Careful Decoder',     'Cheaper hints on Caesar ciphers',          100, 'CAESAR_CORE_1',  'HINT_COST_REDUCTION', 0.90, '🎯'),
('CAESAR_CORE_2',     'CAESAR',   3, 'Caesar Adept',        'Advanced shift cipher techniques',         200, 'CAESAR_CORE_1',  'XP_MULTIPLIER',       1.20, '🏺'),
('CAESAR_ULTIMATE',   'CAESAR',   5, 'Caesar Grandmaster',  'Ultimate mastery of shift ciphers',        500, 'CAESAR_CORE_2',  'XP_MULTIPLIER',       2.00, '👑'),
('VIGENERE_CORE_1',   'VIGENERE', 1, 'Vigenère Initiate',   'Learn keyword-based encryption',           50,  NULL,             'XP_MULTIPLIER',       1.10, '🗝️'),
('VIGENERE_SPEED_1',  'VIGENERE', 2, 'Quick Keyword',       'Faster Vigenère solving',                  100, 'VIGENERE_CORE_1','TIME_BONUS',          1.10, '⚡'),
('VIGENERE_CORE_2',   'VIGENERE', 3, 'Vigenère Adept',      'Advanced polyalphabetic techniques',       200, 'VIGENERE_CORE_1','XP_MULTIPLIER',       1.20, '📜'),
('VIGENERE_ULTIMATE', 'VIGENERE', 5, 'Vigenère Grandmaster','Master of polyalphabetic ciphers',         500, 'VIGENERE_CORE_2','XP_MULTIPLIER',       2.00, '👑'),
('XOR_CORE_1',        'XOR',      1, 'Bitwise Beginner',    'Foundations of XOR encryption',            50,  NULL,             'XP_MULTIPLIER',       1.10, '💾'),
('XOR_CORE_2',        'XOR',      3, 'Stream Splicer',      'Advanced XOR keystream analysis',          200, 'XOR_CORE_1',     'XP_MULTIPLIER',       1.20, '🔌'),
('PLAYFAIR_CORE_1',   'PLAYFAIR', 1, 'Grid Apprentice',     'Foundations of digraph substitution',      50,  NULL,             'XP_MULTIPLIER',       1.10, '🔲'),
('RSA_CORE_1',        'RSA_SIMPLE',1,'Number Theorist',     'Foundations of public-key cryptography',   50,  NULL,             'XP_MULTIPLIER',       1.10, '🔐');

-- ============================================================================
-- Cosmetics catalog
-- ============================================================================
INSERT INTO cosmetics (id, name, description, category, rarity, coin_cost, metadata) VALUES
('title_initiate',     'Initiate',          'Default title for new operators',          'title',         'common',    0,    '{"text":"Initiate"}'),
('title_codebreaker',  'Codebreaker',       'For those who broke their first ciphers',  'title',         'common',    100,  '{"text":"Codebreaker"}'),
('title_spectre',      'Spectre',           'Strike from the shadows',                  'title',         'rare',      400,  '{"text":"Spectre"}'),
('title_archmage',     'Cipher Archmage',   'Legendary mastery of the craft',           'title',         'legendary', 2000, '{"text":"Cipher Archmage"}'),
('frame_steel',        'Steel Frame',       'A no-nonsense avatar frame',               'avatar_frame',  'common',    150,  '{"color":"#8A9BA8"}'),
('frame_neon',         'Neon Frame',        'Glowing cyan avatar frame',                'avatar_frame',  'rare',      500,  '{"color":"#00D9FF"}'),
('frame_gold',         'Gilded Frame',      'For champions of the arena',               'avatar_frame',  'epic',      1200, '{"color":"#FFD700"}'),
('bg_terminal',        'Terminal',          'Classic green-on-black profile backdrop',  'background',    'common',    200,  '{"theme":"terminal"}'),
('bg_circuit',         'Circuit Board',     'Etched copper traces backdrop',            'background',    'rare',      600,  '{"theme":"circuit"}'),
('bg_matrix',          'Digital Rain',      'Cascading glyphs backdrop',                'background',    'epic',      1500, '{"theme":"matrix"}'),
('fx_sparks',          'Solve Sparks',      'Particle burst on every correct solve',    'particle_effect','rare',     800,  '{"effect":"sparks"}'),
('fx_glitch',          'Glitch Pulse',      'Reality stutters when you score',          'particle_effect','epic',     1600, '{"effect":"glitch"}');

-- ============================================================================
-- Bot opponents (fixed UUIDs; cannot log in - no valid bcrypt hash)
-- ============================================================================
INSERT INTO users (id, username, email, password_hash, display_name, title, region, elo_rating, level, is_bot, is_verified, total_games, wins, losses) VALUES
('00000000-0000-4000-8000-0000000000b1', 'NEMESIS_X',  'nemesis_x@bots.cipherclash.local',  '!bot-no-login', 'NEMESIS-X',  'Training Bot', 'US', 1100, 5,  TRUE, TRUE, 0, 0, 0),
('00000000-0000-4000-8000-0000000000b2', 'CIPHER_GHOST','cipher_ghost@bots.cipherclash.local','!bot-no-login', 'CipherGhost','Training Bot', 'EU', 1300, 12, TRUE, TRUE, 0, 0, 0),
('00000000-0000-4000-8000-0000000000b3', 'ENIGMA_PRIME','enigma_prime@bots.cipherclash.local','!bot-no-login', 'EnigmaPrime','Training Bot', 'US', 1550, 20, TRUE, TRUE, 0, 0, 0);
