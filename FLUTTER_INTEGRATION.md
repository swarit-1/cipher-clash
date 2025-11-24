# 🎨 Flutter Client V2.0 - Integration Guide

## 📋 Overview

This guide provides step-by-step instructions for updating the Flutter client to integrate with the new Cipher Clash V2.0 backend services.

---

## 🎯 Integration Checklist

### Phase 1: Setup & Configuration
- [ ] Add required dependencies to `pubspec.yaml`
- [ ] Configure API endpoints
- [ ] Set up environment configuration
- [ ] Create API client base classes

### Phase 2: Authentication Integration
- [ ] Implement AuthService with V2.0 endpoints
- [ ] Add JWT token storage (secure_storage)
- [ ] Implement token refresh logic
- [ ] Add auto-login on app start
- [ ] Create login/register screens

### Phase 3: Puzzle Engine Integration
- [ ] Create PuzzleService client
- [ ] Implement puzzle generation requests
- [ ] Add solution validation
- [ ] Display cipher-specific information
- [ ] Show difficulty and scoring

### Phase 4: Matchmaking Integration
- [ ] Create MatchmakerService client
- [ ] Implement queue join/leave
- [ ] Add queue status polling
- [ ] Display leaderboard
- [ ] Show ELO ratings

### Phase 5: Real-time Game Integration
- [ ] Set up WebSocket connection
- [ ] Implement game state management
- [ ] Add real-time puzzle delivery
- [ ] Implement solution submission
- [ ] Add timer and scoring display

---

## 📦 Required Dependencies

Add these to `apps/client/pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter

  # HTTP & WebSocket
  http: ^1.1.0
  web_socket_channel: ^2.4.0

  # State Management
  flutter_riverpod: ^2.4.0
  # OR
  flutter_bloc: ^8.1.3

  # Secure Storage (for tokens)
  flutter_secure_storage: ^9.0.0

  # JSON Serialization
  json_annotation: ^4.8.1
  freezed_annotation: ^2.4.1

  # Code Generation
  build_runner: ^2.4.6
  json_serializable: ^6.7.1
  freezed: ^2.4.5

  # UI Components
  google_fonts: ^6.1.0
  flutter_animate: ^4.3.0
  shimmer: ^3.0.0

  # Utilities
  dio: ^5.4.0  # Alternative to http with better features
  pretty_dio_logger: ^1.3.1
  intl: ^0.18.1
```

---

## 🔧 Configuration Setup

### 1. Environment Configuration

Create `apps/client/lib/config/app_config.dart`:

```dart
class AppConfig {
  // API Endpoints
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost',
  );

  static const String authServiceUrl = '$baseUrl:8080/api/v1/auth';
  static const String puzzleServiceUrl = '$baseUrl:8082/api/v1/puzzle';
  static const String matchmakerServiceUrl = '$baseUrl:8081/api/v1/matchmaker';
  static const String gameServiceWsUrl = 'ws://localhost:8083/ws';

  // Token Configuration
  static const String accessTokenKey = 'cipher_clash_access_token';
  static const String refreshTokenKey = 'cipher_clash_refresh_token';
  static const String userIdKey = 'cipher_clash_user_id';

  // Timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);

  // Development flags
  static const bool isDevelopment = bool.fromEnvironment(
    'DEVELOPMENT',
    defaultValue: true,
  );
}
```

### 2. API Client Base

Create `apps/client/lib/services/api_client.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ApiClient() {
    _dio = Dio(BaseOptions(
      connectTimeout: AppConfig.connectTimeout,
      receiveTimeout: AppConfig.receiveTimeout,
      headers: {
        'Content-Type': 'application/json',
      },
    ));

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: _onRequest,
      onError: _onError,
    ));

    if (AppConfig.isDevelopment) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
      ));
    }
  }

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Add JWT token to requests
    final token = await _storage.read(key: AppConfig.accessTokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Handle 401 Unauthorized - refresh token
    if (err.response?.statusCode == 401) {
      try {
        await _refreshToken();
        // Retry original request
        final response = await _dio.fetch(err.requestOptions);
        return handler.resolve(response);
      } catch (e) {
        // Refresh failed, logout user
        await _clearTokens();
        return handler.reject(err);
      }
    }
    handler.next(err);
  }

  Future<void> _refreshToken() async {
    final refreshToken = await _storage.read(key: AppConfig.refreshTokenKey);
    if (refreshToken == null) throw Exception('No refresh token');

    final response = await _dio.post(
      '${AppConfig.authServiceUrl}/refresh',
      data: {'refresh_token': refreshToken},
    );

    final newAccessToken = response.data['access_token'];
    await _storage.write(
      key: AppConfig.accessTokenKey,
      value: newAccessToken,
    );
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: AppConfig.accessTokenKey);
    await _storage.delete(key: AppConfig.refreshTokenKey);
    await _storage.delete(key: AppConfig.userIdKey);
  }

  Dio get client => _dio;
}
```

---

## 🔐 Authentication Service

Create `apps/client/lib/services/auth_service.dart`:

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import '../models/user.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _apiClient;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService(this._apiClient);

  Future<User> register({
    required String username,
    required String email,
    required String password,
    String region = 'US',
  }) async {
    final response = await _apiClient.client.post(
      '${AppConfig.authServiceUrl}/register',
      data: {
        'username': username,
        'email': email,
        'password': password,
        'region': region,
      },
    );

    await _saveTokens(
      response.data['access_token'],
      response.data['refresh_token'],
    );

    return User.fromJson(response.data['user']);
  }

  Future<User> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.client.post(
      '${AppConfig.authServiceUrl}/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    await _saveTokens(
      response.data['access_token'],
      response.data['refresh_token'],
    );

    return User.fromJson(response.data['user']);
  }

  Future<User> getProfile() async {
    final response = await _apiClient.client.get(
      '${AppConfig.authServiceUrl}/profile',
    );

    return User.fromJson(response.data);
  }

  Future<void> logout() async {
    try {
      await _apiClient.client.post(
        '${AppConfig.authServiceUrl}/logout',
      );
    } finally {
      await _clearTokens();
    }
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: AppConfig.accessTokenKey);
    return token != null;
  }

  Future<void> _saveTokens(String accessToken, String refreshToken) async {
    await _storage.write(key: AppConfig.accessTokenKey, value: accessToken);
    await _storage.write(key: AppConfig.refreshTokenKey, value: refreshToken);
  }

  Future<void> _clearTokens() async {
    await _storage.delete(key: AppConfig.accessTokenKey);
    await _storage.delete(key: AppConfig.refreshTokenKey);
    await _storage.delete(key: AppConfig.userIdKey);
  }
}
```

---

## 🧩 Puzzle Service

Create `apps/client/lib/services/puzzle_service.dart`:

```dart
import '../config/app_config.dart';
import '../models/puzzle.dart';
import 'api_client.dart';

class PuzzleService {
  final ApiClient _apiClient;

  PuzzleService(this._apiClient);

  Future<Puzzle> generatePuzzle({
    String? cipherType,
    int? difficulty,
    int? playerElo,
  }) async {
    final response = await _apiClient.client.post(
      '${AppConfig.puzzleServiceUrl}/generate',
      data: {
        if (cipherType != null) 'cipher_type': cipherType,
        if (difficulty != null) 'difficulty': difficulty,
        if (playerElo != null) 'player_elo': playerElo,
      },
    );

    return Puzzle.fromJson(response.data);
  }

  Future<ValidationResult> validateSolution({
    required String puzzleId,
    required String solution,
    required int solveTimeMs,
  }) async {
    final response = await _apiClient.client.post(
      '${AppConfig.puzzleServiceUrl}/validate',
      data: {
        'puzzle_id': puzzleId,
        'solution': solution,
        'solve_time_ms': solveTimeMs,
      },
    );

    return ValidationResult.fromJson(response.data);
  }

  Future<Puzzle> getPuzzle(String puzzleId) async {
    final response = await _apiClient.client.get(
      '${AppConfig.puzzleServiceUrl}/get',
      queryParameters: {'puzzle_id': puzzleId},
    );

    return Puzzle.fromJson(response.data);
  }
}
```

---

## 🎯 Matchmaker Service

Create `apps/client/lib/services/matchmaker_service.dart`:

```dart
import '../config/app_config.dart';
import '../models/queue_response.dart';
import '../models/leaderboard_entry.dart';
import 'api_client.dart';

class MatchmakerService {
  final ApiClient _apiClient;

  MatchmakerService(this._apiClient);

  Future<QueueResponse> joinQueue({
    required String userId,
    required String username,
    required int elo,
    String gameMode = 'RANKED_1V1',
    String region = 'US',
  }) async {
    final response = await _apiClient.client.post(
      '${AppConfig.matchmakerServiceUrl}/join',
      data: {
        'user_id': userId,
        'username': username,
        'elo': elo,
        'game_mode': gameMode,
        'region': region,
      },
    );

    return QueueResponse.fromJson(response.data);
  }

  Future<void> leaveQueue(String userId) async {
    await _apiClient.client.post(
      '${AppConfig.matchmakerServiceUrl}/leave',
      data: {'user_id': userId},
    );
  }

  Future<QueueStatus> getQueueStatus(String userId) async {
    final response = await _apiClient.client.get(
      '${AppConfig.matchmakerServiceUrl}/status',
      queryParameters: {'user_id': userId},
    );

    return QueueStatus.fromJson(response.data);
  }

  Future<List<LeaderboardEntry>> getLeaderboard({
    String? region,
    int? seasonId,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiClient.client.get(
      '${AppConfig.matchmakerServiceUrl}/leaderboard',
      queryParameters: {
        if (region != null) 'region': region,
        if (seasonId != null) 'season_id': seasonId,
        'limit': limit,
        'offset': offset,
      },
    );

    final entries = response.data['entries'] as List;
    return entries.map((e) => LeaderboardEntry.fromJson(e)).toList();
  }
}
```

---

## 🎮 WebSocket Game Service

Create `apps/client/lib/services/game_service.dart`:

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/game_message.dart';

class GameService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<GameMessage>.broadcast();

  Stream<GameMessage> get messages => _messageController.stream;

  Future<void> connect(String userId, String accessToken) async {
    final uri = Uri.parse(
      '${AppConfig.gameServiceWsUrl}?user_id=$userId&token=$accessToken',
    );

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (data) {
        final message = GameMessage.fromJson(jsonDecode(data));
        _messageController.add(message);
      },
      onError: (error) {
        print('WebSocket error: $error');
        _messageController.addError(error);
      },
      onDone: () {
        print('WebSocket closed');
      },
    );
  }

  void sendMessage(GameMessage message) {
    if (_channel == null) {
      throw Exception('WebSocket not connected');
    }
    _channel!.sink.add(jsonEncode(message.toJson()));
  }

  void submitSolution({
    required String matchId,
    required String puzzleId,
    required String solution,
    required int solveTimeMs,
  }) {
    sendMessage(GameMessage(
      type: 'SUBMIT_SOLUTION',
      data: {
        'match_id': matchId,
        'puzzle_id': puzzleId,
        'solution': solution,
        'solve_time_ms': solveTimeMs,
      },
    ));
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
```

---

## 📱 Model Classes

### User Model

Create `apps/client/lib/models/user.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

@freezed
class User with _$User {
  const factory User({
    required String id,
    required String username,
    required String email,
    @Default('') String displayName,
    @Default('') String avatarUrl,
    @Default(1200) int eloRating,
    @Default('UNRANKED') String rankTier,
    @Default(0) int totalGames,
    @Default(0) int wins,
    @Default(0) int losses,
    @Default(0) int winStreak,
    String? region,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
```

### Puzzle Model

Create `apps/client/lib/models/puzzle.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'puzzle.freezed.dart';
part 'puzzle.g.dart';

@freezed
class Puzzle with _$Puzzle {
  const factory Puzzle({
    required String id,
    required String cipherType,
    required int difficulty,
    required String encryptedText,
    required String plaintext,
    required Map<String, dynamic> config,
    int? timeLimit,
    int? baseScore,
  }) = _Puzzle;

  factory Puzzle.fromJson(Map<String, dynamic> json) => _$PuzzleFromJson(json);
}

@freezed
class ValidationResult with _$ValidationResult {
  const factory ValidationResult({
    required bool isCorrect,
    required double accuracy,
    required int score,
    required String correctSolution,
  }) = _ValidationResult;

  factory ValidationResult.fromJson(Map<String, dynamic> json) =>
      _$ValidationResultFromJson(json);
}
```

### Leaderboard Entry Model

Create `apps/client/lib/models/leaderboard_entry.dart`:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'leaderboard_entry.freezed.dart';
part 'leaderboard_entry.g.dart';

@freezed
class LeaderboardEntry with _$LeaderboardEntry {
  const factory LeaderboardEntry({
    required int rank,
    required String userId,
    required String username,
    String? displayName,
    String? avatarUrl,
    required int eloRating,
    required String rankTier,
    required int totalGames,
    required int wins,
    required int losses,
    required double winRate,
    int? winStreak,
  }) = _LeaderboardEntry;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      _$LeaderboardEntryFromJson(json);
}
```

---

## 🎨 UI Integration Examples

### Login Screen

```dart
class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = context.read<AuthService>();
      final user = await authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );

      // Navigate to home
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(labelText: 'Email'),
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
              validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: Text(_isLoading ? 'Loading...' : 'Login'),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Matchmaking Queue Screen

```dart
class MatchmakingScreen extends StatefulWidget {
  @override
  State<MatchmakingScreen> createState() => _MatchmakingScreenState();
}

class _MatchmakingScreenState extends State<MatchmakingScreen> {
  Timer? _pollTimer;
  QueueStatus? _queueStatus;

  @override
  void initState() {
    super.initState();
    _joinQueue();
    _startPolling();
  }

  Future<void> _joinQueue() async {
    final matchmaker = context.read<MatchmakerService>();
    final user = context.read<User>();

    await matchmaker.joinQueue(
      userId: user.id,
      username: user.username,
      elo: user.eloRating,
    );
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      final matchmaker = context.read<MatchmakerService>();
      final user = context.read<User>();

      final status = await matchmaker.getQueueStatus(user.id);
      setState(() => _queueStatus = status);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Finding Match...')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Players in queue: ${_queueStatus?.playersInQueue ?? 0}'),
            Text('Searching...'),
          ],
        ),
      ),
    );
  }
}
```

---

## 🚀 Quick Start Integration

### 1. Run Code Generation

```bash
cd apps/client
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 2. Update Main App

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final apiClient = ApiClient();
  final authService = AuthService(apiClient);

  runApp(
    MultiProvider(
      providers: [
        Provider.value(value: apiClient),
        Provider.value(value: authService),
        Provider(create: (_) => PuzzleService(apiClient)),
        Provider(create: (_) => MatchmakerService(apiClient)),
        Provider(create: (_) => GameService()),
      ],
      child: MyApp(),
    ),
  );
}
```

### 3. Test Connection

```dart
// Test auth service
final authService = AuthService(ApiClient());
try {
  final user = await authService.register(
    username: 'testuser',
    email: 'test@test.com',
    password: 'password123',
  );
  print('Registered: ${user.username}');
} catch (e) {
  print('Error: $e');
}
```

---

## 📝 Next Steps

1. **Update UI/UX** with cyberpunk design system
2. **Add error handling** and retry logic
3. **Implement offline mode** with local caching
4. **Add animations** for state transitions
5. **Test on real devices** (iOS/Android)
6. **Performance optimization** (lazy loading, pagination)

---

## 🔗 API Endpoint Reference

| Service | Port | Base URL |
|---------|------|----------|
| Auth | 8080 | `http://localhost:8080/api/v1/auth` |
| Puzzle | 8082 | `http://localhost:8082/api/v1/puzzle` |
| Matchmaker | 8081 | `http://localhost:8081/api/v1/matchmaker` |
| Game (WS) | 8083 | `ws://localhost:8083/ws` |

---

**Ready to integrate!** Start with Phase 1 (Setup & Configuration) and work through each phase sequentially. 🚀
