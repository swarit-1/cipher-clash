/// Canned data for DEMO_MODE. The puzzles were generated with the real Go
/// cipher implementations, so demo gameplay is authentic.
library demo_data;

const demoPuzzles = <Map<String, dynamic>>[
  {'cipher_type': 'CAESAR', 'difficulty': 1, 'encrypted_text': 'WKH TXLFN EURZQ IRA MXPSV RYHU WKH ODCB GRJ', 'plaintext': 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG'},
  {'cipher_type': 'ATBASH', 'difficulty': 2, 'encrypted_text': 'XIBKGLTIZKSB RH GSV ZIG LU HVXFIV XLNNFMRXZGRLM', 'plaintext': 'CRYPTOGRAPHY IS THE ART OF SECURE COMMUNICATION'},
  {'cipher_type': 'ROT13', 'difficulty': 3, 'encrypted_text': 'ZNL GUR SBEPR OR JVGU LBH', 'plaintext': 'MAY THE FORCE BE WITH YOU'},
  {'cipher_type': 'VIGENERE', 'difficulty': 1, 'encrypted_text': 'WPQTLU IZ FOTLNN', 'plaintext': 'WINTER IS COMING'},
  {'cipher_type': 'RAIL_FENCE', 'difficulty': 2, 'encrypted_text': 'HUTNW AEAPOLMOSO EHV  RBE', 'plaintext': 'HOUSTON WE HAVE A PROBLEM'},
  {'cipher_type': 'MORSE', 'difficulty': 3, 'encrypted_text': '. .-.. . -- . -. - .- .-. -.-- / -- -.-- / -.. . .- .-. / .-- .- - ... --- -.', 'plaintext': 'ELEMENTARY MY DEAR WATSON'},
  {'cipher_type': 'HEXADECIMAL', 'difficulty': 1, 'encrypted_text': '5448452043414b452049532041204c4945', 'plaintext': 'THE CAKE IS A LIE'},
  {'cipher_type': 'BASE64', 'difficulty': 2, 'encrypted_text': 'QUxMIFlPVVIgQkFTRSBBUkUgQkVMT05HIFRPIFVT', 'plaintext': 'ALL YOUR BASE ARE BELONG TO US'},
  {'cipher_type': 'BINARY', 'difficulty': 3, 'encrypted_text': '01010100 01001000 01000101 00100000 01010001 01010101 01001001 01000011 01001011 00100000 01000010 01010010 01001111 01010111 01001110 00100000 01000110 01001111 01011000 00100000 01001010 01010101 01001101 01010000 01010011 00100000 01001111 01010110 01000101 01010010 00100000 01010100 01001000 01000101 00100000 01001100 01000001 01011010 01011001 00100000 01000100 01001111 01000111', 'plaintext': 'THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG'},
  {'cipher_type': 'CAESAR', 'difficulty': 1, 'encrypted_text': 'FUBSWRJUDSKB LV WKH DUW RI VHFXUH FRPPXQLFDWLRQ', 'plaintext': 'CRYPTOGRAPHY IS THE ART OF SECURE COMMUNICATION'},
  {'cipher_type': 'VIGENERE', 'difficulty': 2, 'encrypted_text': 'MPY UHT FPRRE CE LIUH NOV', 'plaintext': 'MAY THE FORCE BE WITH YOU'},
  {'cipher_type': 'ATBASH', 'difficulty': 3, 'encrypted_text': 'DRMGVI RH XLNRMT', 'plaintext': 'WINTER IS COMING'},
  {'cipher_type': 'ROT13', 'difficulty': 1, 'encrypted_text': 'UBHFGBA JR UNIR N CEBOYRZ', 'plaintext': 'HOUSTON WE HAVE A PROBLEM'},
  {'cipher_type': 'RAIL_FENCE', 'difficulty': 2, 'encrypted_text': 'EEETR YDA ASNLMNAYM ERWTO', 'plaintext': 'ELEMENTARY MY DEAR WATSON'},
  {'cipher_type': 'CAESAR', 'difficulty': 3, 'encrypted_text': 'CQN LJTN RB J URN', 'plaintext': 'THE CAKE IS A LIE'},
  {'cipher_type': 'MORSE', 'difficulty': 1, 'encrypted_text': '.- .-.. .-.. / -.-- --- ..- .-. / -... .- ... . / .- .-. . / -... . .-.. --- -. --. / - --- / ..- ...', 'plaintext': 'ALL YOUR BASE ARE BELONG TO US'},
];

/// Bot personas the demo matchmaker pairs you against.
const demoOpponents = <Map<String, dynamic>>[
  {'username': 'GHOST_RUNNER', 'elo': 1214},
  {'username': 'NULLPOINTER', 'elo': 1188},
  {'username': 'TURING_HEIR', 'elo': 1242},
];

const demoBot = {'username': 'NEMESIS_X', 'elo': 1100};

const demoLeaderboard = <Map<String, dynamic>>[
  {'rank': 1, 'user_id': 'd1', 'username': 'VERNAM_GHOST', 'elo_rating': 1893, 'rank_tier': 'GOLD', 'total_games': 214, 'wins': 141, 'losses': 73, 'win_rate': 65.9, 'win_streak': 4},
  {'rank': 2, 'user_id': 'd2', 'username': 'KASISKI', 'elo_rating': 1781, 'rank_tier': 'GOLD', 'total_games': 178, 'wins': 109, 'losses': 69, 'win_rate': 61.2, 'win_streak': 0},
  {'rank': 3, 'user_id': 'd3', 'username': 'TURING_HEIR', 'elo_rating': 1742, 'rank_tier': 'GOLD', 'total_games': 305, 'wins': 177, 'losses': 128, 'win_rate': 58.0, 'win_streak': 2},
  {'rank': 4, 'user_id': 'd4', 'username': 'ROTORBREAK', 'elo_rating': 1655, 'rank_tier': 'SILVER', 'total_games': 96, 'wins': 55, 'losses': 41, 'win_rate': 57.3, 'win_streak': 1},
  {'rank': 5, 'user_id': 'd5', 'username': 'GHOST_RUNNER', 'elo_rating': 1531, 'rank_tier': 'SILVER', 'total_games': 142, 'wins': 74, 'losses': 68, 'win_rate': 52.1, 'win_streak': 0},
  {'rank': 6, 'user_id': 'd6', 'username': 'NULLPOINTER', 'elo_rating': 1402, 'rank_tier': 'SILVER', 'total_games': 88, 'wins': 41, 'losses': 47, 'win_rate': 46.6, 'win_streak': 0},
  {'rank': 7, 'user_id': 'd7', 'username': 'CAESARS_BANE', 'elo_rating': 1337, 'rank_tier': 'BRONZE', 'total_games': 61, 'wins': 27, 'losses': 34, 'win_rate': 44.3, 'win_streak': 1},
];

/// Mirrors the seeded achievements (subset).
const demoAchievements = <Map<String, dynamic>>[
  {'id': 'FIRST_WIN', 'name': 'First Blood', 'description': 'Win your first match', 'icon': '🥇', 'rarity': 'COMMON', 'xp_reward': 100, 'total': 1},
  {'id': 'WINS_10', 'name': 'Code Breaker', 'description': 'Win 10 matches', 'icon': '⚔️', 'rarity': 'COMMON', 'xp_reward': 250, 'total': 10},
  {'id': 'STREAK_3', 'name': 'Hat Trick', 'description': 'Win 3 matches in a row', 'icon': '🔥', 'rarity': 'COMMON', 'xp_reward': 200, 'total': 3},
  {'id': 'PUZZLES_25', 'name': 'Apprentice Analyst', 'description': 'Solve 25 puzzles', 'icon': '🧩', 'rarity': 'COMMON', 'xp_reward': 150, 'total': 25},
  {'id': 'SPEED_30S', 'name': 'Speed Demon', 'description': 'Solve a puzzle in under 30 seconds', 'icon': '⏱️', 'rarity': 'RARE', 'xp_reward': 400, 'total': 1},
  {'id': 'BOT_SLAYER', 'name': 'Bot Slayer', 'description': 'Defeat a bot opponent', 'icon': '🤖', 'rarity': 'COMMON', 'xp_reward': 100, 'total': 1},
  {'id': 'PERFECT_MATCH', 'name': 'Flawless Victory', 'description': 'Win a match solving every puzzle correctly', 'icon': '💎', 'rarity': 'RARE', 'xp_reward': 500, 'total': 1},
  {'id': 'RANKED_CLIMBER', 'name': 'Silver Tongue', 'description': 'Reach 1400 ELO', 'icon': '📈', 'rarity': 'RARE', 'xp_reward': 600, 'total': 1400},
];

const demoMissionTemplates = <Map<String, dynamic>>[
  {'id': 'daily_play_1', 'title': 'Warm Up', 'description': 'Play 1 match', 'category': 'PLAY', 'target': 1, 'xp_reward': 50, 'coin_reward': 10, 'icon': '🎮'},
  {'id': 'daily_win_2', 'title': 'Victory Lap', 'description': 'Win 2 matches', 'category': 'WINS', 'target': 2, 'xp_reward': 100, 'coin_reward': 20, 'icon': '🏆'},
  {'id': 'daily_solve_5', 'title': 'Puzzle Hunter', 'description': 'Solve 5 puzzles', 'category': 'PUZZLES', 'target': 5, 'xp_reward': 75, 'coin_reward': 15, 'icon': '🧩'},
];

const demoCosmetics = <Map<String, dynamic>>[
  {'id': 'title_codebreaker', 'name': 'Codebreaker', 'description': 'For those who broke their first ciphers', 'category': 'title', 'rarity': 'common', 'coin_cost': 100},
  {'id': 'title_spectre', 'name': 'Spectre', 'description': 'Strike from the shadows', 'category': 'title', 'rarity': 'rare', 'coin_cost': 400},
  {'id': 'frame_neon', 'name': 'Neon Frame', 'description': 'Glowing cyan avatar frame', 'category': 'avatar_frame', 'rarity': 'rare', 'coin_cost': 500},
  {'id': 'bg_terminal', 'name': 'Terminal', 'description': 'Classic green-on-black profile backdrop', 'category': 'background', 'rarity': 'common', 'coin_cost': 200},
  {'id': 'bg_matrix', 'name': 'Digital Rain', 'description': 'Cascading glyphs backdrop', 'category': 'background', 'rarity': 'epic', 'coin_cost': 1500},
  {'id': 'fx_sparks', 'name': 'Solve Sparks', 'description': 'Particle burst on every correct solve', 'category': 'particle_effect', 'rarity': 'rare', 'coin_cost': 800},
];
