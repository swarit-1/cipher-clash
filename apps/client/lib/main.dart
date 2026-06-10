import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'src/app_routes.dart';
import 'src/core/env.dart';
import 'src/core/token_store.dart';
import 'src/data/demo/demo_backend.dart';
import 'src/services/auth_service.dart';
import 'src/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: AppTheme.deepDark,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  await TokenStore.init();
  if (Env.demoMode) {
    DemoBackend.install();
  }
  final signedIn = await AuthService.restore();

  runApp(ProviderScope(child: CipherClashApp(signedIn: signedIn)));
}

class CipherClashApp extends StatelessWidget {
  const CipherClashApp({super.key, required this.signedIn});

  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cipher Clash',
      theme: AppTheme.darkTheme,
      initialRoute: signedIn ? AppRoutes.menu : AppRoutes.login,
      routes: AppRoutes.getRoutes(),
      onGenerateRoute: AppRoutes.onGenerateRoute,
      debugShowCheckedModeBanner: false,
    );
  }
}
