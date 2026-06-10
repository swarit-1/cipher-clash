import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'env.dart';
import 'token_store.dart';

/// Decoded HTTP result.
class ApiResponse {
  ApiResponse(this.status, this.json);

  final int status;
  final dynamic json;

  bool get ok => status >= 200 && status < 300;

  /// Best-effort human-readable error from the backend's
  /// {"error": {"code", "message"}} convention.
  String get errorMessage {
    if (json is Map) {
      final err = (json as Map)['error'];
      if (err is Map && err['message'] is String) return err['message'];
      if (err is String) return err;
      if ((json as Map)['message'] is String) return (json as Map)['message'];
    }
    return 'Request failed ($status)';
  }
}

/// Transport abstraction: the real HTTP client in normal builds, an
/// in-memory simulator in DEMO_MODE builds.
abstract class ApiClient {
  Future<ApiResponse> get(String url, {bool auth = true});
  Future<ApiResponse> post(String url, {Object? body, bool auth = true});
  Future<ApiResponse> delete(String url, {Object? body, bool auth = true});
}

/// Service locator for the active transport. [Api.client] is replaced by
/// the demo transport at startup when DEMO_MODE is set.
class Api {
  Api._();
  static ApiClient client = HttpApiClient();
}

/// Real HTTP transport. Injects the Bearer token, and on a 401 attempts one
/// refresh-token exchange before retrying the request; a failed refresh
/// clears the session.
class HttpApiClient implements ApiClient {
  HttpApiClient({http.Client? inner}) : _http = inner ?? http.Client();

  final http.Client _http;
  static const _timeout = Duration(seconds: 12);

  Completer<bool>? _refreshing;

  @override
  Future<ApiResponse> get(String url, {bool auth = true}) =>
      _send('GET', url, auth: auth);

  @override
  Future<ApiResponse> post(String url, {Object? body, bool auth = true}) =>
      _send('POST', url, body: body, auth: auth);

  @override
  Future<ApiResponse> delete(String url, {Object? body, bool auth = true}) =>
      _send('DELETE', url, body: body, auth: auth);

  Future<ApiResponse> _send(String method, String url,
      {Object? body, required bool auth, bool retried = false}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (auth && TokenStore.accessToken != null) {
      headers['Authorization'] = 'Bearer ${TokenStore.accessToken}';
    }

    final request = http.Request(method, Uri.parse(url))..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      return ApiResponse(0, {
        'error': {'code': 'NETWORK', 'message': 'Cannot reach the server'}
      });
    }

    if (response.statusCode == 401 && auth && !retried) {
      if (await _refreshToken()) {
        return _send(method, url, body: body, auth: auth, retried: true);
      }
    }

    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      decoded = null;
    }
    return ApiResponse(response.statusCode, decoded);
  }

  /// Exchanges the refresh token for a new access token. Coalesces
  /// concurrent refresh attempts; clears the session if refresh fails.
  Future<bool> _refreshToken() async {
    final pending = _refreshing;
    if (pending != null) return pending.future;

    final refresh = TokenStore.refreshToken;
    if (refresh == null) return false;

    final completer = Completer<bool>();
    _refreshing = completer;
    try {
      final response = await _http
          .post(
            Uri.parse('${Env.authUrl}/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refresh}),
          )
          .timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccess = data['access_token'] as String?;
        if (newAccess != null) {
          await TokenStore.updateAccessToken(newAccess);
          completer.complete(true);
          return true;
        }
      }
      await TokenStore.clear();
      completer.complete(false);
      return false;
    } catch (_) {
      completer.complete(false);
      return false;
    } finally {
      _refreshing = null;
    }
  }
}
