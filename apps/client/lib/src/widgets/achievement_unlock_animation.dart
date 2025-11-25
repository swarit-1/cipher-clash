import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../theme/app_theme.dart';

/// Achievement unlock overlay with confetti and animations
class AchievementUnlockAnimation extends StatefulWidget {
  final String achievementName;
  final String description;
  final IconData icon;
  final int points;
  final VoidCallback? onDismiss;

  const AchievementUnlockAnimation({
    Key? key,
    required this.achievementName,
    required this.description,
    required this.icon,
    required this.points,
    this.onDismiss,
  }) : super(key: key);

  @override
  State<AchievementUnlockAnimation> createState() =>
      _AchievementUnlockAnimationState();
}

class _AchievementUnlockAnimationState
    extends State<AchievementUnlockAnimation> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));

    // Trigger haptic feedback and confetti
    HapticFeedback.heavyImpact();
    _confettiController.play();

    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() {
    widget.onDismiss?.call();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.8),
      child: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14 / 2, // downward
              emissionFrequency: 0.05,
              numberOfParticles: 30,
              gravity: 0.2,
              colors: [
                AppTheme.cyberBlue,
                AppTheme.electricGreen,
                AppTheme.neonPurple,
                AppTheme.electricYellow,
              ],
            ),
          ),

          // Achievement card
          Center(
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 32),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.cyberBlue.withValues(alpha: 0.2),
                      AppTheme.neonPurple.withValues(alpha: 0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: AppTheme.cyberBlue,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.cyberBlue.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // "Achievement Unlocked" text
                    Text(
                      'ACHIEVEMENT UNLOCKED',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppTheme.electricGreen,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                    ).animate().fadeIn(duration: 300.ms).slideY(
                          begin: -0.5,
                          end: 0,
                          duration: 300.ms,
                        ),

                    const SizedBox(height: 16),

                    // Icon with glow effect
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.cyberBlue.withValues(alpha: 0.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cyberBlue.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: Icon(
                        widget.icon,
                        size: 40,
                        color: AppTheme.cyberBlue,
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0, 0),
                          end: const Offset(1, 1),
                          duration: 500.ms,
                          curve: Curves.elasticOut,
                        )
                        .then()
                        .shimmer(
                          duration: 1500.ms,
                          color: AppTheme.electricGreen.withValues(alpha: 0.5),
                        ),

                    const SizedBox(height: 16),

                    // Achievement name
                    Text(
                      widget.achievementName,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                    ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

                    const SizedBox(height: 8),

                    // Description
                    Text(
                      widget.description,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ).animate().fadeIn(delay: 400.ms, duration: 300.ms),

                    const SizedBox(height: 16),

                    // Points badge
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.electricGreen.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppTheme.electricGreen,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.stars,
                            size: 16,
                            color: AppTheme.electricGreen,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '+${widget.points} XP',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  color: AppTheme.electricGreen,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 600.ms, duration: 300.ms)
                        .scale(delay: 600.ms, duration: 300.ms),

                    const SizedBox(height: 24),

                    // Tap to dismiss hint
                    Text(
                      'Tap anywhere to continue',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                    )
                        .animate(onPlay: (controller) => controller.repeat())
                        .fadeIn(duration: 1000.ms)
                        .then()
                        .fadeOut(duration: 1000.ms),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show achievement unlock
void showAchievementUnlock(
  BuildContext context, {
  required String achievementName,
  required String description,
  required IconData icon,
  required int points,
}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.8),
    builder: (context) => AchievementUnlockAnimation(
      achievementName: achievementName,
      description: description,
      icon: icon,
      points: points,
    ),
  );
}
