import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/token_store.dart';
import '../../data/matchmaking_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Global ELO leaderboard backed by the matchmaker service.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _entries = const [];
  String _region = '';

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
    final response =
        await MatchmakingApi.leaderboard(limit: 50, region: _region);
    if (!mounted) return;
    if (!response.ok || response.json is! Map) {
      setState(() {
        _loading = false;
        _error = response.errorMessage;
      });
      return;
    }
    final list = (response.json as Map)['entries'];
    setState(() {
      _loading = false;
      _entries = list is List
          ? list
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList()
          : const [];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leaderboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
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
                  _buildRegionTabs(),
                  Expanded(
                    child: AsyncView(
                      loading: _loading,
                      error: _error,
                      onRetry: _load,
                      empty: _entries.isEmpty,
                      emptyIcon: Icons.leaderboard,
                      emptyTitle: 'No ranked players yet',
                      emptyMessage:
                          'Play a ranked match to claim the first spot on the board.',
                      child: RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(AppTheme.spacing2),
                          children: [
                            if (_entries.length >= 3) _buildPodium(),
                            const SizedBox(height: AppTheme.spacing2),
                            if (_entries.length >= 3)
                              ..._entries.skip(3).map(_buildRow)
                            else
                              ..._entries.map(_buildRow),
                          ],
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

  Widget _buildRegionTabs() {
    const regions = ['', 'US', 'EU', 'ASIA'];
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Row(
        children: regions.map((r) {
          final selected = _region == r;
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spacing1),
            child: ChoiceChip(
              label: Text(r.isEmpty ? 'GLOBAL' : r),
              selected: selected,
              onSelected: (_) {
                setState(() => _region = r);
                _load();
              },
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

  Widget _buildPodium() {
    final first = _entries[0];
    final second = _entries[1];
    final third = _entries[2];
    return SizedBox(
      height: 210,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
              child: _podiumColumn(second, 2, 130, const Color(0xFFC0C0C0))),
          const SizedBox(width: AppTheme.spacing1),
          Expanded(
              child: _podiumColumn(first, 1, 170, AppTheme.electricYellow)),
          const SizedBox(width: AppTheme.spacing1),
          Expanded(child: _podiumColumn(third, 3, 105, AppTheme.bronzeBrown)),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _podiumColumn(
      Map<String, dynamic> entry, int place, double height, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          entry['username'] as String? ?? '???',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          '${entry['elo_rating'] ?? '—'}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
              ),
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withValues(alpha: 0.55),
                color.withValues(alpha: 0.12)
              ],
            ),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppTheme.radiusMedium)),
            border: Border.all(color: color.withValues(alpha: 0.6)),
          ),
          child: Center(
            child: Text(
              '$place',
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRow(Map<String, dynamic> entry) {
    final isYou = entry['user_id'] == TokenStore.userId;
    final rank = entry['rank'] ?? '—';
    final winRate = entry['win_rate'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: isYou ? GlowCardVariant.primary : GlowCardVariant.none,
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                '#$rank',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontFamily: 'monospace',
                    ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry['username'] ?? '???'}${isYou ? '  (you)' : ''}',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              isYou ? AppTheme.cyberBlue : AppTheme.textPrimary,
                        ),
                  ),
                  Text(
                    '${entry['rank_tier'] ?? 'UNRANKED'} · ${entry['wins'] ?? 0}W ${entry['losses'] ?? 0}L'
                    '${winRate != null ? ' · $winRate%' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textTertiary,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              '${entry['elo_rating'] ?? '—'}',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.electricGreen,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
