import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cyberpunk_button.dart';
import '../../../widgets/glow_card.dart';

class CipherPracticeWidget extends StatefulWidget {
  final String cipherType;
  final String encryptedText;
  final Map<String, dynamic> key_;
  final String answer;
  final VoidCallback onCorrect;

  const CipherPracticeWidget({
    Key? key,
    required this.cipherType,
    required this.encryptedText,
    required this.key_,
    required this.answer,
    required this.onCorrect,
  }) : super(key: key);

  @override
  State<CipherPracticeWidget> createState() => _CipherPracticeWidgetState();
}

class _CipherPracticeWidgetState extends State<CipherPracticeWidget> {
  final _answerController = TextEditingController();
  bool _isCorrect = false;
  bool _hasAttempted = false;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  void _checkAnswer() {
    setState(() {
      _hasAttempted = true;
      _isCorrect = _answerController.text.trim().toUpperCase() ==
                   widget.answer.trim().toUpperCase();
    });

    if (_isCorrect) {
      HapticFeedback.heavyImpact();
      widget.onCorrect();
    } else {
      HapticFeedback.mediumImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      glowVariant: _isCorrect ? GlowCardVariant.success : GlowCardVariant.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Title
          Text(
            'Practice: ${widget.cipherType}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.cyberBlue,
                ),
          ),

          const SizedBox(height: AppTheme.spacing2),

          // Key information
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.cyberBlue.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.key, color: AppTheme.cyberBlue, size: 20),
                const SizedBox(width: AppTheme.spacing1),
                Expanded(
                  child: Text(
                    _formatKey(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                        ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing2),

          // Encrypted text
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: AppTheme.darkNavy,
              borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              border: Border.all(
                color: AppTheme.neonRed.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Encrypted:',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.encryptedText,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTheme.neonRed,
                        letterSpacing: 2,
                      ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing2),

          // Answer input
          TextFormField(
            controller: _answerController,
            enabled: !_isCorrect,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Your Answer',
              hintText: 'Enter decrypted text',
              prefixIcon: Icon(
                _isCorrect
                    ? Icons.check_circle
                    : (_hasAttempted ? Icons.error : Icons.lock_open),
                color: _isCorrect
                    ? AppTheme.electricGreen
                    : (_hasAttempted ? AppTheme.neonRed : AppTheme.cyberBlue.withValues(alpha: 0.7)),
              ),
            ),
            onFieldSubmitted: (_) => _checkAnswer(),
          ),

          if (_hasAttempted) ...[
            const SizedBox(height: AppTheme.spacing2),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing2),
              decoration: BoxDecoration(
                color: (_isCorrect ? AppTheme.electricGreen : AppTheme.neonRed)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: _isCorrect ? AppTheme.electricGreen : AppTheme.neonRed,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isCorrect ? Icons.check_circle : Icons.error,
                    color: _isCorrect ? AppTheme.electricGreen : AppTheme.neonRed,
                    size: 20,
                  ),
                  const SizedBox(width: AppTheme.spacing1),
                  Expanded(
                    child: Text(
                      _isCorrect
                          ? 'Correct! Well done!'
                          : 'Incorrect. Try again!',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _isCorrect ? AppTheme.electricGreen : AppTheme.neonRed,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppTheme.spacing3),

          // Check button
          if (!_isCorrect)
            CyberpunkButton(
              label: 'CHECK ANSWER',
              onPressed: _checkAnswer,
              variant: CyberpunkButtonVariant.primary,
              icon: Icons.check,
              fullWidth: true,
            ),
        ],
      ),
    );
  }

  String _formatKey() {
    if (widget.key_.containsKey('shift')) {
      return 'Shift: ${widget.key_['shift']}';
    }
    if (widget.key_.containsKey('keyword')) {
      return 'Keyword: ${widget.key_['keyword']}';
    }
    return widget.key_.toString();
  }
}
