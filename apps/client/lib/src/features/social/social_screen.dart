import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/token_store.dart';
import '../../data/match_models.dart';
import '../../data/matchmaking_api.dart';
import '../../data/progression_api.dart';
import '../../theme/app_theme.dart';
import '../../widgets/async_view.dart';
import '../../widgets/glow_card.dart';

/// Friends and match invites. Accepting an invite creates a real match on
/// the backend; both players are routed into it.
class SocialScreen extends StatefulWidget {
  const SocialScreen({Key? key}) : super(key: key);

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _friends = const [];
  List<Map<String, dynamic>> _pending = const [];
  List<Map<String, dynamic>> _invites = const [];
  final Map<String, String> _usernames = {}; // user_id -> username
  final _searchController = TextEditingController();
  bool _searching = false;
  Timer? _invitePoll;

  @override
  void initState() {
    super.initState();
    _load();
    // Poll invites so a challenged player sees the invite arrive.
    _invitePoll = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_loading) _loadInvites();
    });
  }

  @override
  void dispose() {
    _invitePoll?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseList(dynamic body, List<String> keys) {
    dynamic list = body;
    if (body is Map) {
      for (final key in keys) {
        if (body[key] is List) {
          list = body[key];
          break;
        }
      }
    }
    if (list is! List) return const [];
    return list.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final friendsResp = await ProgressionApi.friends();
    final pendingResp = await ProgressionApi.pendingRequests();
    if (!mounted) return;

    if (!friendsResp.ok && friendsResp.status != 404) {
      setState(() {
        _loading = false;
        _error = friendsResp.errorMessage;
      });
      return;
    }

    _friends = _parseList(friendsResp.json, ['friends', 'friendships', 'data']);
    _pending = _parseList(pendingResp.json, ['requests', 'pending', 'data']);
    await _loadInvites();
    await _resolveUsernames();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadInvites() async {
    final invitesResp = await ProgressionApi.invites();
    if (!mounted) return;
    setState(() {
      _invites = _parseList(invitesResp.json, ['invites', 'data']);
    });
  }

  /// The social service returns user ids; show usernames where we can.
  Future<void> _resolveUsernames() async {
    final ids = <String>{};
    for (final f in _friends) {
      ids.add(f['user1_id'] as String? ?? '');
      ids.add(f['user2_id'] as String? ?? '');
    }
    for (final p in _pending) {
      ids.add(p['user1_id'] as String? ?? '');
    }
    for (final i in _invites) {
      ids.add(i['from_user_id'] as String? ?? '');
    }
    ids.removeWhere((id) => id.isEmpty || _usernames.containsKey(id));
    // No bulk lookup endpoint; ids resolve lazily as rows render.
  }

  String _displayName(String? userId) {
    if (userId == null || userId.isEmpty) return '???';
    if (userId == TokenStore.userId) return 'You';
    return _usernames[userId] ?? '${userId.substring(0, 8)}…';
  }

  Future<void> _addFriend() async {
    final username = _searchController.text.trim();
    if (username.isEmpty) return;
    setState(() => _searching = true);

    final lookup = await ProgressionApi.lookupUser(username);
    if (!mounted) return;
    if (!lookup.ok || lookup.json is! Map) {
      setState(() => _searching = false);
      _toast('No operator named "$username" found', error: true);
      return;
    }
    final target = (lookup.json as Map).cast<String, dynamic>();
    final targetId = target['id'] as String?;
    if (targetId == null || targetId == TokenStore.userId) {
      setState(() => _searching = false);
      _toast('That is you.', error: true);
      return;
    }
    _usernames[targetId] = target['username'] as String? ?? username;

    final response = await ProgressionApi.sendFriendRequest(targetId);
    if (!mounted) return;
    setState(() => _searching = false);
    if (response.ok) {
      _toast('Friend request sent to $username');
      _searchController.clear();
      _load();
    } else {
      _toast(response.errorMessage, error: true);
    }
  }

  Future<void> _challenge(String userId) async {
    final response = await ProgressionApi.sendMatchInvite(userId);
    if (!mounted) return;
    if (response.ok) {
      _toast('Challenge sent — waiting for them to accept. '
          'You will be pulled in automatically.');
      _watchForMatch();
    } else {
      _toast(response.errorMessage, error: true);
    }
  }

  /// After challenging (or accepting), the matchmaker status poll surfaces
  /// the created match for both sides.
  void _watchForMatch() {
    int attempts = 0;
    Timer.periodic(const Duration(seconds: 2), (t) async {
      attempts++;
      if (!mounted || attempts > 45) {
        t.cancel();
        return;
      }
      final status = await _queueStatus();
      if (status != null && status['status'] == 'match_found') {
        t.cancel();
        if (!mounted) return;
        final opponent =
            (status['opponent'] as Map?)?.cast<String, dynamic>();
        Navigator.pushNamed(context, '/game',
            arguments: MatchArgs(
              matchId: status['match_id'] as String? ?? '',
              gameMode: status['game_mode'] as String? ?? 'CASUAL_1V1',
              isRanked: status['is_ranked'] as bool? ?? false,
              opponentUsername: opponent?['username'] as String?,
              opponentElo: (opponent?['elo'] as num?)?.toInt(),
            ));
      }
    });
  }

  Future<Map<String, dynamic>?> _queueStatus() async {
    final response = await MatchmakingApi.queueStatus();
    if (response.ok && response.json is Map) {
      return (response.json as Map).cast<String, dynamic>();
    }
    return null;
  }

  Future<void> _acceptInvite(Map<String, dynamic> invite) async {
    final response =
        await ProgressionApi.acceptInvite(invite['id'] as String? ?? '');
    if (!mounted) return;
    if (response.ok) {
      _toast('Challenge accepted — entering the arena…');
      _watchForMatch();
    } else {
      _toast(response.errorMessage, error: true);
    }
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppTheme.neonRed : AppTheme.darkNavy,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
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
              child: AsyncView(
                loading: _loading,
                error: _error,
                onRetry: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppTheme.spacing2),
                  children: [
                    _buildAddFriend(),
                    const SizedBox(height: AppTheme.spacing3),
                    if (_invites.isNotEmpty) ...[
                      _sectionTitle('INCOMING CHALLENGES'),
                      ..._invites.map(_buildInviteCard),
                      const SizedBox(height: AppTheme.spacing2),
                    ],
                    if (_pending.isNotEmpty) ...[
                      _sectionTitle('FRIEND REQUESTS'),
                      ..._pending.map(_buildPendingCard),
                      const SizedBox(height: AppTheme.spacing2),
                    ],
                    _sectionTitle('FRIENDS'),
                    if (_friends.isEmpty)
                      const AsyncView(
                        loading: false,
                        empty: true,
                        emptyIcon: Icons.group_add,
                        emptyTitle: 'No friends yet',
                        emptyMessage:
                            'Add an operator by username to challenge them.',
                        child: SizedBox.shrink(),
                      )
                    else
                      ..._friends.map(_buildFriendCard),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
              color: AppTheme.textSecondary,
            ),
      ),
    );
  }

  Widget _buildAddFriend() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _addFriend(),
            decoration: const InputDecoration(
              labelText: 'Add friend by username',
              prefixIcon: Icon(Icons.person_search),
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing1),
        FilledButton.icon(
          onPressed: _searching ? null : _addFriend,
          icon: _searching
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.person_add),
          label: const Text('ADD'),
        ),
      ],
    );
  }

  Widget _buildInviteCard(Map<String, dynamic> invite) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: GlowCardVariant.primary,
        child: Row(
          children: [
            const Icon(Icons.sports_kabaddi, color: AppTheme.cyberBlue),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Text(
                '${_displayName(invite['from_user_id'] as String?)} challenges you'
                ' (${invite['game_mode'] ?? 'CASUAL_1V1'})',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => _acceptInvite(invite),
              child: const Text('ACCEPT',
                  style: TextStyle(
                      color: AppTheme.electricGreen,
                      fontWeight: FontWeight.w900)),
            ),
            TextButton(
              onPressed: () async {
                await ProgressionApi.rejectInvite(
                    invite['id'] as String? ?? '');
                _loadInvites();
              },
              child: const Text('DECLINE',
                  style: TextStyle(color: AppTheme.neonRed)),
            ),
          ],
        ),
      ).animate().fadeIn(),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> request) {
    final fromId = request['user1_id'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: GlowCardVariant.none,
        child: Row(
          children: [
            const Icon(Icons.person_add, color: AppTheme.neonPurple),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Text(
                '${_displayName(fromId)} wants to be friends',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            TextButton(
              onPressed: () async {
                final response =
                    await ProgressionApi.acceptFriendRequest(fromId ?? '');
                if (response.ok) _load();
              },
              child: const Text('ACCEPT',
                  style: TextStyle(
                      color: AppTheme.electricGreen,
                      fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(Map<String, dynamic> friendship) {
    final me = TokenStore.userId;
    final otherId = friendship['user1_id'] == me
        ? friendship['user2_id'] as String?
        : friendship['user1_id'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing1),
      child: GlowCard(
        glowVariant: GlowCardVariant.none,
        child: Row(
          children: [
            const Icon(Icons.person, color: AppTheme.cyberBlue),
            const SizedBox(width: AppTheme.spacing2),
            Expanded(
              child: Text(
                _displayName(otherId),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: otherId == null ? null : () => _challenge(otherId),
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('CHALLENGE'),
            ),
          ],
        ),
      ),
    );
  }
}
