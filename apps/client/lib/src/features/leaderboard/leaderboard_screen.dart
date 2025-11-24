import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock leaderboard data - TODO: Replace with API call
  final List<Map<String, dynamic>> _globalLeaderboard = [
    {'rank': 1, 'username': 'CryptoGod', 'elo': 2150, 'tier': 'DIAMOND', 'wins': 450},
    {'rank': 2, 'username': 'CipherQueen', 'elo': 2080, 'tier': 'DIAMOND', 'wins': 398},
    {'rank': 3, 'username': 'DecryptKing', 'elo': 2020, 'tier': 'DIAMOND', 'wins': 375},
    {'rank': 4, 'username': 'CodeBreaker', 'elo': 1950, 'tier': 'PLATINUM', 'wins': 342},
    {'rank': 5, 'username': 'CipherNinja', 'elo': 1890, 'tier': 'PLATINUM', 'wins': 310},
    {'rank': 6, 'username': 'QuantumHack', 'elo': 1825, 'tier': 'PLATINUM', 'wins': 289},
    {'rank': 7, 'username': 'CryptoWizard', 'elo': 1780, 'tier': 'PLATINUM', 'wins': 265},
    {'rank': 8, 'username': 'CipherMaster', 'elo': 1650, 'tier': 'PLATINUM', 'wins': 156, 'isCurrentUser': true},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              HapticFeedback.selectionClick();
              // TODO: Refresh leaderboard
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Column(
          children: [
            // Top 3 Podium
            _buildPodium(),

            // Tabs
            _buildTabs(),

            // Leaderboard List
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildLeaderboardList(_globalLeaderboard),
                  _buildLeaderboardList(_globalLeaderboard), // Regional
                  _buildLeaderboardList(_globalLeaderboard.take(3).toList()), // Friends
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodium() {
    if (_globalLeaderboard.length < 3) return const SizedBox.shrink();

    final first = _globalLeaderboard[0];
    final second = _globalLeaderboard[1];
    final third = _globalLeaderboard[2];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 2nd Place
          _buildPodiumCard(second, 2, 120, AppTheme.silverGray)
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0),

          const SizedBox(width: AppTheme.spacing2),

          // 1st Place
          _buildPodiumCard(first, 1, 150, AppTheme.goldYellow)
              .animate()
              .fadeIn(delay: 100.ms)
              .slideY(begin: 0.3, end: 0)
              .shimmer(delay: 500.ms, duration: 2.seconds),

          const SizedBox(width: AppTheme.spacing2),

          // 3rd Place
          _buildPodiumCard(third, 3, 100, AppTheme.bronzeBrown)
              .animate()
              .fadeIn(delay: 300.ms)
              .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(
    Map<String, dynamic> player,
    int rank,
    double height,
    Color color,
  ) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          // Avatar with crown for 1st
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: rank == 1 ? 80 : 60,
                height: rank == 1 ? 80 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.2),
                  border: Border.all(color: color, width: 3),
                  boxShadow: rank == 1
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.5),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
                child: Icon(
                  Icons.person,
                  color: color,
                  size: rank == 1 ? 40 : 30,
                ),
              ),
              if (rank == 1)
                Positioned(
                  top: -15,
                  left: 0,
                  right: 0,
                  child: Icon(
                    Icons.emoji_events,
                    color: AppTheme.goldYellow,
                    size: 32,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing1),

          // Username
          Text(
            player['username'],
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),

          // ELO
          Text(
            '${player['elo']}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),

          const SizedBox(height: AppTheme.spacing1),

          // Podium base
          Container(
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.3),
                  color.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium),
              ),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                '#$rank',
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ),
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
          Tab(text: 'Global'),
          Tab(text: 'Regional'),
          Tab(text: 'Friends'),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildLeaderboardList(List<Map<String, dynamic>> players) {
    return RefreshIndicator(
      onRefresh: () async {
        HapticFeedback.mediumImpact();
        await Future.delayed(const Duration(seconds: 1));
      },
      color: AppTheme.cyberBlue,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppTheme.spacing3),
        itemCount: players.length,
        separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacing2),
        itemBuilder: (context, index) {
          final player = players[index];
          final isCurrentUser = player['isCurrentUser'] == true;

          return GlowCard(
            glowVariant: isCurrentUser ? GlowCardVariant.primary : GlowCardVariant.none,
            child: Row(
              children: [
                // Rank
                SizedBox(
                  width: 50,
                  child: Text(
                    '#${player['rank']}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _getRankColor(player['rank']),
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: AppTheme.spacing2),

                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCurrentUser
                        ? AppTheme.cyberBlue.withValues(alpha: 0.2)
                        : AppTheme.surfaceVariant,
                    border: Border.all(
                      color: isCurrentUser ? AppTheme.cyberBlue : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.person,
                    color: isCurrentUser ? AppTheme.cyberBlue : AppTheme.textSecondary,
                  ),
                ),

                const SizedBox(width: AppTheme.spacing2),

                // Player info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              player['username'],
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: isCurrentUser ? AppTheme.cyberBlue : null,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isCurrentUser)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.cyberBlue.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              ),
                              child: Text(
                                'YOU',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppTheme.cyberBlue,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.getRankColor(player['tier'])
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                              border: Border.all(
                                color: AppTheme.getRankColor(player['tier']),
                              ),
                            ),
                            child: Text(
                              player['tier'],
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppTheme.getRankColor(player['tier']),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing1),
                          Text(
                            '${player['wins']} wins',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.textTertiary,
                                ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ELO
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${player['elo']}',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
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
          ).animate().fadeIn(delay: (500 + (index * 50)).ms);
        },
      ),
    );
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return AppTheme.goldYellow;
    if (rank == 2) return AppTheme.silverGray;
    if (rank == 3) return AppTheme.bronzeBrown;
    return AppTheme.cyberBlue;
  }
}
