import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/matchmaking_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Match replay: plays back the recorded event timeline (progress, solves,
/// disconnects) with a scrubber, and reveals the puzzles with solutions.
class ReplayScreen extends StatefulWidget {
  const ReplayScreen({Key? key, required this.matchId}) : super(key: key);

  final String matchId;

  @override
  State<ReplayScreen> createState() => _ReplayScreenState();
}

class _ReplayScreenState extends State<ReplayScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _players = const [];
  List<Map<String, dynamic>> _puzzles = const [];
  List<Map<String, dynamic>> _events = const [];
  Map<String, dynamic> _result = const {};

  // Playback
  Timer? _ticker;
  bool _playing = false;
  int _cursorMs = 0;
  int _totalMs = 1;
  static const _speed = 4; // 4x real time

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await MatchmakingApi.replay(widget.matchId);
    if (!mounted) return;
    if (!response.ok || response.json is! Map) {
      setState(() {
        _loading = false;
        _error = response.status == 404
            ? 'No replay exists for this match'
            : response.errorMessage;
      });
      return;
    }

    final data = (response.json as Map).cast<String, dynamic>();
    List<Map<String, dynamic>> listOf(String key) {
      final raw = data[key];
      return raw is List
          ? raw.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
          : const [];
    }

    final events = listOf('events');
    int total = 1;
    for (final e in events) {
      final t = (e['t_ms'] as num?)?.toInt() ?? 0;
      if (t > total) total = t;
    }

    setState(() {
      _loading = false;
      _players = listOf('players');
      _puzzles = listOf('puzzles');
      _events = events;
      _result = (data['result'] as Map?)?.cast<String, dynamic>() ?? const {};
      _totalMs = total;
      _cursorMs = 0;
    });
  }

  void _togglePlay() {
    if (_playing) {
      _ticker?.cancel();
      setState(() => _playing = false);
      return;
    }
    if (_cursorMs >= _totalMs) _cursorMs = 0;
    setState(() => _playing = true);
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
      setState(() {
        _cursorMs += 100 * _speed;
        if (_cursorMs >= _totalMs) {
          _cursorMs = _totalMs;
          _playing = false;
          _ticker?.cancel();
        }
      });
    });
  }

  /// State of a player at the playback cursor, derived from the event log.
  ({int solves, double progress, bool connected}) _playerStateAt(String uid) {
    int solves = 0;
    double progress = 0;
    bool connected = true;
    for (final e in _events) {
      final t = (e['t_ms'] as num?)?.toInt() ?? 0;
      if (t > _cursorMs) break;
      if (e['uid'] != uid) continue;
      switch (e['type']) {
        case 'SOLVED':
          solves++;
          progress = 0;
          break;
        case 'PROGRESS':
          final data = (e['data'] as Map?)?.cast<String, dynamic>();
          progress = (data?['pct'] as num?)?.toDouble() ?? progress;
          break;
        case 'DISCONNECT':
          connected = false;
          break;
        case 'JOIN':
        case 'RECONNECT':
          connected = true;
          break;
      }
    }
    return (solves: solves, progress: progress, connected: connected);
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Match Replay')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: AsyncView(
                loading: _loading,
                error: _error,
                onRetry: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppTheme.spacing2),
                  children: [
                    _buildResultBanner(),
                    const SizedBox(height: AppTheme.spacing2),
                    ..._players.map(_buildPlayerLane),
                    const SizedBox(height: AppTheme.spacing2),
                    _buildScrubber(),
                    const SizedBox(height: AppTheme.spacing3),
                    Text(
                      'THE PUZZLES',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: AppTheme.spacing1),
                    ..._puzzles.asMap().entries.map(
                        (entry) => _buildPuzzleCard(entry.key, entry.value)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultBanner() {
    final winnerId = _result['winner_id'] as String? ?? '';
    String winnerName = 'Draw';
    for (final p in _players) {
      if (p['user_id'] == winnerId) {
        winnerName = p['username'] as String? ?? '???';
      }
    }
    return GlowCard(
      glowVariant: GlowCardVariant.primary,
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppTheme.electricYellow),
          const SizedBox(width: AppTheme.spacing1),
          Expanded(
            child: Text(
              winnerId.isEmpty
                  ? 'Match ended in a draw (${_result['reason'] ?? ''})'
                  : '$winnerName won by ${(_result['reason'] as String? ?? 'COMPLETED').toLowerCase()}',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            _fmt((_result['duration_ms'] as num?)?.toInt() ?? _totalMs),
            style: const TextStyle(
                fontFamily: 'monospace', color: AppTheme.textSecondary),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPlayerLane(Map<String, dynamic> player) {
    final uid = player['user_id'] as String? ?? '';
    final state = _playerStateAt(uid);
    final isBot = player['is_bot'] == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: GlowCardVariant.none,
        child: Row(
          children: [
            Icon(isBot ? Icons.smart_toy : Icons.person,
                color: AppTheme.cyberBlue),
            const SizedBox(width: AppTheme.spacing1),
            SizedBox(
              width: 130,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player['username'] as String? ?? '???',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${player['elo_before'] ?? '—'} ELO'
                    '${state.connected ? '' : ' · OFFLINE'}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: state.connected
                              ? AppTheme.textTertiary
                              : AppTheme.electricYellow,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: LinearProgressIndicator(
                  value: state.progress,
                  minHeight: 10,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.neonPurple),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing2),
            Text(
              '${state.solves}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrubber() {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Row(
        children: [
          IconButton(
            onPressed: _togglePlay,
            iconSize: 36,
            icon: Icon(
              _playing ? Icons.pause_circle : Icons.play_circle,
              color: AppTheme.cyberBlue,
            ),
          ),
          Expanded(
            child: Slider(
              value: _cursorMs.toDouble().clamp(0, _totalMs.toDouble()),
              max: _totalMs.toDouble(),
              activeColor: AppTheme.cyberBlue,
              inactiveColor: AppTheme.surfaceVariant,
              onChanged: (v) => setState(() => _cursorMs = v.toInt()),
            ),
          ),
          Text(
            '${_fmt(_cursorMs)} / ${_fmt(_totalMs)}  ·  ${_speed}x',
            style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.textSecondary,
                fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleCard(int index, Map<String, dynamic> puzzle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: GlowCardVariant.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${index + 1}  ${puzzle['cipher_type'] ?? '?'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontFamily: 'monospace',
                        color: AppTheme.cyberBlue,
                      ),
                ),
                const Spacer(),
                Text(
                  'difficulty ${puzzle['difficulty'] ?? '?'}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              puzzle['encrypted_text'] as String? ?? '',
              style: const TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.electricGreen,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '→ ${puzzle['solution'] ?? ''}',
              style: TextStyle(
                fontFamily: 'monospace',
                color: AppTheme.textPrimary.withValues(alpha: 0.85),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
