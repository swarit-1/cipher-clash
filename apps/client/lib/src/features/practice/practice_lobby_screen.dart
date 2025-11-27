import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';
import '../../services/practice_service.dart';
import 'practice_session_screen.dart';

class PracticeLobbyScreen extends StatefulWidget {
  const PracticeLobbyScreen({Key? key}) : super(key: key);

  @override
  State<PracticeLobbyScreen> createState() => _PracticeLobbyScreenState();
}

class _PracticeLobbyScreenState extends State<PracticeLobbyScreen> {
  String _selectedCipher = 'CAESAR';
  int _difficulty = 5;
  String _mode = 'UNTIMED';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _ciphers = [
    {'type': 'CAESAR', 'name': 'Caesar', 'level': 18, 'winRate': 78.5, 'locked': false},
    {'type': 'VIGENERE', 'name': 'Vigenère', 'level': 12, 'winRate': 65.0, 'locked': false},
    {'type': 'RAIL_FENCE', 'name': 'Rail Fence', 'level': 8, 'winRate': 55.0, 'locked': false},
    {'type': 'PLAYFAIR', 'name': 'Playfair', 'level': 5, 'winRate': 45.0, 'locked': false},
    {'type': 'SUBSTITUTION', 'name': 'Substitution', 'level': 3, 'winRate': 0.0, 'locked': false},
    {'type': 'TRANSPOSITION', 'name': 'Transposition', 'level': 2, 'winRate': 0.0, 'locked': false},
  ];

  void _startPractice() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    final result = await PracticeService.generatePuzzle(
      cipherType: _selectedCipher,
      difficulty: _difficulty,
      mode: _mode,
      timeLimitSeconds: _mode == 'TIMED' ? 300 : null,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (result['success']) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PracticeSessionScreen(
            sessionData: result['data'],
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result['error'] ?? 'Failed to start practice'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(AppTheme.spacing3),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: AppTheme.cyberBlue),
                      onPressed: () => Navigator.pop(context),
                    ),
                    SizedBox(width: AppTheme.spacing2),
                    Text(
                      'PRACTICE MODE',
                      style: AppTheme.headingLarge,
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
                      // Description
                      Text(
                        'Master ciphers at your own pace',
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacing4),

                      // Cipher selection
                      Text('Select Cipher Type:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: AppTheme.spacing2,
                          mainAxisSpacing: AppTheme.spacing2,
                          childAspectRatio: 1.5,
                        ),
                        itemCount: _ciphers.length,
                        itemBuilder: (context, index) {
                          final cipher = _ciphers[index];
                          final isSelected = _selectedCipher == cipher['type'];
                          final isLocked = cipher['locked'] as bool;

                          return GestureDetector(
                            onTap: isLocked
                                ? null
                                : () {
                                    setState(() => _selectedCipher = cipher['type']);
                                    HapticFeedback.selectionClick();
                                  },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppTheme.cyberBlue.withValues(alpha: 0.2)
                                    : AppTheme.darkNavy,
                                border: Border.all(
                                  color: isSelected ? AppTheme.cyberBlue : Colors.transparent,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                boxShadow: isSelected
                                    ? AppTheme.glowCyberBlue(intensity: 0.5)
                                    : [],
                              ),
                              padding: EdgeInsets.all(AppTheme.spacing2),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    cipher['name'],
                                    style: AppTheme.headingSmall.copyWith(
                                      color: isLocked ? AppTheme.textSecondary : AppTheme.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: AppTheme.spacing1),
                                  if (!isLocked) ...[
                                    Text(
                                      'Level ${cipher['level']}',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.electricGreen,
                                      ),
                                    ),
                                    Text(
                                      '${cipher['winRate'].toStringAsFixed(1)}% Win',
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                      ),
                                    ),
                                  ] else
                                    Icon(Icons.lock, color: AppTheme.textSecondary, size: 24),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Difficulty slider
                      Text('Difficulty:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacing3),
                        decoration: BoxDecoration(
                          color: AppTheme.darkNavy,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Easy', style: AppTheme.bodySmall),
                                Text(
                                  '$_difficulty / 10',
                                  style: AppTheme.headingMedium.copyWith(
                                    color: AppTheme.cyberBlue,
                                  ),
                                ),
                                Text('Hard', style: AppTheme.bodySmall),
                              ],
                            ),
                            SliderTheme(
                              data: SliderThemeData(
                                activeTrackColor: AppTheme.cyberBlue,
                                inactiveTrackColor: AppTheme.cyberBlue.withValues(alpha: 0.3),
                                thumbColor: AppTheme.cyberBlue,
                                overlayColor: AppTheme.cyberBlue.withValues(alpha: 0.2),
                              ),
                              child: Slider(
                                value: _difficulty.toDouble(),
                                min: 1,
                                max: 10,
                                divisions: 9,
                                onChanged: (value) {
                                  setState(() => _difficulty = value.toInt());
                                  HapticFeedback.selectionClick();
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Mode selection
                      Text('Practice Mode:', style: AppTheme.headingMedium),
                      SizedBox(height: AppTheme.spacing2),
                      Wrap(
                        spacing: AppTheme.spacing2,
                        runSpacing: AppTheme.spacing2,
                        children: [
                          _buildModeChip('UNTIMED', 'Untimed'),
                          _buildModeChip('TIMED', 'Timed (5 min)'),
                          _buildModeChip('SPEED_RUN', 'Speed Run'),
                          _buildModeChip('ACCURACY', 'Accuracy'),
                        ],
                      ),

                      SizedBox(height: AppTheme.spacing4),

                      // Start button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _startPractice,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.cyberBlue,
                            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  'START PRACTICE',
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

  Widget _buildModeChip(String mode, String label) {
    final isSelected = _mode == mode;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _mode = mode);
        HapticFeedback.selectionClick();
      },
      selectedColor: AppTheme.cyberBlue.withValues(alpha: 0.3),
      checkmarkColor: AppTheme.cyberBlue,
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.cyberBlue : AppTheme.textPrimary,
      ),
    );
  }
}
