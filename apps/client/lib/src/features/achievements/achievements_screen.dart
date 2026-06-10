import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/progression_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Achievement gallery backed by the achievement service: real progress,
/// unlock state, rarity, and XP rewards.
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _achievements = const [];
  String _filter = 'ALL';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final response = await ProgressionApi.achievements();
    if (!mounted) return;
    if (!response.ok || response.json is! Map) {
      setState(() {
        _loading = false;
        _error = response.errorMessage;
      });
      return;
    }
    final list = (response.json as Map)['achievements'];
    final parsed = list is List
        ? list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
        : <Map<String, dynamic>>[];
    parsed.sort((a, b) {
      final ua = a['unlocked'] == true ? 0 : 1;
      final ub = b['unlocked'] == true ? 0 : 1;
      if (ua != ub) return ua - ub;
      return _rarityRank(a['rarity']) - _rarityRank(b['rarity']);
    });
    setState(() {
      _loading = false;
      _achievements = parsed;
    });
  }

  int _rarityRank(dynamic rarity) {
    switch (rarity) {
      case 'LEGENDARY':
        return 0;
      case 'EPIC':
        return 1;
      case 'RARE':
        return 2;
      default:
        return 3;
    }
  }

  Color _rarityColor(dynamic rarity) {
    switch (rarity) {
      case 'LEGENDARY':
        return AppTheme.electricYellow;
      case 'EPIC':
        return AppTheme.neonPurple;
      case 'RARE':
        return AppTheme.cyberBlue;
      default:
        return AppTheme.textSecondary;
    }
  }

  List<Map<String, dynamic>> get _filtered {
    switch (_filter) {
      case 'UNLOCKED':
        return _achievements.where((a) => a['unlocked'] == true).toList();
      case 'LOCKED':
        return _achievements.where((a) => a['unlocked'] != true).toList();
      default:
        return _achievements;
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked =
        _achievements.where((a) => a['unlocked'] == true).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        actions: [
          if (_achievements.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppTheme.spacing2),
                child: Text(
                  '$unlocked / ${_achievements.length}',
                  style: const TextStyle(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                children: [
                  _buildFilterChips(),
                  Expanded(
                    child: AsyncView(
                      loading: _loading,
                      error: _error,
                      onRetry: _load,
                      empty: _filtered.isEmpty,
                      emptyIcon: Icons.emoji_events,
                      emptyTitle: 'No achievements here',
                      emptyMessage:
                          'Win matches and solve ciphers to start unlocking.',
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppTheme.spacing2),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) =>
                              _buildAchievement(_filtered[index], index),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    const filters = ['ALL', 'UNLOCKED', 'LOCKED'];
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Row(
        children: filters.map((f) {
          final selected = _filter == f;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing1),
            child: ChoiceChip(
              label: Text(f),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f),
              selectedColor: AppTheme.cyberBlue.withValues(alpha: 0.25),
              labelStyle: TextStyle(
                color: selected ? AppTheme.cyberBlue : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAchievement(Map<String, dynamic> a, int index) {
    final unlocked = a['unlocked'] == true;
    final rarity = a['rarity'] as String? ?? 'COMMON';
    final color = _rarityColor(rarity);
    final progress = (a['progress'] as num?)?.toInt() ?? 0;
    final total = (a['total'] as num?)?.toInt() ?? 1;
    final pct = total > 0 ? (progress / total).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: Opacity(
        opacity: unlocked ? 1 : 0.75,
        child: GlowCard(
          glowVariant:
              unlocked ? GlowCardVariant.success : GlowCardVariant.none,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: unlocked ? 0.2 : 0.08),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                  border: Border.all(
                      color: color.withValues(alpha: unlocked ? 0.8 : 0.3)),
                ),
                child: Center(
                  child: unlocked
                      ? Text(a['icon'] as String? ?? '🏆',
                          style: const TextStyle(fontSize: 26))
                      : const Icon(Icons.lock,
                          color: AppTheme.textTertiary, size: 24),
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            a['name'] as String? ?? '???',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                          ),
                          child: Text(
                            rarity,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      a['description'] as String? ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusSmall),
                            child: LinearProgressIndicator(
                              value: unlocked ? 1 : pct,
                              minHeight: 6,
                              backgroundColor: AppTheme.surfaceVariant,
                              valueColor: AlwaysStoppedAnimation(
                                  unlocked ? AppTheme.electricGreen : color),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing1),
                        Text(
                          unlocked ? 'DONE' : '$progress/$total',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: unlocked
                                    ? AppTheme.electricGreen
                                    : AppTheme.textTertiary,
                                fontFamily: 'monospace',
                              ),
                        ),
                        const SizedBox(width: AppTheme.spacing1),
                        Text(
                          '+${a['xp_reward'] ?? 0} XP',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: AppTheme.electricYellow,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(delay: (40 * (index % 12)).ms),
    );
  }
}
