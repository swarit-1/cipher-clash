import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

/// 🎨 Spectacular enhanced profile screen with stats, heatmap, and achievements
/// This is the crown jewel of the UX redesign
class EnhancedProfileScreen extends StatefulWidget {
  final String userId;

  const EnhancedProfileScreen({
    super.key,
    required this.userId,
  });

  @override
  State<EnhancedProfileScreen> createState() => _EnhancedProfileScreenState();
}

class _EnhancedProfileScreenState extends State<EnhancedProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.deepDark,
      body: CustomScrollView(
        slivers: [
          // Stunning animated app bar
          _buildSliverAppBar(),

          // Stats cards
          SliverToBoxAdapter(
            child: _buildStatsSection(),
          ),

          // Tab bar
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                indicatorColor: AppTheme.cyberBlue,
                labelColor: AppTheme.cyberBlue,
                unselectedLabelColor: AppTheme.textSecondary,
                tabs: const [
                  Tab(text: 'Activity'),
                  Tab(text: 'Ciphers'),
                  Tab(text: 'Achievements'),
                  Tab(text: 'Friends'),
                ],
              ),
            ),
          ),

          // Tab content
          SliverFillRemaining(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildActivityTab(),
                _buildCiphersTab(),
                _buildAchievementsTab(),
                _buildFriendsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: AppTheme.darkNavy,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Gradient background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.deepDark,
                    AppTheme.darkNavy,
                    AppTheme.cyberBlue.withValues(alpha: 0.1),
                  ],
                ),
              ),
            ),

            // Animated particles background
            ...List.generate(20, (index) {
              return Positioned(
                left: (index * 50.0) % MediaQuery.of(context).size.width,
                top: (index * 30.0) % 200,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.cyberBlue.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.cyberBlue.withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                )
                    .animate(onPlay: (controller) => controller.repeat())
                    .fadeIn(duration: 2.seconds)
                    .then()
                    .fadeOut(duration: 2.seconds),
              );
            }),

            // Profile content
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Avatar with glow effect
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppTheme.cyberBlue, AppTheme.neonPurple],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cyberBlue.withValues(alpha: 0.6),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.person,
                          size: 50,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ).animate().scale(delay: 200.ms),

                    const SizedBox(height: AppTheme.spacing2),

                    // Username
                    const Text(
                      'CipherMaster',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.3),

                    // Title
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing2,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.goldYellow.withValues(alpha: 0.3),
                            AppTheme.goldYellow.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                        border: Border.all(color: AppTheme.goldYellow),
                      ),
                      child: const Text(
                        '👑 Enigma Breaker',
                        style: TextStyle(
                          color: AppTheme.goldYellow,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.8, 0.8)),

                    const SizedBox(height: AppTheme.spacing2),

                    // ELO and Rank
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildStatChip(
                          icon: Icons.emoji_events,
                          label: 'Diamond',
                          value: '1850 ELO',
                          color: AppTheme.diamondPurple,
                        ),
                        const SizedBox(width: AppTheme.spacing2),
                        _buildStatChip(
                          icon: Icons.trending_up,
                          label: 'Rank',
                          value: '#42',
                          color: AppTheme.electricGreen,
                        ),
                      ],
                    ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.5),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.emoji_events,
                  label: 'Total Wins',
                  value: '142',
                  color: AppTheme.electricGreen,
                  delay: 0,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.speed,
                  label: 'Avg Time',
                  value: '45s',
                  color: AppTheme.cyberBlue,
                  delay: 100,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  icon: Icons.percent,
                  label: 'Win Rate',
                  value: '68%',
                  color: AppTheme.neonPurple,
                  delay: 200,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: _buildStatCard(
                  icon: Icons.local_fire_department,
                  label: 'Streak',
                  value: '5',
                  color: AppTheme.electricYellow,
                  delay: 300,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required int delay,
  }) {
    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: delay.ms).slideX(begin: -0.3);
  }

  Widget _buildActivityTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ACTIVITY HEATMAP',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          _buildActivityHeatmap(),
          const SizedBox(height: AppTheme.spacing4),
          const Text(
            'RECENT MATCHES',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          ..._buildRecentMatches(),
        ],
      ),
    );
  }

  Widget _buildActivityHeatmap() {
    // Generate 365 days of activity data
    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 364));

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.cyberBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          // Month labels
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec']
                .map((month) => Text(
                      month,
                      style: const TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 9,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppTheme.spacing1),

          // Heatmap grid (52 weeks x 7 days)
          SizedBox(
            height: 100,
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
                childAspectRatio: 1.5,
              ),
              itemCount: 365,
              itemBuilder: (context, index) {
                final date = startDate.add(Duration(days: index));
                final activity = _getActivityLevel(date);
                return _buildHeatmapCell(activity, date);
              },
            ),
          ),

          const SizedBox(height: AppTheme.spacing2),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              const Text(
                'Less',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 9,
                ),
              ),
              const SizedBox(width: 8),
              _buildHeatmapCell(0, DateTime.now()),
              const SizedBox(width: 3),
              _buildHeatmapCell(1, DateTime.now()),
              const SizedBox(width: 3),
              _buildHeatmapCell(2, DateTime.now()),
              const SizedBox(width: 3),
              _buildHeatmapCell(3, DateTime.now()),
              const SizedBox(width: 3),
              _buildHeatmapCell(4, DateTime.now()),
              const SizedBox(width: 8),
              const Text(
                'More',
                style: TextStyle(
                  color: AppTheme.textTertiary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildHeatmapCell(int level, DateTime date) {
    final colors = [
      AppTheme.textDisabled.withValues(alpha: 0.1),
      AppTheme.cyberBlue.withValues(alpha: 0.3),
      AppTheme.cyberBlue.withValues(alpha: 0.5),
      AppTheme.cyberBlue.withValues(alpha: 0.7),
      AppTheme.cyberBlue,
    ];

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: colors[level],
        borderRadius: BorderRadius.circular(2),
        border: level > 0
            ? Border.all(
                color: AppTheme.cyberBlue.withValues(alpha: 0.3),
              )
            : null,
        boxShadow: level >= 3
            ? [
                BoxShadow(
                  color: AppTheme.cyberBlue.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ]
            : null,
      ),
    );
  }

  int _getActivityLevel(DateTime date) {
    // Mock data - higher activity on weekends and recent days
    final daysSinceStart = DateTime.now().difference(date).inDays;
    if (daysSinceStart < 7) return 4;
    if (daysSinceStart < 30) return 3;
    if (date.weekday >= 6) return 2;
    return (date.day % 5);
  }

  List<Widget> _buildRecentMatches() {
    return List.generate(5, (index) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing2),
        child: GlowCard(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing2),
            child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing2),
                decoration: BoxDecoration(
                  color: index % 2 == 0
                      ? AppTheme.electricGreen.withValues(alpha: 0.2)
                      : AppTheme.neonRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(
                  index % 2 == 0 ? Icons.check_circle : Icons.cancel,
                  color: index % 2 == 0 ? AppTheme.electricGreen : AppTheme.neonRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      index % 2 == 0 ? 'VICTORY' : 'DEFEAT',
                      style: TextStyle(
                        color: index % 2 == 0 ? AppTheme.electricGreen : AppTheme.neonRed,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'vs. CryptoNinja',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '1250 pts',
                    style: TextStyle(
                      color: AppTheme.cyberBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${index + 1}h ago',
                    style: const TextStyle(
                      color: AppTheme.textTertiary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
            ),
          ),
        ),
      ).animate(delay: (index * 50).ms).fadeIn().slideX(begin: 0.3);
    });
  }

  Widget _buildCiphersTab() {
    final ciphers = [
      {'name': 'Caesar', 'level': 8, 'solved': 145, 'color': AppTheme.cyberBlue},
      {'name': 'Vigenère', 'level': 6, 'solved': 89, 'color': AppTheme.neonPurple},
      {'name': 'Playfair', 'level': 5, 'solved': 67, 'color': AppTheme.electricGreen},
      {'name': 'Rail Fence', 'level': 7, 'solved': 103, 'color': AppTheme.electricYellow},
      {'name': 'Affine', 'level': 3, 'solved': 24, 'color': AppTheme.infoCyan},
      {'name': 'Enigma-lite', 'level': 2, 'solved': 12, 'color': AppTheme.diamondPurple},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: AppTheme.spacing2,
        crossAxisSpacing: AppTheme.spacing2,
        childAspectRatio: 1.2,
      ),
      itemCount: ciphers.length,
      itemBuilder: (context, index) {
        final cipher = ciphers[index];
        return _buildCipherMasteryCard(
          name: cipher['name'] as String,
          level: cipher['level'] as int,
          solved: cipher['solved'] as int,
          color: cipher['color'] as Color,
          delay: index * 50,
        );
      },
    );
  }

  Widget _buildCipherMasteryCard({
    required String name,
    required int level,
    required int solved,
    required Color color,
    required int delay,
  }) {
    return GlowCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                    border: Border.all(color: color),
                  ),
                  child: Text(
                    'LVL $level',
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Icon(Icons.lock_outline, color: color, size: 20),
              ],
            ),
            const Spacer(),
            Text(
              name,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$solved solved',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: AppTheme.spacing1),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              child: LinearProgressIndicator(
                value: level / 10,
                backgroundColor: AppTheme.textDisabled.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 4,
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: delay.ms).fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildAchievementsTab() {
    return const Center(
      child: Text(
        'Achievements coming soon!',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  Widget _buildFriendsTab() {
    return const Center(
      child: Text(
        'Friends list coming soon!',
        style: TextStyle(color: AppTheme.textSecondary),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _TabBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: AppTheme.darkNavy,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_TabBarDelegate oldDelegate) {
    return false;
  }
}
