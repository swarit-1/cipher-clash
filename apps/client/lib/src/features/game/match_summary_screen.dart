import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

/// Post-match results: outcome, score comparison, and the real ELO change
/// reported by the server in MATCH_END.
class MatchSummaryScreen extends StatefulWidget {
  const MatchSummaryScreen({Key? key, this.matchData}) : super(key: key);

  final Map<String, dynamic>? matchData;

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _eloController;
  late ConfettiController _confettiController;

  late final bool _isWinner;
  late final bool _isDraw;
  late final String _reason;
  late final int _playerScore;
  late final int _opponentScore;
  late final int _solveTime;
  late final int _eloChange;
  late final int _newElo;
  late final String _opponentName;
  late final bool _isRanked;
  late final bool _opponentIsBot;

  int _displayedEloChange = 0;

  @override
  void initState() {
    super.initState();

    final data = widget.matchData ?? const <String, dynamic>{};
    _isWinner = data['isWinner'] as bool? ?? false;
    _isDraw = data['isDraw'] as bool? ?? false;
    _reason = data['reason'] as String? ?? 'COMPLETED';
    _playerScore = data['playerScore'] as int? ?? 0;
    _opponentScore = data['opponentScore'] as int? ?? 0;
    _solveTime = data['solveTime'] as int? ?? 0;
    _eloChange = data['eloChange'] as int? ?? 0;
    _newElo = data['newElo'] as int? ?? 0;
    _opponentName = data['opponentName'] as String? ?? 'Opponent';
    _isRanked = data['isRanked'] as bool? ?? false;
    _opponentIsBot = data['opponentIsBot'] as bool? ?? false;

    _eloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        setState(() {
          _displayedEloChange = (_eloChange * _eloController.value).round();
        });
      });

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));

    if (_isWinner) {
      _confettiController.play();
      HapticFeedback.heavyImpact();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) _eloController.forward();
    });
  }

  @override
  void dispose() {
    _eloController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  Color get _resultColor => _isDraw
      ? AppTheme.electricYellow
      : (_isWinner ? AppTheme.electricGreen : AppTheme.neonRed);

  String get _resultTitle =>
      _isDraw ? 'DRAW' : (_isWinner ? 'VICTORY!' : 'DEFEAT');

  String get _resultSubtitle {
    switch (_reason) {
      case 'FORFEIT':
        return _isWinner
            ? '$_opponentName forfeited the match'
            : 'You forfeited the match';
      case 'TIMEOUT':
        return _isDraw
            ? 'Time expired with the score level'
            : (_isWinner
                ? 'Time expired — you were ahead'
                : 'Time expired — $_opponentName was ahead');
      case 'ABORTED':
        return 'The match was aborted before it began';
      case 'DRAW':
        return 'Neither codebreaker prevailed';
      default:
        return _isWinner
            ? 'You cracked the ciphers first!'
            : '$_opponentName cracked the ciphers first';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Stack(
          children: [
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(AppTheme.spacing3),
                    child: Column(
                      children: [
                        const SizedBox(height: AppTheme.spacing4),
                        _buildResultHeader(),
                        const SizedBox(height: AppTheme.spacing4),
                        _buildScoreComparison(),
                        const SizedBox(height: AppTheme.spacing3),
                        _buildStatsBreakdown(),
                        if (_isRanked && _eloChange != 0) ...[
                          const SizedBox(height: AppTheme.spacing3),
                          _buildEloChange(),
                        ],
                        const SizedBox(height: AppTheme.spacing4),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_isWinner)
              Align(
                alignment: Alignment.topCenter,
                child: ConfettiWidget(
                  confettiController: _confettiController,
                  blastDirectionality: BlastDirectionality.explosive,
                  particleDrag: 0.05,
                  emissionFrequency: 0.02,
                  numberOfParticles: 30,
                  gravity: 0.1,
                  colors: const [
                    AppTheme.cyberBlue,
                    AppTheme.neonPurple,
                    AppTheme.electricGreen,
                    AppTheme.electricYellow,
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultHeader() {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isWinner ? AppTheme.accentGradient : null,
            color: _isWinner ? null : _resultColor.withValues(alpha: 0.2),
            border: Border.all(color: _resultColor, width: 3),
            boxShadow: _isWinner
                ? AppTheme.glowElectricGreen(intensity: 2.0)
                : null,
          ),
          child: Icon(
            _isDraw
                ? Icons.balance
                : (_isWinner ? Icons.emoji_events : Icons.close),
            size: 60,
            color: _isWinner ? Colors.black : _resultColor,
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(
                duration: 2.seconds,
                color: _isWinner ? AppTheme.electricGreen : null),
        const SizedBox(height: AppTheme.spacing3),
        Text(
          _resultTitle,
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: _resultColor,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
        const SizedBox(height: AppTheme.spacing1),
        Text(
          _resultSubtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildScoreComparison() {
    return GlowCard(
      glowVariant: _isWinner ? GlowCardVariant.success : GlowCardVariant.none,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _scoreColumn('You', _playerScore, AppTheme.cyberBlue),
          Container(
            height: 80,
            width: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  AppTheme.cyberBlue.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          _scoreColumn(_opponentName, _opponentScore, AppTheme.neonPurple),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).scale();
  }

  Widget _scoreColumn(String label, int score, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != 'You' && _opponentIsBot)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child:
                    Icon(Icons.smart_toy, size: 16, color: AppTheme.neonPurple),
              ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing1),
        Text(
          '$score',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
              ),
        ),
        Text('solved', style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _buildStatsBreakdown() {
    final minutes = _solveTime ~/ 60;
    final seconds = _solveTime % 60;
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Match Statistics',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: AppTheme.spacing2),
          _buildStatRow(
              'Duration',
              '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
              Icons.timer),
          const Divider(height: AppTheme.spacing2),
          _buildStatRow('Result', _reasonLabel(), Icons.gavel),
          const Divider(height: AppTheme.spacing2),
          _buildStatRow(
              'Mode', _isRanked ? 'Ranked' : 'Unranked', Icons.military_tech),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  String _reasonLabel() {
    switch (_reason) {
      case 'FORFEIT':
        return 'Forfeit';
      case 'TIMEOUT':
        return 'Time expired';
      case 'DRAW':
        return 'Draw';
      case 'ABORTED':
        return 'Aborted';
      default:
        return 'Completed';
    }
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.cyberBlue, size: 20),
        const SizedBox(width: AppTheme.spacing1),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.cyberBlue,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }

  Widget _buildEloChange() {
    final isPositive = _eloChange > 0;
    final color = isPositive ? AppTheme.electricGreen : AppTheme.neonRed;

    return GlowCard(
      glowVariant: isPositive ? GlowCardVariant.success : GlowCardVariant.none,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: color,
                size: 32,
              ),
              const SizedBox(width: AppTheme.spacing2),
              Text(
                'Rating Change',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${isPositive ? '+' : ''}$_displayedEloChange',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
              ),
              const SizedBox(width: AppTheme.spacing1),
              Text(
                'ELO',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
          if (_newElo > 0) ...[
            const SizedBox(height: AppTheme.spacing1),
            Text(
              'New Rating: $_newElo',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        CyberpunkButton(
          label: 'PLAY AGAIN',
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/matchmaking',
              (route) => route.settings.name == '/menu' || route.isFirst,
            );
          },
          variant: CyberpunkButtonVariant.primary,
          icon: Icons.replay,
          fullWidth: true,
        ),
        const SizedBox(height: AppTheme.spacing2),
        CyberpunkButton(
          label: 'BACK TO MENU',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamedAndRemoveUntil(context, '/menu', (route) => false);
          },
          variant: CyberpunkButtonVariant.ghost,
          icon: Icons.home,
          fullWidth: true,
        ),
      ],
    ).animate().fadeIn(delay: 1200.ms);
  }
}
