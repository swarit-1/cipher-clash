import '../core/api_client.dart';
import '../core/env.dart';
import 'match_models.dart';

/// Matchmaking + match REST endpoints (matchmaker and game services).
class MatchmakingApi {
  MatchmakingApi._();

  /// Joins the queue for [gameMode]. Identity comes from the JWT.
  static Future<ApiResponse> joinQueue(String gameMode) {
    return Api.client.post('${Env.matchmakerUrl}/matchmaker/join',
        body: {'game_mode': gameMode});
  }

  static Future<ApiResponse> leaveQueue() {
    return Api.client.post('${Env.matchmakerUrl}/matchmaker/leave');
  }

  /// Polls matchmaking state: {status: searching|match_found|idle, ...}.
  static Future<ApiResponse> queueStatus() {
    return Api.client.get('${Env.matchmakerUrl}/matchmaker/status');
  }

  static Future<ApiResponse> leaderboard({int limit = 50, String region = ''}) {
    final query = region.isEmpty ? '' : '&region=$region';
    return Api.client.get(
        '${Env.matchmakerUrl}/matchmaker/leaderboard?limit=$limit$query',
        auth: false);
  }

  /// Creates an on-demand bot match; returns [MatchArgs] on success.
  static Future<MatchArgs?> createBotMatch() async {
    final response = await Api.client.post('${Env.gameUrl}/match/bot');
    if (!response.ok || response.json is! Map) return null;
    final data = (response.json as Map).cast<String, dynamic>();
    final opponent = (data['opponent'] as Map?)?.cast<String, dynamic>();
    return MatchArgs(
      matchId: data['match_id'] as String? ?? '',
      gameMode: data['game_mode'] as String? ?? 'BOT_MATCH',
      isRanked: data['is_ranked'] as bool? ?? false,
      opponentUsername: opponent?['username'] as String?,
      opponentElo: (opponent?['elo'] as num?)?.toInt(),
      opponentIsBot: true,
    );
  }

  static Future<ApiResponse> matchHistory({int limit = 20}) {
    return Api.client.get('${Env.gameUrl}/matches/history?limit=$limit');
  }

  static Future<ApiResponse> replay(String matchId) {
    return Api.client
        .get('${Env.gameUrl}/matches/replay?match_id=$matchId', auth: false);
  }

  static Future<ApiResponse> liveMatches() {
    return Api.client.get('${Env.gameUrl}/matches/live', auth: false);
  }
}
