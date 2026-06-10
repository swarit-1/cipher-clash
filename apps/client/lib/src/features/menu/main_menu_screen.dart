import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../data/progression_api.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

/// Command center: live profile summary, queue entry points, real daily
/// missions, and navigation to every feature.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({Key? key}) : super(key: key);

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _missions = const [];
  bool _missionsLoading = true;
  String? _claimingTemplate;

  @override
  void initState() {
    super.initState();
    _user = AuthService.currentUser;
    _load();
  }

  Future<void> _load() async {
    final profile = await AuthService.fetchProfile();
    if (mounted && profile != null) {
      setState(() => _user = profile);
    }
    await _loadMissions();
  }

  Future<void> _loadMissions() async {
    setState(() => _missionsLoading = true);
    var response = await ProgressionApi.activeMissions();
    var missions = _parseMissions(response.json);

    // First visit of the day: ask the missions service to deal a fresh set.
    if (response.ok && missions.isEmpty) {
      await ProgressionApi.assignDailyMissions();
      response = await ProgressionApi.activeMissions();
      missions = _parseMissions(response.json);
    }

    if (mounted) {
      setState(() {
        _missions = missions;
        _missionsLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _parseMissions(dynamic body) {
    final list = body is Map ? (body['missions'] ?? body['data']) : body;
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> _claim(Map<String, dynamic> mission) async {
    final templateId = mission['template_id'] as String?;
    if (templateId == null) return;
    setState(() => _claimingTemplate = templateId);
    final response = await ProgressionApi.claimMission(templateId);
    if (!mounted) return;
    setState(() => _claimingTemplate = null);

    if (response.ok) {
      HapticFeedback.heavyImpact();
      final rewards = response.json is Map
          ? ((response.json as Map)['rewards'] ?? response.json) as Map?
          : null;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Claimed: +${rewards?['xp'] ?? 0} XP, +${rewards?['coins'] ?? 0} coins'),
        backgroundColor: AppTheme.darkNavy,
      ));
      await _load(); // refresh coins + missions
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(response.errorMessage),
        backgroundColor: AppTheme.neonRed,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    _buildAppBar(),
                    SliverPadding(
                      padding: const EdgeInsets.all(AppTheme.spacing3),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildUserStatsCard(),
                          const SizedBox(height: AppTheme.spacing3),
                          _buildPlayButtons(),
                          const SizedBox(height: AppTheme.spacing3),
                          _buildDailyMissions(),
                          const SizedBox(height: AppTheme.spacing3),
                          _buildQuickActions(),
                        ]),
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

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      title: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppTheme.cyberBlue),
          const SizedBox(width: AppTheme.spacing1),
          Text(
            'CIPHER CLASH',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Settings',
          icon: const Icon(Icons.settings),
          onPressed: () => Navigator.pushNamed(context, '/settings'),
        ),
      ],
    );
  }

  Widget _buildUserStatsCard() {
    final user = _user ?? const {};
    final username = user['username'] as String? ?? AuthService.username ?? '…';
    final elo = user['elo_rating'] ?? '—';
    final tier = user['rank_tier'] as String? ?? 'UNRANKED';
    final level = user['level'] ?? 1;
    final wins = user['wins'] ?? 0;
    final losses = user['losses'] ?? 0;
    final coins = user['coins'] ?? 0;

    return GlowCard(
      glowVariant: GlowCardVariant.primary,
      onTap: () => Navigator.pushNamed(context, '/profile'),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: AppTheme.glowCyberBlue(intensity: 0.8),
            ),
            child: Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 28,
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$tier · Level $level · 🪙 $coins',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$elo',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppTheme.electricGreen,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'monospace',
                    ),
              ),
              Text(
                '${wins}W · ${losses}L',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textTertiary,
                    ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPlayButtons() {
    return Column(
      children: [
        CyberpunkButton(
          label: 'RANKED MATCH',
          onPressed: () {
            HapticFeedback.heavyImpact();
            Navigator.pushNamed(context, '/queue',
                arguments: {'mode': 'RANKED_1V1'});
          },
          icon: Icons.emoji_events,
          fullWidth: true,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
        ),
        const SizedBox(height: AppTheme.spacing1),
        Row(
          children: [
            Expanded(
              child: CyberpunkButton(
                label: 'VS BOT',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/queue',
                      arguments: {'mode': 'BOT_MATCH'});
                },
                variant: CyberpunkButtonVariant.secondary,
                icon: Icons.smart_toy,
                fullWidth: true,
              ),
            ),
            const SizedBox(width: AppTheme.spacing1),
            Expanded(
              child: CyberpunkButton(
                label: 'CASUAL',
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/queue',
                      arguments: {'mode': 'CASUAL_1V1'});
                },
                variant: CyberpunkButtonVariant.secondary,
                icon: Icons.sports_esports,
                fullWidth: true,
              ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildDailyMissions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'DAILY MISSIONS',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: AppTheme.textSecondary,
                  ),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Refresh missions',
              iconSize: 18,
              icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
              onPressed: _missionsLoading ? null : _loadMissions,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing1),
        if (_missionsLoading)
          const Padding(
            padding: EdgeInsets.all(AppTheme.spacing2),
            child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))),
          )
        else if (_missions.isEmpty)
          GlowCard(
            glowVariant: GlowCardVariant.none,
            child: Row(
              children: [
                const Icon(Icons.assignment_turned_in,
                    color: AppTheme.textTertiary),
                const SizedBox(width: AppTheme.spacing1),
                Expanded(
                  child: Text(
                    'No missions available right now — play a match and check back.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          )
        else
          ..._missions.map(_buildMissionCard),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildMissionCard(Map<String, dynamic> mission) {
    final template = (mission['template'] as Map?)?.cast<String, dynamic>();
    final title = template?['title'] as String? ?? mission['template_id'];
    final icon = template?['icon'] as String? ?? '🎯';
    final progress = (mission['progress'] as num?)?.toInt() ?? 0;
    final target = (mission['target'] as num?)?.toInt() ?? 1;
    final status = mission['status'] as String? ?? 'active';
    final completed = status == 'completed';
    final claimed = status == 'claimed';
    final pct = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;
    final claiming = _claimingTemplate == mission['template_id'];

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: completed ? GlowCardVariant.success : GlowCardVariant.none,
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title ?? 'Mission',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusSmall),
                          child: LinearProgressIndicator(
                            value: pct,
                            minHeight: 6,
                            backgroundColor: AppTheme.surfaceVariant,
                            valueColor: AlwaysStoppedAnimation(completed
                                ? AppTheme.electricGreen
                                : AppTheme.cyberBlue),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing1),
                      Text(
                        '$progress/$target',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontFamily: 'monospace',
                              color: AppTheme.textTertiary,
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing1),
            if (claimed)
              const Icon(Icons.check_circle, color: AppTheme.textTertiary)
            else if (completed)
              TextButton(
                onPressed: claiming ? null : () => _claim(mission),
                child: claiming
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('CLAIM',
                        style: TextStyle(
                            color: AppTheme.electricGreen,
                            fontWeight: FontWeight.w900)),
              )
            else
              Text(
                '+${template?['xp_reward'] ?? 0} XP',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.electricYellow,
                      fontWeight: FontWeight.w700,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final actions = [
      ('PRACTICE', Icons.fitness_center, '/practice'),
      ('TUTORIAL', Icons.school, '/tutorial'),
      ('LEADERBOARD', Icons.leaderboard, '/leaderboard'),
      ('ACHIEVEMENTS', Icons.emoji_events, '/achievements'),
      ('SHOP', Icons.storefront, '/shop'),
      ('FRIENDS', Icons.group, '/social'),
      ('PROFILE', Icons.person, '/profile'),
      ('SPECTATE', Icons.visibility, '/spectate'),
      ('CODEX', Icons.menu_book, '/codex'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OPERATIONS',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
                color: AppTheme.textSecondary,
              ),
        ),
        const SizedBox(height: AppTheme.spacing1),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: AppTheme.spacing1,
            crossAxisSpacing: AppTheme.spacing1,
            childAspectRatio: 1.7,
          ),
          itemCount: actions.length,
          itemBuilder: (context, index) {
            final (label, icon, route) = actions[index];
            return GlowCard(
              glowVariant: GlowCardVariant.none,
              onTap: () {
                HapticFeedback.selectionClick();
                Navigator.pushNamed(context, route);
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppTheme.cyberBlue, size: 26),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ).animate().fadeIn(delay: (40 * index).ms);
          },
        ),
      ],
    );
  }
}
