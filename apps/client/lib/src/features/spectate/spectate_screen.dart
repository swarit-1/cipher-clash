import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/game_socket.dart';
import '../../data/matchmaking_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Lists live matches and opens a read-only spectator view of one.
class SpectateScreen extends StatefulWidget {
  const SpectateScreen({Key? key}) : super(key: key);

  @override
  State<SpectateScreen> createState() => _SpectateScreenState();
}

class _SpectateScreenState extends State<SpectateScreen> {
  bool _loading = true;
  String? _error;
  List<String> _matchIds = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await MatchmakingApi.liveMatches();
    if (!mounted) return;
    if (!response.ok || response.json is! Map) {
      setState(() {
        _loading = false;
        _error = response.errorMessage;
      });
      return;
    }
    final ids = (response.json as Map)['match_ids'];
    setState(() {
      _loading = false;
      _matchIds = ids is List ? ids.whereType<String>().toList() : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spectate'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
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
                empty: _matchIds.isEmpty,
                emptyIcon: Icons.visibility_off,
                emptyTitle: 'No live matches right now',
                emptyMessage:
                    'Start a match in another tab — it will appear here.',
                child: ListView.builder(
                  padding: const EdgeInsets.all(AppTheme.spacing2),
                  itemCount: _matchIds.length,
                  itemBuilder: (context, index) {
                    final id = _matchIds[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppTheme.spacing1),
                      child: GlowCard(
                        glowVariant: GlowCardVariant.none,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SpectatorView(matchId: id),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.live_tv,
                                color: AppTheme.neonRed),
                            const SizedBox(width: AppTheme.spacing2),
                            Expanded(
                              child: Text(
                                'Live match ${id.substring(0, 8)}…',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ),
                            const Text('WATCH',
                                style: TextStyle(
                                    color: AppTheme.cyberBlue,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Read-only live view of a match over the spectator WebSocket stream.
class SpectatorView extends StatefulWidget {
  const SpectatorView({Key? key, required this.matchId}) : super(key: key);

  final String matchId;

  @override
  State<SpectatorView> createState() => _SpectatorViewState();
}

class _SpectatorViewState extends State<SpectatorView> {
  late final GameSocket _socket;
  StreamSubscription<ServerMessage>? _sub;

  String _status = 'WAITING';
  List<Map<String, dynamic>> _players = const [];
  final Map<String, double> _progress = {};
  final Map<String, int> _solves = {};
  String? _endText;

  @override
  void initState() {
    super.initState();
    _socket = GameSocketFactory.create();
    _sub = _socket.messages.listen(_onMessage);
    _socket.connect(widget.matchId, spectate: true);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _socket.close();
    super.dispose();
  }

  void _onMessage(ServerMessage message) {
    if (!mounted) return;
    switch (message.type) {
      case 'SPECTATOR_STATE':
        final players = message.payload['players'];
        setState(() {
          _status = message.payload['status'] as String? ?? 'WAITING';
          if (players is List) {
            _players = players
                .whereType<Map>()
                .map((e) => e.cast<String, dynamic>())
                .toList();
            for (final p in _players) {
              final id = p['user_id'] as String? ?? '';
              _progress[id] = (p['progress'] as num?)?.toDouble() ?? 0;
              _solves[id] = (p['solved_count'] as num?)?.toInt() ?? 0;
            }
          }
        });
        break;
      case 'MATCH_STARTED':
        setState(() => _status = 'IN_PROGRESS');
        break;
      case 'PLAYER_PROGRESS':
        setState(() {
          final id = message.payload['user_id'] as String? ?? '';
          _progress[id] =
              (message.payload['progress'] as num?)?.toDouble() ?? 0;
        });
        break;
      case 'PLAYER_SOLVED':
        setState(() {
          final id = message.payload['user_id'] as String? ?? '';
          _solves[id] = (message.payload['solved_count'] as num?)?.toInt() ??
              (_solves[id] ?? 0);
          _progress[id] = 0;
        });
        break;
      case 'MATCH_END':
        setState(() {
          _status = 'COMPLETED';
          final winner = message.payload['winner_id'] as String? ?? '';
          String name = 'Draw';
          for (final p in _players) {
            if (p['user_id'] == winner) {
              name = p['username'] as String? ?? '???';
            }
          }
          _endText = winner.isEmpty ? 'Match drawn' : '$name wins!';
        });
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Spectating')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing3),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.circle,
                                color: AppTheme.neonRed, size: 10)
                            .animate(onPlay: (c) => c.repeat())
                            .fadeIn(duration: 600.ms)
                            .then()
                            .fadeOut(duration: 600.ms),
                        const SizedBox(width: 8),
                        Text(
                          _endText ?? 'LIVE — $_status',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing3),
                    if (_players.isEmpty)
                      const CircularProgressIndicator()
                    else
                      ..._players.map(_buildPlayerCard),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlayerCard(Map<String, dynamic> player) {
    final id = player['user_id'] as String? ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing2),
      child: GlowCard(
        glowVariant: GlowCardVariant.none,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  player['is_bot'] == true ? Icons.smart_toy : Icons.person,
                  color: AppTheme.cyberBlue,
                ),
                const SizedBox(width: AppTheme.spacing1),
                Text(
                  player['username'] as String? ?? '???',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${_solves[id] ?? 0} solved',
                  style: const TextStyle(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: LinearProgressIndicator(
                value: _progress[id] ?? 0,
                minHeight: 10,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: const AlwaysStoppedAnimation(AppTheme.neonPurple),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
