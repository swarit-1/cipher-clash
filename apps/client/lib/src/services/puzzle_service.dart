import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'auth_service.dart';

class PuzzleService {
  // Generate a puzzle
  static Future<Map<String, dynamic>> generatePuzzle({
    required String cipherType,
    required int difficulty,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.puzzleBaseUrl}/puzzle/generate'),
            headers: AuthService.getAuthHeaders(),
            body: jsonEncode({
              'cipher_type': cipherType,
              'difficulty': difficulty,
            }),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'puzzle': data,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Failed to generate puzzle'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Validate puzzle solution
  static Future<Map<String, dynamic>> validateSolution({
    required String puzzleId,
    required String solution,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.puzzleBaseUrl}/puzzle/validate'),
            headers: AuthService.getAuthHeaders(),
            body: jsonEncode({
              'puzzle_id': puzzleId,
              'solution': solution,
            }),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'is_correct': data['is_correct'] ?? false,
          'score': data['score'] ?? 0,
        };
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Validation failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Get available cipher types
  static Future<List<String>> getCipherTypes() async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.puzzleBaseUrl}/puzzle/types'),
            headers: AuthService.getAuthHeaders(),
          )
          .timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['cipher_types'] ?? []);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
