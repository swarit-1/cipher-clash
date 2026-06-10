import 'package:shared_preferences/shared_preferences.dart';

/// Persists the session across page reloads (localStorage on web).
class TokenStore {
  TokenStore._();

  static const _kAccess = 'cc_access_token';
  static const _kRefresh = 'cc_refresh_token';
  static const _kUserId = 'cc_user_id';
  static const _kUsername = 'cc_username';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static String? get accessToken => _prefs?.getString(_kAccess);
  static String? get refreshToken => _prefs?.getString(_kRefresh);
  static String? get userId => _prefs?.getString(_kUserId);
  static String? get username => _prefs?.getString(_kUsername);

  static Future<void> save({
    required String accessToken,
    required String refreshToken,
    required String userId,
    required String username,
  }) async {
    await init();
    await _prefs!.setString(_kAccess, accessToken);
    await _prefs!.setString(_kRefresh, refreshToken);
    await _prefs!.setString(_kUserId, userId);
    await _prefs!.setString(_kUsername, username);
  }

  static Future<void> updateAccessToken(String accessToken) async {
    await init();
    await _prefs!.setString(_kAccess, accessToken);
  }

  static Future<void> clear() async {
    await init();
    await _prefs!.remove(_kAccess);
    await _prefs!.remove(_kRefresh);
    await _prefs!.remove(_kUserId);
    await _prefs!.remove(_kUsername);
  }
}
