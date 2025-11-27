import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class PracticeService {
  static Map<String, String> _getHeaders() {
    final token = AuthService.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Generate a practice puzzle
  static Future<Map<String, dynamic>> generatePuzzle({
    required String cipherType,
    required int difficulty,
    String mode = 'UNTIMED',
    int? timeLimitSeconds,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.practiceBaseUrl}/practice/generate'),
        headers: _getHeaders(),
        body: jsonEncode({
          'cipher_type': cipherType,
          'difficulty': difficulty,
          'mode': mode,
          if (timeLimitSeconds != null) 'time_limit_seconds': timeLimitSeconds,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Failed to generate puzzle'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Submit a solution for a practice puzzle
  static Future<Map<String, dynamic>> submitSolution({
    required String sessionId,
    required String solution,
    required int solveTimeMs,
    int hintsUsed = 0,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.practiceBaseUrl}/practice/submit'),
        headers: _getHeaders(),
        body: jsonEncode({
          'session_id': sessionId,
          'solution': solution,
          'solve_time_ms': solveTimeMs,
          'hints_used': hintsUsed,
        }),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Failed to submit solution'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get practice session history
  static Future<Map<String, dynamic>> getHistory({
    String? cipherType,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var url = '${ApiConfig.practiceBaseUrl}/practice/history?limit=$limit&offset=$offset';
      if (cipherType != null && cipherType.isNotEmpty) {
        url += '&cipher_type=$cipherType';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? 'Failed to fetch history'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Get personal best records for a cipher
  static Future<Map<String, dynamic>> getPersonalBests({
    required String cipherType,
    int? difficulty,
  }) async {
    try {
      var url = '${ApiConfig.practiceBaseUrl}/practice/leaderboard/$cipherType';
      if (difficulty != null) {
        url += '?difficulty=$difficulty';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _getHeaders(),
      ).timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {'success': true, 'data': data['data']};
      } else {
        return {'success': false, 'error': 'Failed to fetch personal bests'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
