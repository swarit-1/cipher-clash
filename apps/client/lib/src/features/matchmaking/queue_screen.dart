import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/match_models.dart';
import '../../data/matchmaking_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

/// Live matchmaking queue: joins the real queue, polls status until the
/// matchmaker reports match_found, and falls back to a bot opponent when
/// no human appears (offer at 25s, automatic at 40s).
class QueueScreen extends StatefulWidget {
  final String gameMode;

  const QueueScreen({
    Key? key,
    this.gameMode = 'RANKED_1V1',
  }) : super(key: key);

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

const _botOfferAfterSeconds = 25;
const _botAutoAfterSeconds = 40;

class _QueueScreenState extends State<QueueScreen>
    with TickerProviderStateMixin {
  late AnimationController _searchController;

  Timer? _pollTimer;
  Timer? _clockTimer;

  int _elapsedSeconds = 0;
  int _playersInQueue = 1;
  int _searchRange = 100;
  bool _matchFound = false;
  bool _creatingBotMatch = false;
  bool _leaving = false;
  String? _error;
  MatchArgs? _foundMatch;

  @override
  void initState() {
    super.initState();
    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _startMatchmaking();
  }

  Future<void> _startMatchmaking() async {
    // Bot matches skip the queue entirely.
    if (widget.gameMode == 'BOT_MATCH') {
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _elapsedSeconds++);
      });
      _startBotMatch();
      return;
    }

    final response = await MatchmakingApi.joinQueue(widget.gameMode);
    if (!mounted) return;

    // "Already in queue" is fine — we just resume polling.
    if (!response.ok && response.status != 409) {
      setState(() => _error = response.errorMessage);
      return;
    }

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
      if (_elapsedSeconds >= _botAutoAfterSeconds &&
          !_matchFound &&
          !_creatingBotMatch) {
        _startBotMatch(auto: true);
      }
    });

    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    if (_matchFound || _creatingBotMatch || _leaving) return;
    final response = await MatchmakingApi.queueStatus();
    if (!mounted || _matchFound || _creatingBotMatch) return;
    if (!response.ok || response.json is! Map) return;

    final data = (response.json as Map).cast<String, dynamic>();
    final status = data['status'] as String?;

    if (status == 'match_found') {
      final opponent = (data['opponent'] as Map?)?.cast<String, dynamic>();
      _onMatchFound(MatchArgs(
        matchId: data['match_id'] as String? ?? '',
        gameMode: data['game_mode'] as String? ?? widget.gameMode,
        isRanked: data['is_ranked'] as bool? ?? true,
        opponentUsername: opponent?['username'] as String?,
        opponentElo: (opponent?['elo'] as num?)?.toInt(),
      ));
    } else if (status == 'searching') {
      setState(() {
        _playersInQueue = (data['players_in_queue'] as num?)?.toInt() ?? 1;
        _searchRange = (data['search_range'] as num?)?.toInt() ?? 100;
        _elapsedSeconds =
            (data['wait_time_seconds'] as num?)?.toInt() ?? _elapsedSeconds;
      });
    }
  }

  Future<void> _startBotMatch({bool auto = false}) async {
    if (_creatingBotMatch || _matchFound) return;
    setState(() => _creatingBotMatch = true);

    // Leave the human queue first so we cannot be double-matched.
    await MatchmakingApi.leaveQueue();
    final match = await MatchmakingApi.createBotMatch();
    if (!mounted) return;

    if (match == null || match.matchId.isEmpty) {
      setState(() {
        _creatingBotMatch = false;
        _error = 'Could not start a bot match. Still searching…';
      });
      return;
    }
    _onMatchFound(match);
  }

  void _onMatchFound(MatchArgs match) {
    if (_matchFound) return;
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    setState(() {
      _matchFound = true;
      _foundMatch = match;
    });
    HapticFeedback.heavyImpact();

    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/game', arguments: match);
    });
  }

  Future<void> _cancelQueue() async {
    HapticFeedback.mediumImpact();
    setState(() => _leaving = true);
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    await MatchmakingApi.leaveQueue();
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String get _formattedTime {
    final minutes = _elapsedSeconds ~/ 60;
    final seconds = _elapsedSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_matchFound) {
      return _buildMatchFoundScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_getGameModeTitle()),
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing3),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildSearchAnimation(),
                const SizedBox(height: AppTheme.spacing5),
                _buildStatusText(),
                const SizedBox(height: AppTheme.spacing3),
                if (_error != null) _buildError(),
                _buildQueueStats(),
                const SizedBox(height: AppTheme.spacing4),
                _buildSearchRange(),
                const Spacer(),
                if (_elapsedSeconds >= _botOfferAfterSeconds &&
                    !_creatingBotMatch)
                  _buildBotOffer(),
                if (_creatingBotMatch) _buildBotSpinner(),
                const SizedBox(height: AppTheme.spacing2),
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing2),
      child: Text(
        _error!,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.neonRed,
            ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBotOffer() {
    final secondsLeft =
        (_botAutoAfterSeconds - _elapsedSeconds).clamp(0, _botAutoAfterSeconds);
    return Column(
      children: [
        Text(
          'No opponent yet — facing a training bot in ${secondsLeft}s',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spacing1),
        CyberpunkButton(
          label: 'FIGHT A BOT NOW',
          onPressed: () => _startBotMatch(),
          variant: CyberpunkButtonVariant.secondary,
          icon: Icons.smart_toy,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildBotSpinner() {
    return Column(
      children: [
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 3),
        ),
        const SizedBox(height: AppTheme.spacing1),
        Text(
          'Summoning opponent…',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }

  Widget _buildSearchAnimation() {
    return AnimatedBuilder(
      animation: _searchController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppTheme.cyberBlue.withValues(alpha: 0.3),
                AppTheme.cyberBlue.withValues(alpha: 0.1),
                Colors.transparent,
              ],
              stops: const [0.3, 0.6, 1.0],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: _searchController.value * 2 * 3.14159,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.cyberBlue,
                      width: 2,
                    ),
                  ),
                ),
              ),
              Transform.rotate(
                angle: -_searchController.value * 2 * 3.14159,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.neonPurple,
                      width: 2,
                    ),
                  ),
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.glowCyberBlue(intensity: 1.2),
                ),
                child: const Icon(
                  Icons.search,
                  size: 40,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusText() {
    return Column(
      children: [
        Text(
          'SEARCHING FOR OPPONENT',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.cyberBlue,
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
          textAlign: TextAlign.center,
        )
            .animate(onPlay: (controller) => controller.repeat())
            .fadeIn(duration: 1.seconds)
            .then()
            .fadeOut(duration: 1.seconds),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          _formattedTime,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
        ),
      ],
    );
  }

  Widget _buildQueueStats() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatCard(
          'Players in Queue',
          '$_playersInQueue',
          Icons.people,
          AppTheme.cyberBlue,
        ),
        _buildStatCard(
          'Game Mode',
          _getGameModeTitle(),
          Icons.bolt,
          AppTheme.neonPurple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: SizedBox(
        width: 150,
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppTheme.spacing1),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildSearchRange() {
    return Column(
      children: [
        Text(
          'Search Range',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: AppTheme.spacing1),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '±$_searchRange',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.electricYellow,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(width: AppTheme.spacing1),
            Text(
              'ELO',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing1),
        Container(
          height: 6,
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            color: AppTheme.surfaceVariant,
          ),
          child: FractionallySizedBox(
            widthFactor: (_searchRange / 500).clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                gradient: const LinearGradient(
                  colors: [AppTheme.electricGreen, AppTheme.electricYellow],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton() {
    return CyberpunkButton(
      label: 'CANCEL',
      onPressed: _leaving ? null : _cancelQueue,
      variant: CyberpunkButtonVariant.danger,
      icon: Icons.close,
      fullWidth: true,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
    );
  }

  Widget _buildMatchFoundScreen() {
    final opponent = _foundMatch?.opponentUsername ?? 'OPPONENT';
    final elo = _foundMatch?.opponentElo;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                  boxShadow: AppTheme.glowElectricGreen(intensity: 2.0),
                ),
                child: Icon(
                  _foundMatch?.opponentIsBot == true
                      ? Icons.smart_toy
                      : Icons.check_circle,
                  size: 80,
                  color: Colors.black,
                ),
              )
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack)
                  .then()
                  .shimmer(duration: 1.seconds),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                'MATCH FOUND!',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.electricGreen,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 4,
                    ),
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                elo != null ? 'vs $opponent  ·  $elo ELO' : 'vs $opponent',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ).animate().fadeIn(delay: 350.ms),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                'Preparing battle...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ).animate().fadeIn(delay: 450.ms),
              const SizedBox(height: AppTheme.spacing4),
              const SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(AppTheme.electricGreen),
                ),
              ).animate().fadeIn(delay: 600.ms),
            ],
          ),
        ),
      ),
    );
  }

  String _getGameModeTitle() {
    switch (widget.gameMode.toUpperCase()) {
      case 'RANKED_1V1':
        return 'Ranked';
      case 'CASUAL_1V1':
        return 'Casual';
      case 'BOT_MATCH':
        return 'Vs. Bot';
      default:
        return 'Matchmaking';
    }
  }
}
