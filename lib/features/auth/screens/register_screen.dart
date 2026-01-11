import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/form_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _termsAccepted = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  // Password validation flags
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    // Listen to password changes for validation
    _passwordController.addListener(_validatePassword);

    // Clear any existing errors when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;

    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordValid() {
    return _hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasNumber &&
        _hasSpecialChar;
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // Show loading overlay during registration
    if (authState.status == AuthStatus.loading) {
      return Scaffold(
        backgroundColor: AppColors.warmOffWhite,
        body: Center(
          child: LoadingAnimationWidget.staggeredDotsWave(
            color: AppColors.primary,
            size: 60,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.warmOffWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Account',
          style: TextStyle(color: AppColors.textDark),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Create account text
              const Text(
                'Create Account',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Sign up to start earning rewards',
                style: TextStyle(color: AppColors.textNeutral, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Show error if any
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.error!,
                          style: TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Registration Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Email Field
                    FormTextField(
                      label: 'Email Address',
                      hintText: 'you@example.com',
                      prefixIcon: Icons.email,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email address';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email address';
                        }
                        return null;
                      },
                    ),

                    // Password Field
                    FormTextField(
                      label: 'Password',
                      hintText: 'Create a strong password',
                      prefixIcon: Icons.lock,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.textNeutral,
                        ),
                        onPressed: () {
                          setState(() {
                            _showPassword = !_showPassword;
                          });
                        },
                      ),
                      controller: _passwordController,
                      obscureText: !_showPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a password';
                        }
                        if (!_isPasswordValid()) {
                          return 'Password does not meet requirements';
                        }
                        return null;
                      },
                    ),

                    // Confirm Password Field
                    FormTextField(
                      label: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      prefixIcon: Icons.lock_outline,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showConfirmPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.textNeutral,
                        ),
                        onPressed: () {
                          setState(() {
                            _showConfirmPassword = !_showConfirmPassword;
                          });
                        },
                      ),
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Password Requirements
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.warmOffWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.buttonBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password Requirements:',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),

                          _buildRequirementRow(
                            'At least 8 characters',
                            _hasMinLength,
                          ),
                          _buildRequirementRow(
                            'One uppercase letter (A-Z)',
                            _hasUppercase,
                          ),
                          _buildRequirementRow(
                            'One lowercase letter (a-z)',
                            _hasLowercase,
                          ),
                          _buildRequirementRow('One number (0-9)', _hasNumber),
                          _buildRequirementRow(
                            'One special character (!@#\$%^&*)',
                            _hasSpecialChar,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Terms Checkbox
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.buttonBorder,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Checkbox(
                              value: _termsAccepted,
                              onChanged: (value) {
                                setState(() {
                                  _termsAccepted = value ?? false;
                                });
                              },
                              activeColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Expanded(
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: AppColors.textNeutral,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                  children: [
                                    const TextSpan(text: 'I agree to the '),
                                    TextSpan(
                                      text: 'Terms of Service',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const TextSpan(text: ' and '),
                                    TextSpan(
                                      text: 'Privacy Policy',
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const TextSpan(
                                      text:
                                          '. I understand that my data will be processed in accordance with Dowell\'s privacy policy.',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Register Button
                    PrimaryButton(
                      text: 'Create Account',
                      onPressed: _termsAccepted
                          ? () {
                              if (_formKey.currentState!.validate()) {
                                _register(context);
                              }
                            }
                          : () {},
                    ),

                    const SizedBox(height: 32),

                    // Divider with "or"
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppColors.textNeutral.withOpacity(0.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'or sign up with',
                            style: TextStyle(color: AppColors.textNeutral),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: AppColors.textNeutral.withOpacity(0.3),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Social Registration Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google
                        _buildSocialButton(
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFFDB4437),
                          onPressed: () => _socialRegister('Google', context),
                        ),

                        const SizedBox(width: 16),

                        // Facebook
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: const Color(0xFF4267B2),
                          onPressed: () => _socialRegister('Facebook', context),
                        ),

                        const SizedBox(width: 16),

                        // Apple
                        _buildSocialButton(
                          icon: Icons.apple,
                          color: Colors.black,
                          onPressed: () => _socialRegister('Apple', context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Already have account
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account? ",
                          style: TextStyle(color: AppColors.textNeutral),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Text(
                            'Sign in here',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRequirementRow(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle : Icons.circle_outlined,
            color: isMet ? AppColors.success : AppColors.textNeutral,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: isMet ? AppColors.success : AppColors.textNeutral,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.buttonBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Future<void> _register(BuildContext context) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_termsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms and Privacy Policy'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Clear any previous errors
    ref.read(authProvider.notifier).clearError();

    // Call the auth provider to register
    await ref
        .read(authProvider.notifier)
        .registerWithEmail(
          email: email,
          password: password,
          role: 'customer', // Default role
        );

    // Check registration result
    final authState = ref.read(authProvider);

    if (authState.status == AuthStatus.authenticated) {
      // Registration successful
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate to role selection after a delay
      await Future.delayed(const Duration(seconds: 2), () {
        Navigator.pushReplacementNamed(context, '/role-selection');
      });
    } else if (authState.error != null) {
      // Error is already shown in the UI via authState.error
      // No need to show another snackbar
    }
  }

  void _socialRegister(String platform, BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$platform registration coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}
