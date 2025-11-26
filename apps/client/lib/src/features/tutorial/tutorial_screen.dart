import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../widgets/glow_card.dart';
import 'widgets/cipher_practice_widget.dart';
import 'widgets/tutorial_progress_bar.dart';

class TutorialScreen extends ConsumerStatefulWidget {
  const TutorialScreen({super.key});

  @override
  ConsumerState<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends ConsumerState<TutorialScreen> {
  int currentStep = 0;
  final int totalSteps = 8;
  bool isLoading = false;

  final List<TutorialStepData> steps = [
    TutorialStepData(
      id: 'tutorial_welcome',
      title: 'Welcome to Cipher Clash',
      description:
          'Welcome to the world of competitive cryptography! In Cipher Clash, you\'ll battle opponents by solving encrypted puzzles faster than them. Let\'s learn the basics!',
      category: 'intro',
      xpReward: 25,
      hasInteraction: false,
    ),
    TutorialStepData(
      id: 'tutorial_caesar_intro',
      title: 'Caesar Cipher Basics',
      description:
          'The Caesar cipher shifts each letter by a fixed number. For example, with shift 3: A→D, B→E, C→F. Try decrypting the message below!',
      category: 'cipher_basics',
      cipherType: 'CAESAR',
      xpReward: 50,
      hasInteraction: true,
      practiceText: 'KHOOR',
      practiceKey: {'shift': 3},
      practiceAnswer: 'HELLO',
    ),
    TutorialStepData(
      id: 'tutorial_vigenere_intro',
      title: 'Vigenère Cipher',
      description:
          'The Vigenère cipher uses a keyword to shift letters differently. Each letter in the keyword determines the shift for the corresponding plaintext letter.',
      category: 'cipher_basics',
      cipherType: 'VIGENERE',
      xpReward: 75,
      hasInteraction: true,
      practiceText: 'RIJVS',
      practiceKey: {'key': 'KEY'},
      practiceAnswer: 'HELLO',
    ),
    TutorialStepData(
      id: 'tutorial_first_match',
      title: 'Your First Match',
      description:
          'Now it\'s time for your first battle! You\'ll face a training bot with easy puzzles. Don\'t worry - take your time and use hints if needed.',
      category: 'combat',
      xpReward: 100,
      hasInteraction: false,
      hasMatchButton: true,
    ),
    TutorialStepData(
      id: 'tutorial_rail_fence_intro',
      title: 'Rail Fence Cipher',
      description:
          'Rail Fence is a transposition cipher that writes the message in a zigzag pattern across multiple "rails", then reads it row by row.',
      category: 'cipher_basics',
      cipherType: 'RAIL_FENCE',
      xpReward: 75,
      hasInteraction: true,
      practiceText: 'HOREL',
      practiceKey: {'rails': 2},
      practiceAnswer: 'HELLO',
    ),
    TutorialStepData(
      id: 'tutorial_playfair_intro',
      title: 'Playfair Cipher',
      description:
          'Playfair encrypts pairs of letters (digraphs) using a 5x5 key matrix. It\'s one of the more complex classical ciphers!',
      category: 'cipher_basics',
      cipherType: 'PLAYFAIR',
      xpReward: 100,
      hasInteraction: true,
      practiceText: 'GDKKN',
      practiceKey: {'keyword': 'MONARCHY'},
      practiceAnswer: 'HELLO',
    ),
    TutorialStepData(
      id: 'tutorial_powerups',
      title: 'Using Power-Ups',
      description:
          'During matches, you can use power-ups to gain advantages:\n\n• Hint: Reveals a letter\n• Time Freeze: Pause opponent\'s timer\n• Auto-Solve: Complete current puzzle\n\nUse them wisely!',
      category: 'advanced',
      xpReward: 75,
      hasInteraction: false,
    ),
    TutorialStepData(
      id: 'tutorial_mastery_tree',
      title: 'Cipher Mastery Trees',
      description:
          'As you solve puzzles, you earn Mastery Points for each cipher type. Spend these points to unlock bonuses like faster solve times, score multipliers, and special abilities!',
      category: 'advanced',
      xpReward: 50,
      hasInteraction: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = steps[currentStep];

    return Scaffold(
      backgroundColor: AppTheme.deepDark,
      appBar: AppBar(
        title: Text(
          'Tutorial - Step ${currentStep + 1}/$totalSteps',
          style: AppTheme.headingMedium,
        ),
        backgroundColor: AppTheme.darkNavy,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: _skipTutorial,
            child: Text(
              'Skip',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          TutorialProgressBar(
            currentStep: currentStep,
            totalSteps: totalSteps,
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(AppTheme.spacing4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GlowCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getStepIcon(step.category),
                              color: AppTheme.cyberBlue,
                              size: 32,
                            ),
                            SizedBox(width: AppTheme.spacing2),
                            Expanded(
                              child: Text(
                                step.title,
                                style: AppTheme.headingLarge,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppTheme.spacing2),
                        Text(
                          step.description,
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.5,
                          ),
                        ),
                        if (step.cipherType != null) ...[
                          SizedBox(height: AppTheme.spacing2),
                          _buildCipherTypeBadge(step.cipherType!),
                        ],
                      ],
                    ),
                  ),

                  SizedBox(height: AppTheme.spacing4),

                  if (step.hasInteraction && step.cipherType != null)
                    CipherPracticeWidget(
                      cipherType: step.cipherType!,
                      encryptedText: step.practiceText!,
                      key_: step.practiceKey!,
                      answer: step.practiceAnswer!,
                      onCorrect: _handlePracticeComplete,
                    ),

                  if (step.hasMatchButton) _buildMatchButton(),

                  SizedBox(height: AppTheme.spacing4),
                  _buildRewardDisplay(step.xpReward),
                ],
              ),
            ),
          ),

          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildCipherTypeBadge(String cipherType) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppTheme.spacing2,
        vertical: AppTheme.spacing1,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.cyberBlue.withValues(alpha: 0.3),
            AppTheme.neonPurple.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(
          color: AppTheme.cyberBlue,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lock_outline,
            color: AppTheme.cyberBlue,
            size: 16,
          ),
          SizedBox(width: AppTheme.spacing1),
          Text(
            cipherType.replaceAll('_', ' '),
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.cyberBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchButton() {
    return CyberpunkButton(
      label: 'START TRAINING MATCH',
      onPressed: _startBotBattle,
      icon: Icons.sports_martial_arts,
      variant: CyberpunkButtonVariant.success,
    );
  }

  Widget _buildRewardDisplay(int xp) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.electricGreen.withValues(alpha: 0.2),
            AppTheme.electricGreen.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(
          color: AppTheme.electricGreen.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star,
            color: AppTheme.electricGreen,
            size: 24,
          ),
          SizedBox(width: AppTheme.spacing2),
          Text(
            'Complete for +$xp XP',
            style: AppTheme.bodyLarge.copyWith(
              color: AppTheme.electricGreen,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacing3),
      decoration: BoxDecoration(
        color: AppTheme.darkNavy,
        boxShadow: [
          BoxShadow(
            color: AppTheme.cyberBlue.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (currentStep > 0)
            Expanded(
              child: CyberpunkButton(
                label: 'PREVIOUS',
                onPressed: _previousStep,
                icon: Icons.arrow_back,
                variant: CyberpunkButtonVariant.ghost,
              ),
            ),
          if (currentStep > 0) SizedBox(width: AppTheme.spacing2),
          Expanded(
            flex: 2,
            child: CyberpunkButton(
              label: currentStep == totalSteps - 1
                  ? 'COMPLETE TUTORIAL'
                  : 'NEXT',
              onPressed: _nextStep,
              icon: currentStep == totalSteps - 1
                  ? Icons.check_circle
                  : Icons.arrow_forward,
              variant: CyberpunkButtonVariant.primary,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(String category) {
    switch (category) {
      case 'intro':
        return Icons.waving_hand;
      case 'cipher_basics':
        return Icons.lock_outline;
      case 'combat':
        return Icons.sports_martial_arts;
      case 'advanced':
        return Icons.trending_up;
      default:
        return Icons.lightbulb_outline;
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
    }
  }

  void _nextStep() {
    final step = steps[currentStep];

    if (step.hasInteraction && !_isStepCompleted(currentStep)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Complete the practice exercise to continue!'),
          backgroundColor: AppTheme.neonPurple,
        ),
      );
      return;
    }

    if (currentStep < totalSteps - 1) {
      setState(() {
        currentStep++;
      });
    } else {
      _completeTutorial();
    }
  }

  bool _isStepCompleted(int stepIndex) {
    return true;
  }

  void _handlePracticeComplete() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.electricGreen),
            SizedBox(width: AppTheme.spacing2),
            Text('Correct! Well done!'),
          ],
        ),
        backgroundColor: AppTheme.darkNavy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startBotBattle() {
    Navigator.pushNamed(context, '/bot-battle');
  }

  void _skipTutorial() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        title: Text('Skip Tutorial?', style: AppTheme.headingMedium),
        content: Text(
          'You can always access the tutorial later from Settings. Skip now?',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/menu');
            },
            child: Text('Skip', style: TextStyle(color: AppTheme.cyberBlue)),
          ),
        ],
      ),
    );
  }

  void _completeTutorial() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        title: Row(
          children: [
            Icon(Icons.celebration, color: AppTheme.electricGreen, size: 32),
            SizedBox(width: AppTheme.spacing2),
            Text('Tutorial Complete!', style: AppTheme.headingMedium),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'You\'ve completed the tutorial and earned ${steps.fold<int>(0, (sum, step) => sum + step.xpReward)} XP!',
              style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppTheme.spacing3),
            Text(
              'Ready to battle?',
              style: AppTheme.bodyLarge.copyWith(
                color: AppTheme.cyberBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          CyberpunkButton(
            label: 'Enter Cipher Clash!',
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/menu');
            },
            icon: Icons.arrow_forward,
            variant: CyberpunkButtonVariant.primary,
          ),
        ],
      ),
    );
  }
}

class TutorialStepData {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? cipherType;
  final int xpReward;
  final bool hasInteraction;
  final bool hasMatchButton;
  final String? practiceText;
  final Map<String, dynamic>? practiceKey;
  final String? practiceAnswer;

  TutorialStepData({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.cipherType,
    required this.xpReward,
    this.hasInteraction = false,
    this.hasMatchButton = false,
    this.practiceText,
    this.practiceKey,
    this.practiceAnswer,
  });
}
