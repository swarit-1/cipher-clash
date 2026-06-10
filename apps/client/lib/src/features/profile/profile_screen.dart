import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/matchmaking_api.dart';
import '../../data/progression_api.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Operator profile: real account stats, match history from the game
/// service, and per-cipher mastery progression.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _matches = const [];
  List<Map<String, dynamic>> _mastery = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final profile = await AuthService.fetchProfile();
    if (!mounted) return;
    if (profile == null) {
      setState(() {
        _loading = false;
        _error = 'Could not load your profile';
      });
      return;
    }

    final historyResponse = await MatchmakingApi.matchHistory(limit: 20);
    final masteryResponse = await ProgressionApi.masteryPoints();
    if (!mounted) return;

    List<Map<String, dynamic>> matches = const [];
    if (historyResponse.ok && historyResponse.json is Map) {
      final list = (historyResponse.json as Map)['matches'];
      if (list is List) {
        matches = list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    List<Map<String, dynamic>> mastery = const [];
    if (masteryResponse.ok) {
      final body = masteryResponse.json;
      final list = body is Map
          ? (body['points'] ?? body['data'] ?? body['mastery'])
          : body;
      if (list is List) {
        mastery = list
            .whereType<Map>()
            .map((e) => e.cast<String, dynamic>())
            .toList();
      }
    }

    setState(() {
      _loading = false;
      _user = profile;
      _matches = matches;
      _mastery = mastery;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await AuthService.logout();
              if (context.mounted) {
                Navigator.pushNamedAndRemoveUntil(
                    context, '/login', (route) => false);
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: AsyncView(
            loading: _loading,
            error: _error,
            onRetry: _load,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  children: [
                    _buildHeader(),
                    TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.cyberBlue,
                      unselectedLabelColor: AppTheme.textSecondary,
                      indicatorColor: AppTheme.cyberBlue,
                      tabs: const [
                        Tab(text: 'STATS'),
                        Tab(text: 'MATCHES'),
                        Tab(text: 'MASTERY'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildStatsTab(),
                          _buildMatchesTab(),
                          _buildMasteryTab(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final user = _user ?? const {};
    final username = user['username'] as String? ?? '???';
    final elo = user['elo_rating'] ?? 1200;
    final tier = user['rank_tier'] as String? ?? 'UNRANKED';
    final level = user['level'] ?? 1;
    final coins = user['coins'] ?? 0;
    final title = user['title'] as String?;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: GlowCard(
        glowVariant: GlowCardVariant.primary,
        child: Row(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.primaryGradient,
                boxShadow: AppTheme.glowCyberBlue(intensity: 1.0),
              ),
              child: Center(
                child: Text(
                  username.isNotEmpty ? username[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    username,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  if (title != null && title.isNotEmpty)
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.neonPurple,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: AppTheme.spacing1,
                    runSpacing: 4,
                    children: [
                      _chip('$elo ELO', AppTheme.electricGreen),
                      _chip(tier, AppTheme.cyberBlue),
                      _chip('LVL $level', AppTheme.neonPurple),
                      _chip('🪙 $coins', AppTheme.electricYellow),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStatsTab() {
    final user = _user ?? const {};
    final totalGames = (user['total_games'] as num?)?.toInt() ?? 0;
    final wins = (user['wins'] as num?)?.toInt() ?? 0;
    final losses = (user['losses'] as num?)?.toInt() ?? 0;
    final winRate =
        totalGames > 0 ? (wins / totalGames * 100).toStringAsFixed(1) : '—';
    final fastest = (user['fastest_solve_ms'] as num?)?.toInt();

    final stats = [
      ('Matches Played', '$totalGames', Icons.sports_esports),
      ('Wins', '$wins', Icons.emoji_events),
      ('Losses', '$losses', Icons.close),
      ('Win Rate', '$winRate%', Icons.percent),
      (
        'Current Streak',
        '${user['win_streak'] ?? 0}',
        Icons.local_fire_department
      ),
      ('Best Streak', '${user['best_win_streak'] ?? 0}', Icons.whatshot),
      ('Puzzles Solved', '${user['puzzles_solved'] ?? 0}', Icons.extension),
      (
        'Fastest Solve',
        fastest != null && fastest > 0
            ? '${(fastest / 1000).toStringAsFixed(1)}s'
            : '—',
        Icons.bolt
      ),
      ('XP', '${user['xp'] ?? 0}', Icons.star),
      ('Region', '${user['region'] ?? '—'}', Icons.public),
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisSpacing: AppTheme.spacing1,
        crossAxisSpacing: AppTheme.spacing1,
        childAspectRatio: 1.8,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) {
        final (label, value, icon) = stats[index];
        return GlowCard(
          glowVariant: GlowCardVariant.none,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: AppTheme.cyberBlue),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
              ),
            ],
          ),
        ).animate().fadeIn(delay: (30 * index).ms);
      },
    );
  }

  Widget _buildMatchesTab() {
    if (_matches.isEmpty) {
      return const AsyncView(
        loading: false,
        empty: true,
        emptyIcon: Icons.history,
        emptyTitle: 'No matches yet',
        emptyMessage: 'Your completed matches will appear here.',
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      itemCount: _matches.length,
      itemBuilder: (context, index) {
        final match = _matches[index];
        final won = match['won'] == true;
        final draw = (match['winner_id'] as String? ?? '').isEmpty;
        final eloChange = (match['elo_change'] as num?)?.toInt() ?? 0;
        final color = draw
            ? AppTheme.electricYellow
            : (won ? AppTheme.electricGreen : AppTheme.neonRed);
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
          child: GlowCard(
            glowVariant: GlowCardVariant.none,
            onTap: match['has_replay'] == true
                ? () => Navigator.pushNamed(context, '/replay',
                    arguments: match['match_id'])
                : null,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Center(
                    child: Text(
                      draw ? '=' : (won ? 'W' : 'L'),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'vs ${match['opponent_username'] ?? '???'}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        '${match['game_mode'] ?? ''} · '
                        '${match['your_score'] ?? 0}-${match['opponent_score'] ?? 0}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ),
                if (eloChange != 0)
                  Text(
                    '${eloChange > 0 ? '+' : ''}$eloChange',
                    style: TextStyle(
                      color: eloChange > 0
                          ? AppTheme.electricGreen
                          : AppTheme.neonRed,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
                  ),
                if (match['has_replay'] == true) ...[
                  const SizedBox(width: AppTheme.spacing1),
                  const Icon(Icons.play_circle_outline,
                      color: AppTheme.cyberBlue, size: 20),
                ],
              ],
            ),
          ),
        ).animate().fadeIn(delay: (30 * (index % 10)).ms);
      },
    );
  }

  Widget _buildMasteryTab() {
    if (_mastery.isEmpty) {
      return const AsyncView(
        loading: false,
        empty: true,
        emptyIcon: Icons.auto_graph,
        emptyTitle: 'No cipher mastery yet',
        emptyMessage:
            'Solve puzzles in matches to earn per-cipher mastery XP.',
        child: SizedBox.shrink(),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      itemCount: _mastery.length,
      itemBuilder: (context, index) {
        final m = _mastery[index];
        final level = (m['level'] as num?)?.toInt() ?? 1;
        final points = (m['total_points'] as num?)?.toInt() ?? 0;
        final solved = (m['puzzles_solved'] as num?)?.toInt() ?? 0;
        final intoLevel = points % 100;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
          child: GlowCard(
            glowVariant: GlowCardVariant.none,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      m['cipher_type'] as String? ?? '???',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                    ),
                    const Spacer(),
                    _chip('LVL $level', AppTheme.neonPurple),
                    const SizedBox(width: AppTheme.spacing1),
                    _chip('$solved solved', AppTheme.cyberBlue),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: LinearProgressIndicator(
                    value: intoLevel / 100,
                    minHeight: 6,
                    backgroundColor: AppTheme.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation(AppTheme.neonPurple),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$intoLevel / 100 XP to level ${level + 1}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textTertiary,
                      ),
                ),
              ],
            ),
          ),
        ).animate().fadeIn(delay: (30 * (index % 10)).ms);
      },
    );
  }
}
