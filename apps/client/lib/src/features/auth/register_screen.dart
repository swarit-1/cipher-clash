import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptedTerms = false;
  String? _errorMessage;
  String _selectedRegion = 'US';

  final List<Map<String, String>> _regions = [
    {'code': 'US', 'name': 'North America'},
    {'code': 'EU', 'name': 'Europe'},
    {'code': 'AS', 'name': 'Asia'},
    {'code': 'SA', 'name': 'South America'},
    {'code': 'OC', 'name': 'Oceania'},
  ];

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _getPasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) return 0.0;

    double strength = 0.0;
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.25;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[a-z]').hasMatch(password)) strength += 0.15;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.1;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength += 0.1;

    return strength.clamp(0.0, 1.0);
  }

  Color _getPasswordStrengthColor(double strength) {
    if (strength < 0.3) return AppTheme.neonRed;
    if (strength < 0.6) return AppTheme.electricYellow;
    if (strength < 0.8) return AppTheme.cyberBlue;
    return AppTheme.electricGreen;
  }

  String _getPasswordStrengthText(double strength) {
    if (strength == 0.0) return '';
    if (strength < 0.3) return 'Weak';
    if (strength < 0.6) return 'Fair';
    if (strength < 0.8) return 'Good';
    return 'Strong';
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    if (!_acceptedTerms) {
      setState(() => _errorMessage = 'Please accept the Terms and Conditions');
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call AuthService to register
      final result = await AuthService.register(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        // Navigate to main menu on success
        HapticFeedback.heavyImpact();
        Navigator.pushReplacementNamed(context, '/menu');
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Registration failed';
          _isLoading = false;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Network error: Unable to connect to server';
        _isLoading = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing3),
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  const SizedBox(height: AppTheme.spacing4),

                  // Registration Form
                  _buildRegistrationForm(),

                  const SizedBox(height: AppTheme.spacing3),

                  // Error Message
                  if (_errorMessage != null) _buildErrorMessage(),

                  const SizedBox(height: AppTheme.spacing3),

                  // Terms Checkbox
                  _buildTermsCheckbox(),

                  const SizedBox(height: AppTheme.spacing3),

                  // Register Button
                  _buildRegisterButton(),

                  const SizedBox(height: AppTheme.spacing2),

                  // Login Link
                  _buildLoginLink(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'JOIN THE BATTLE',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.electricGreen,
                fontWeight: FontWeight.w900,
                letterSpacing: 3,
              ),
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),

        const SizedBox(height: AppTheme.spacing1),

        Text(
          'Become a cryptography champion',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ).animate().fadeIn(delay: 200.ms),
      ],
    );
  }

  Widget _buildRegistrationForm() {
    return Form(
      key: _formKey,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Username
            TextFormField(
              controller: _usernameController,
              enabled: !_isLoading,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Username',
                hintText: 'Choose a unique username',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: AppTheme.cyberBlue.withValues(alpha: 0.7),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Username is required';
                }
                if (value.length < 3) {
                  return 'Username must be at least 3 characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                  return 'Only letters, numbers, and underscores allowed';
                }
                return null;
              },
            ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: AppTheme.spacing2),

            // Email
            TextFormField(
              controller: _emailController,
              enabled: !_isLoading,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: AppTheme.cyberBlue.withValues(alpha: 0.7),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Email is required';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: AppTheme.spacing2),

            // Password
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}), // Update password strength
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Create a strong password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppTheme.cyberBlue.withValues(alpha: 0.7),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Password is required';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters';
                }
                return null;
              },
            ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.2, end: 0),

            // Password Strength Indicator
            if (_passwordController.text.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacing1),
              _buildPasswordStrength(),
            ],

            const SizedBox(height: AppTheme.spacing2),

            // Confirm Password
            TextFormField(
              controller: _confirmPasswordController,
              enabled: !_isLoading,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                hintText: 'Re-enter your password',
                prefixIcon: Icon(
                  Icons.lock_outline,
                  color: AppTheme.cyberBlue.withValues(alpha: 0.7),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppTheme.textSecondary,
                  ),
                  onPressed: () {
                    setState(
                        () => _obscureConfirmPassword = !_obscureConfirmPassword);
                    HapticFeedback.selectionClick();
                  },
                ),
              ),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: AppTheme.spacing2),

            // Region Selector
            DropdownButtonFormField<String>(
              initialValue: _selectedRegion,
              decoration: InputDecoration(
                labelText: 'Region',
                prefixIcon: Icon(
                  Icons.public,
                  color: AppTheme.cyberBlue.withValues(alpha: 0.7),
                ),
              ),
              dropdownColor: AppTheme.darkNavy,
              items: _regions.map((region) {
                return DropdownMenuItem(
                  value: region['code'],
                  child: Text(region['name']!),
                );
              }).toList(),
              onChanged: _isLoading ? null : (value) {
                setState(() => _selectedRegion = value!);
                HapticFeedback.selectionClick();
              },
            ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordStrength() {
    final strength = _getPasswordStrength();
    final color = _getPasswordStrengthColor(strength);
    final text = _getPasswordStrengthText(strength);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                child: LinearProgressIndicator(
                  value: strength,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 4,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing1),
            Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ],
    ).animate().fadeIn(duration: 200.ms);
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      decoration: BoxDecoration(
        color: AppTheme.neonRed.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        border: Border.all(color: AppTheme.neonRed, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, color: AppTheme.neonRed, size: 20),
          const SizedBox(width: AppTheme.spacing1),
          Expanded(
            child: Text(
              _errorMessage!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.neonRed,
                  ),
            ),
          ),
        ],
      ),
    ).animate().shake(duration: 400.ms).fadeIn();
  }

  Widget _buildTermsCheckbox() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Row(
        children: [
          Checkbox(
            value: _acceptedTerms,
            onChanged: _isLoading
                ? null
                : (value) {
                    setState(() => _acceptedTerms = value!);
                    HapticFeedback.selectionClick();
                  },
            activeColor: AppTheme.cyberBlue,
          ),
          Expanded(
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() => _acceptedTerms = !_acceptedTerms);
                      HapticFeedback.selectionClick();
                    },
              child: RichText(
                text: TextSpan(
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  children: [
                    const TextSpan(text: 'I accept the '),
                    TextSpan(
                      text: 'Terms and Conditions',
                      style: const TextStyle(
                        color: AppTheme.cyberBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(text: ' and '),
                    TextSpan(
                      text: 'Privacy Policy',
                      style: const TextStyle(
                        color: AppTheme.cyberBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildRegisterButton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: CyberpunkButton(
        label: 'CREATE ACCOUNT',
        onPressed: _isLoading ? null : _handleRegister,
        variant: CyberpunkButtonVariant.success,
        icon: Icons.rocket_launch,
        isLoading: _isLoading,
        fullWidth: true,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      ),
    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  Navigator.pop(context);
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            'Log In',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.cyberBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 1000.ms);
  }
}
