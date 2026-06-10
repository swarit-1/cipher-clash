import '../core/env.dart';

/// Backwards-compatible facade over [Env]. New code should use [Env]
/// directly; these constants exist for the original service classes.
class ApiConfig {
  ApiConfig._();

  static const String authBaseUrl = Env.authUrl;
  static const String matchmakerBaseUrl = Env.matchmakerUrl;
  static const String puzzleBaseUrl = Env.puzzleUrl;
  static const String achievementBaseUrl = Env.achievementUrl;
  static const String gameBaseUrl = Env.gameUrl;
  static const String tutorialBaseUrl = Env.tutorialUrl;
  static const String practiceBaseUrl = Env.practiceUrl;
  static const String masteryBaseUrl = Env.masteryUrl;
  static const String missionsBaseUrl = Env.missionsUrl;
  static const String socialBaseUrl = Env.socialUrl;
  static const String cosmeticsBaseUrl = Env.cosmeticsUrl;

  static const String gameWebSocketUrl = Env.gameWsUrl;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
}
