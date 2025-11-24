import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

class MatchSummaryScreen extends StatefulWidget {
  final Map<String, dynamic>? matchData;

  const MatchSummaryScreen({
    Key? key,
    this.matchData,
  }) : super(key: key);

  @override
  State<MatchSummaryScreen> createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen>
    with TickerProviderStateMixin {
  late AnimationController _xpController;
  late AnimationController _eloController;
  late ConfettiController _confettiController;

  late bool _isWinner;
  late int _playerScore;
  late int _opponentScore;
  late int _solveTime;
  late int _xpGained;
  late int _eloChange;

  int _currentXp = 0;
  int _currentElo = 1650;
  int _displayedXp = 0;
  int _displayedElo = 1650;

  @override
  void initState() {
    super.initState();

    // Extract match data
    final data = widget.matchData ?? {
      'isWinner': true,
      'playerScore': 1500,
      'opponentScore': 0,
      'solveTime': 45,
      'xpGained': 125,
      'eloChange': 18,
    };

    _isWinner = data['isWinner'] as bool;
    _playerScore = data['playerScore'] as int;
    _opponentScore = data['opponentScore'] as int;
    _solveTime = data['solveTime'] as int;
    _xpGained = data['xpGained'] as int;
    _eloChange = data['eloChange'] as int;

    // Animation controllers
    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        setState(() {
          _displayedXp = (_currentXp + (_xpGained * _xpController.value)).toInt();
        });
      });

    _eloController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addListener(() {
        setState(() {
          _displayedElo = (_currentElo + (_eloChange * _eloController.value)).toInt();
        });
      });

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Start animations
    if (_isWinner) {
      _confettiController.play();
      HapticFeedback.heavyImpact();
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      _xpController.forward();
      _eloController.forward();
    });
  }

  @override
  void dispose() {
    _xpController.dispose();
    _eloController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.spacing3),
                child: Column(
                  children: [
                    const SizedBox(height: AppTheme.spacing4),

                    // Victory/Defeat Header
                    _buildResultHeader(),

                    const SizedBox(height: AppTheme.spacing4),

                    // Score Comparison
                    _buildScoreComparison(),

                    const SizedBox(height: AppTheme.spacing3),

                    // Stats Breakdown
                    _buildStatsBreakdown(),

                    const SizedBox(height: AppTheme.spacing3),

                    // XP Gain
                    _buildXpGain(),

                    const SizedBox(height: AppTheme.spacing3),

                    // ELO Change
                    _buildEloChange(),

                    const SizedBox(height: AppTheme.spacing4),

                    // Action Buttons
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),

            // Confetti overlay (victory only)
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
        // Result icon
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: _isWinner ? AppTheme.accentGradient : null,
            color: _isWinner ? null : AppTheme.neonRed.withValues(alpha: 0.2),
            border: Border.all(
              color: _isWinner ? AppTheme.electricGreen : AppTheme.neonRed,
              width: 3,
            ),
            boxShadow: _isWinner
                ? AppTheme.glowElectricGreen(intensity: 2.0)
                : AppTheme.glowNeonRed(intensity: 1.5),
          ),
          child: Icon(
            _isWinner ? Icons.emoji_events : Icons.close,
            size: 60,
            color: _isWinner ? Colors.black : AppTheme.neonRed,
          ),
        )
            .animate()
            .scale(duration: 600.ms, curve: Curves.elasticOut)
            .then()
            .shimmer(duration: 2.seconds, color: _isWinner ? AppTheme.electricGreen : null),

        const SizedBox(height: AppTheme.spacing3),

        // Result text
        Text(
          _isWinner ? 'VICTORY!' : 'DEFEAT',
          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                color: _isWinner ? AppTheme.electricGreen : AppTheme.neonRed,
                fontWeight: FontWeight.w900,
                letterSpacing: 6,
              ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

        const SizedBox(height: AppTheme.spacing1),

        Text(
          _isWinner ? 'You cracked the cipher first!' : 'Your opponent was faster',
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
          // Player score
          Column(
            children: [
              Text(
                'You',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing1),
              Text(
                '$_playerScore',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.cyberBlue,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'points',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),

          // Divider
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

          // Opponent score
          Column(
            children: [
              Text(
                'Opponent',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing1),
              Text(
                '$_opponentScore',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.neonPurple,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              Text(
                'points',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms).scale();
  }

  Widget _buildStatsBreakdown() {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Match Statistics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacing2),
          _buildStatRow('Solve Time', '${_solveTime}s', Icons.timer),
          const Divider(height: AppTheme.spacing2),
          _buildStatRow(
            'Accuracy',
            '100%',
            Icons.check_circle,
          ),
          const Divider(height: AppTheme.spacing2),
          _buildStatRow(
            'Time Bonus',
            _solveTime < 60 ? '+20%' : '+0%',
            Icons.bolt,
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildStatRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.cyberBlue, size: 20),
        const SizedBox(width: AppTheme.spacing1),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
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

  Widget _buildXpGain() {
    return GlowCard(
      glowVariant: GlowCardVariant.success,
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: AppTheme.electricGreen,
                size: 32,
              ),
              const SizedBox(width: AppTheme.spacing2),
              Text(
                'Experience Gained',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppTheme.electricGreen,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '+$_displayedXp',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      color: AppTheme.electricGreen,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(width: AppTheme.spacing1),
              Text(
                'XP',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          // XP progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: AnimatedBuilder(
              animation: _xpController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _xpController.value,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.electricGreen),
                  minHeight: 8,
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.1, end: 0);
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
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${isPositive ? '+' : ''}$_displayedElo',
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
          const SizedBox(height: AppTheme.spacing1),
          Text(
            'New Rating: ${1650 + _displayedElo}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 1200.ms).slideY(begin: 0.1, end: 0);
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        // Play Again
        CyberpunkButton(
          label: 'PLAY AGAIN',
          onPressed: () {
            HapticFeedback.mediumImpact();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/matchmaking',
              (route) => route.settings.name == '/menu',
            );
          },
          variant: CyberpunkButtonVariant.primary,
          icon: Icons.replay,
          fullWidth: true,
        ),

        const SizedBox(height: AppTheme.spacing2),

        // Back to Menu
        CyberpunkButton(
          label: 'BACK TO MENU',
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/menu',
              (route) => false,
            );
          },
          variant: CyberpunkButtonVariant.ghost,
          icon: Icons.home,
          fullWidth: true,
        ),

        const SizedBox(height: AppTheme.spacing2),

        // View Replay (optional)
        TextButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            // TODO: Implement replay viewer
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.movie, color: AppTheme.cyberBlue, size: 18),
              const SizedBox(width: AppTheme.spacing1),
              Text(
                'View Replay',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.cyberBlue,
                    ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 1400.ms);
  }
}
