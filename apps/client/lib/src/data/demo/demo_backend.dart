/// DEMO_MODE backend: replaces [Api.client] with an in-memory transport so
/// the entire app runs with zero live services (used for the static Vercel
/// deployment). The full route simulation lands with the demo data set;
/// until then this placeholder keeps non-demo builds unaffected.
library demo_backend;

import '../../core/api_client.dart';

class DemoBackend {
  DemoBackend._();

  /// Swaps the transport for the in-memory demo implementation.
  static void install() {
    Api.client = DemoApiClient();
  }
}

/// In-memory transport. Routes are added incrementally; unknown routes
/// return 404 with a clear message so gaps surface during development.
class DemoApiClient implements ApiClient {
  @override
  Future<ApiResponse> get(String url, {bool auth = true}) async =>
      _route('GET', url, null);

  @override
  Future<ApiResponse> post(String url, {Object? body, bool auth = true}) async =>
      _route('POST', url, body);

  @override
  Future<ApiResponse> delete(String url, {Object? body, bool auth = true}) async =>
      _route('DELETE', url, body);

  Future<ApiResponse> _route(String method, String url, Object? body) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return ApiResponse(404, {
      'error': {
        'code': 'DEMO_UNIMPLEMENTED',
        'message': 'Demo route not implemented: $method $url',
      }
    });
  }
}
