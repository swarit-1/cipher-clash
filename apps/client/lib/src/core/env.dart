/// Build-time environment configuration.
///
/// Every value can be overridden with `--dart-define`, e.g.:
///   flutter build web --dart-define=AUTH_URL=https://api.example.com/auth \
///                     --dart-define=DEMO_MODE=true
///
/// Defaults target the local development stack (canonical ports).
class Env {
  Env._();

  /// Demo mode runs the entire app against in-memory mock services and a
  /// local bot opponent — no backend required. Used for the static Vercel
  /// deployment.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  static const String authUrl = String.fromEnvironment(
      'AUTH_URL', defaultValue: 'http://localhost:8085/api/v1');
  static const String matchmakerUrl = String.fromEnvironment(
      'MATCHMAKER_URL', defaultValue: 'http://localhost:8086/api/v1');
  static const String puzzleUrl = String.fromEnvironment(
      'PUZZLE_URL', defaultValue: 'http://localhost:8087/api/v1');
  static const String gameUrl = String.fromEnvironment(
      'GAME_URL', defaultValue: 'http://localhost:8088/api/v1');
  static const String gameWsUrl = String.fromEnvironment(
      'GAME_WS_URL', defaultValue: 'ws://localhost:8088/ws');
  static const String tutorialUrl = String.fromEnvironment(
      'TUTORIAL_URL', defaultValue: 'http://localhost:8089/api/v1');
  static const String practiceUrl = String.fromEnvironment(
      'PRACTICE_URL', defaultValue: 'http://localhost:8090/api/v1');
  static const String achievementUrl = String.fromEnvironment(
      'ACHIEVEMENT_URL', defaultValue: 'http://localhost:8083/api/v1');
  static const String missionsUrl = String.fromEnvironment(
      'MISSIONS_URL', defaultValue: 'http://localhost:8084/api/v1');
  static const String masteryUrl = String.fromEnvironment(
      'MASTERY_URL', defaultValue: 'http://localhost:8091/api/v1');
  static const String socialUrl = String.fromEnvironment(
      'SOCIAL_URL', defaultValue: 'http://localhost:8092/api/v1');
  static const String cosmeticsUrl = String.fromEnvironment(
      'COSMETICS_URL', defaultValue: 'http://localhost:8093/api/v1');
}
