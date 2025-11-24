import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

class MatchmakingScreen extends StatefulWidget {
  const MatchmakingScreen({Key? key}) : super(key: key);

  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  String _selectedMode = 'RANKED_1V1';

  final List<Map<String, dynamic>> _gameModes = [
    {
      'id': 'RANKED_1V1',
      'name': 'Ranked 1v1',
      'description': 'Competitive matchmaking with ELO rating',
      'icon': Icons.emoji_events,
      'color': AppTheme.cyberBlue,
      'estimatedTime': '30-60s',
    },
    {
      'id': 'CASUAL',
      'name': 'Casual Match',
      'description': 'Practice without affecting your ranking',
      'icon': Icons.sports_esports,
      'color': AppTheme.neonPurple,
      'estimatedTime': '20-40s',
    },
    {
      'id': 'PRACTICE',
      'name': 'Practice Mode',
      'description': 'Solo practice with AI opponent',
      'icon': Icons.school,
      'color': AppTheme.electricGreen,
      'estimatedTime': 'Instant',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Game Mode'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing3),
            child: Column(
              children: [
                // Game Mode Selection
                Expanded(
                  child: ListView.separated(
                    itemCount: _gameModes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppTheme.spacing2),
                    itemBuilder: (context, index) {
                      final mode = _gameModes[index];
                      final isSelected = _selectedMode == mode['id'];

                      return GlowCard(
                        glowVariant: isSelected
                            ? GlowCardVariant.primary
                            : GlowCardVariant.none,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedMode = mode['id'];
                          });
                        },
                        child: Row(
                          children: [
                            // Mode Icon
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: (mode['color'] as Color)
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMedium),
                                border: Border.all(
                                  color: mode['color'] as Color,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                mode['icon'] as IconData,
                                color: mode['color'] as Color,
                                size: 40,
                              ),
                            ),

                            const SizedBox(width: AppTheme.spacing2),

                            // Mode Info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    mode['name'],
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    mode['description'],
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                  const SizedBox(height: AppTheme.spacing1),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.timer,
                                        size: 16,
                                        color: mode['color'] as Color,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        mode['estimatedTime'],
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: mode['color'] as Color,
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Selection Indicator
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.cyberBlue
                                      .withValues(alpha: 0.2),
                                ),
                                child: const Icon(
                                  Icons.check,
                                  color: AppTheme.cyberBlue,
                                  size: 24,
                                ),
                              )
                                  .animate()
                                  .scale(duration: 300.ms)
                                  .fadeIn(),
                          ],
                        ),
                      ).animate().fadeIn(delay: (100 + (index * 100)).ms);
                    },
                  ),
                ),

                const SizedBox(height: AppTheme.spacing3),

                // Current ELO Display (for ranked mode)
                if (_selectedMode == 'RANKED_1V1')
                  GlowCard(
                    glowVariant: GlowCardVariant.none,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.leaderboard,
                              color: AppTheme.cyberBlue,
                            ),
                            const SizedBox(width: AppTheme.spacing1),
                            Text(
                              'Current Rating',
                              style:
                                  Theme.of(context).textTheme.bodyLarge,
                            ),
                          ],
                        ),
                        Text(
                          '1650 ELO',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppTheme.cyberBlue,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),

                const SizedBox(height: AppTheme.spacing2),

                // Start Matchmaking Button
                CyberpunkButton(
                  label: _getButtonLabel(),
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    Navigator.pushNamed(
                      context,
                      '/queue',
                      arguments: {'mode': _selectedMode},
                    );
                  },
                  variant: CyberpunkButtonVariant.primary,
                  icon: Icons.play_arrow,
                  fullWidth: true,
                  padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getButtonLabel() {
    switch (_selectedMode) {
      case 'RANKED_1V1':
        return 'START RANKED MATCH';
      case 'CASUAL':
        return 'START CASUAL MATCH';
      case 'PRACTICE':
        return 'START PRACTICE';
      default:
        return 'START MATCH';
    }
  }
}
