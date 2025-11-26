class ApiConfig {
  // Base URLs for each microservice (HTTP/REST)
  static const String authBaseUrl = 'http://localhost:8085/api/v1';
  static const String matchmakerBaseUrl = 'http://localhost:8086/api/v1';
  static const String puzzleBaseUrl = 'http://localhost:8087/api/v1';
  static const String achievementBaseUrl = 'http://localhost:8083/api/v1';
  static const String gameBaseUrl = 'http://localhost:8088/api/v1';
  static const String tutorialBaseUrl = 'http://localhost:8089/api/v1';

  // WebSocket URLs
  static const String gameWebSocketUrl = 'ws://localhost:8088/ws';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
