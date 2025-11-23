import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/terminal_theme.dart';
import '../game/game_service.dart';

class DuelScreen extends ConsumerStatefulWidget {
  const DuelScreen({super.key});

  @override
  ConsumerState<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends ConsumerState<DuelScreen> {
  final TextEditingController _inputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final gameService = ref.read(gameServiceProvider);
      gameService.connect('ws://localhost:8080/ws');

      // Listen for updates
      gameService.gameEvents.listen((event) {
        if (event['type'] == 'PUZZLE_UPDATE') {
          ref.read(puzzleStateProvider.notifier).state =
              event['data'] as PuzzleState;
        }
      });
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    // ref.read(gameServiceProvider).disconnect(); // Keep connection alive for now or handle in provider
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opponentProgress = ref.watch(opponentProgressProvider);
    final puzzleState = ref.watch(puzzleStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('DUEL_MODE // ACTIVE'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.warning, color: TerminalTheme.error),
            onPressed: () {
              ref.read(gameServiceProvider).sendAction('SURRENDER', {});
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildOpponentBar(opponentProgress),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildPuzzleView(puzzleState)),
                Container(
                    width: 1, color: TerminalTheme.secondary.withOpacity(0.3)),
                Expanded(child: _buildWorkspace()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpponentBar(double progress) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
            bottom:
                BorderSide(color: TerminalTheme.secondary.withOpacity(0.3))),
      ),
      child: Row(
        children: [
          const Text('OPPONENT: NEMESIS_X'),
          const Spacer(),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: TerminalTheme.secondary.withOpacity(0.1),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(TerminalTheme.error),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleView(PuzzleState? state) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ENCRYPTED_DATA_STREAM:',
              style: TextStyle(color: TerminalTheme.secondary)),
          const SizedBox(height: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black26,
                border:
                    Border.all(color: TerminalTheme.secondary.withOpacity(0.3)),
              ),
              child: Text(
                state?.encryptedText ?? 'WAITING_FOR_STREAM...',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 24,
                  letterSpacing: 2.0,
                  color: TerminalTheme.primary,
                ),
              ),
            ),
          ),
          if (state != null) ...[
            const SizedBox(height: 10),
            Text('CIPHER: ${state.cipherType} // DIFF: ${state.difficulty}'),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspace() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('DECRYPTION_CONSOLE:',
              style: TextStyle(color: TerminalTheme.secondary)),
          const SizedBox(height: 10),
          TextField(
            controller: _inputController,
            style: const TextStyle(
              fontFamily: 'Courier',
              fontSize: 24,
              color: TerminalTheme.primary,
            ),
            decoration: const InputDecoration(
              border: OutlineInputBorder(
                borderSide: BorderSide(color: TerminalTheme.primary),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: TerminalTheme.secondary),
              ),
              hintText: 'ENTER_PLAINTEXT',
              hintStyle: TextStyle(color: Colors.white24),
            ),
            onChanged: (value) {
              // Send keystrokes for visualization
              ref.read(gameServiceProvider).sendAction('KEYSTROKE',
                  {'char': value.isNotEmpty ? value[value.length - 1] : ''});
            },
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                ref
                    .read(gameServiceProvider)
                    .sendAction('SUBMIT', {'guess': _inputController.text});
                _inputController.clear();
              },
              child: const Text('SUBMIT_SOLUTION()'),
            ),
          ),
        ],
      ),
    );
  }
}
