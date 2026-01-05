import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/form_text_field.dart';
import '../../../core/widgets/primary_button.dart';
import 'role_selection_screen.dart';

class RegisterScreen extends StatefulWidget {
  // CHANGE TO StatefulWidget
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Move controllers to State
  late TextEditingController emailController;
  late TextEditingController passwordController;
  late TextEditingController confirmPasswordController;

  @override
  void initState() {
    super.initState();
    // Initialize controllers in initState
    emailController = TextEditingController();
    passwordController = TextEditingController();
    confirmPasswordController = TextEditingController();
  }

  @override
  void dispose() {
    // Dispose controllers
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

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

              // Registration Form
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
                      hintText: 'Create a strong password',
                      obscureText: true,
                      prefixIcon: Icons.lock,
                      controller: passwordController,
                    ),

                    FormTextField(
                      label: 'Confirm Password',
                      hintText: 'Re-enter your password',
                      obscureText: true,
                      prefixIcon: Icons.lock_outline,
                      controller: confirmPasswordController,
                    ),

                    const SizedBox(height: 8),

                    // Password requirements
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.warmOffWhite,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.buttonBorder,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Password must contain:',
                            style: TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '• At least 8 characters\n• One uppercase letter\n• One number\n• One special character',
                            style: TextStyle(
                              color: AppColors.textNeutral,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Terms Checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: true, // In real app, manage state
                          onChanged: (value) {},
                          activeColor: AppColors.primary,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: AppColors.textNeutral,
                                fontSize: 14,
                              ),
                              children: const [
                                TextSpan(text: 'I agree to the '),
                                TextSpan(
                                  text: 'Terms of Service',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Register Button
                    PrimaryButton(
                      text: 'Create Account',
                      onPressed: () {
                        _register(context);
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

  void _register(BuildContext context) {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      _showSnackBar(context, 'Please fill all fields');
      return;
    }

    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email)) {
      _showSnackBar(context, 'Please enter a valid email address');
      return;
    }

    if (password.length < 8) {
      _showSnackBar(context, 'Password must be at least 8 characters');
      return;
    }

    if (password != confirmPassword) {
      _showSnackBar(context, 'Passwords do not match');
      return;
    }

    // Simulate registration process
    _showSnackBar(context, 'Account created successfully!');

    // Navigate to role selection screen
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    });
  }

  void _socialRegister(String platform, BuildContext context) {
    _showSnackBar(context, 'Signing up with $platform...');
    // In real app, this would navigate to role selection after social auth
    Future.delayed(const Duration(milliseconds: 500), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
      );
    });
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }
}
