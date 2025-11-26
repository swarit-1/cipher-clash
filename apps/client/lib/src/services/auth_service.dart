import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class AuthService {
  static String? _accessToken;
  static String? _refreshToken;
  static String? _userId;
  static String? _username;

  // Getters
  static String? get accessToken => _accessToken;
  static String? get userId => _userId;
  static String? get username => _username;
  static bool get isAuthenticated => _accessToken != null;

  // Register new user
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.authBaseUrl}/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
            }),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 201 || response.statusCode == 200) {
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user_id'];
        _username = username;
        return {'success': true, 'message': 'Registration successful'};
      } else {
        return {
          'success': false,
          'message': data['error'] ?? 'Registration failed'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Login existing user
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.authBaseUrl}/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'password': password,
            }),
          )
          .timeout(ApiConfig.connectTimeout);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        _userId = data['user_id'];
        _username = username;
        return {'success': true, 'message': 'Login successful'};
      } else {
        return {'success': false, 'message': data['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  // Logout
  static void logout() {
    _accessToken = null;
    _refreshToken = null;
    _userId = null;
    _username = null;
  }

  // Set mock auth data for development (bypasses backend)
  static void setDevMockAuth({
    required String accessToken,
    required String userId,
    required String username,
  }) {
    _accessToken = accessToken;
    _refreshToken = 'dev-mock-refresh-token';
    _userId = userId;
    _username = username;
  }

  // Get authorization header
  static Map<String, String> getAuthHeaders() {
    if (_accessToken == null) {
      return {'Content-Type': 'application/json'};
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_accessToken',
    };
  }

  // Refresh token (if needed)
  static Future<bool> refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.authBaseUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': _refreshToken}),
          )
          .timeout(ApiConfig.connectTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _accessToken = data['access_token'];
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
