import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Provider for the GameService
final gameServiceProvider = Provider<GameService>((ref) {
  return GameService();
});

// State provider for the current puzzle
final puzzleStateProvider = StateProvider<PuzzleState?>((ref) => null);

// State provider for opponent progress
final opponentProgressProvider = StateProvider<double>((ref) => 0.0);

class GameService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;

  // Stream for game events
  final _eventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get gameEvents => _eventController.stream;

  // Connection status
  bool get isConnected => _channel != null;

  void connect(String url) {
    if (_channel != null) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _subscription = _channel!.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          disconnect();
        },
        onDone: () {
          debugPrint('WebSocket Closed');
          disconnect();
        },
      );
    } catch (e) {
      debugPrint('Connection Error: $e');
    }
  }

  void disconnect() {
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
    _subscription = null;
  }

  void sendAction(String action, Map<String, dynamic> payload) {
    if (_channel == null) return;

    final message = jsonEncode({
      'action': action,
      'payload': payload,
    });
    _channel!.sink.add(message);
  }

  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];
      final payload = data['payload'];

      debugPrint('Received: $type');

      if (type == 'MATCH_STARTED') {
        // Parse nested puzzle state
        if (payload['puzzle'] != null) {
          final puzzle = PuzzleState.fromJson(payload['puzzle']);
          _eventController.add({'type': 'PUZZLE_UPDATE', 'data': puzzle});
        }
      }
    } catch (e) {
      debugPrint('Error parsing message: $e');
    }
  }
}

class PuzzleState {
  final String encryptedText;
  final String solution;
  final String cipherType;
  final int difficulty;

  PuzzleState({
    required this.encryptedText,
    required this.solution,
    required this.cipherType,
    required this.difficulty,
  });

  factory PuzzleState.fromJson(Map<String, dynamic> json) {
    return PuzzleState(
      encryptedText: json['encrypted_text'] ?? '',
      solution: json['solution'] ?? '',
      cipherType: json['cipher_type'] ?? 'UNKNOWN',
      difficulty: json['difficulty'] ?? 1,
    );
  }
}
