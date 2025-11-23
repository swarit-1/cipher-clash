import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/terminal_theme.dart';
import '../duel/duel_screen.dart';

class WorkbenchScreen extends ConsumerWidget {
  const WorkbenchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CIPHER CLASH // WORKBENCH'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusPanel(),
            const SizedBox(height: 20),
            Expanded(
              child: _buildToolsGrid(context),
            ),
            const SizedBox(height: 20),
            _buildMatchButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: TerminalTheme.primary),
        color: TerminalTheme.background,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('OPERATOR: GHOST_1'),
          Text('STATUS: ONLINE'),
          Text('RATING: 1200 [UNRANKED]'),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      children: [
        _buildToolCard('CIPHER_ANALYZER', Icons.analytics),
        _buildToolCard('FREQUENCY_MAP', Icons.bar_chart),
        _buildToolCard('HISTORY_LOG', Icons.history),
        _buildToolCard('SETTINGS', Icons.settings),
      ],
    );
  }

  Widget _buildToolCard(String title, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: TerminalTheme.secondary.withOpacity(0.5)),
        color: TerminalTheme.background,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: TerminalTheme.secondary),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: TerminalTheme.secondary)),
        ],
      ),
    );
  }

  Widget _buildMatchButton(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DuelScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: TerminalTheme.primary.withOpacity(0.1),
        ),
        child: const Text('INITIATE_DUEL_SEQUENCE()'),
      ),
    );
  }
}
