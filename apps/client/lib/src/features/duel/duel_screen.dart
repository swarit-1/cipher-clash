import 'dart:async';
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

  // Game State
  bool _isSuccess = false;
  bool _isFailure = false;

  // Ghost Protocol (AI Opponent)
  Timer? _botTimer;
  double _botProgress = 0.0;
  bool _isGameOver = false;

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
          _startBot();
        }
      });
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _botTimer?.cancel();
    super.dispose();
  }

  void _startBot() {
    _botTimer?.cancel();
    _botProgress = 0.0;
    _isGameOver = false;

    // Bot progresses every 500ms
    _botTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) return;

      setState(() {
        _botProgress += 0.02; // 2% every 500ms

        if (_botProgress >= 1.0) {
          _botProgress = 1.0;
          _isGameOver = true;
          _botTimer?.cancel();
        }
      });
    });
  }

  void _validateSolution(String input) {
    if (_isGameOver) return;

    final puzzleState = ref.read(puzzleStateProvider);
    if (puzzleState == null) return;

    final normalizedInput = input.trim().toUpperCase();
    final normalizedSolution = puzzleState.solution.trim().toUpperCase();

    if (normalizedInput == normalizedSolution) {
      _botTimer?.cancel();
      setState(() {
        _isSuccess = true;
        _isFailure = false;
      });
      // Trigger success action
      ref.read(gameServiceProvider).sendAction('SOLVED', {});
    } else {
      setState(() {
        _isFailure = true;
        _inputController.clear();
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isFailure = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
      body: Stack(
        children: [
          Column(
            children: [
              _buildOpponentBar(_botProgress),
              Expanded(
                child: Row(
                  children: [
                    Expanded(child: _buildPuzzleView(puzzleState)),
                    Container(
                        width: 1,
                        color: TerminalTheme.secondary.withValues(alpha: 0.3)),
                    Expanded(child: _buildWorkspace()),
                  ],
                ),
              ),
            ],
          ),
          if (_isSuccess)
            Container(
              color: Colors.green.withValues(alpha: 0.2),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.green, width: 2),
                    color: Colors.black87,
                  ),
                  child: const Text(
                    'ACCESS GRANTED',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                ),
              ),
            ),
          if (_isFailure)
            IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: Colors.red.withValues(alpha: 0.5), width: 4),
                ),
              ),
            ),
          if (_isGameOver)
            Container(
              color: Colors.red.withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.black, size: 80),
                    const SizedBox(height: 20),
                    const Text(
                      'SYSTEM HACKED',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'NEMESIS_X HAS BREACHED THE FIREWALL',
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.red,
                      ),
                      onPressed: () {
                        // Restart game
                        _startBot();
                        setState(() {
                          _inputController.clear();
                          _isSuccess = false;
                          _isFailure = false;
                        });
                      },
                      child: const Text('REBOOT_SYSTEM()'),
                    ),
                  ],
                ),
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
            bottom: BorderSide(
                color: TerminalTheme.secondary.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const Text('OPPONENT: NEMESIS_X'),
          const Spacer(),
          SizedBox(
            width: 200,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: TerminalTheme.secondary.withValues(alpha: 0.1),
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
                border: Border.all(
                    color: TerminalTheme.secondary.withValues(alpha: 0.3)),
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
              ref.read(gameServiceProvider).sendAction('KEYSTROKE',
                  {'char': value.isNotEmpty ? value[value.length - 1] : ''});
            },
            onSubmitted: (value) => _validateSolution(value),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                _validateSolution(_inputController.text);
              },
              child: const Text('SUBMIT_SOLUTION()'),
            ),
          ),
        ],
      ),
    );
  }
}
