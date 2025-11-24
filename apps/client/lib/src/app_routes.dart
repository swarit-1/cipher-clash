import 'package:flutter/material.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/menu/main_menu_screen.dart';
import 'features/matchmaking/matchmaking_screen.dart';
import 'features/matchmaking/queue_screen.dart';
import 'features/game/enhanced_game_screen.dart';
import 'features/game/match_summary_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/achievements/achievements_screen.dart';
import 'features/settings/settings_screen.dart';

class AppRoutes {
  static const String login = '/login';
  static const String register = '/register';
  static const String menu = '/menu';
  static const String matchmaking = '/matchmaking';
  static const String queue = '/queue';
  static const String game = '/game';
  static const String matchSummary = '/match-summary';
  static const String profile = '/profile';
  static const String leaderboard = '/leaderboard';
  static const String achievements = '/achievements';
  static const String settings = '/settings';
  static const String social = '/social';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      menu: (context) => const MainMenuScreen(),
      matchmaking: (context) => const MatchmakingScreen(),
      queue: (context) => const QueueScreen(),
      game: (context) => const EnhancedGameScreen(),
      matchSummary: (context) => const MatchSummaryScreen(),
      profile: (context) => const ProfileScreen(),
      leaderboard: (context) => const LeaderboardScreen(),
      achievements: (context) => const AchievementsScreen(),
      settings: (context) => const SettingsScreen(),
      // Social screen is a placeholder
      social: (context) => Scaffold(
            appBar: AppBar(title: const Text('Social')),
            body: const Center(child: Text('Social features coming soon!')),
          ),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case login:
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (context) => const RegisterScreen());
      case menu:
        return MaterialPageRoute(builder: (context) => const MainMenuScreen());
      case matchmaking:
        return MaterialPageRoute(
          builder: (context) => const MatchmakingScreen(),
          settings: settings,
        );
      case queue:
        return MaterialPageRoute(
          builder: (context) {
            final args = settings.arguments as Map<String, dynamic>?;
            return QueueScreen(
              gameMode: args?['mode'] ?? 'RANKED_1V1',
            );
          },
        );
      case game:
        return MaterialPageRoute(builder: (context) => const EnhancedGameScreen());
      case matchSummary:
        return MaterialPageRoute(
          builder: (context) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MatchSummaryScreen(matchData: args);
          },
        );
      case profile:
        return MaterialPageRoute(builder: (context) => const ProfileScreen());
      case leaderboard:
        return MaterialPageRoute(builder: (context) => const LeaderboardScreen());
      case achievements:
        return MaterialPageRoute(builder: (context) => const AchievementsScreen());
      case settings:
        return MaterialPageRoute(builder: (context) => const SettingsScreen());
      case social:
        return MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Social')),
            body: const Center(child: Text('Social features coming soon!')),
          ),
        );
      default:
        return null;
    }
  }
}
