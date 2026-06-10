import 'package:flutter/material.dart';

import 'data/match_models.dart';
import 'features/achievements/achievements_screen.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/codex/cipher_codex.dart';
import 'features/game/match_screen.dart';
import 'features/game/match_summary_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/matchmaking/matchmaking_screen.dart';
import 'features/matchmaking/queue_screen.dart';
import 'features/menu/main_menu_screen.dart';
import 'features/practice/practice_lobby_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/replay/replay_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/social/social_screen.dart';
import 'features/spectate/spectate_screen.dart';

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
  static const String practice = '/practice';
  static const String shop = '/shop';
  static const String spectate = '/spectate';
  static const String replay = '/replay';
  static const String codex = '/codex';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginScreen(),
      register: (context) => const RegisterScreen(),
      menu: (context) => const MainMenuScreen(),
      matchmaking: (context) => const MatchmakingScreen(),
      // NOTE: /queue, /game, /match-summary, and /replay take arguments and
      // are handled exclusively by onGenerateRoute — the static map would
      // swallow their arguments.
      profile: (context) => const ProfileScreen(),
      leaderboard: (context) => const LeaderboardScreen(),
      achievements: (context) => const AchievementsScreen(),
      settings: (context) => const SettingsScreen(),
      practice: (context) => const PracticeLobbyScreen(),
      social: (context) => const SocialScreen(),
      shop: (context) => const ShopScreen(),
      spectate: (context) => const SpectateScreen(),
      codex: (context) => const CodexScreen(),
    };
  }

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/queue':
        return MaterialPageRoute(
          builder: (context) {
            final args = settings.arguments as Map<String, dynamic>?;
            return QueueScreen(
              gameMode: args?['mode'] ?? 'RANKED_1V1',
            );
          },
        );
      case '/game':
        final matchArgs = settings.arguments;
        if (matchArgs is! MatchArgs) {
          // A match cannot start without its handoff payload.
          return MaterialPageRoute(
            builder: (context) => const MainMenuScreen(),
          );
        }
        return MaterialPageRoute(
          builder: (context) => MatchScreen(args: matchArgs),
        );
      case '/match-summary':
        return MaterialPageRoute(
          builder: (context) {
            final args = settings.arguments as Map<String, dynamic>?;
            return MatchSummaryScreen(matchData: args);
          },
        );
      case '/replay':
        final matchId = settings.arguments;
        return MaterialPageRoute(
          builder: (context) => matchId is String
              ? ReplayScreen(matchId: matchId)
              : const MainMenuScreen(),
        );
      default:
        // Static routes in getRoutes() handle everything else.
        return null;
    }
  }
}
