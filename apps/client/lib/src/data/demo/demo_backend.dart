/// DEMO_MODE backend: replaces the HTTP transport and the game WebSocket
/// with in-memory simulations so the entire app is fully playable with zero
/// live services (used for the static Vercel deployment).
library demo_backend;

import 'dart:math';

import '../../core/api_client.dart';
import '../game_socket.dart';
import 'demo_data.dart';
import 'demo_game_socket.dart';

class DemoBackend {
  DemoBackend._();

  /// Swaps both transports for the in-memory demo implementations.
  static void install() {
    Api.client = DemoApiClient();
    GameSocketFactory.create = DemoGameSocket.new;
  }
}

/// All mutable demo-session state in one place.
class DemoState {
  DemoState._();
  static final DemoState instance = DemoState._();

  String username = 'OPERATOR';
  int elo = 1200;
  int xp = 0;
  int coins = 250;
  int wins = 0;
  int losses = 0;
  int winStreak = 0;
  int bestStreak = 0;
  int puzzlesSolved = 0;
  int fastestSolveMs = 0;

  final Set<String> ownedCosmetics = {};
  final Map<String, int> achievementProgress = {};
  final Set<String> unlockedAchievements = {};
  final List<Map<String, dynamic>> missions = [];
  final List<Map<String, dynamic>> history = [];
  final Map<String, Map<String, dynamic>> replays = {};
  final Map<String, int> masterySolves = {};

  // Matchmaking simulation.
  DateTime? queuedAt;
  Map<String, dynamic>? pendingAssignment;

  // Practice simulation.
  final Map<String, Map<String, dynamic>> practiceSessions = {};
  final List<Map<String, dynamic>> practiceHistory = [];

  int get totalGames => wins + losses;

  String get rankTier {
    if (totalGames == 0 && elo == 1200) return 'UNRANKED';
    if (elo < 1400) return 'BRONZE';
    if (elo < 1600) return 'SILVER';
    if (elo < 1800) return 'GOLD';
    return 'PLATINUM';
  }

  Map<String, dynamic> profile() => {
        'id': 'demo-user',
        'username': username,
        'email': 'demo@cipherclash.dev',
        'level': 1 + xp ~/ 1000,
        'xp': xp,
        'coins': coins,
        'elo_rating': elo,
        'rank_tier': rankTier,
        'region': 'US',
        'total_games': totalGames,
        'wins': wins,
        'losses': losses,
        'win_streak': winStreak,
        'best_win_streak': bestStreak,
        'puzzles_solved': puzzlesSolved,
        'fastest_solve_ms': fastestSolveMs,
      };

  /// Applies a finished demo match to all progression systems.
  void recordMatch({
    required bool won,
    required bool ranked,
    required int yourScore,
    required int opponentScore,
    required String opponentName,
    required int eloChange,
    required int durationMs,
    required int solvedThisMatch,
    required bool perfect,
    required int fastestMs,
    required Map<String, int> solvedByCipher,
    required String matchId,
    required Map<String, dynamic> replay,
  }) {
    if (won) {
      wins++;
      winStreak++;
      if (winStreak > bestStreak) bestStreak = winStreak;
    } else {
      losses++;
      winStreak = 0;
    }
    if (ranked) elo += eloChange;
    puzzlesSolved += solvedThisMatch;
    if (fastestMs > 0 && (fastestSolveMs == 0 || fastestMs < fastestSolveMs)) {
      fastestSolveMs = fastestMs;
    }
    solvedByCipher.forEach((cipher, count) {
      masterySolves[cipher] = (masterySolves[cipher] ?? 0) + count;
    });

    history.insert(0, {
      'match_id': matchId,
      'game_mode': ranked ? 'RANKED_1V1' : 'BOT_MATCH',
      'opponent_username': opponentName,
      'winner_id': won ? 'demo-user' : 'demo-opponent',
      'won': won,
      'your_score': yourScore,
      'opponent_score': opponentScore,
      'elo_change': ranked ? eloChange : 0,
      'duration_ms': durationMs,
      'ended_at': DateTime.now().toIso8601String(),
      'has_replay': true,
    });
    replays[matchId] = replay;

    // Achievements.
    void bump(String id, int delta) {
      achievementProgress[id] = (achievementProgress[id] ?? 0) + delta;
    }

    void setMax(String id, int value) {
      if (value > (achievementProgress[id] ?? 0)) {
        achievementProgress[id] = value;
      }
    }

    if (won) bump('FIRST_WIN', 1);
    if (won) bump('WINS_10', 1);
    setMax('STREAK_3', winStreak);
    bump('PUZZLES_25', solvedThisMatch);
    if (fastestMs > 0 && fastestMs < 30000) setMax('SPEED_30S', 1);
    if (won && !ranked) bump('BOT_SLAYER', 1);
    if (won && perfect && solvedThisMatch > 0) bump('PERFECT_MATCH', 1);
    setMax('RANKED_CLIMBER', elo);
    for (final a in demoAchievements) {
      final id = a['id'] as String;
      if ((achievementProgress[id] ?? 0) >= (a['total'] as int)) {
        if (unlockedAchievements.add(id)) {
          xp += a['xp_reward'] as int;
        }
      }
    }

    // Missions.
    for (final mission in missions) {
      if (mission['status'] != 'active') continue;
      final template = mission['template'] as Map<String, dynamic>;
      int progress = mission['progress'] as int;
      switch (template['category']) {
        case 'PLAY':
          progress++;
          break;
        case 'WINS':
          if (won) progress++;
          break;
        case 'PUZZLES':
          progress += solvedThisMatch;
          break;
      }
      final target = mission['target'] as int;
      mission['progress'] = progress.clamp(0, target);
      if (progress >= target) mission['status'] = 'completed';
    }
  }
}

/// In-memory transport simulating every backend route the app calls, with
/// realistic latency.
class DemoApiClient implements ApiClient {
  final _random = Random();
  DemoState get _state => DemoState.instance;

  @override
  Future<ApiResponse> get(String url, {bool auth = true}) =>
      _route('GET', url, null);

  @override
  Future<ApiResponse> post(String url, {Object? body, bool auth = true}) =>
      _route('POST', url, body);

  @override
  Future<ApiResponse> delete(String url, {Object? body, bool auth = true}) =>
      _route('DELETE', url, body);

  ApiResponse _ok(dynamic json) => ApiResponse(200, json);
  ApiResponse _err(int status, String message) => ApiResponse(status, {
        'error': {'code': 'DEMO', 'message': message}
      });

  Future<ApiResponse> _route(String method, String url, Object? body) async {
    await Future<void>.delayed(
        Duration(milliseconds: 120 + _random.nextInt(180)));
    final params = body is Map ? body.cast<String, dynamic>() : const <String, dynamic>{};

    // ── auth ────────────────────────────────────────────────────────────
    if (url.contains('/auth/register') || url.contains('/auth/login')) {
      _state.username =
          (params['username'] as String?)?.toUpperCase() ?? 'OPERATOR';
      return _ok({
        'user': _state.profile(),
        'access_token': 'demo-access-token',
        'refresh_token': 'demo-refresh-token',
        'expires_in': 900,
      });
    }
    if (url.contains('/auth/refresh')) {
      return _ok({'access_token': 'demo-access-token'});
    }
    if (url.contains('/auth/profile')) return _ok(_state.profile());
    if (url.contains('/auth/users/lookup')) {
      return _err(404, 'Demo mode has no other registered operators');
    }

    // ── matchmaker ──────────────────────────────────────────────────────
    if (url.contains('/matchmaker/join')) {
      _state.queuedAt = DateTime.now();
      _state.pendingAssignment = null;
      return _ok({
        'queue_id': 'demo-user',
        'estimated_wait_time_seconds': 8,
        'players_in_queue': 3 + _random.nextInt(5),
        'position': 1,
      });
    }
    if (url.contains('/matchmaker/leave')) {
      _state.queuedAt = null;
      return _ok({'message': 'Left queue successfully'});
    }
    if (url.contains('/matchmaker/status')) {
      final queuedAt = _state.queuedAt;
      if (queuedAt == null) {
        final pending = _state.pendingAssignment;
        if (pending != null) return _ok(pending);
        return _ok({'status': 'idle', 'in_queue': false});
      }
      final waited = DateTime.now().difference(queuedAt).inSeconds;
      // A "human" opponent appears after ~6 seconds.
      if (waited >= 6) {
        _state.queuedAt = null;
        final opponent =
            demoOpponents[_random.nextInt(demoOpponents.length)];
        final assignment = {
          'status': 'match_found',
          'in_queue': false,
          'match_id': 'demo-${DateTime.now().millisecondsSinceEpoch}',
          'game_mode': 'RANKED_1V1',
          'is_ranked': true,
          'opponent': {
            'user_id': 'demo-opponent',
            'username': opponent['username'],
            'elo': opponent['elo'],
          },
        };
        _state.pendingAssignment = assignment;
        return _ok(assignment);
      }
      return _ok({
        'status': 'searching',
        'in_queue': true,
        'wait_time_seconds': waited,
        'position': 1,
        'players_in_queue': 3 + _random.nextInt(5),
        'game_mode': 'RANKED_1V1',
        'search_range': 100 + (waited ~/ 15) * 50,
      });
    }
    if (url.contains('/matchmaker/leaderboard')) {
      final entries = [...demoLeaderboard];
      if (_state.totalGames > 0) {
        entries.add({
          'rank': 0,
          'user_id': 'demo-user',
          'username': _state.username,
          'elo_rating': _state.elo,
          'rank_tier': _state.rankTier,
          'total_games': _state.totalGames,
          'wins': _state.wins,
          'losses': _state.losses,
          'win_rate': _state.totalGames > 0
              ? double.parse(
                  (100 * _state.wins / _state.totalGames).toStringAsFixed(1))
              : 0.0,
          'win_streak': _state.winStreak,
        });
        entries.sort((a, b) =>
            (b['elo_rating'] as int).compareTo(a['elo_rating'] as int));
        for (var i = 0; i < entries.length; i++) {
          entries[i] = {...entries[i], 'rank': i + 1};
        }
      }
      return _ok({'entries': entries, 'total_count': entries.length});
    }

    // ── game REST ───────────────────────────────────────────────────────
    if (url.contains('/match/bot')) {
      return _ok({
        'match_id': 'demo-bot-${DateTime.now().millisecondsSinceEpoch}',
        'game_mode': 'BOT_MATCH',
        'is_ranked': false,
        'opponent': {
          'user_id': 'demo-opponent',
          'username': demoBot['username'],
          'elo': demoBot['elo'],
          'is_bot': true,
        },
      });
    }
    if (url.contains('/matches/history')) {
      return _ok({'matches': _state.history});
    }
    if (url.contains('/matches/replay')) {
      final id = Uri.parse(url).queryParameters['match_id'];
      final replay = _state.replays[id];
      if (replay == null) return _err(404, 'No replay for this match');
      return _ok(replay);
    }
    if (url.contains('/matches/live')) {
      return _ok({'match_ids': <String>[]});
    }

    // ── achievements ────────────────────────────────────────────────────
    if (url.contains('/user/achievements')) {
      final list = demoAchievements.map((a) {
        final id = a['id'] as String;
        return {
          ...a,
          'progress': (_state.achievementProgress[id] ?? 0)
              .clamp(0, a['total'] as int),
          'unlocked': _state.unlockedAchievements.contains(id),
        };
      }).toList();
      return _ok({'achievements': list, 'count': list.length});
    }

    // ── missions ────────────────────────────────────────────────────────
    if (url.contains('/missions/assign')) {
      if (_state.missions.isEmpty) {
        for (final template in demoMissionTemplates) {
          _state.missions.add({
            'id': 'demo-${template['id']}',
            'template_id': template['id'],
            'template': template,
            'progress': 0,
            'target': template['target'],
            'status': 'active',
          });
        }
      }
      return _ok({'missions': _state.missions});
    }
    if (url.contains('/missions/claim')) {
      final templateId = params['template_id'];
      for (final mission in _state.missions) {
        if (mission['template_id'] == templateId &&
            mission['status'] == 'completed') {
          mission['status'] = 'claimed';
          final template = mission['template'] as Map<String, dynamic>;
          _state.coins += template['coin_reward'] as int;
          _state.xp += template['xp_reward'] as int;
          return _ok({
            'rewards': {
              'xp': template['xp_reward'],
              'coins': template['coin_reward'],
            }
          });
        }
      }
      return _err(400, 'Mission not completed');
    }
    if (url.contains('/missions/user/')) {
      return _ok({'missions': _state.missions});
    }

    // ── mastery ─────────────────────────────────────────────────────────
    if (url.contains('/mastery/points/')) {
      final points = _state.masterySolves.entries
          .map((entry) => {
                'user_id': 'demo-user',
                'cipher_type': entry.key,
                'total_points': entry.value * 15,
                'available_points': entry.value * 15,
                'spent_points': 0,
                'level': 1 + (entry.value * 15) ~/ 100,
                'puzzles_solved': entry.value,
              })
          .toList();
      return _ok({'points': points});
    }

    // ── social ──────────────────────────────────────────────────────────
    if (url.contains('/friends/pending')) return _ok({'requests': []});
    if (url.contains('/friends/')) return _ok({'friends': []});
    if (url.contains('/invites/')) return _ok({'invites': []});

    // ── cosmetics ───────────────────────────────────────────────────────
    if (url.contains('/cosmetics/catalog')) {
      return _ok({'cosmetics': demoCosmetics});
    }
    if (url.contains('/cosmetics/inventory')) {
      return _ok({
        'inventory': _state.ownedCosmetics
            .map((id) => {'cosmetic_id': id})
            .toList(),
      });
    }
    if (url.contains('/cosmetics/purchase')) {
      final id = params['cosmetic_id'] as String?;
      final item = demoCosmetics.where((c) => c['id'] == id).firstOrNull;
      if (item == null) return _err(404, 'Unknown cosmetic');
      final cost = item['coin_cost'] as int;
      if (_state.ownedCosmetics.contains(id)) {
        return _err(400, 'You already own this cosmetic');
      }
      if (_state.coins < cost) return _err(400, 'Insufficient coins');
      _state.coins -= cost;
      _state.ownedCosmetics.add(id!);
      return _ok({'new_balance': _state.coins});
    }
    if (url.contains('/cosmetics/loadout/equip')) {
      return _ok({'message': 'Equipped'});
    }

    // ── practice ────────────────────────────────────────────────────────
    if (url.contains('/practice/generate')) {
      final cipherType = params['cipher_type'] as String?;
      final candidates = cipherType == null
          ? demoPuzzles
          : demoPuzzles
              .where((p) => p['cipher_type'] == cipherType)
              .toList();
      final pool = candidates.isEmpty ? demoPuzzles : candidates;
      final puzzle = pool[_random.nextInt(pool.length)];
      final sessionId = 'demo-practice-${DateTime.now().millisecondsSinceEpoch}';
      _state.practiceSessions[sessionId] = puzzle;
      return _ok({
        'session_id': sessionId,
        'puzzle': {
          'id': sessionId,
          'cipher_type': puzzle['cipher_type'],
          'difficulty': puzzle['difficulty'],
          'encrypted_text': puzzle['encrypted_text'],
        },
      });
    }
    if (url.contains('/practice/submit')) {
      final sessionId = params['session_id'] as String?;
      final puzzle = _state.practiceSessions[sessionId];
      if (puzzle == null) return _err(404, 'Session not found');
      final correct = _normalize(params['solution'] as String? ?? '') ==
          _normalize(puzzle['plaintext'] as String);
      final solveMs = (params['solve_time_ms'] as num?)?.toInt() ?? 0;
      final score =
          correct ? 100 * (puzzle['difficulty'] as int) : 0;
      if (correct) {
        _state.puzzlesSolved++;
        _state.practiceHistory.insert(0, {
          'cipher_type': puzzle['cipher_type'],
          'difficulty': puzzle['difficulty'],
          'is_correct': true,
          'solve_time_ms': solveMs,
          'score': score,
        });
      }
      return _ok({
        'is_correct': correct,
        'score': score,
        'accuracy': correct ? 1.0 : 0.0,
      });
    }
    if (url.contains('/practice/history')) {
      return _ok({'sessions': _state.practiceHistory});
    }
    if (url.contains('/practice/leaderboard')) {
      return _ok({'entries': []});
    }

    // ── tutorial ────────────────────────────────────────────────────────
    if (url.contains('/tutorial/')) {
      return _ok({'steps': [], 'progress': []});
    }

    return _err(404, 'Demo route not implemented: $method $url');
  }

  String _normalize(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
