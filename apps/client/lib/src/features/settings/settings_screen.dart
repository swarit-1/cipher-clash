import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glow_card.dart';
import '../../widgets/cyberpunk_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Audio Settings
  bool _masterAudioEnabled = true;
  double _masterVolume = 0.8;
  bool _musicEnabled = true;
  double _musicVolume = 0.7;
  bool _sfxEnabled = true;
  double _sfxVolume = 0.9;

  // Gameplay Settings
  bool _hapticFeedbackEnabled = true;
  bool _autoSubmitEnabled = false;
  bool _showTimerWarnings = true;
  String _defaultGameMode = 'RANKED';

  // Graphics Settings
  String _quality = 'HIGH';
  bool _animationsEnabled = true;
  bool _particleEffectsEnabled = true;
  bool _glowEffectsEnabled = true;

  // Notifications
  bool _matchNotifications = true;
  bool _friendNotifications = true;
  bool _achievementNotifications = true;
  bool _dailyQuestReminders = true;

  // Account
  final String _username = 'CipherMaster';
  final String _email = 'cipher@example.com';
  final String _region = 'US';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacing3),
          children: [
            // Audio Settings
            _buildSection(
              'Audio',
              Icons.volume_up,
              AppTheme.cyberBlue,
              [
                _buildSwitchTile(
                  'Master Audio',
                  'Enable/disable all sounds',
                  _masterAudioEnabled,
                  (value) => setState(() => _masterAudioEnabled = value),
                ),
                _buildSliderTile(
                  'Master Volume',
                  _masterVolume,
                  (value) => setState(() => _masterVolume = value),
                  enabled: _masterAudioEnabled,
                ),
                const Divider(height: AppTheme.spacing2),
                _buildSwitchTile(
                  'Music',
                  'Background music',
                  _musicEnabled,
                  (value) => setState(() => _musicEnabled = value),
                  enabled: _masterAudioEnabled,
                ),
                _buildSliderTile(
                  'Music Volume',
                  _musicVolume,
                  (value) => setState(() => _musicVolume = value),
                  enabled: _masterAudioEnabled && _musicEnabled,
                ),
                const Divider(height: AppTheme.spacing2),
                _buildSwitchTile(
                  'Sound Effects',
                  'UI and game sounds',
                  _sfxEnabled,
                  (value) => setState(() => _sfxEnabled = value),
                  enabled: _masterAudioEnabled,
                ),
                _buildSliderTile(
                  'SFX Volume',
                  _sfxVolume,
                  (value) => setState(() => _sfxVolume = value),
                  enabled: _masterAudioEnabled && _sfxEnabled,
                ),
              ],
            ).animate().fadeIn(delay: 100.ms),

            const SizedBox(height: AppTheme.spacing3),

            // Gameplay Settings
            _buildSection(
              'Gameplay',
              Icons.sports_esports,
              AppTheme.neonPurple,
              [
                _buildSwitchTile(
                  'Haptic Feedback',
                  'Vibration on interactions',
                  _hapticFeedbackEnabled,
                  (value) => setState(() => _hapticFeedbackEnabled = value),
                ),
                _buildSwitchTile(
                  'Auto Submit',
                  'Automatically submit correct solutions',
                  _autoSubmitEnabled,
                  (value) => setState(() => _autoSubmitEnabled = value),
                ),
                _buildSwitchTile(
                  'Timer Warnings',
                  'Show visual warnings when time is low',
                  _showTimerWarnings,
                  (value) => setState(() => _showTimerWarnings = value),
                ),
                const Divider(height: AppTheme.spacing2),
                _buildDropdownTile(
                  'Default Game Mode',
                  _defaultGameMode,
                  ['RANKED', 'CASUAL', 'PRACTICE'],
                  (value) => setState(() => _defaultGameMode = value!),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: AppTheme.spacing3),

            // Graphics Settings
            _buildSection(
              'Graphics',
              Icons.auto_awesome,
              AppTheme.electricGreen,
              [
                _buildDropdownTile(
                  'Quality',
                  _quality,
                  ['LOW', 'MEDIUM', 'HIGH', 'ULTRA'],
                  (value) => setState(() => _quality = value!),
                ),
                const Divider(height: AppTheme.spacing2),
                _buildSwitchTile(
                  'Animations',
                  'Enable UI animations',
                  _animationsEnabled,
                  (value) => setState(() => _animationsEnabled = value),
                ),
                _buildSwitchTile(
                  'Particle Effects',
                  'Confetti and visual effects',
                  _particleEffectsEnabled,
                  (value) => setState(() => _particleEffectsEnabled = value),
                ),
                _buildSwitchTile(
                  'Glow Effects',
                  'Card and button glow effects',
                  _glowEffectsEnabled,
                  (value) => setState(() => _glowEffectsEnabled = value),
                ),
              ],
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: AppTheme.spacing3),

            // Notifications
            _buildSection(
              'Notifications',
              Icons.notifications,
              AppTheme.electricYellow,
              [
                _buildSwitchTile(
                  'Match Notifications',
                  'Match found and results',
                  _matchNotifications,
                  (value) => setState(() => _matchNotifications = value),
                ),
                _buildSwitchTile(
                  'Friend Notifications',
                  'Friend requests and activity',
                  _friendNotifications,
                  (value) => setState(() => _friendNotifications = value),
                ),
                _buildSwitchTile(
                  'Achievement Notifications',
                  'Achievement unlocks',
                  _achievementNotifications,
                  (value) => setState(() => _achievementNotifications = value),
                ),
                _buildSwitchTile(
                  'Daily Quest Reminders',
                  'Remind about incomplete quests',
                  _dailyQuestReminders,
                  (value) => setState(() => _dailyQuestReminders = value),
                ),
              ],
            ).animate().fadeIn(delay: 400.ms),

            const SizedBox(height: AppTheme.spacing3),

            // Account Settings
            _buildSection(
              'Account',
              Icons.person,
              AppTheme.cyberBlue,
              [
                _buildInfoTile('Username', _username, Icons.person),
                _buildInfoTile('Email', _email, Icons.email),
                _buildInfoTile('Region', _region, Icons.public),
                const Divider(height: AppTheme.spacing2),
                _buildActionTile(
                  'Change Password',
                  Icons.lock_outline,
                  () {
                    HapticFeedback.selectionClick();
                    // TODO: Navigate to change password
                  },
                ),
                _buildActionTile(
                  'Edit Profile',
                  Icons.edit,
                  () {
                    HapticFeedback.selectionClick();
                    // TODO: Navigate to edit profile
                  },
                ),
              ],
            ).animate().fadeIn(delay: 500.ms),

            const SizedBox(height: AppTheme.spacing3),

            // About & Support
            _buildSection(
              'About & Support',
              Icons.info_outline,
              AppTheme.textSecondary,
              [
                _buildActionTile(
                  'Privacy Policy',
                  Icons.privacy_tip_outlined,
                  () {
                    HapticFeedback.selectionClick();
                    // TODO: Show privacy policy
                  },
                ),
                _buildActionTile(
                  'Terms of Service',
                  Icons.description_outlined,
                  () {
                    HapticFeedback.selectionClick();
                    // TODO: Show terms of service
                  },
                ),
                _buildActionTile(
                  'Support',
                  Icons.help_outline,
                  () {
                    HapticFeedback.selectionClick();
                    // TODO: Navigate to support
                  },
                ),
                const Divider(height: AppTheme.spacing2),
                _buildInfoTile('Version', '2.0.0', Icons.info),
              ],
            ).animate().fadeIn(delay: 600.ms),

            const SizedBox(height: AppTheme.spacing3),

            // Danger Zone
            _buildSection(
              'Danger Zone',
              Icons.warning,
              AppTheme.neonRed,
              [
                CyberpunkButton(
                  label: 'CLEAR CACHE',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _showConfirmDialog(
                      'Clear Cache',
                      'This will clear all cached data. Are you sure?',
                      () {
                        // TODO: Clear cache
                        _showSnackBar('Cache cleared successfully');
                      },
                    );
                  },
                  variant: CyberpunkButtonVariant.ghost,
                  icon: Icons.cleaning_services,
                  fullWidth: true,
                ),
                const SizedBox(height: AppTheme.spacing2),
                CyberpunkButton(
                  label: 'LOG OUT',
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _showConfirmDialog(
                      'Log Out',
                      'Are you sure you want to log out?',
                      () {
                        // TODO: Implement logout
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/login',
                          (route) => false,
                        );
                      },
                    );
                  },
                  variant: CyberpunkButtonVariant.danger,
                  icon: Icons.logout,
                  fullWidth: true,
                ),
                const SizedBox(height: AppTheme.spacing2),
                CyberpunkButton(
                  label: 'DELETE ACCOUNT',
                  onPressed: () {
                    HapticFeedback.heavyImpact();
                    _showDeleteAccountDialog();
                  },
                  variant: CyberpunkButtonVariant.danger,
                  icon: Icons.delete_forever,
                  fullWidth: true,
                ),
              ],
            ).animate().fadeIn(delay: 700.ms),

            const SizedBox(height: AppTheme.spacing4),

            // Save Button
            CyberpunkButton(
              label: 'SAVE SETTINGS',
              onPressed: () {
                HapticFeedback.mediumImpact();
                // TODO: Save settings to backend
                _showSnackBar('Settings saved successfully');
              },
              variant: CyberpunkButtonVariant.primary,
              icon: Icons.save,
              fullWidth: true,
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
            ).animate().fadeIn(delay: 800.ms),

            const SizedBox(height: AppTheme.spacing2),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return GlowCard(
      glowVariant: GlowCardVariant.none,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: AppTheme.spacing2),
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: color,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged, {
    bool enabled = true,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: enabled ? null : AppTheme.textTertiary,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
      trailing: Switch(
        value: value,
        onChanged: enabled
            ? (newValue) {
                HapticFeedback.selectionClick();
                onChanged(newValue);
              }
            : null,
        activeTrackColor: AppTheme.electricGreen,
        activeThumbColor: Colors.white,
      ),
    );
  }

  Widget _buildSliderTile(
    String title,
    double value,
    Function(double) onChanged, {
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: enabled ? null : AppTheme.textTertiary,
                  ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: enabled ? AppTheme.cyberBlue : AppTheme.textTertiary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        Slider(
          value: value,
          onChanged: enabled
              ? (newValue) {
                  onChanged(newValue);
                }
              : null,
          activeColor: AppTheme.cyberBlue,
          inactiveColor: AppTheme.surfaceVariant,
        ),
      ],
    );
  }

  Widget _buildDropdownTile(
    String title,
    String value,
    List<String> options,
    Function(String?) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(color: AppTheme.cyberBlue),
          ),
          child: DropdownButton<String>(
            value: value,
            onChanged: (newValue) {
              HapticFeedback.selectionClick();
              onChanged(newValue);
            },
            underline: const SizedBox.shrink(),
            dropdownColor: AppTheme.darkNavy,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.cyberBlue,
                  fontWeight: FontWeight.w700,
                ),
            items: options.map((option) {
              return DropdownMenuItem(
                value: option,
                child: Text(option),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.cyberBlue),
      title: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
      ),
      subtitle: Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }

  Widget _buildActionTile(String title, IconData icon, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppTheme.cyberBlue),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge,
      ),
      trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
      onTap: onTap,
    );
  }

  void _showConfirmDialog(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.mediumImpact();
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neonRed,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkNavy,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          side: const BorderSide(color: AppTheme.neonRed, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning, color: AppTheme.neonRed),
            const SizedBox(width: AppTheme.spacing2),
            Text(
              'Delete Account',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.neonRed,
                  ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This action is permanent and cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neonRed,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppTheme.spacing2),
            Text(
              'All your data will be permanently deleted:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppTheme.spacing1),
            _buildDeleteWarning('Profile and account information'),
            _buildDeleteWarning('Match history and statistics'),
            _buildDeleteWarning('Achievements and progress'),
            _buildDeleteWarning('Friends and social connections'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.pop(context);
              // TODO: Implement account deletion
              _showSnackBar('Account deletion is not available in demo');
            },
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.neonRed,
            ),
            child: const Text('DELETE FOREVER'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteWarning(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(
            Icons.close,
            color: AppTheme.neonRed,
            size: 16,
          ),
          const SizedBox(width: AppTheme.spacing1),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.darkNavy,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        ),
      ),
    );
  }
}
