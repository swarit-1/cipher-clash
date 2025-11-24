import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Mock achievements data - TODO: Replace with API call
  final List<Map<String, dynamic>> _allAchievements = [
    {
      'id': 1,
      'name': 'First Steps',
      'description': 'Complete your first match',
      'icon': Icons.directions_walk,
      'rarity': 'COMMON',
      'unlocked': true,
      'progress': 1,
      'total': 1,
      'xpReward': 50,
      'unlockedDate': '2024-06-15',
    },
    {
      'id': 2,
      'name': 'Speed Demon',
      'description': 'Solve a cipher in under 30 seconds',
      'icon': Icons.flash_on,
      'rarity': 'EPIC',
      'unlocked': true,
      'progress': 1,
      'total': 1,
      'xpReward': 200,
      'unlockedDate': '2024-07-20',
    },
    {
      'id': 3,
      'name': 'Win Streak Master',
      'description': 'Win 10 matches in a row',
      'icon': Icons.local_fire_department,
      'rarity': 'LEGENDARY',
      'unlocked': true,
      'progress': 10,
      'total': 10,
      'xpReward': 500,
      'unlockedDate': '2024-08-10',
    },
    {
      'id': 4,
      'name': 'Caesar Champion',
      'description': 'Solve 100 Caesar ciphers',
      'icon': Icons.emoji_events,
      'rarity': 'RARE',
      'unlocked': true,
      'progress': 100,
      'total': 100,
      'xpReward': 150,
      'unlockedDate': '2024-09-05',
    },
    {
      'id': 5,
      'name': 'Vigenere Virtuoso',
      'description': 'Solve 50 Vigenere ciphers',
      'icon': Icons.workspace_premium,
      'rarity': 'RARE',
      'unlocked': false,
      'progress': 35,
      'total': 50,
      'xpReward': 150,
    },
    {
      'id': 6,
      'name': 'RSA Master',
      'description': 'Solve 25 RSA challenges',
      'icon': Icons.security,
      'rarity': 'EPIC',
      'unlocked': false,
      'progress': 12,
      'total': 25,
      'xpReward': 200,
    },
    {
      'id': 7,
      'name': 'Perfect Game',
      'description': 'Win a match without any mistakes',
      'icon': Icons.stars,
      'rarity': 'LEGENDARY',
      'unlocked': false,
      'progress': 0,
      'total': 1,
      'xpReward': 500,
    },
    {
      'id': 8,
      'name': 'Century Club',
      'description': 'Win 100 total matches',
      'icon': Icons.military_tech,
      'rarity': 'EPIC',
      'unlocked': false,
      'progress': 67,
      'total': 100,
      'xpReward': 300,
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _unlockedAchievements =>
      _allAchievements.where((a) => a['unlocked'] == true).toList();

  List<Map<String, dynamic>> get _lockedAchievements =>
      _allAchievements.where((a) => a['unlocked'] == false).toList();

  List<Map<String, dynamic>> _getAchievementsByRarity(String rarity) =>
      _allAchievements.where((a) => a['rarity'] == rarity).toList();

  int get _totalXpEarned => _unlockedAchievements.fold(
      0, (sum, achievement) => sum + (achievement['xpReward'] as int));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              HapticFeedback.selectionClick();
              _showAchievementInfo();
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
            // Statistics Overview
            _buildStatisticsOverview(),

            // Tabs
            _buildTabs(),

            // Achievement Grid
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAchievementGrid(_allAchievements),
                  _buildAchievementGrid(_unlockedAchievements),
                  _buildAchievementGrid(_lockedAchievements),
                  _buildRarityList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsOverview() {
    return Container(
      margin: const EdgeInsets.all(AppTheme.spacing3),
      child: GlowCard(
        glowVariant: GlowCardVariant.primary,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatColumn(
              'Unlocked',
              '${_unlockedAchievements.length}/${_allAchievements.length}',
              Icons.lock_open,
              AppTheme.electricGreen,
            ),
            Container(
              height: 40,
              width: 1,
              color: AppTheme.textTertiary,
            ),
            _buildStatColumn(
              'Total XP',
              '+$_totalXpEarned',
              Icons.star,
              AppTheme.cyberBlue,
            ),
            Container(
              height: 40,
              width: 1,
              color: AppTheme.textTertiary,
            ),
            _buildStatColumn(
              'Completion',
              '${(_unlockedAchievements.length / _allAchievements.length * 100).toStringAsFixed(0)}%',
              Icons.trending_up,
              AppTheme.neonPurple,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale();
  }

  Widget _buildStatColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: AppTheme.spacing1),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
        isScrollable: true,
        tabAlignment: TabAlignment.center,
        tabs: const [
          Tab(text: 'All'),
          Tab(text: 'Unlocked'),
          Tab(text: 'Locked'),
          Tab(text: 'By Rarity'),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildAchievementGrid(List<Map<String, dynamic>> achievements) {
    if (achievements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: AppTheme.textTertiary,
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              'No achievements found',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppTheme.spacing2,
        mainAxisSpacing: AppTheme.spacing2,
        childAspectRatio: 0.85,
      ),
      itemCount: achievements.length,
      itemBuilder: (context, index) {
        final achievement = achievements[index];
        return _buildAchievementCard(achievement, index);
      },
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement, int index) {
    final bool unlocked = achievement['unlocked'] as bool;
    final String rarity = achievement['rarity'] as String;
    final Color rarityColor = _getRarityColor(rarity);
    final int progress = achievement['progress'] as int;
    final int total = achievement['total'] as int;
    final double progressPercent = total > 0 ? progress / total : 0.0;

    return GlowCard(
      glowVariant: unlocked && rarity == 'LEGENDARY'
          ? GlowCardVariant.secondary
          : GlowCardVariant.none,
      onTap: () {
        HapticFeedback.selectionClick();
        _showAchievementDetails(achievement);
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with lock overlay if locked
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: rarityColor.withValues(alpha: unlocked ? 0.2 : 0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                    color: unlocked ? rarityColor : AppTheme.textTertiary,
                    width: 2,
                  ),
                ),
                child: Icon(
                  achievement['icon'] as IconData,
                  color: unlocked ? rarityColor : AppTheme.textTertiary,
                  size: 40,
                ),
              ),
              if (!unlocked)
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  ),
                  child: const Icon(
                    Icons.lock,
                    color: AppTheme.textTertiary,
                    size: 32,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing1),

          // Achievement name
          Text(
            achievement['name'],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: unlocked ? null : AppTheme.textTertiary,
                ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 4),

          // Rarity badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: unlocked ? 0.2 : 0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              rarity,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: unlocked ? rarityColor : AppTheme.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),

          const Spacer(),

          // Progress bar for locked achievements
          if (!unlocked) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              child: LinearProgressIndicator(
                value: progressPercent,
                backgroundColor: AppTheme.surfaceVariant,
                valueColor: AlwaysStoppedAnimation(rarityColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$progress / $total',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textTertiary,
                  ),
            ),
          ],

          // XP Reward
          if (unlocked)
            Text(
              '+${achievement['xpReward']} XP',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.w700,
                  ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: (100 + (index * 50)).ms);
  }

  Widget _buildRarityList() {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing3),
      children: [
        _buildRaritySection('LEGENDARY', AppTheme.neonPurple),
        const SizedBox(height: AppTheme.spacing3),
        _buildRaritySection('EPIC', AppTheme.cyberBlue),
        const SizedBox(height: AppTheme.spacing3),
        _buildRaritySection('RARE', AppTheme.electricGreen),
        const SizedBox(height: AppTheme.spacing3),
        _buildRaritySection('COMMON', AppTheme.textSecondary),
      ],
    );
  }

  Widget _buildRaritySection(String rarity, Color color) {
    final achievements = _getAchievementsByRarity(rarity);
    final unlockedCount =
        achievements.where((a) => a['unlocked'] == true).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppTheme.spacing1),
            Text(
              rarity,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(width: AppTheme.spacing1),
            Text(
              '($unlockedCount/${achievements.length})',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing2),
        ...achievements.map((achievement) {
          final bool unlocked = achievement['unlocked'] as bool;
          final int progress = achievement['progress'] as int;
          final int total = achievement['total'] as int;

          return GlowCard(
            glowVariant: unlocked && rarity == 'LEGENDARY'
                ? GlowCardVariant.secondary
                : GlowCardVariant.none,
            child: Row(
              children: [
                // Icon
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: unlocked ? 0.2 : 0.05),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    border: Border.all(
                      color: unlocked ? color : AppTheme.textTertiary,
                      width: 2,
                    ),
                  ),
                  child: unlocked
                      ? Icon(
                          achievement['icon'] as IconData,
                          color: color,
                          size: 32,
                        )
                      : const Icon(
                          Icons.lock,
                          color: AppTheme.textTertiary,
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
                              color: unlocked ? null : AppTheme.textTertiary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        achievement['description'],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      if (!unlocked) ...[
                        const SizedBox(height: AppTheme.spacing1),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusSmall),
                                child: LinearProgressIndicator(
                                  value: progress / total,
                                  backgroundColor: AppTheme.surfaceVariant,
                                  valueColor: AlwaysStoppedAnimation(color),
                                  minHeight: 4,
                                ),
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacing1),
                            Text(
                              '$progress/$total',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.textTertiary,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // XP Reward
                if (unlocked)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.electricGreen.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Text(
                      '+${achievement['xpReward']} XP',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.electricGreen,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
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
      case 'COMMON':
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  void _showAchievementDetails(Map<String, dynamic> achievement) {
    final bool unlocked = achievement['unlocked'] as bool;
    final String rarity = achievement['rarity'] as String;
    final Color rarityColor = _getRarityColor(rarity);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          side: BorderSide(color: rarityColor, width: 2),
        ),
        title: Row(
          children: [
            Icon(
              achievement['icon'] as IconData,
              color: rarityColor,
              size: 32,
            ),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Text(
                achievement['name'],
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: rarityColor,
                    ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              achievement['description'],
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacing2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Rarity:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: rarityColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    rarity,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: rarityColor,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing1),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'XP Reward:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                Text(
                  '+${achievement['xpReward']} XP',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.electricGreen,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            if (unlocked) ...[
              const SizedBox(height: AppTheme.spacing1),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Unlocked:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                  Text(
                    achievement['unlockedDate'] ?? 'Unknown',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
            if (!unlocked) ...[
              const SizedBox(height: AppTheme.spacing2),
              Text(
                'Progress:',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
              const SizedBox(height: AppTheme.spacing1),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: LinearProgressIndicator(
                  value: (achievement['progress'] as int) /
                      (achievement['total'] as int),
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(rarityColor),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${achievement['progress']} / ${achievement['total']}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showAchievementInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: Row(
          children: [
            const Icon(Icons.info, color: AppTheme.cyberBlue),
            const SizedBox(width: AppTheme.spacing2),
            Text(
              'Achievement Rarities',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRarityInfo('LEGENDARY', AppTheme.neonPurple, '500 XP'),
            const SizedBox(height: AppTheme.spacing1),
            _buildRarityInfo('EPIC', AppTheme.cyberBlue, '200-300 XP'),
            const SizedBox(height: AppTheme.spacing1),
            _buildRarityInfo('RARE', AppTheme.electricGreen, '100-150 XP'),
            const SizedBox(height: AppTheme.spacing1),
            _buildRarityInfo('COMMON', AppTheme.textSecondary, '50 XP'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildRarityInfo(String rarity, Color color, String xpRange) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
        ),
        const SizedBox(width: AppTheme.spacing2),
        Expanded(
          child: Text(
            rarity,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Text(
          xpRange,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
      ],
    );
  }
}
