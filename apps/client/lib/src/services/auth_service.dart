import '../core/api_client.dart';
import '../core/env.dart';
import '../core/token_store.dart';

/// Authentication + session facade. Tokens persist across reloads via
/// [TokenStore]; requests flow through [Api.client], which transparently
/// refreshes expired access tokens.
class AuthService {
  AuthService._();

  /// The most recently fetched profile (richer than the token payload).
  static Map<String, dynamic>? currentUser;

  static String? get accessToken => TokenStore.accessToken;
  static String? get userId => TokenStore.userId;
  static String? get username => TokenStore.username;
  static bool get isAuthenticated => TokenStore.accessToken != null;

  /// Restores a persisted session and validates it by fetching the
  /// profile. Returns true when the user is signed in.
  static Future<bool> restore() async {
    await TokenStore.init();
    if (TokenStore.accessToken == null) return false;
    final profile = await fetchProfile();
    return profile != null;
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    String region = 'US',
  }) async {
    final response = await Api.client.post(
      '${Env.authUrl}/auth/register',
      auth: false,
      body: {
        'username': username,
        'email': email,
        'password': password,
        'region': region,
      },
    );
    return _handleAuthResponse(response, fallbackUsername: username);
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await Api.client.post(
      '${Env.authUrl}/auth/login',
      auth: false,
      body: {'username': username, 'password': password},
    );
    return _handleAuthResponse(response, fallbackUsername: username);
  }

  static Future<Map<String, dynamic>> _handleAuthResponse(
    ApiResponse response, {
    required String fallbackUsername,
  }) async {
    if (!response.ok || response.json is! Map) {
      return {'success': false, 'message': response.errorMessage};
    }
    final data = (response.json as Map).cast<String, dynamic>();
    final user = (data['user'] as Map?)?.cast<String, dynamic>();
    final access = data['access_token'] as String?;
    final refresh = data['refresh_token'] as String?;
    if (access == null || refresh == null) {
      return {'success': false, 'message': 'Malformed auth response'};
    }

    await TokenStore.save(
      accessToken: access,
      refreshToken: refresh,
      userId: user?['id'] as String? ?? '',
      username: user?['username'] as String? ?? fallbackUsername,
    );
    currentUser = user;
    return {'success': true, 'message': 'OK'};
  }

  /// Fetches (and caches) the authenticated user's profile.
  static Future<Map<String, dynamic>?> fetchProfile() async {
    final response = await Api.client.get('${Env.authUrl}/auth/profile');
    if (response.ok && response.json is Map) {
      currentUser = (response.json as Map).cast<String, dynamic>();
      return currentUser;
    }
    if (response.status == 401) {
      await logout();
    }
    return null;
  }

  static Future<void> logout() async {
    currentUser = null;
    await TokenStore.clear();
  }

  /// Authorization headers for code paths that still build requests
  /// manually.
  static Map<String, String> getAuthHeaders() {
    final token = TokenStore.accessToken;
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }
}
