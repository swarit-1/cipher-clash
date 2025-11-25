import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';

class EnhancedGameScreen extends StatefulWidget {
  const EnhancedGameScreen({Key? key}) : super(key: key);

  @override
  State<EnhancedGameScreen> createState() => _EnhancedGameScreenState();
}

class _EnhancedGameScreenState extends State<EnhancedGameScreen>
    with TickerProviderStateMixin {
  final _solutionController = TextEditingController();
  late AnimationController _timerController;
  late AnimationController _pulseController;
  late ConfettiController _confettiController;

  Timer? _countdownTimer;
  int _remainingSeconds = 120; // 2 minutes
  bool _gameActive = true;
  bool _isPlayerWinner = false;
  String _gameResult = '';
  int _currentPuzzleIndex = 0;
  int _playerPuzzlesSolved = 0;
  int _opponentPuzzlesSolved = 0;

  // Three puzzles per round
  final List<Map<String, dynamic>> _puzzles = [
    {
      'cipherType': 'CAESAR',
      'difficulty': 5,
      'encryptedText': 'KHOOR ZRUOG',
      'solution': 'HELLO WORLD',
      'hint': 'Shift by 3',
    },
    {
      'cipherType': 'VIGENERE',
      'difficulty': 7,
      'encryptedText': 'RIJVS UYVJN',
      'solution': 'HELLO WORLD',
      'hint': 'Keyword: LEMON',
    },
    {
      'cipherType': 'ATBASH',
      'difficulty': 6,
      'encryptedText': 'SVOOL DLIOW',
      'solution': 'HELLO WORLD',
      'hint': 'Reverse alphabet',
    },
  ];

  // Player info - TODO: Replace with actual game state
  final Map<String, dynamic> _gameData = {
    'playerName': 'You',
    'opponentName': 'CipherKing',
    'playerElo': 1650,
    'opponentElo': 1680,
  };

  @override
  void initState() {
    super.initState();

    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _remainingSeconds),
    )..forward();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );

    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingSeconds <= 0) {
        timer.cancel();
        _onTimeUp();
        return;
      }

      setState(() => _remainingSeconds--);

      // Warning state at 30 seconds
      if (_remainingSeconds == 30) {
        HapticFeedback.mediumImpact();
      }

      // Critical state at 10 seconds
      if (_remainingSeconds == 10) {
        HapticFeedback.heavyImpact();
      }
    });
  }

  void _onTimeUp() {
    setState(() {
      _gameActive = false;
      _gameResult = 'TIME UP!';
      _isPlayerWinner = false;
    });
    HapticFeedback.heavyImpact();
    _navigateToSummary();
  }

  void _submitSolution() {
    if (_solutionController.text.isEmpty) return;

    HapticFeedback.mediumImpact();

    // Check solution against current puzzle
    final currentPuzzle = _puzzles[_currentPuzzleIndex];
    final isCorrect = _solutionController.text.toUpperCase() == currentPuzzle['solution'];

    if (isCorrect) {
      _onCorrectSolution();
    } else {
      _onIncorrectSolution();
    }
  }

  void _onCorrectSolution() {
    setState(() {
      _playerPuzzlesSolved++;
      _solutionController.clear();
    });

    HapticFeedback.heavyImpact();

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle_outline, color: AppTheme.electricGreen),
            const SizedBox(width: 8),
            Text('Correct! Puzzle ${_currentPuzzleIndex + 1}/3 solved'),
          ],
        ),
        backgroundColor: AppTheme.electricGreen.withValues(alpha: 0.2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    // Check if all puzzles are solved
    if (_currentPuzzleIndex >= _puzzles.length - 1) {
      // Won the game
      setState(() {
        _gameActive = false;
        _gameResult = 'VICTORY!';
        _isPlayerWinner = true;
      });
      _confettiController.play();
      _navigateToSummary();
    } else {
      // Move to next puzzle
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) {
          setState(() {
            _currentPuzzleIndex++;
          });
        }
      });

      // Simulate opponent progress (random)
      _simulateOpponentProgress();
    }
  }

  void _simulateOpponentProgress() {
    // Simulate opponent solving puzzles with some randomness
    Future.delayed(Duration(seconds: 5 + (_currentPuzzleIndex * 3)), () {
      if (mounted && _gameActive && _opponentPuzzlesSolved < _currentPuzzleIndex) {
        setState(() {
          _opponentPuzzlesSolved++;
        });
      }
    });
  }

  void _onIncorrectSolution() {
    HapticFeedback.mediumImpact();

    // Shake animation for incorrect answer
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.neonRed),
            const SizedBox(width: 8),
            const Text('Incorrect solution! Try again'),
          ],
        ),
        backgroundColor: AppTheme.neonRed.withValues(alpha: 0.2),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );

    _solutionController.clear();
  }

  void _navigateToSummary() {
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/match-summary',
        arguments: {
          'isWinner': _isPlayerWinner,
          'playerScore': _playerPuzzlesSolved * 500,
          'opponentScore': _opponentPuzzlesSolved * 500,
          'solveTime': 120 - _remainingSeconds,
          'xpGained': _isPlayerWinner ? 125 : 25,
          'eloChange': _isPlayerWinner ? 18 : -12,
        },
      );
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _timerController.dispose();
    _pulseController.dispose();
    _confettiController.dispose();
    _solutionController.dispose();
    super.dispose();
  }

  Color get _timerColor {
    if (_remainingSeconds > 60) return AppTheme.cyberBlue;
    if (_remainingSeconds > 30) return AppTheme.electricYellow;
    return AppTheme.neonRed;
  }

  String get _formattedTime {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Timer Header
                  _buildTimerHeader(),

                  // Players Info
                  _buildPlayersInfo(),

                  const SizedBox(height: AppTheme.spacing2),

                  // Cipher Display
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppTheme.spacing2),
                      child: Column(
                        children: [
                          _buildCipherCard(),
                          const SizedBox(height: AppTheme.spacing2),
                          _buildSolutionInput(),
                          const SizedBox(height: AppTheme.spacing2),
                          _buildHintCard(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Confetti overlay
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.05,
                numberOfParticles: 50,
                gravity: 0.2,
                colors: const [
                  AppTheme.cyberBlue,
                  AppTheme.neonPurple,
                  AppTheme.electricGreen,
                  AppTheme.electricYellow,
                ],
              ),
            ),

            // Game Result Overlay
            if (!_gameActive) _buildGameResultOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildTimerHeader() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      decoration: BoxDecoration(
        color: AppTheme.deepDark.withValues(alpha: 0.95),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          // Timer display
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing3,
                  vertical: AppTheme.spacing2,
                ),
                decoration: BoxDecoration(
                  color: _timerColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
                  border: Border.all(
                    color: _timerColor.withValues(
                      alpha: 0.5 + (_pulseController.value * 0.5),
                    ),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _timerColor.withValues(
                        alpha: 0.3 * _pulseController.value,
                      ),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Text(
                  _formattedTime,
                  style: Theme.of(context).textTheme.displayMedium?.copyWith(
                        color: _timerColor,
                        fontWeight: FontWeight.w900,
                        fontFamily: 'monospace',
                      ),
                ),
              );
            },
          ),

          const SizedBox(height: AppTheme.spacing1),

          // Timer progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            child: AnimatedBuilder(
              animation: _timerController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: 1 - _timerController.value,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(_timerColor),
                  minHeight: 6,
                );
              },
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPlayersInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing3),
      child: Row(
        children: [
          // Player
          Expanded(
            child: _buildPlayerCard(
              _gameData['playerName'],
              _gameData['playerElo'],
              _playerPuzzlesSolved,
              AppTheme.cyberBlue,
              true,
            ),
          ),

          // VS Indicator with progress
          Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing2),
                padding: const EdgeInsets.all(AppTheme.spacing1),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                ),
                child: const Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Puzzle ${_currentPuzzleIndex + 1}/3',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
              ),
            ],
          ),

          // Opponent
          Expanded(
            child: _buildPlayerCard(
              _gameData['opponentName'],
              _gameData['opponentElo'],
              _opponentPuzzlesSolved,
              AppTheme.neonPurple,
              false,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildPlayerCard(
    String name,
    int elo,
    int score,
    Color color,
    bool isPlayer,
  ) {
    return GlowCard(
      glowVariant: isPlayer ? GlowCardVariant.primary : GlowCardVariant.secondary,
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.2),
              border: Border.all(color: color, width: 2),
            ),
            child: Icon(Icons.person, color: color, size: 24),
          ),

          const SizedBox(height: AppTheme.spacing1),

          // Name
          Text(
            name,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          // ELO
          Text(
            '$elo ELO',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: AppTheme.spacing1),

          // Puzzles Solved
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing1,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            ),
            child: Text(
              '$score/3 Solved',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCipherCard() {
    final currentPuzzle = _puzzles[_currentPuzzleIndex];

    return GlowCard(
      glowVariant: GlowCardVariant.success,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cipher type badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing2,
                  vertical: AppTheme.spacing1,
                ),
                decoration: BoxDecoration(
                  gradient: AppTheme.accentGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  currentPuzzle['cipherType'],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing1),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing1,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.getDifficultyColor(currentPuzzle['difficulty'])
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: AppTheme.getDifficultyColor(currentPuzzle['difficulty']),
                  ),
                ),
                child: Text(
                  'Difficulty ${currentPuzzle['difficulty']}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.getDifficultyColor(currentPuzzle['difficulty']),
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing3),

          // Encrypted text
          Text(
            'Encrypted Text:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),

          const SizedBox(height: AppTheme.spacing1),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              border: Border.all(
                color: AppTheme.electricGreen.withValues(alpha: 0.3),
              ),
            ),
            child: SelectableText(
              currentPuzzle['encryptedText'],
              style: AppTheme.monoStyleLarge,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).scale();
  }

  Widget _buildSolutionInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _solutionController,
          enabled: _gameActive,
          textAlign: TextAlign.center,
          style: AppTheme.monoStyle.copyWith(fontSize: 18),
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _submitSolution(),
          decoration: const InputDecoration(
            labelText: 'Your Solution',
            hintText: 'Enter decrypted text...',
            prefixIcon: Icon(Icons.edit_outlined),
          ),
        ),

        const SizedBox(height: AppTheme.spacing2),

        CyberpunkButton(
          label: 'SUBMIT SOLUTION',
          onPressed: _gameActive ? _submitSolution : null,
          variant: CyberpunkButtonVariant.success,
          icon: Icons.send,
          fullWidth: true,
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _buildHintCard() {
    final currentPuzzle = _puzzles[_currentPuzzleIndex];

    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Row(
        children: [
          const Icon(
            Icons.lightbulb_outline,
            color: AppTheme.electricYellow,
            size: 24,
          ),
          const SizedBox(width: AppTheme.spacing2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hint',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppTheme.electricYellow,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentPuzzle['hint'],
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 500.ms);
  }

  Widget _buildGameResultOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.8),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _gameResult,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: _isPlayerWinner
                        ? AppTheme.electricGreen
                        : AppTheme.neonRed,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

            const SizedBox(height: AppTheme.spacing3),

            Text(
              _isPlayerWinner ? 'You solved it first!' : 'Better luck next time',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }
}
