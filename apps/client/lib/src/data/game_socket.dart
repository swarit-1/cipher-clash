import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/env.dart';
import '../core/token_store.dart';

/// A decoded server envelope.
class ServerMessage {
  ServerMessage(this.type, this.payload);

  final String type;
  final Map<String, dynamic> payload;
}

enum SocketState { connecting, connected, reconnecting, closed }

/// Transport for a live match. The real implementation speaks the game
/// service's WebSocket protocol; DEMO_MODE swaps in a local simulator.
abstract class GameSocket {
  Stream<ServerMessage> get messages;
  Stream<SocketState> get state;

  Future<void> connect(String matchId, {bool spectate = false});
  void submit(int puzzleIndex, String solution);
  void sendProgress(double progress);
  void forfeit();
  Future<void> close();
}

/// Factory for the active implementation; replaced in DEMO_MODE.
class GameSocketFactory {
  GameSocketFactory._();
  static GameSocket Function() create = RealGameSocket.new;
}

/// WebSocket client with app-level PING keepalive and automatic
/// reconnection with backoff (the room resyncs us via ROOM_STATE).
class RealGameSocket implements GameSocket {
  RealGameSocket();

  final _messages = StreamController<ServerMessage>.broadcast();
  final _state = StreamController<SocketState>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _progressThrottle;
  double? _pendingProgress;

  String? _matchId;
  bool _spectate = false;
  bool _closed = false;
  int _reconnectAttempts = 0;

  @override
  Stream<ServerMessage> get messages => _messages.stream;

  @override
  Stream<SocketState> get state => _state.stream;

  @override
  Future<void> connect(String matchId, {bool spectate = false}) async {
    _matchId = matchId;
    _spectate = spectate;
    _closed = false;
    _reconnectAttempts = 0;
    await _open();
  }

  Future<void> _open() async {
    final token = TokenStore.accessToken;
    if (token == null || _matchId == null) {
      _state.add(SocketState.closed);
      return;
    }

    _state.add(_reconnectAttempts == 0
        ? SocketState.connecting
        : SocketState.reconnecting);

    final uri = Uri.parse(
        '${Env.gameWsUrl}?match_id=$_matchId&token=$token${_spectate ? '&spectate=true' : ''}');
    try {
      final channel = WebSocketChannel.connect(uri);
      await channel.ready;
      _channel = channel;
      _reconnectAttempts = 0;
      _state.add(SocketState.connected);

      _subscription = channel.stream.listen(
        _onData,
        onDone: _onDisconnected,
        onError: (_) => _onDisconnected(),
        cancelOnError: true,
      );

      _pingTimer?.cancel();
      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _send('PING', const {});
      });
    } catch (_) {
      _onDisconnected();
    }
  }

  void _onData(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is Map && decoded['type'] is String) {
        final payload = decoded['payload'];
        _messages.add(ServerMessage(
          decoded['type'] as String,
          payload is Map ? payload.cast<String, dynamic>() : const {},
        ));
      }
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _onDisconnected() {
    _pingTimer?.cancel();
    _subscription?.cancel();
    _channel = null;
    if (_closed) return;

    // Reconnect with capped exponential backoff; the room holds our seat
    // for 45 seconds.
    _reconnectAttempts++;
    if (_reconnectAttempts > 8) {
      _state.add(SocketState.closed);
      return;
    }
    _state.add(SocketState.reconnecting);
    final delay = Duration(milliseconds: 500 * (1 << (_reconnectAttempts - 1)).clamp(1, 16));
    Timer(delay, () {
      if (!_closed) _open();
    });
  }

  void _send(String type, Map<String, dynamic> payload) {
    final channel = _channel;
    if (channel == null) return;
    channel.sink.add(jsonEncode({'type': type, 'payload': payload}));
  }

  @override
  void submit(int puzzleIndex, String solution) {
    _send('SUBMIT', {'puzzle_index': puzzleIndex, 'solution': solution});
  }

  @override
  void sendProgress(double progress) {
    // Throttle to one update per second.
    _pendingProgress = progress;
    _progressThrottle ??= Timer(const Duration(seconds: 1), () {
      _progressThrottle = null;
      final p = _pendingProgress;
      if (p != null) {
        _send('PROGRESS', {'progress': p.clamp(0.0, 1.0)});
      }
    });
  }

  @override
  void forfeit() => _send('FORFEIT', const {});

  @override
  Future<void> close() async {
    _closed = true;
    _pingTimer?.cancel();
    _progressThrottle?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();
    _state.add(SocketState.closed);
  }
}
