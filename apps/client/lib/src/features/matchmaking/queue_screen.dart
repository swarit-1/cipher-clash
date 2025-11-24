import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

class QueueScreen extends StatefulWidget {
  final String gameMode;

  const QueueScreen({
    Key? key,
    this.gameMode = 'RANKED_1V1',
  }) : super(key: key);

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen>
    with TickerProviderStateMixin {
  late AnimationController _searchController;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  Timer? _timer;
  int _elapsedSeconds = 0;
  int _playersInQueue = 0;
  int _searchRange = 100;
  bool _matchFound = false;

  @override
  void initState() {
    super.initState();

    // Search animation (rotating)
    _searchController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Search range expansion animation
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    // Start matchmaking simulation
    _startMatchmaking();
  }

  void _startMatchmaking() {
    // Simulate queue updates
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      setState(() {
        _elapsedSeconds++;
        _playersInQueue = 5 + (_elapsedSeconds % 10);

        // Expand search range every 15 seconds
        if (_elapsedSeconds % 15 == 0 && _searchRange < 500) {
          _searchRange += 50;
          _expandController.forward(from: 0.0);
        }

        // Simulate match found after random time (15-30 seconds)
        if (_elapsedSeconds > 15 && !_matchFound) {
          _onMatchFound();
        }
      });
    });
  }

  void _onMatchFound() {
    setState(() {
      _matchFound = true;
    });

    HapticFeedback.heavyImpact();

    // Navigate to game screen after animation
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/game');
    });
  }

  void _cancelQueue() {
    HapticFeedback.mediumImpact();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _searchController.dispose();
    _expandController.dispose();
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
                // Search Animation
                _buildSearchAnimation(),

                const SizedBox(height: AppTheme.spacing6),

                // Status Text
                _buildStatusText(),

                const SizedBox(height: AppTheme.spacing4),

                // Queue Stats
                _buildQueueStats(),

                const SizedBox(height: AppTheme.spacing6),

                // Search Range Indicator
                _buildSearchRange(),

                const Spacer(),

                // Cancel Button
                _buildCancelButton(),
              ],
            ),
          ),
        ),
      ),
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
              // Outer ring
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

              // Inner ring
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

              // Center icon
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
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: 2.seconds,
          color: AppTheme.cyberBlue.withValues(alpha: 0.3),
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
          'Estimated Wait',
          '${(30 - _elapsedSeconds).clamp(0, 30)}s',
          Icons.timer,
          AppTheme.neonPurple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
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
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
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
    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
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
        )
            .animate(
              target: _expandAnimation.value,
            )
            .scale(duration: 400.ms);
      },
    );
  }

  Widget _buildCancelButton() {
    return CyberpunkButton(
      label: 'CANCEL',
      onPressed: _cancelQueue,
      variant: CyberpunkButtonVariant.danger,
      icon: Icons.close,
      fullWidth: true,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
    );
  }

  Widget _buildMatchFoundScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Success icon
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                  boxShadow: AppTheme.glowElectricGreen(intensity: 2.0),
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.black,
                ),
              )
                  .animate()
                  .scale(duration: 400.ms, curve: Curves.easeOutBack)
                  .then()
                  .shimmer(duration: 1.seconds),

              const SizedBox(height: AppTheme.spacing4),

              // Match found text
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
                'Preparing battle...',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ).animate().fadeIn(delay: 400.ms),

              const SizedBox(height: AppTheme.spacing4),

              // Loading indicator
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.electricGreen),
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
        return 'Ranked Match';
      case 'CASUAL':
        return 'Casual Match';
      default:
        return 'Matchmaking';
    }
  }
}
