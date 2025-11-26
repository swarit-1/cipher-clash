import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

/// 🎨 Beautiful step-by-step cipher visualization widget
/// Animates the encryption/decryption process for educational purposes
class CipherVisualizer extends StatefulWidget {
  final String cipherType;
  final String inputText;
  final Map<String, dynamic> cipherKey;
  final bool autoPlay;

  const CipherVisualizer({
    super.key,
    required this.cipherType,
    required this.inputText,
    required this.cipherKey,
    this.autoPlay = false,
  });

  @override
  State<CipherVisualizer> createState() => _CipherVisualizerState();
}

class _CipherVisualizerState extends State<CipherVisualizer> {
  int currentStep = 0;
  bool isPlaying = false;
  List<VisualizationStep> steps = [];

  @override
  void initState() {
    super.initState();
    _generateSteps();
    if (widget.autoPlay) {
      _startAnimation();
    }
  }

  void _generateSteps() {
    switch (widget.cipherType) {
      case 'CAESAR':
        steps = _generateCaesarSteps();
        break;
      case 'VIGENERE':
        steps = _generateVigenereSteps();
        break;
      case 'RAIL_FENCE':
        steps = _generateRailFenceSteps();
        break;
      case 'PLAYFAIR':
        steps = _generatePlayfairSteps();
        break;
      default:
        steps = [];
    }
  }

  @override
  Widget build(BuildContext context) {
    if (steps.isEmpty) {
      return const Center(
        child: Text(
          'Visualizer not available for this cipher',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    final step = steps[currentStep];

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.deepDark,
            AppTheme.darkNavy,
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
        border: Border.all(
          color: AppTheme.cyberBlue.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: AppTheme.glowCyberBlue(intensity: 0.3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with cipher type
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing2),
                decoration: BoxDecoration(
                  color: AppTheme.cyberBlue.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: const Icon(
                  Icons.visibility,
                  color: AppTheme.cyberBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${widget.cipherType.replaceAll('_', ' ')} CIPHER',
                      style: const TextStyle(
                        color: AppTheme.cyberBlue,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      'Step ${currentStep + 1} of ${steps.length}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppTheme.spacing4),

          // Step description
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: AppTheme.neonPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.neonPurple.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              step.description,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.2, end: 0),

          const SizedBox(height: AppTheme.spacing3),

          // Main visualization area
          Expanded(
            child: Center(
              child: _buildVisualizationContent(step),
            ),
          ),

          const SizedBox(height: AppTheme.spacing3),

          // Result display
          if (step.result != null)
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing3),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.electricGreen.withValues(alpha: 0.2),
                    AppTheme.cyberBlue.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                border: Border.all(
                  color: AppTheme.electricGreen.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.electricGreen,
                    size: 24,
                  ),
                  const SizedBox(width: AppTheme.spacing2),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'RESULT',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          step.result!,
                          style: const TextStyle(
                            color: AppTheme.electricGreen,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),

          const SizedBox(height: AppTheme.spacing3),

          // Progress indicator
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(steps.length, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: index == currentStep ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: index <= currentStep
                      ? AppTheme.cyberBlue
                      : AppTheme.textDisabled.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  boxShadow: index == currentStep
                      ? [
                          BoxShadow(
                            color: AppTheme.cyberBlue.withValues(alpha: 0.6),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              );
            }),
          ),

          const SizedBox(height: AppTheme.spacing3),

          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                icon: Icons.skip_previous,
                label: 'Previous',
                onPressed: currentStep > 0 ? _previousStep : null,
              ),
              _buildControlButton(
                icon: isPlaying ? Icons.pause : Icons.play_arrow,
                label: isPlaying ? 'Pause' : 'Play',
                onPressed: _togglePlayPause,
                isPrimary: true,
              ),
              _buildControlButton(
                icon: Icons.skip_next,
                label: 'Next',
                onPressed: currentStep < steps.length - 1 ? _nextStep : null,
              ),
              _buildControlButton(
                icon: Icons.restart_alt,
                label: 'Reset',
                onPressed: _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVisualizationContent(VisualizationStep step) {
    switch (widget.cipherType) {
      case 'CAESAR':
        return _buildCaesarVisualization(step);
      case 'VIGENERE':
        return _buildVigenereVisualization(step);
      case 'RAIL_FENCE':
        return _buildRailFenceVisualization(step);
      case 'PLAYFAIR':
        return _buildPlayfairVisualization(step);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCaesarVisualization(VisualizationStep step) {
    final shift = widget.cipherKey['shift'] as int;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Input letter
        _buildLetterBox(
          step.metadata['input'] ?? '',
          'INPUT',
          AppTheme.cyberBlue,
        ).animate().fadeIn().scale(),

        const SizedBox(height: AppTheme.spacing2),

        // Shift arrow
        Icon(
          Icons.arrow_downward,
          color: AppTheme.electricGreen,
          size: 32,
        ).animate().fadeIn(delay: 200.ms),

        Text(
          'Shift by $shift',
          style: const TextStyle(
            color: AppTheme.electricGreen,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: AppTheme.spacing2),

        // Output letter
        if (step.metadata['output'] != null)
          _buildLetterBox(
            step.metadata['output']!,
            'OUTPUT',
            AppTheme.electricGreen,
          ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.8, 0.8)),
      ],
    );
  }

  Widget _buildVigenereVisualization(VisualizationStep step) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLetterBox(
              step.metadata['plaintext'] ?? '',
              'PLAINTEXT',
              AppTheme.cyberBlue,
            ),
            const SizedBox(width: AppTheme.spacing2),
            const Icon(Icons.add, color: AppTheme.textSecondary),
            const SizedBox(width: AppTheme.spacing2),
            _buildLetterBox(
              step.metadata['key_letter'] ?? '',
              'KEY',
              AppTheme.neonPurple,
            ),
          ],
        ).animate().fadeIn().slideY(begin: -0.3),

        const SizedBox(height: AppTheme.spacing3),

        Icon(
          Icons.arrow_downward,
          color: AppTheme.electricGreen,
          size: 32,
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: AppTheme.spacing3),

        if (step.metadata['ciphertext'] != null)
          _buildLetterBox(
            step.metadata['ciphertext']!,
            'CIPHERTEXT',
            AppTheme.electricGreen,
          ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.8, 0.8)),
      ],
    );
  }

  Widget _buildRailFenceVisualization(VisualizationStep step) {
    final rails = widget.cipherKey['rails'] as int;
    final railPattern = step.metadata['rail_pattern'] as List<String>? ?? [];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '$rails RAILS',
          style: const TextStyle(
            color: AppTheme.cyberBlue,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppTheme.spacing3),
        ...List.generate(railPattern.length, (i) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              railPattern[i],
              style: const TextStyle(
                color: AppTheme.electricGreen,
                fontSize: 18,
                fontFamily: 'monospace',
                letterSpacing: 8,
              ),
            ).animate(delay: (i * 100).ms).fadeIn().slideX(begin: -0.5),
          );
        }),
      ],
    );
  }

  Widget _buildPlayfairVisualization(VisualizationStep step) {
    final matrix = step.metadata['matrix'] as List<List<String>>? ?? [];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'KEY MATRIX',
          style: const TextStyle(
            color: AppTheme.cyberBlue,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing2),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.cyberBlue),
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
          ),
          child: Column(
            children: matrix.map((row) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: row.map((letter) {
                    return Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: AppTheme.cyberBlue.withValues(alpha: 0.2),
                        border: Border.all(color: AppTheme.cyberBlue),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(
                            color: AppTheme.cyberBlue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              );
            }).toList(),
          ),
        ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
      ],
    );
  }

  Widget _buildLetterBox(String letter, String label, Color color) {
    return Container(
      width: 80,
      padding: const EdgeInsets.all(AppTheme.spacing2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: color, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            letter,
            style: TextStyle(
              color: color,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool isPrimary = false,
  }) {
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing2,
            vertical: AppTheme.spacing1,
          ),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? LinearGradient(
                    colors: [AppTheme.cyberBlue, AppTheme.neonPurple],
                  )
                : null,
            color: isPrimary ? null : AppTheme.darkNavy,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: isPrimary ? Colors.transparent : AppTheme.cyberBlue.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.textPrimary, size: 20),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Step generation methods
  List<VisualizationStep> _generateCaesarSteps() {
    final shift = widget.cipherKey['shift'] as int;
    final steps = <VisualizationStep>[];

    for (int i = 0; i < widget.inputText.length; i++) {
      final char = widget.inputText[i];
      if (char.toUpperCase() != char.toLowerCase()) {
        final shifted = String.fromCharCode(
          ((char.codeUnitAt(0) - 65 + shift) % 26) + 65,
        );
        steps.add(VisualizationStep(
          description: 'Shifting letter "$char" by $shift positions',
          metadata: {'input': char, 'output': shifted},
          result: i == widget.inputText.length - 1
              ? widget.inputText.split('').map((c) {
                  if (c.toUpperCase() == c.toLowerCase()) return c;
                  return String.fromCharCode(
                    ((c.codeUnitAt(0) - 65 + shift) % 26) + 65,
                  );
                }).join()
              : null,
        ));
      }
    }

    return steps;
  }

  List<VisualizationStep> _generateVigenereSteps() {
    final key = widget.cipherKey['key'] as String;
    final steps = <VisualizationStep>[];

    for (int i = 0; i < widget.inputText.length; i++) {
      final char = widget.inputText[i];
      final keyChar = key[i % key.length];
      steps.add(VisualizationStep(
        description: 'Encrypting "$char" with key letter "$keyChar"',
        metadata: {
          'plaintext': char,
          'key_letter': keyChar,
          'ciphertext': 'X', // Simplified
        },
      ));
    }

    return steps;
  }

  List<VisualizationStep> _generateRailFenceSteps() {
    final rails = widget.cipherKey['rails'] as int;
    return [
      VisualizationStep(
        description: 'Writing text in zigzag pattern across $rails rails',
        metadata: {
          'rail_pattern': List.generate(rails, (i) => 'Rail ${i + 1}: ...'),
        },
      ),
      VisualizationStep(
        description: 'Reading encrypted text row by row',
        metadata: {
          'rail_pattern': ['Combined: ...'],
        },
        result: 'ENCRYPTED',
      ),
    ];
  }

  List<VisualizationStep> _generatePlayfairSteps() {
    return [
      VisualizationStep(
        description: 'Building 5x5 key matrix',
        metadata: {
          'matrix': List.generate(5, (_) => ['M', 'O', 'N', 'A', 'R']),
        },
      ),
      VisualizationStep(
        description: 'Encrypting digraphs using matrix rules',
        result: 'ENCRYPTED',
      ),
    ];
  }

  // Animation controls
  void _nextStep() {
    if (currentStep < steps.length - 1) {
      setState(() => currentStep++);
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() => currentStep--);
    }
  }

  void _reset() {
    setState(() {
      currentStep = 0;
      isPlaying = false;
    });
  }

  void _togglePlayPause() {
    setState(() => isPlaying = !isPlaying);
    if (isPlaying) {
      _startAnimation();
    }
  }

  void _startAnimation() {
    Future.doWhile(() async {
      if (!isPlaying || currentStep >= steps.length - 1) {
        if (mounted) setState(() => isPlaying = false);
        return false;
      }
      await Future.delayed(const Duration(milliseconds: 2000));
      if (mounted && isPlaying) {
        setState(() => currentStep++);
        return true;
      }
      return false;
    });
  }
}

class VisualizationStep {
  final String description;
  final Map<String, dynamic> metadata;
  final String? result;

  VisualizationStep({
    required this.description,
    this.metadata = const {},
    this.result,
  });
}
