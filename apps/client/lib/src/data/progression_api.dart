import '../core/api_client.dart';
import '../core/env.dart';
import '../core/token_store.dart';

/// REST wrappers for the progression services: achievements, missions,
/// mastery, social, and cosmetics.
class ProgressionApi {
  ProgressionApi._();

  static String get _uid => TokenStore.userId ?? '';

  // ── Achievements ──────────────────────────────────────────────────────────

  static Future<ApiResponse> achievements() =>
      Api.client.get('${Env.achievementUrl}/user/achievements');

  static Future<ApiResponse> achievementStats() =>
      Api.client.get('${Env.achievementUrl}/user/achievements/stats');

  // ── Missions ──────────────────────────────────────────────────────────────

  static Future<ApiResponse> activeMissions() =>
      Api.client.get('${Env.missionsUrl}/missions/user/$_uid/active');

  static Future<ApiResponse> assignDailyMissions() =>
      Api.client.post('${Env.missionsUrl}/missions/assign',
          body: {'user_id': _uid});

  static Future<ApiResponse> claimMission(String templateId) =>
      Api.client.post('${Env.missionsUrl}/missions/claim',
          body: {'user_id': _uid, 'template_id': templateId});

  // ── Mastery ───────────────────────────────────────────────────────────────

  static Future<ApiResponse> masteryPoints() =>
      Api.client.get('${Env.masteryUrl}/mastery/points/$_uid');

  // ── Social ────────────────────────────────────────────────────────────────

  static Future<ApiResponse> friends() =>
      Api.client.get('${Env.socialUrl}/friends/$_uid');

  static Future<ApiResponse> pendingRequests() =>
      Api.client.get('${Env.socialUrl}/friends/pending/$_uid');

  static Future<ApiResponse> lookupUser(String username) => Api.client
      .get('${Env.authUrl}/auth/users/lookup?username=${Uri.encodeQueryComponent(username)}');

  static Future<ApiResponse> sendFriendRequest(String toUserId) =>
      Api.client.post('${Env.socialUrl}/friends/request',
          body: {'from_user_id': _uid, 'to_user_id': toUserId});

  static Future<ApiResponse> acceptFriendRequest(String friendId) =>
      Api.client.post('${Env.socialUrl}/friends/accept',
          body: {'user_id': _uid, 'friend_id': friendId});

  static Future<ApiResponse> sendMatchInvite(String toUserId,
          {String gameMode = 'CASUAL_1V1'}) =>
      Api.client.post('${Env.socialUrl}/invites/send', body: {
        'from_user_id': _uid,
        'to_user_id': toUserId,
        'game_mode': gameMode,
      });

  static Future<ApiResponse> invites() =>
      Api.client.get('${Env.socialUrl}/invites/$_uid');

  static Future<ApiResponse> acceptInvite(String inviteId) =>
      Api.client.post('${Env.socialUrl}/invites/accept',
          body: {'invite_id': inviteId});

  static Future<ApiResponse> rejectInvite(String inviteId) =>
      Api.client.post('${Env.socialUrl}/invites/reject',
          body: {'invite_id': inviteId});

  // ── Cosmetics ─────────────────────────────────────────────────────────────

  static Future<ApiResponse> cosmeticsCatalog() =>
      Api.client.get('${Env.cosmeticsUrl}/cosmetics/catalog', auth: false);

  static Future<ApiResponse> cosmeticsInventory() =>
      Api.client.get('${Env.cosmeticsUrl}/cosmetics/inventory/$_uid');

  static Future<ApiResponse> purchaseCosmetic(String cosmeticId) =>
      Api.client.post('${Env.cosmeticsUrl}/cosmetics/purchase',
          body: {'user_id': _uid, 'cosmetic_id': cosmeticId});

  static Future<ApiResponse> equipCosmetic(String cosmeticId) =>
      Api.client.post('${Env.cosmeticsUrl}/cosmetics/loadout/equip',
          body: {'user_id': _uid, 'cosmetic_id': cosmeticId});
}
