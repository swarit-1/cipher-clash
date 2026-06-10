import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/token_store.dart';
import '../../data/game_socket.dart';
import '../../data/match_models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

/// Live WebSocket match: countdown, race-to-three cipher solving with real
/// opponent progress, reconnect handling, and the final result handoff.
class MatchScreen extends StatefulWidget {
  const MatchScreen({Key? key, required this.args}) : super(key: key);

  final MatchArgs args;

  @override
  State<MatchScreen> createState() => _MatchScreenState();
}

class _MatchScreenState extends State<MatchScreen> {
  late final GameSocket _socket;
  StreamSubscription<ServerMessage>? _messageSub;
  StreamSubscription<SocketState>? _stateSub;

  final _solutionController = TextEditingController();
  final _solutionFocus = FocusNode();

  // Room state
  String _status = 'WAITING';
  RoomState? _room;
  PuzzleView? _puzzle;
  int _totalPuzzles = 5;
  int _targetSolves = 3;

  int _yourSolves = 0;
  int _opponentSolves = 0;
  double _opponentProgress = 0;
  bool _opponentGone = false;
  int _forfeitCountdown = 0;
  Timer? _forfeitTimer;

  // Clock
  int? _deadlineMs;
  int? _startsAtMs;
  int _serverOffsetMs = 0;
  Timer? _clock;
  Duration _remaining = Duration.zero;
  Duration _untilStart = Duration.zero;

  SocketState _connection = SocketState.connecting;
  bool _submitting = false;
  bool _lastWrong = false;
  bool _ended = false;

  String get _opponentName =>
      _room?.opponent.username ?? widget.args.opponentUsername ?? 'OPPONENT';

  @override
  void initState() {
    super.initState();
    _socket = GameSocketFactory.create();
    _messageSub = _socket.messages.listen(_onMessage);
    _stateSub = _socket.state.listen((s) {
      if (mounted) setState(() => _connection = s);
    });
    _socket.connect(widget.args.matchId);

    _clock = Timer.periodic(const Duration(milliseconds: 250), (_) => _tick());
    _solutionController.addListener(_onTyping);
  }

  @override
  void dispose() {
    _clock?.cancel();
    _forfeitTimer?.cancel();
    _messageSub?.cancel();
    _stateSub?.cancel();
    _socket.close();
    _solutionController.dispose();
    _solutionFocus.dispose();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;
    setState(() {
      if (_startsAtMs != null && now < _startsAtMs!) {
        _untilStart = Duration(milliseconds: _startsAtMs! - now);
      } else {
        _untilStart = Duration.zero;
      }
      if (_deadlineMs != null) {
        final left = _deadlineMs! - now;
        _remaining = Duration(milliseconds: left.clamp(0, 1 << 31));
      }
    });
  }

  void _onTyping() {
    final puzzle = _puzzle;
    if (puzzle == null || puzzle.encryptedText.isEmpty) return;
    final progress =
        (_solutionController.text.length / puzzle.encryptedText.length)
            .clamp(0.0, 1.0);
    _socket.sendProgress(progress);
  }

  void _onMessage(ServerMessage message) {
    if (!mounted) return;
    switch (message.type) {
      case 'ROOM_STATE':
        final room = RoomState.fromJson(message.payload);
        setState(() {
          _room = room;
          _status = room.status;
          _totalPuzzles = room.totalPuzzles;
          _targetSolves = room.targetSolves;
          _yourSolves = room.you.solvedCount;
          _opponentSolves = room.opponent.solvedCount;
          _opponentProgress = room.opponent.progress;
          _opponentGone = !room.opponent.connected && room.status == 'IN_PROGRESS';
          if (room.puzzle != null) _puzzle = room.puzzle;
          _startsAtMs = room.startsAtMs;
          _deadlineMs = room.deadlineMs;
          if (room.serverNowMs != null) {
            _serverOffsetMs =
                room.serverNowMs! - DateTime.now().millisecondsSinceEpoch;
          }
        });
        break;

      case 'MATCH_STARTED':
        setState(() {
          _status = 'COUNTDOWN';
          _startsAtMs = (message.payload['starts_at_ms'] as num?)?.toInt();
          _deadlineMs = (message.payload['deadline_ms'] as num?)?.toInt();
          final serverNow = (message.payload['server_now_ms'] as num?)?.toInt();
          if (serverNow != null) {
            _serverOffsetMs =
                serverNow - DateTime.now().millisecondsSinceEpoch;
          }
        });
        HapticFeedback.mediumImpact();
        break;

      case 'PUZZLE_SET':
        final puzzle = message.payload['puzzle'];
        setState(() {
          _status = 'IN_PROGRESS';
          if (puzzle is Map) {
            _puzzle = PuzzleView.fromJson(puzzle.cast<String, dynamic>());
          }
          _totalPuzzles =
              (message.payload['total_puzzles'] as num?)?.toInt() ?? _totalPuzzles;
          _submitting = false;
          _lastWrong = false;
          _solutionController.clear();
        });
        _solutionFocus.requestFocus();
        break;

      case 'SUBMIT_RESULT':
        final correct = message.payload['correct'] == true;
        setState(() {
          _submitting = false;
          _yourSolves =
              (message.payload['solved_count'] as num?)?.toInt() ?? _yourSolves;
          _lastWrong = !correct;
        });
        if (correct) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
        break;

      case 'OPPONENT_PROGRESS':
        setState(() {
          _opponentProgress =
              (message.payload['progress'] as num?)?.toDouble() ?? 0;
        });
        break;

      case 'OPPONENT_SOLVED':
        setState(() {
          _opponentSolves =
              (message.payload['solved_count'] as num?)?.toInt() ?? _opponentSolves;
          _opponentProgress = 0;
        });
        HapticFeedback.lightImpact();
        break;

      case 'OPPONENT_DISCONNECTED':
        final seconds =
            (message.payload['forfeit_in_seconds'] as num?)?.toInt() ?? 45;
        setState(() {
          _opponentGone = true;
          _forfeitCountdown = seconds;
        });
        _forfeitTimer?.cancel();
        _forfeitTimer = Timer.periodic(const Duration(seconds: 1), (t) {
          if (!mounted || !_opponentGone) {
            t.cancel();
            return;
          }
          setState(() {
            _forfeitCountdown = (_forfeitCountdown - 1).clamp(0, 999);
          });
        });
        break;

      case 'OPPONENT_RECONNECTED':
        _forfeitTimer?.cancel();
        setState(() => _opponentGone = false);
        break;

      case 'MATCH_END':
        _onMatchEnd(MatchEnd.fromJson(message.payload));
        break;
    }
  }

  void _onMatchEnd(MatchEnd end) {
    if (_ended) return;
    _ended = true;
    final isWinner = end.winnerId == TokenStore.userId;
    final isDraw = end.winnerId.isEmpty;

    Navigator.pushReplacementNamed(context, '/match-summary', arguments: {
      'isWinner': isWinner,
      'isDraw': isDraw,
      'reason': end.reason,
      'playerScore': end.yourScore,
      'opponentScore': end.opponentScore,
      'solveTime': end.durationMs ~/ 1000,
      'eloChange': end.eloChange,
      'newElo': end.newElo,
      'opponentName': _opponentName,
      'isRanked': widget.args.isRanked,
      'opponentIsBot':
          _room?.opponent.isBot ?? widget.args.opponentIsBot,
    });
  }

  void _submit() {
    final puzzle = _puzzle;
    if (puzzle == null || _submitting) return;
    final text = _solutionController.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    _socket.submit(puzzle.index, text);
  }

  Future<void> _confirmForfeit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        title: const Text('Forfeit match?'),
        content: const Text(
            'Your opponent will be awarded the win. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP FIGHTING'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('FORFEIT',
                style: TextStyle(color: AppTheme.neonRed)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _socket.forfeit();
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing2),
                    child: Column(
                      children: [
                        _buildTopBar(),
                        const SizedBox(height: AppTheme.spacing2),
                        _buildOpponentRow(),
                        const SizedBox(height: AppTheme.spacing2),
                        Expanded(child: _buildBody()),
                      ],
                    ),
                  ),
                ),
              ),
              if (_connection == SocketState.reconnecting)
                _buildReconnectBanner(),
              if (_status == 'COUNTDOWN' && _untilStart > Duration.zero)
                _buildCountdownOverlay(),
              if (_status == 'WAITING') _buildWaitingOverlay(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    final urgent = _remaining.inSeconds <= 30 && _status == 'IN_PROGRESS';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _scoreChip('YOU', _yourSolves, AppTheme.cyberBlue),
        Column(
          children: [
            Text(
              _status == 'IN_PROGRESS' ? _formatDuration(_remaining) : '--:--',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: urgent ? AppTheme.neonRed : AppTheme.textPrimary,
                  ),
            ),
            Text(
              'first to $_targetSolves',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        Row(
          children: [
            _scoreChip(
                _opponentName.length > 8
                    ? '${_opponentName.substring(0, 8)}…'
                    : _opponentName,
                _opponentSolves,
                AppTheme.neonPurple),
            const SizedBox(width: AppTheme.spacing1),
            IconButton(
              tooltip: 'Forfeit',
              onPressed:
                  _status == 'IN_PROGRESS' && !_ended ? _confirmForfeit : null,
              icon: const Icon(Icons.flag, color: AppTheme.neonRed),
            ),
          ],
        ),
      ],
    );
  }

  Widget _scoreChip(String label, int solves, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing2, vertical: AppTheme.spacing1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
          Text('$solves',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildOpponentRow() {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Row(
        children: [
          Icon(
            _room?.opponent.isBot ?? widget.args.opponentIsBot
                ? Icons.smart_toy
                : Icons.person,
            color: AppTheme.neonPurple,
          ),
          const SizedBox(width: AppTheme.spacing1),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      _opponentName,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(width: AppTheme.spacing1),
                    if (_opponentGone)
                      Text(
                        'DISCONNECTED — wins in ${_forfeitCountdown}s',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.electricYellow,
                            ),
                      ).animate(onPlay: (c) => c.repeat()).fadeIn().then().fadeOut(),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: LinearProgressIndicator(
                    value: _opponentProgress,
                    minHeight: 8,
                    backgroundColor: AppTheme.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.neonPurple),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final puzzle = _puzzle;
    if (puzzle == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlowCard(
            glowVariant: GlowCardVariant.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _tag(puzzle.cipherType, AppTheme.cyberBlue),
                    const SizedBox(width: AppTheme.spacing1),
                    _tag('DIFFICULTY ${puzzle.difficulty}',
                        AppTheme.electricYellow),
                    const Spacer(),
                    Text(
                      'PUZZLE ${puzzle.index + 1}/$_totalPuzzles',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                            letterSpacing: 1,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing2),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppTheme.spacing2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                        color: AppTheme.cyberBlue.withValues(alpha: 0.3)),
                  ),
                  child: SelectableText(
                    puzzle.encryptedText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 18,
                      height: 1.6,
                      letterSpacing: 1.5,
                      color: AppTheme.electricGreen,
                    ),
                  ),
                ),
              ],
            ),
          ).animate(key: ValueKey(puzzle.index)).fadeIn().slideY(begin: 0.05),
          const SizedBox(height: AppTheme.spacing2),
          TextField(
            controller: _solutionController,
            focusNode: _solutionFocus,
            enabled: _status == 'IN_PROGRESS' && !_ended,
            autofocus: true,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
            decoration: InputDecoration(
              labelText: 'DECRYPTED MESSAGE',
              hintText: 'Type the plaintext and press Enter',
              errorText: _lastWrong ? 'Incorrect — try again' : null,
              suffixIcon: IconButton(
                icon: const Icon(Icons.send),
                onPressed: _submit,
              ),
            ),
          ).animate(target: _lastWrong ? 1 : 0).shake(hz: 5, duration: 300.ms),
          const SizedBox(height: AppTheme.spacing2),
          CyberpunkButton(
            label: _submitting ? 'CHECKING…' : 'SUBMIT SOLUTION',
            onPressed:
                _status == 'IN_PROGRESS' && !_submitting && !_ended
                    ? _submit
                    : null,
            icon: Icons.lock_open,
            fullWidth: true,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
          ),
        ],
      ),
    );
  }

  Widget _tag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildReconnectBanner() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: AppTheme.electricYellow.withValues(alpha: 0.9),
        padding: const EdgeInsets.all(AppTheme.spacing1),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.black),
              ),
            ),
            SizedBox(width: 8),
            Text(
              'Connection lost — reconnecting…',
              style: TextStyle(
                  color: Colors.black, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCountdownOverlay() {
    final seconds = (_untilStart.inMilliseconds / 1000).ceil();
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Text(
          '$seconds',
          key: ValueKey(seconds),
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: AppTheme.cyberBlue,
                fontWeight: FontWeight.w900,
                fontSize: 120,
              ),
        ).animate(key: ValueKey('cd$seconds')).scale(
              begin: const Offset(1.6, 1.6),
              end: const Offset(1.0, 1.0),
              duration: 350.ms,
              curve: Curves.easeOutBack,
            ),
      ),
    );
  }

  Widget _buildWaitingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              'Waiting for $_opponentName…',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
