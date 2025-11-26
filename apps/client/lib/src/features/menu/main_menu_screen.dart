import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  // Mock user data - TODO: Replace with actual user state
  final Map<String, dynamic> _userData = {
    'username': 'CipherMaster',
    'elo': 1650,
    'rank': 'PLATINUM',
    'level': 42,
    'wins': 156,
    'losses': 89,
    'winRate': 63.7,
  };

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  double get _winRate => _userData['winRate'] as double;
  String get _rankTier => _userData['rank'] as String;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // App Bar
              _buildAppBar(),

              // Content
              SliverPadding(
                padding: const EdgeInsets.all(AppTheme.spacing3),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // User Stats Card
                    _buildUserStatsCard(),

                    const SizedBox(height: AppTheme.spacing3),

                    // Quick Play Button
                    _buildQuickPlayButton(),

                    const SizedBox(height: AppTheme.spacing2),

                    // Game Mode Selection
                    _buildGameModeButtons(),

                    const SizedBox(height: AppTheme.spacing3),

                    // Daily Quests
                    _buildDailyQuests(),

                    const SizedBox(height: AppTheme.spacing3),

                    // Quick Actions
                    _buildQuickActions(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: AppTheme.deepDark.withValues(alpha: 0.95),
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
            ),
            child: const Icon(Icons.lock, color: Colors.black, size: 24),
          ),
          const SizedBox(width: AppTheme.spacing2),
          Text(
            'CIPHER CLASH',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.cyberBlue,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
          ),
        ],
      ),
      actions: [
        // Notifications
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            HapticFeedback.selectionClick();
            // TODO: Show notifications
          },
        ),
        // Settings
        IconButton(
          icon: const Icon(Icons.settings_outlined),
          onPressed: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, '/settings');
          },
        ),
      ],
    );
  }

  Widget _buildUserStatsCard() {
    return GlowCard(
      glowVariant: GlowCardVariant.primary,
      child: Column(
        children: [
          // Username and Rank
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.accentGradient,
                  boxShadow: AppTheme.glowNeonPurple(intensity: 0.8),
                ),
                child: const Icon(Icons.person, size: 32, color: Colors.black),
              ),

              const SizedBox(width: AppTheme.spacing2),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userData['username'] as String,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.getRankColor(_rankTier)
                                .withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: AppTheme.getRankColor(_rankTier),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _rankTier,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.getRankColor(_rankTier),
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing1),
                        Text(
                          'Level ${_userData['level']}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ELO Display
              Column(
                children: [
                  Text(
                    '${_userData['elo']}',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppTheme.cyberBlue,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(
                    'ELO',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing2),
          const Divider(),
          const SizedBox(height: AppTheme.spacing2),

          // Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatColumn('Wins', '${_userData['wins']}', AppTheme.electricGreen),
              _buildStatColumn('Losses', '${_userData['losses']}', AppTheme.neonRed),
              _buildStatColumn('Win Rate', '${_winRate.toStringAsFixed(1)}%', AppTheme.cyberBlue),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.1, end: 0);
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildQuickPlayButton() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
            boxShadow: AppTheme.glowCyberBlue(
              intensity: 0.8 + (_pulseController.value * 0.4),
            ),
          ),
          child: child,
        );
      },
      child: CyberpunkButton(
        label: 'QUICK PLAY',
        onPressed: () {
          HapticFeedback.heavyImpact();
          Navigator.pushNamed(context, '/matchmaking');
        },
        variant: CyberpunkButtonVariant.primary,
        icon: Icons.flash_on,
        fullWidth: true,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing3),
      ),
    ).animate().fadeIn(delay: 300.ms).scale(delay: 300.ms);
  }

  Widget _buildGameModeButtons() {
    return Row(
      children: [
        Expanded(
          child: CyberpunkButton(
            label: 'RANKED',
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(context, '/matchmaking', arguments: {'mode': 'ranked'});
            },
            variant: CyberpunkButtonVariant.secondary,
            icon: Icons.emoji_events,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
          ),
        ),
        const SizedBox(width: AppTheme.spacing2),
        Expanded(
          child: CyberpunkButton(
            label: 'CASUAL',
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pushNamed(context, '/matchmaking', arguments: {'mode': 'casual'});
            },
            variant: CyberpunkButtonVariant.ghost,
            icon: Icons.sports_esports,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildDailyQuests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Daily Quests',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text(
              'Resets in 6h 23m',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.electricYellow,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing2),
        _buildQuestCard(
          'Win 3 Matches',
          2,
          3,
          100,
          Icons.emoji_events,
          AppTheme.electricGreen,
        ),
        const SizedBox(height: AppTheme.spacing2),
        _buildQuestCard(
          'Solve 5 Vigenere Ciphers',
          3,
          5,
          75,
          Icons.vpn_key,
          AppTheme.cyberBlue,
        ),
        const SizedBox(height: AppTheme.spacing2),
        _buildQuestCard(
          'Play with Friends',
          0,
          1,
          150,
          Icons.people,
          AppTheme.neonPurple,
        ),
      ],
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildQuestCard(
    String title,
    int current,
    int total,
    int xp,
    IconData icon,
    Color color,
  ) {
    final progress = current / total;

    return GlowCard(
      glowVariant: current == total ? GlowCardVariant.success : GlowCardVariant.none,
      child: Row(
        children: [
          // Icon
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(color: color, width: 1),
            ),
            child: Icon(icon, color: color),
          ),

          const SizedBox(width: AppTheme.spacing2),

          // Quest Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                        child: LinearProgressIndicator(
                          value: progress,
                          backgroundColor: AppTheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(color),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing1),
                    Text(
                      '$current/$total',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: AppTheme.spacing2),

          // XP Reward
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.electricGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              '+$xp XP',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppTheme.spacing2),
        Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Tutorial',
                    Icons.school_outlined,
                    AppTheme.electricYellow,
                    () => Navigator.pushNamed(context, '/tutorial'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing2),
                Expanded(
                  child: _buildActionCard(
                    'Profile',
                    Icons.person_outline,
                    AppTheme.cyberBlue,
                    () => Navigator.pushNamed(context, '/profile'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing2),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Leaderboard',
                    Icons.leaderboard,
                    AppTheme.neonPurple,
                    () => Navigator.pushNamed(context, '/leaderboard'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing2),
                Expanded(
                  child: _buildActionCard(
                    'Achievements',
                    Icons.emoji_events_outlined,
                    AppTheme.electricGreen,
                    () => Navigator.pushNamed(context, '/achievements'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing2),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Social',
                    Icons.people_outline,
                    AppTheme.neonRed,
                    () => Navigator.pushNamed(context, '/social'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing2),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing2),
        height: 100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: AppTheme.spacing1),
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
