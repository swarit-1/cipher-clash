import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class MatchmakerService {
  // Join matchmaking queue
  static Future<Map<String, dynamic>> joinQueue({
    required String gameMode,
  }) async {
    if (AuthService.userId == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.matchmakerBaseUrl}/matchmaker/join'),
            headers: AuthService.getAuthHeaders(),
            body: jsonEncode({
              'user_id': AuthService.userId,
              'username': AuthService.username,
              'elo': 1500, // TODO: Get from user profile
              'game_mode': gameMode,
            }),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Joined queue',
          'queue_position': data['queue_position'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to join queue'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Leave matchmaking queue
  static Future<Map<String, dynamic>> leaveQueue() async {
    if (AuthService.userId == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.matchmakerBaseUrl}/matchmaker/leave'),
            headers: AuthService.getAuthHeaders(),
            body: jsonEncode({'user_id': AuthService.userId}),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'message': data['message'] ?? 'Left queue',
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to leave queue'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get queue status
  static Future<Map<String, dynamic>> getQueueStatus() async {
    if (AuthService.userId == null) {
      return {'success': false, 'message': 'Not authenticated'};
    }

    try {
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.matchmakerBaseUrl}/matchmaker/status/${AuthService.userId}'),
            headers: AuthService.getAuthHeaders(),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'in_queue': data['in_queue'] ?? false,
          'queue_position': data['queue_position'] ?? 0,
          'estimated_wait': data['estimated_wait'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to get status'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get leaderboard
  static Future<List<Map<String, dynamic>>> getLeaderboard({
    int limit = 50,
  }) async {
    try {
      final response = await http
          .get(
            Uri.parse(
                '${ApiConfig.matchmakerBaseUrl}/matchmaker/leaderboard?limit=$limit'),
            headers: AuthService.getAuthHeaders(),
          )
          .timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['leaderboard'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
