/// Typed models for the game service's WebSocket protocol.
library match_models;

/// Arguments passed to the match screen.
class MatchArgs {
  MatchArgs({
    required this.matchId,
    required this.gameMode,
    required this.isRanked,
    this.opponentUsername,
    this.opponentElo,
    this.opponentIsBot = false,
  });

  final String matchId;
  final String gameMode;
  final bool isRanked;
  final String? opponentUsername;
  final int? opponentElo;
  final bool opponentIsBot;
}

class PuzzleView {
  PuzzleView({
    required this.index,
    required this.cipherType,
    required this.difficulty,
    required this.encryptedText,
  });

  factory PuzzleView.fromJson(Map<String, dynamic> json) => PuzzleView(
        index: (json['index'] as num?)?.toInt() ?? 0,
        cipherType: json['cipher_type'] as String? ?? 'UNKNOWN',
        difficulty: (json['difficulty'] as num?)?.toInt() ?? 1,
        encryptedText: json['encrypted_text'] as String? ?? '',
      );

  final int index;
  final String cipherType;
  final int difficulty;
  final String encryptedText;
}

class PlayerView {
  PlayerView({
    required this.userId,
    required this.username,
    required this.elo,
    required this.isBot,
    required this.connected,
    required this.solvedCount,
    required this.puzzleIndex,
    required this.progress,
  });

  factory PlayerView.fromJson(Map<String, dynamic> json) => PlayerView(
        userId: json['user_id'] as String? ?? '',
        username: json['username'] as String? ?? '???',
        elo: (json['elo'] as num?)?.toInt() ?? 0,
        isBot: json['is_bot'] as bool? ?? false,
        connected: json['connected'] as bool? ?? false,
        solvedCount: (json['solved_count'] as num?)?.toInt() ?? 0,
        puzzleIndex: (json['puzzle_index'] as num?)?.toInt() ?? 0,
        progress: (json['progress'] as num?)?.toDouble() ?? 0,
      );

  final String userId;
  final String username;
  final int elo;
  final bool isBot;
  final bool connected;
  final int solvedCount;
  final int puzzleIndex;
  final double progress;
}

class RoomState {
  RoomState({
    required this.matchId,
    required this.status,
    required this.gameMode,
    required this.isRanked,
    required this.you,
    required this.opponent,
    required this.totalPuzzles,
    required this.targetSolves,
    this.puzzle,
    this.startsAtMs,
    this.deadlineMs,
    this.serverNowMs,
    this.opponentGoneMs,
  });

  factory RoomState.fromJson(Map<String, dynamic> json) => RoomState(
        matchId: json['match_id'] as String? ?? '',
        status: json['status'] as String? ?? 'WAITING',
        gameMode: json['game_mode'] as String? ?? '',
        isRanked: json['is_ranked'] as bool? ?? false,
        you: PlayerView.fromJson((json['you'] as Map).cast<String, dynamic>()),
        opponent: PlayerView.fromJson(
            (json['opponent'] as Map).cast<String, dynamic>()),
        totalPuzzles: (json['total_puzzles'] as num?)?.toInt() ?? 5,
        targetSolves: (json['target_solves'] as num?)?.toInt() ?? 3,
        puzzle: json['puzzle'] is Map
            ? PuzzleView.fromJson((json['puzzle'] as Map).cast<String, dynamic>())
            : null,
        startsAtMs: (json['starts_at_ms'] as num?)?.toInt(),
        deadlineMs: (json['deadline_ms'] as num?)?.toInt(),
        serverNowMs: (json['server_now_ms'] as num?)?.toInt(),
        opponentGoneMs: (json['opponent_gone_ms'] as num?)?.toInt(),
      );

  final String matchId;
  final String status;
  final String gameMode;
  final bool isRanked;
  final PlayerView you;
  final PlayerView opponent;
  final int totalPuzzles;
  final int targetSolves;
  final PuzzleView? puzzle;
  final int? startsAtMs;
  final int? deadlineMs;
  final int? serverNowMs;
  final int? opponentGoneMs;
}

class MatchEnd {
  MatchEnd({
    required this.winnerId,
    required this.reason,
    required this.yourScore,
    required this.opponentScore,
    required this.eloChange,
    required this.newElo,
    required this.durationMs,
  });

  factory MatchEnd.fromJson(Map<String, dynamic> json) => MatchEnd(
        winnerId: json['winner_id'] as String? ?? '',
        reason: json['reason'] as String? ?? 'COMPLETED',
        yourScore: (json['your_score'] as num?)?.toInt() ?? 0,
        opponentScore: (json['opponent_score'] as num?)?.toInt() ?? 0,
        eloChange: (json['elo_change'] as num?)?.toInt() ?? 0,
        newElo: (json['new_elo'] as num?)?.toInt() ?? 0,
        durationMs: (json['duration_ms'] as num?)?.toInt() ?? 0,
      );

  final String winnerId;
  final String reason;
  final int yourScore;
  final int opponentScore;
  final int eloChange;
  final int newElo;
  final int durationMs;
}
