import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyberpunk_button.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call AuthService to login
      final result = await AuthService.login(
        username: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        // Navigate to main menu on success
        HapticFeedback.heavyImpact();
        Navigator.pushReplacementNamed(context, '/menu');
      } else {
        setState(() {
          _errorMessage = result['message'] ?? 'Login failed';
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

  void _skipForDev() {
    HapticFeedback.heavyImpact();
    // Set mock auth data for dev mode
    AuthService.setDevMockAuth(
      accessToken: 'dev-mock-token',
      userId: 'dev-user-123',
      username: 'DevUser',
    );
    Navigator.pushReplacementNamed(context, '/menu');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacing3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  _buildHeader(),

                  const SizedBox(height: AppTheme.spacing6),

                  // Login Form
                  _buildLoginForm(),

                  const SizedBox(height: AppTheme.spacing3),

                  // Error Message
                  if (_errorMessage != null) _buildErrorMessage(),

                  const SizedBox(height: AppTheme.spacing3),

                  // Login Button
                  _buildLoginButton(),

                  const SizedBox(height: AppTheme.spacing2),

                  // Forgot Password
                  _buildForgotPassword(),

                  const SizedBox(height: AppTheme.spacing4),

                  // Divider
                  _buildDivider(),

                  const SizedBox(height: AppTheme.spacing4),

                  // Dev Skip Button
                  _buildDevSkipButton(),

                  const SizedBox(height: AppTheme.spacing3),

                  // Register Link
                  _buildRegisterLink(),
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
        // Cipher Clash Logo
        Container(
          padding: const EdgeInsets.all(AppTheme.spacing3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppTheme.primaryGradient,
            boxShadow: AppTheme.glowCyberBlue(intensity: 1.5),
          ),
          child: const Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.black,
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),

        const SizedBox(height: AppTheme.spacing3),

        // Title
        Text(
          'CIPHER CLASH',
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppTheme.cyberBlue,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
        ).animate().fadeIn(delay: 200.ms).slideY(
              begin: -0.2,
              end: 0,
              duration: 400.ms,
            ),

        const SizedBox(height: AppTheme.spacing1),

        Text(
          'Competitive Cryptography Esports',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                letterSpacing: 1.5,
              ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Form(
      key: _formKey,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          children: [
            // Email Field
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
            ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.2, end: 0),

            const SizedBox(height: AppTheme.spacing2),

            // Password Field
            TextFormField(
              controller: _passwordController,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleLogin(),
              decoration: InputDecoration(
                labelText: 'Password',
                hintText: 'Enter your password',
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
            ).animate().fadeIn(delay: 700.ms).slideX(begin: -0.2, end: 0),
          ],
        ),
      ),
    );
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
          Text(
            _errorMessage!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.neonRed,
                ),
          ),
        ],
      ),
    )
        .animate()
        .shake(duration: 400.ms)
        .fadeIn();
  }

  Widget _buildLoginButton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: CyberpunkButton(
        label: 'LOGIN',
        onPressed: _isLoading ? null : _handleLogin,
        variant: CyberpunkButtonVariant.primary,
        icon: Icons.login,
        isLoading: _isLoading,
        fullWidth: true,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      ),
    ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildForgotPassword() {
    return TextButton(
      onPressed: _isLoading
          ? null
          : () {
              // TODO: Implement forgot password
              HapticFeedback.selectionClick();
            },
      child: Text(
        'Forgot Password?',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.cyberBlue,
            ),
      ),
    ).animate().fadeIn(delay: 900.ms);
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing2),
          child: Text(
            'OR',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.textTertiary,
                ),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    ).animate().fadeIn(delay: 1000.ms);
  }

  Widget _buildDevSkipButton() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      child: CyberpunkButton(
        label: 'SKIP FOR DEV',
        onPressed: _isLoading ? null : _skipForDev,
        variant: CyberpunkButtonVariant.secondary,
        icon: Icons.fast_forward,
        fullWidth: true,
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing2),
      ),
    ).animate().fadeIn(delay: 1050.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
        ),
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  Navigator.pushNamed(context, '/register');
                },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 4),
          ),
          child: Text(
            'Sign Up',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.electricGreen,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 1100.ms);
  }
}
