import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/form_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatelessWidget {
  LoginScreen({super.key});

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
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
          'Sign In',
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

              // Welcome back text
              const Text(
                'Welcome Back',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Sign in to continue to your account',
                style: TextStyle(color: AppColors.textNeutral, fontSize: 16),
              ),

              const SizedBox(height: 40),

              // Login Form
              Form(
                child: Column(
                  children: [
                    FormTextField(
                      label: 'Email Address',
                      hintText: 'you@example.com',
                      prefixIcon: Icons.email,
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),

                    FormTextField(
                      label: 'Password',
                      hintText: 'Enter your password',
                      obscureText: true,
                      prefixIcon: Icons.lock,
                      controller: passwordController,
                    ),

                    const SizedBox(height: 8),

                    // Forgot Password
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          _showForgotPasswordDialog(context);
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Login Button
                    PrimaryButton(
                      text: 'Sign In',
                      onPressed: () {
                        _login(context);
                      },
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
                            'or continue with',
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

                    // Social Login Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Google
                        _buildSocialButton(
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFFDB4437),
                          onPressed: () => _socialLogin('Google', context),
                        ),

                        const SizedBox(width: 16),

                        // Facebook
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: const Color(0xFF4267B2),
                          onPressed: () => _socialLogin('Facebook', context),
                        ),

                        const SizedBox(width: 16),

                        // Apple
                        // Line ~155 in login_screen.dart
                        // Apple
                        _buildSocialButton(
                          // Changed from _BuildSocialButton
                          icon: Icons.apple,
                          color: Colors.black,
                          onPressed: () => _socialLogin('Apple', context),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Register Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account yet? ",
                          style: TextStyle(color: AppColors.textNeutral),
                        ),
                        // Line ~178 in login_screen.dart
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RegisterScreen(), // Already correct
                              ),
                            );
                          },
                          child: const Text(
                            'Register here',
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
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, size: 24),
      ),
    );
  }

  void _login(BuildContext context) {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar(context, 'Please enter email and password');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showSnackBar(context, 'Please enter a valid email address');
      return;
    }

    // Simulate login process
    _showSnackBar(context, 'Login successful!');

    // In real app, navigate to dashboard or role selection
    // Navigator.pushReplacementNamed(context, '/dashboard');
  }

  void _socialLogin(String platform, BuildContext context) {
    _showSnackBar(context, 'Signing in with $platform...');
    // Implement actual social login here
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: const Text(
          'Enter your email to receive a password reset link:',
        ),
        actions: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Email address',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showSnackBar(context, 'Password reset link sent!');
                },
                child: const Text('Send Link'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }
}
