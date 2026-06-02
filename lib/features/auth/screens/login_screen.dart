import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/form_text_field.dart';
import '../../../core/widgets/logo_image.dart';
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
  bool _showPassword = false;

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

    // When sign-in succeeds the auth listener flips state to `authenticated`,
    // but if the user got here via Navigator.pushNamedAndRemoveUntil('/login')
    // (the logout path) the AuthWrapper at '/' is no longer mounted, so the
    // role-based dashboard never renders. Push back to '/' so AuthWrapper
    // takes over and routes the user to the correct dashboard.
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated &&
          previous?.status != AuthStatus.authenticated) {
        Navigator.of(
          context,
          rootNavigator: true,
        ).pushNamedAndRemoveUntil('/', (route) => false);
      }
    });

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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// Centered brand header
              Center(
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    const LogoImage(size: 64),
                    const SizedBox(height: 20),
                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        color: AppColors.textDark,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Sign in to continue to your account',
                      style: TextStyle(
                        color: AppColors.textNeutral,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Error message
              if (authState.error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.error.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.error),
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
                      prefixIcon: const Icon(Icons.email),
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
                      obscureText: !_showPassword,
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: AppColors.textNeutral,
                        ),
                        tooltip: _showPassword
                            ? 'Hide password'
                            : 'Show password',
                        onPressed: () =>
                            setState(() => _showPassword = !_showPassword),
                      ),
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

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => _showForgotPasswordDialog(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    PrimaryButton(
                      text: 'Sign In',
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          await _login();
                        }
                      },
                    ),

                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Don't have an account yet? ",
                          style: TextStyle(
                            color: AppColors.textNeutral,
                            fontSize: 14,
                          ),
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
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
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

  Future<void> _login() async {
    ref.read(authProvider.notifier).clearError();

    await ref
        .read(authProvider.notifier)
        .loginWithEmail(
          email: emailController.text.trim(),
          password: passwordController.text,
        );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    // Pre-fill with whatever the user already typed on the sign-in form.
    final controller = TextEditingController(
      text: emailController.text.trim(),
    );
    final formKey = GlobalKey<FormState>();
    final messenger = ScaffoldMessenger.of(context);
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => StatefulBuilder(
        builder: (innerContext, setDialogState) => Dialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 24,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Reset Password',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your email and we\'ll send you a link to reset your password.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textNeutral,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 22),
                  TextFormField(
                    controller: controller,
                    enabled: !isSending,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: AppColors.textNeutral,
                      ),
                      hintStyle: const TextStyle(
                        color: AppColors.textNeutral,
                        fontSize: 15,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 16,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.buttonBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.6,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 1.6,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    validator: (value) {
                      final v = value?.trim() ?? '';
                      if (v.isEmpty) return 'Please enter your email';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: isSending
                              ? null
                              : () => Navigator.pop(dialogContext),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(
                                color: AppColors.buttonBorder,
                              ),
                            ),
                            foregroundColor: AppColors.textDark,
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: isSending
                              ? null
                              : () async {
                                  if (!formKey.currentState!.validate()) return;
                                  setDialogState(() => isSending = true);
                                  final email = controller.text.trim();
                                  try {
                                    await ref
                                        .read(authProvider.notifier)
                                        .resetPassword(email);
                                    if (dialogContext.mounted) {
                                      Navigator.pop(dialogContext);
                                    }
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Password reset link sent to $email.',
                                        ),
                                        backgroundColor: AppColors.success,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (_) {
                                    if (dialogContext.mounted) {
                                      setDialogState(() => isSending = false);
                                    }
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Could not send reset link. Please try again.',
                                        ),
                                        backgroundColor: AppColors.error,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.primary
                                .withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: isSending
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'Send Link',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ).then((_) => controller.dispose());
  }
}
