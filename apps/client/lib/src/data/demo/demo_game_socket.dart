/// Local match simulation for DEMO_MODE: speaks the exact server protocol
/// (ROOM_STATE, MATCH_STARTED, PUZZLE_SET, SUBMIT_RESULT, OPPONENT_*,
/// MATCH_END) and runs the bot opponent in-process.
library demo_game_socket;

import 'dart:async';
import 'dart:math';

import '../game_socket.dart';
import 'demo_backend.dart';
import 'demo_data.dart';

class DemoGameSocket implements GameSocket {
  DemoGameSocket();

  final _messages = StreamController<ServerMessage>.broadcast();
  final _state = StreamController<SocketState>.broadcast();
  final _random = Random();

  late String _matchId;
  late bool _ranked;
  late Map<String, dynamic> _opponent;
  late List<Map<String, dynamic>> _puzzles;

  static const _targetSolves = 3;
  static const _matchSeconds = 300;

  int _yourIndex = 0;
  int _yourSolves = 0;
  int _wrongAttempts = 0;
  int _botIndex = 0;
  int _botSolves = 0;
  final List<int> _yourSolveTimes = [];
  final Map<String, int> _solvedByCipher = {};
  final List<Map<String, dynamic>> _events = [];

  DateTime _epoch = DateTime.now();
  DateTime _puzzleStart = DateTime.now();
  Timer? _botProgressTimer;
  Timer? _botSolveTimer;
  Timer? _deadlineTimer;
  DateTime _botPuzzleStart = DateTime.now();
  Duration _botTarget = Duration.zero;
  bool _ended = false;

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  Stream<SocketState> get state => _state.stream;

  void _emit(String type, Map<String, dynamic> payload) {
    if (!_messages.isClosed) _messages.add(ServerMessage(type, payload));
  }

  void _record(String uid, String type, [Map<String, dynamic>? data]) {
    _events.add({
      't_ms': DateTime.now().difference(_epoch).inMilliseconds,
      'uid': uid,
      'type': type,
      if (data != null) 'data': data,
    });
  }

  @override
  Future<void> connect(String matchId, {bool spectate = false}) async {
    _matchId = matchId;
    _ranked = !matchId.startsWith('demo-bot');
    _opponent = _ranked
        ? demoOpponents[_random.nextInt(demoOpponents.length)]
        : Map<String, dynamic>.from(demoBot);

    // A small, varied puzzle set for the match.
    final shuffled = [...demoPuzzles]..shuffle(_random);
    _puzzles = shuffled.take(5).toList();

    _epoch = DateTime.now();
    _state.add(SocketState.connecting);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    _state.add(SocketState.connected);
    _record('demo-user', 'JOIN');
    _record('demo-opponent', 'JOIN');

    _emit('ROOM_STATE', {
      'match_id': _matchId,
      'status': 'WAITING',
      'game_mode': _ranked ? 'RANKED_1V1' : 'BOT_MATCH',
      'is_ranked': _ranked,
      'you': _playerView('demo-user'),
      'opponent': _playerView('demo-opponent'),
      'total_puzzles': _puzzles.length,
      'target_solves': _targetSolves,
      'server_now_ms': DateTime.now().millisecondsSinceEpoch,
    });

    // Countdown, then play.
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final startsAt = DateTime.now().add(const Duration(seconds: 3));
    final deadline = startsAt.add(const Duration(seconds: _matchSeconds));
    _emit('MATCH_STARTED', {
      'starts_at_ms': startsAt.millisecondsSinceEpoch,
      'deadline_ms': deadline.millisecondsSinceEpoch,
      'server_now_ms': DateTime.now().millisecondsSinceEpoch,
    });
    _record('', 'MATCH_STARTED');

    Timer(const Duration(seconds: 3), () {
      if (_ended) return;
      _puzzleStart = DateTime.now();
      _sendPuzzle();
      _startBotPuzzle();
      _deadlineTimer = Timer(const Duration(seconds: _matchSeconds), () {
        if (!_ended) _finish(timeout: true);
      });
    });
  }

  Map<String, dynamic> _playerView(String id) {
    final you = id == 'demo-user';
    final state = DemoState.instance;
    return {
      'user_id': id,
      'username': you ? state.username : _opponent['username'],
      'elo': you ? state.elo : _opponent['elo'],
      'is_bot': !you && !_ranked,
      'connected': true,
      'solved_count': you ? _yourSolves : _botSolves,
      'puzzle_index': you ? _yourIndex : _botIndex,
      'progress': 0.0,
    };
  }

  void _sendPuzzle() {
    final puzzle = _puzzles[_yourIndex];
    _emit('PUZZLE_SET', {
      'puzzle': {
        'index': _yourIndex,
        'cipher_type': puzzle['cipher_type'],
        'difficulty': puzzle['difficulty'],
        'encrypted_text': puzzle['encrypted_text'],
      },
      'total_puzzles': _puzzles.length,
    });
  }

  // ── Bot behaviour ──────────────────────────────────────────────────────

  void _startBotPuzzle() {
    if (_ended || _botIndex >= _puzzles.length) return;
    final difficulty = _puzzles[_botIndex]['difficulty'] as int;
    // Beatable but persistent: ~25-60s per puzzle.
    final baseMs = 22000 + difficulty * 9000;
    final jitter = 0.75 + _random.nextDouble() * 0.5;
    _botTarget = Duration(milliseconds: (baseMs * jitter).round());
    _botPuzzleStart = DateTime.now();

    _botProgressTimer?.cancel();
    _botProgressTimer =
        Timer.periodic(const Duration(seconds: 2), (_) => _botProgress());
    _botSolveTimer?.cancel();
    _botSolveTimer = Timer(_botTarget, _botSolve);
  }

  void _botProgress() {
    if (_ended) return;
    final elapsed = DateTime.now().difference(_botPuzzleStart);
    var progress = elapsed.inMilliseconds / _botTarget.inMilliseconds;
    progress = progress.clamp(0.0, 0.95);
    _emit('OPPONENT_PROGRESS', {
      'progress': progress,
      'puzzle_index': _botIndex,
    });
    _record('demo-opponent', 'PROGRESS', {'pct': progress, 'puzzle': _botIndex});
  }

  void _botSolve() {
    if (_ended) return;
    _botSolves++;
    final solveMs = DateTime.now().difference(_botPuzzleStart).inMilliseconds;
    _record('demo-opponent', 'SOLVED', {'puzzle': _botIndex, 'ms': solveMs});
    _emit('OPPONENT_SOLVED', {
      'puzzle_index': _botIndex,
      'solved_count': _botSolves,
      'solve_time_ms': solveMs,
    });
    if (_botSolves >= _targetSolves) {
      _finish(winnerIsYou: false);
      return;
    }
    _botIndex++;
    _startBotPuzzle();
  }

  // ── Player actions ─────────────────────────────────────────────────────

  @override
  void submit(int puzzleIndex, String solution) {
    if (_ended || puzzleIndex != _yourIndex) return;
    final puzzle = _puzzles[_yourIndex];
    final correct = _normalize(solution) ==
        _normalize(puzzle['plaintext'] as String);
    final solveMs = DateTime.now().difference(_puzzleStart).inMilliseconds;

    if (!correct) {
      _wrongAttempts++;
      _record('demo-user', 'SUBMIT_WRONG', {'puzzle': _yourIndex});
      _emit('SUBMIT_RESULT', {
        'puzzle_index': _yourIndex,
        'correct': false,
        'solved_count': _yourSolves,
      });
      return;
    }

    _yourSolves++;
    _yourSolveTimes.add(solveMs);
    final cipher = puzzle['cipher_type'] as String;
    _solvedByCipher[cipher] = (_solvedByCipher[cipher] ?? 0) + 1;
    _record('demo-user', 'SOLVED', {'puzzle': _yourIndex, 'ms': solveMs});
    _emit('SUBMIT_RESULT', {
      'puzzle_index': _yourIndex,
      'correct': true,
      'solve_time_ms': solveMs,
      'solved_count': _yourSolves,
    });

    if (_yourSolves >= _targetSolves) {
      _finish(winnerIsYou: true);
      return;
    }
    if (_yourIndex + 1 < _puzzles.length) {
      _yourIndex++;
      _puzzleStart = DateTime.now();
      _sendPuzzle();
    }
  }

  @override
  void sendProgress(double progress) {
    // The local bot does not need to see your progress; recorded for replay.
    _record('demo-user', 'PROGRESS', {'pct': progress, 'puzzle': _yourIndex});
  }

  @override
  void forfeit() {
    if (_ended) return;
    _record('demo-user', 'FORFEIT');
    _finish(winnerIsYou: false, reason: 'FORFEIT');
  }

  // ── Match end ──────────────────────────────────────────────────────────

  void _finish({bool? winnerIsYou, bool timeout = false, String? reason}) {
    if (_ended) return;
    _ended = true;
    _botProgressTimer?.cancel();
    _botSolveTimer?.cancel();
    _deadlineTimer?.cancel();

    bool youWin;
    String endReason;
    if (timeout) {
      youWin = _yourSolves > _botSolves;
      endReason = _yourSolves == _botSolves ? 'DRAW' : 'TIMEOUT';
    } else {
      youWin = winnerIsYou ?? false;
      endReason = reason ?? 'COMPLETED';
    }
    final isDraw = endReason == 'DRAW';

    final state = DemoState.instance;
    final eloChange = isDraw ? 0 : (youWin ? 14 + _random.nextInt(6) : -(12 + _random.nextInt(6)));
    final durationMs = DateTime.now().difference(_epoch).inMilliseconds;
    final fastest = _yourSolveTimes.isEmpty
        ? 0
        : _yourSolveTimes.reduce((a, b) => a < b ? a : b);

    _record(isDraw ? '' : (youWin ? 'demo-user' : 'demo-opponent'),
        'MATCH_END', {'reason': endReason});

    final replay = {
      'version': 1,
      'players': [
        {
          'user_id': 'demo-user',
          'username': state.username,
          'elo_before': state.elo,
          'is_bot': false,
        },
        {
          'user_id': 'demo-opponent',
          'username': _opponent['username'],
          'elo_before': _opponent['elo'],
          'is_bot': !_ranked,
        },
      ],
      'puzzles': _puzzles
          .map((p) => {
                'cipher_type': p['cipher_type'],
                'difficulty': p['difficulty'],
                'encrypted_text': p['encrypted_text'],
                'solution': p['plaintext'],
              })
          .toList(),
      'events': _events,
      'result': {
        'winner_id': isDraw ? '' : (youWin ? 'demo-user' : 'demo-opponent'),
        'reason': endReason,
        'duration_ms': durationMs,
      },
    };

    state.recordMatch(
      won: youWin && !isDraw,
      ranked: _ranked,
      yourScore: _yourSolves,
      opponentScore: _botSolves,
      opponentName: _opponent['username'] as String,
      eloChange: _ranked ? eloChange : 0,
      durationMs: durationMs,
      solvedThisMatch: _yourSolves,
      perfect: _wrongAttempts == 0,
      fastestMs: fastest,
      solvedByCipher: _solvedByCipher,
      matchId: _matchId,
      replay: replay,
    );

    _emit('MATCH_END', {
      'winner_id': isDraw ? '' : (youWin ? 'demo-user' : 'demo-opponent'),
      'reason': endReason,
      'your_score': _yourSolves,
      'opponent_score': _botSolves,
      'elo_change': _ranked ? eloChange : 0,
      'new_elo': _ranked ? state.elo : 0,
      'duration_ms': durationMs,
      'solve_times': {
        'demo-user': _yourSolveTimes,
      },
    });
  }

  @override
  Future<void> close() async {
    _botProgressTimer?.cancel();
    _botSolveTimer?.cancel();
    _deadlineTimer?.cancel();
    // Leaving an unfinished match counts as a forfeit, like the server.
    if (!_ended) {
      _ended = true;
    }
    _state.add(SocketState.closed);
    await _messages.close();
    await _state.close();
  }

  String _normalize(String s) =>
      s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}
