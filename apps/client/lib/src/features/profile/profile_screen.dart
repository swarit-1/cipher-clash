import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock user data - TODO: Replace with actual user state
  final Map<String, dynamic> _userData = {
    'username': 'CipherMaster',
    'displayName': 'The Cipher Master',
    'email': 'cipher@example.com',
    'elo': 1650,
    'rank': 'PLATINUM',
    'level': 42,
    'currentXp': 8750,
    'nextLevelXp': 10000,
    'totalGames': 245,
    'wins': 156,
    'losses': 89,
    'winRate': 63.7,
    'winStreak': 5,
    'bestWinStreak': 12,
    'favoriteCipher': 'Vigenere',
    'totalSolveTime': 125430, // seconds
    'fastestSolve': 18, // seconds
    'joinDate': '2024-06-15',
    'region': 'US',
  };

  final List<Map<String, dynamic>> _recentMatches = [
    {
      'opponent': 'CryptoNinja',
      'result': 'WIN',
      'score': '1500-0',
      'cipher': 'Caesar',
      'time': '45s',
      'eloChange': '+15',
    },
    {
      'opponent': 'CodeBreaker99',
      'result': 'WIN',
      'score': '1200-950',
      'cipher': 'Vigenere',
      'time': '1m 23s',
      'eloChange': '+18',
    },
    {
      'opponent': 'QuantumHacker',
      'result': 'LOSS',
      'score': '0-1500',
      'cipher': 'RSA',
      'time': '2m 15s',
      'eloChange': '-12',
    },
  ];

  final List<Map<String, dynamic>> _topAchievements = [
    {
      'name': 'Speed Demon',
      'description': 'Solve a cipher in under 30 seconds',
      'icon': Icons.flash_on,
      'rarity': 'EPIC',
    },
    {
      'name': 'Win Streak Master',
      'description': 'Win 10 matches in a row',
      'icon': Icons.local_fire_department,
      'rarity': 'LEGENDARY',
    },
    {
      'name': 'Caesar Champion',
      'description': 'Solve 100 Caesar ciphers',
      'icon': Icons.emoji_events,
      'rarity': 'RARE',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  double get _xpProgress =>
      (_userData['currentXp'] as int) / (_userData['nextLevelXp'] as int);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              HapticFeedback.selectionClick();
              // TODO: Navigate to edit profile
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Header
              _buildProfileHeader(),

              // Tabs
              _buildTabs(),

              // Tab Content
              SizedBox(
                height: 600,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildStatsTab(),
                    _buildMatchHistoryTab(),
                    _buildAchievementsTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.deepDark,
            AppTheme.deepDark.withValues(alpha: 0),
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar and basic info
          Row(
            children: [
              // Avatar
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.glowCyberBlue(intensity: 1.5),
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.black),
              ).animate().scale(duration: 600.ms),

              const SizedBox(width: AppTheme.spacing3),

              // User info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userData['username'],
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
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
                            color: AppTheme.getRankColor(_userData['rank'])
                                .withValues(alpha: 0.2),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            border: Border.all(
                              color: AppTheme.getRankColor(_userData['rank']),
                            ),
                          ),
                          child: Text(
                            _userData['rank'],
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.getRankColor(_userData['rank']),
                                      fontWeight: FontWeight.w700,
                                    ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing1),
                        Text(
                          'Level ${_userData['level']}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing1),
                    Text(
                      '${_userData['elo']} ELO',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: AppTheme.cyberBlue,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ).animate().fadeIn().slideX(begin: -0.1, end: 0),

          const SizedBox(height: AppTheme.spacing3),

          // Level progress
          GlowCard(
            glowVariant: GlowCardVariant.primary,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Level Progress',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(
                      '${_userData['currentXp']} / ${_userData['nextLevelXp']} XP',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppTheme.electricGreen,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing1),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: LinearProgressIndicator(
                    value: _xpProgress,
                    backgroundColor: AppTheme.surfaceVariant,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.electricGreen),
                    minHeight: 8,
                  ),
                ),
              ],
            ),
          ).animate().fadeIn(delay: 200.ms),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.black,
        unselectedLabelColor: AppTheme.textSecondary,
        tabs: const [
          Tab(text: 'Stats'),
          Tab(text: 'Matches'),
          Tab(text: 'Achievements'),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Career Statistics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacing2),

          // Win/Loss Record
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Wins',
                  '${_userData['wins']}',
                  Icons.emoji_events,
                  AppTheme.electricGreen,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: _buildStatCard(
                  'Losses',
                  '${_userData['losses']}',
                  Icons.close,
                  AppTheme.neonRed,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing2),

          // Additional stats
          _buildStatCard(
            'Win Rate',
            '${_userData['winRate']}%',
            Icons.bar_chart,
            AppTheme.cyberBlue,
            fullWidth: true,
          ),

          const SizedBox(height: AppTheme.spacing2),

          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Current Streak',
                  '${_userData['winStreak']}',
                  Icons.local_fire_department,
                  AppTheme.electricYellow,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: _buildStatCard(
                  'Best Streak',
                  '${_userData['bestWinStreak']}',
                  Icons.stars,
                  AppTheme.neonPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing3),

          Text(
            'Performance Metrics',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: AppTheme.spacing2),

          _buildStatCard(
            'Fastest Solve',
            '${_userData['fastestSolve']}s',
            Icons.speed,
            AppTheme.electricGreen,
            fullWidth: true,
          ),

          const SizedBox(height: AppTheme.spacing2),

          _buildStatCard(
            'Favorite Cipher',
            _userData['favoriteCipher'],
            Icons.favorite,
            AppTheme.cyberBlue,
            fullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
  }) {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Column(
        children: [
          Icon(icon, color: color, size: fullWidth ? 32 : 28),
          const SizedBox(height: AppTheme.spacing1),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
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
    );
  }

  Widget _buildMatchHistoryTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      itemCount: _recentMatches.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTheme.spacing2),
      itemBuilder: (context, index) {
        final match = _recentMatches[index];
        final isWin = match['result'] == 'WIN';

        return GlowCard(
          glowVariant: isWin ? GlowCardVariant.success : GlowCardVariant.none,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Result badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (isWin ? AppTheme.electricGreen : AppTheme.neonRed)
                          .withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: isWin ? AppTheme.electricGreen : AppTheme.neonRed,
                      ),
                    ),
                    child: Text(
                      match['result'],
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isWin ? AppTheme.electricGreen : AppTheme.neonRed,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),

                  const Spacer(),

                  // ELO change
                  Text(
                    match['eloChange'],
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isWin ? AppTheme.electricGreen : AppTheme.neonRed,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing1),

              // Opponent
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'vs ${match['opponent']}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),

              const SizedBox(height: AppTheme.spacing1),

              // Match details
              Row(
                children: [
                  _buildMatchDetail(Icons.lock, match['cipher']),
                  const SizedBox(width: AppTheme.spacing2),
                  _buildMatchDetail(Icons.timer, match['time']),
                  const Spacer(),
                  Text(
                    match['score'],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMatchDetail(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textTertiary),
        const SizedBox(width: 4),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textTertiary,
              ),
        ),
      ],
    );
  }

  Widget _buildAchievementsTab() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      itemCount: _topAchievements.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppTheme.spacing2),
      itemBuilder: (context, index) {
        final achievement = _topAchievements[index];
        final rarity = achievement['rarity'] as String;
        final color = _getRarityColor(rarity);

        return GlowCard(
          glowVariant: rarity == 'LEGENDARY'
              ? GlowCardVariant.secondary
              : GlowCardVariant.none,
          child: Row(
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  achievement['icon'] as IconData,
                  color: color,
                  size: 32,
                ),
              ),

              const SizedBox(width: AppTheme.spacing2),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement['name'],
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement['description'],
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      ),
                      child: Text(
                        rarity,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity) {
      case 'LEGENDARY':
        return AppTheme.neonPurple;
      case 'EPIC':
        return AppTheme.cyberBlue;
      case 'RARE':
        return AppTheme.electricGreen;
      default:
        return AppTheme.textSecondary;
    }
  }
}
