import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/practice_service.dart';
import 'dart:async';

class PracticeSessionScreen extends StatefulWidget {
  final Map<String, dynamic> sessionData;

  const PracticeSessionScreen({
    Key? key,
    required this.sessionData,
  }) : super(key: key);

  @override
  State<PracticeSessionScreen> createState() => _PracticeSessionScreenState();
}

class _PracticeSessionScreenState extends State<PracticeSessionScreen> {
  final TextEditingController _solutionController = TextEditingController();
  late Stopwatch _stopwatch;
  late Timer _timer;
  late String _sessionId;
  late String _encryptedText;
  late String _cipherType;
  late int _difficulty;
  int _hintsUsed = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final puzzle = widget.sessionData['puzzle'];
    _sessionId = widget.sessionData['session_id'];
    _encryptedText = puzzle['encrypted_text'];
    _cipherType = puzzle['cipher_type'];
    _difficulty = puzzle['difficulty'];

    // Start stopwatch
    _stopwatch = Stopwatch()..start();
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    _solutionController.dispose();
    super.dispose();
  }

  String _formatTime() {
    final milliseconds = _stopwatch.elapsedMilliseconds;
    final seconds = (milliseconds / 1000).floor();
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    final remainingMilliseconds = (milliseconds % 1000) ~/ 100;

    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}.${remainingMilliseconds}';
  }

  void _submitSolution() async {
    if (_solutionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter a solution'),
          backgroundColor: AppTheme.neonRed,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    _stopwatch.stop();
    HapticFeedback.mediumImpact();

    final result = await PracticeService.submitSolution(
      sessionId: _sessionId,
      solution: _solutionController.text.trim(),
      solveTimeMs: _stopwatch.elapsedMilliseconds,
      hintsUsed: _hintsUsed,
    );

    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (result['success']) {
      // Navigate to result screen (to be implemented)
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Solution submitted!'),
          backgroundColor: AppTheme.electricGreen,
        ),
      );
    } else {
      // Restart stopwatch if submission failed
      _stopwatch.start();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to submit solution'),
          backgroundColor: AppTheme.neonRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with timer
              Container(
                padding: EdgeInsets.all(AppTheme.spacing3),
                decoration: BoxDecoration(
                  color: AppTheme.darkNavy,
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppTheme.cyberBlue),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'PRACTICE: $_cipherType',
                            style: AppTheme.headingMedium,
                          ),
                          Text(
                            'Difficulty: $_difficulty/10',
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing2,
                        vertical: AppTheme.spacing1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.cyberBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        border: Border.all(color: AppTheme.cyberBlue),
                      ),
                      child: Text(
                        _formatTime(),
                        style: AppTheme.monoStyleLarge.copyWith(
                          color: AppTheme.cyberBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppTheme.spacing3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Encrypted text
                      Text('Encrypted Text:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(AppTheme.spacing3),
                        decoration: BoxDecoration(
                          color: AppTheme.darkNavy,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          border: Border.all(color: AppTheme.cyberBlue),
                        ),
                        child: SelectableText(
                          _encryptedText,
                          style: AppTheme.monoStyleLarge.copyWith(
                            color: AppTheme.cyberBlue,
                          ),
                        ),
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Solution input
                      Text('Your Solution:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      TextField(
                        controller: _solutionController,
                        decoration: InputDecoration(
                          hintText: 'Enter decrypted text...',
                          hintStyle: TextStyle(color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.darkNavy,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.cyberBlue),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.cyberBlue.withValues(alpha: 0.3)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            borderSide: BorderSide(color: AppTheme.cyberBlue, width: 2),
                          ),
                        ),
                        style: AppTheme.monoStyleLarge,
                        textCapitalization: TextCapitalization.characters,
                        maxLines: 3,
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Tools
                      Text('Tools & Hints:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      Wrap(
                        spacing: AppTheme.spacing2,
                        runSpacing: AppTheme.spacing2,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              // TODO: Implement hint functionality
                              setState(() => _hintsUsed++);
                            },
                            icon: Icon(Icons.lightbulb_outline),
                            label: Text('Get Hint ($_hintsUsed used)'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.neonPurple,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _solutionController.clear();
                            },
                            icon: Icon(Icons.refresh),
                            label: Text('Reset'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.darkNavy,
                            ),
                          ),
                        ],
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitSolution,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.electricGreen,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                          child: _isSubmitting
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'SUBMIT SOLUTION',
                                  style: AppTheme.headingMedium.copyWith(color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
