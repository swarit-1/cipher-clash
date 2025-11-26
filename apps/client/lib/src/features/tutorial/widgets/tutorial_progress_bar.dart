import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// A sleek, cyberpunk-styled progress bar for tutorial completion
/// Shows current step, total steps, and animated progress
class TutorialProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const TutorialProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (currentStep + 1) / totalSteps;

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyberBlue.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'TUTORIAL PROGRESS',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.cyberBlue.withValues(alpha: 0.3),
                      AppTheme.neonPurple.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: AppTheme.cyberBlue.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
                child: Text(
                  'STEP ${currentStep + 1}/$totalSteps',
                  style: const TextStyle(
                    color: AppTheme.cyberBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Stack(
            children: [
              // Background track
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.textDisabled.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  border: Border.all(
                    color: AppTheme.textDisabled.withValues(alpha: 0.5),
                    width: 1,
                  ),
                ),
              ),
              // Progress fill with glow effect
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                height: 10,
                width: MediaQuery.of(context).size.width * progress * 0.85,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: progress >= 1.0
                        ? [AppTheme.electricGreen, AppTheme.cyberBlue]
                        : [AppTheme.cyberBlue, AppTheme.neonPurple],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  boxShadow: [
                    BoxShadow(
                      color: (progress >= 1.0
                              ? AppTheme.electricGreen
                              : AppTheme.cyberBlue)
                          .withValues(alpha: 0.6),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              // Progress indicator dots
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(totalSteps, (index) {
                    final isCompleted = index <= currentStep;
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isCompleted
                            ? AppTheme.electricGreen
                            : AppTheme.textDisabled.withValues(alpha: 0.5),
                        border: Border.all(
                          color: isCompleted
                              ? AppTheme.electricGreen
                              : AppTheme.textDisabled,
                          width: 2,
                        ),
                        boxShadow: isCompleted
                            ? [
                                BoxShadow(
                                  color:
                                      AppTheme.electricGreen.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: isCompleted
                          ? const Icon(
                              Icons.check,
                              size: 6,
                              color: AppTheme.deepDark,
                            )
                          : null,
                    );
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing1),
          // Percentage text
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(progress * 100).toInt()}% COMPLETE',
              style: TextStyle(
                color: progress >= 1.0
                    ? AppTheme.electricGreen
                    : AppTheme.cyberBlue,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
