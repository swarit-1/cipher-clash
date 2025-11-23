import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'src/theme/terminal_theme.dart';
import 'src/features/workbench/workbench_screen.dart';

void main() {
  runApp(const ProviderScope(child: CipherClashApp()));
}

class CipherClashApp extends StatelessWidget {
  const CipherClashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cipher Clash',
      theme: TerminalTheme.darkTheme,
      home: const WorkbenchScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
