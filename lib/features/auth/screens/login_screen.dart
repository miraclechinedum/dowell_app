import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/form_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    // 🔄 Loading state
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
        automaticallyImplyLeading: false, // ✅ IMPORTANT
        backgroundColor: Colors.white,
        elevation: 0,
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

              // ❌ Error message
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          authState.error!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // 🔐 Login Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    FormTextField(
                      label: 'Email Address',
                      hintText: 'you@example.com',
                      prefixIcon: Icons.email,
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(value)) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),

                    FormTextField(
                      label: 'Password',
                      hintText: 'Enter your password',
                      obscureText: true,
                      prefixIcon: Icons.lock,
                      controller: passwordController,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(context),
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

                    PrimaryButton(
                      text: 'Sign In',
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          await _login();
                        }
                      },
                    ),

                    const SizedBox(height: 32),

                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: AppColors.textNeutral.withOpacity(0.3),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16),
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

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildSocialButton(
                          icon: Icons.g_mobiledata,
                          color: const Color(0xFFDB4437),
                          onPressed: () => _socialLogin('Google'),
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          icon: Icons.facebook,
                          color: const Color(0xFF4267B2),
                          onPressed: () => _socialLogin('Facebook'),
                        ),
                        const SizedBox(width: 16),
                        _buildSocialButton(
                          icon: Icons.apple,
                          color: Colors.black,
                          onPressed: () => _socialLogin('Apple'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Don't have an account yet? ",
                          style: TextStyle(color: AppColors.textNeutral),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const RegisterScreen(),
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
        border: Border.all(color: AppColors.buttonBorder),
      ),
      child: IconButton(
        icon: Icon(icon, color: color),
        onPressed: onPressed,
      ),
    );
  }

  Future<void> _login() async {
    ref.read(authProvider.notifier).clearError();

    await ref
        .read(authProvider.notifier)
        .loginWithEmail(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
  }

  void _socialLogin(String platform) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$platform login coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Password'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Email address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(authProvider.notifier)
                  .resetPassword(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
}
