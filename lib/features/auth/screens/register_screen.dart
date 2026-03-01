// lib/features/auth/screens/register_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/form_text_field.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/widgets/privacy_policy_dialog.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _cardController;
  late Animation<Offset> _cardSlide;
  late Animation<double> _cardFade;

  bool _termsAccepted = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  bool _isLoading = false;

  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();

    _cardController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _cardSlide = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeOutCubic,
    ).drive(Tween(begin: const Offset(0, 0.18), end: Offset.zero));

    _cardFade = CurvedAnimation(
      parent: _cardController,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _cardController.forward();
    _passwordController.addListener(_validatePassword);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final p = _passwordController.text;
    setState(() {
      _hasMinLength = p.length >= 8;
      _hasUppercase = p.contains(RegExp(r'[A-Z]'));
      _hasLowercase = p.contains(RegExp(r'[a-z]'));
      _hasNumber = p.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = p.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isPasswordValid() =>
      _hasMinLength &&
      _hasUppercase &&
      _hasLowercase &&
      _hasNumber &&
      _hasSpecialChar;

  int get _metCount => [
    _hasMinLength,
    _hasUppercase,
    _hasLowercase,
    _hasNumber,
    _hasSpecialChar,
  ].where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Green gradient background ────────────────────────────────────
          CustomPaint(painter: _GreenBgPainter()),

          // ── Header ───────────────────────────────────────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : () => Navigator.pop(context),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.1,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign up to start earning rewards',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withOpacity(0.75),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── White card ───────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: MediaQuery.of(context).size.height * 0.30,
            child: SlideTransition(
              position: _cardSlide,
              child: FadeTransition(
                opacity: _cardFade,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(36),
                      topRight: Radius.circular(36),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 36, 28, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Error banner
                        if (authState.error != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: AppColors.error.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.error.withOpacity(0.3),
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
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Email
                              FormTextField(
                                label: 'Email Address',
                                hintText: 'you@example.com',
                                prefixIcon: const Icon(Icons.email_outlined),
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email address';
                                  }
                                  if (!RegExp(
                                    r'^[^@]+@[^@]+\.[^@]+',
                                  ).hasMatch(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Password
                              FormTextField(
                                label: 'Password',
                                hintText: 'Create a strong password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: AppColors.textNeutral,
                                  ),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                                controller: _passwordController,
                                obscureText: !_showPassword,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter a password';
                                  }
                                  if (!_isPasswordValid()) {
                                    return 'Password does not meet all requirements';
                                  }
                                  return null;
                                },
                              ),

                              // Compact strength indicator
                              if (_passwordController.text.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    2,
                                    10,
                                    2,
                                    4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: List.generate(5, (i) {
                                          final filled = i < _metCount;
                                          Color barColor;
                                          if (_metCount <= 2) {
                                            barColor = AppColors.error;
                                          } else if (_metCount <= 3) {
                                            barColor = Colors.orange;
                                          } else {
                                            barColor = AppColors.success;
                                          }
                                          return Expanded(
                                            child: Container(
                                              height: 4,
                                              margin: EdgeInsets.only(
                                                right: i < 4 ? 4 : 0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: filled
                                                    ? barColor
                                                    : Colors.grey.withOpacity(
                                                        0.25,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                            ),
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        children: [
                                          _chip('8+ chars', _hasMinLength),
                                          _chip('A-Z', _hasUppercase),
                                          _chip('a-z', _hasLowercase),
                                          _chip('0-9', _hasNumber),
                                          _chip('#!@', _hasSpecialChar),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                              const SizedBox(height: 20),

                              // Confirm Password
                              FormTextField(
                                label: 'Confirm Password',
                                hintText: 'Re-enter your password',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showConfirmPassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: AppColors.textNeutral,
                                  ),
                                  onPressed: () => setState(
                                    () => _showConfirmPassword =
                                        !_showConfirmPassword,
                                  ),
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

                              const SizedBox(height: 24),

                              // Terms checkbox
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: _termsAccepted
                                        ? AppColors.primary.withOpacity(0.4)
                                        : AppColors.buttonBorder,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Checkbox(
                                        value: _termsAccepted,
                                        onChanged: _isLoading
                                            ? null
                                            : (value) => setState(
                                                () => _termsAccepted =
                                                    value ?? false,
                                              ),
                                        activeColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              color: AppColors.textNeutral,
                                              fontSize: 13,
                                              height: 1.4,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'I agree to the ',
                                              ),
                                              WidgetSpan(
                                                child: GestureDetector(
                                                  onTap: _isLoading
                                                      ? null
                                                      : _showTermsDialog,
                                                  child: const Text(
                                                    'Terms of Service',
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const TextSpan(text: ' and '),
                                              WidgetSpan(
                                                child: GestureDetector(
                                                  onTap: _isLoading
                                                      ? null
                                                      : _showPrivacyPolicy,
                                                  child: const Text(
                                                    'Privacy Policy',
                                                    style: TextStyle(
                                                      color: AppColors.primary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      decoration: TextDecoration
                                                          .underline,
                                                    ),
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

                              const SizedBox(height: 28),

                              // ── Create Account button with inline loader ──
                              _CreateAccountButton(
                                isLoading: _isLoading,
                                enabled: _termsAccepted,
                                onPressed: () {
                                  if (_formKey.currentState!.validate()) {
                                    _register(context);
                                  }
                                },
                              ),

                              const SizedBox(height: 28),

                              // Sign in link
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account? ',
                                    style: TextStyle(
                                      color: AppColors.textNeutral,
                                      fontSize: 14,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _isLoading
                                        ? null
                                        : () => Navigator.pop(context),
                                    child: Text(
                                      'Sign in',
                                      style: TextStyle(
                                        color: _isLoading
                                            ? AppColors.textNeutral
                                            : AppColors.primary,
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: met
            ? AppColors.success.withOpacity(0.12)
            : Colors.grey.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: met
              ? AppColors.success.withOpacity(0.4)
              : Colors.grey.withOpacity(0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check : Icons.remove,
            size: 11,
            color: met ? AppColors.success : AppColors.textNeutral,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: met ? AppColors.success : AppColors.textNeutral,
            ),
          ),
        ],
      ),
    );
  }

  void _showTermsDialog() {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyDialog(
        title: 'Terms of Service',
        content: '''
Dowell Pest Control Terms of Service

Last updated: February 10, 2026

1. Acceptance of Terms
By accessing or using the Dowell Pest Control mobile application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.

2. Description of Service
Dowell Pest Control provides a platform for:
- Scheduling pest control services
- Managing service appointments
- Processing payments
- Submitting and tracking referrals
- Earning and redeeming rewards (Bug Bucks)

3. User Accounts
- You must be at least 18 years old to create an account
- You are responsible for maintaining account security
- You must provide accurate and complete information
- You are responsible for all activities under your account

4. Referral Program Terms
- Bug Bucks are awarded upon referral submission
- Rewards have no cash value and are non-transferable
- Dowell reserves the right to modify or terminate the program
- Fraudulent referrals will result in account termination

5. Payments and Refunds
- Service payments are processed securely through our payment partners
- Refunds are handled according to our refund policy
- Subscription fees are non-refundable unless required by law

6. User Conduct
You agree not to:
- Use the App for any illegal purpose
- Attempt to gain unauthorized access
- Interfere with the App\'s functionality
- Submit false or misleading information

7. Intellectual Property
All content in the App is owned by Dowell Pest Control and protected by copyright and other laws.

8. Termination
We reserve the right to suspend or terminate accounts for violations of these terms.

9. Limitation of Liability
Dowell Pest Control is not liable for indirect, incidental, or consequential damages.

10. Changes to Terms
We may update these terms. Continued use of the App constitutes acceptance of updated terms.

11. Contact Information
For questions about these Terms, contact:
Email: legal@dowellpestcontrol.com
Phone: 361-729-2370
''',
      ),
    );
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyDialog(
        title: 'Privacy Policy',
        content: '''
Dowell Pest Control Privacy Policy

Last updated: February 10, 2026

Information We Collect

Personal Information
We may collect personal information that you voluntarily provide, including but not limited to:
• Name
• Email address
• Phone number
• Service address
• Account login information

Usage Data
We may automatically collect certain information when you use the App, including:
• Device type
• Operating system
• App version
• IP address
• Pages or features used within the App
• Date and time of use

How We Use Your Information
We use the information we collect to:
• Provide and manage pest control services
• Schedule appointments and service visits
• Communicate with you regarding your account or services
• Improve app functionality and customer experience
• Respond to customer support requests
• Maintain security and prevent fraud

We do not sell your personal data.

Contact Us
Email: info@dowellpestcontrol.com
Phone: 361-729-2370
Website: https://www.dowellpestcontrol.com
''',
      ),
    );
  }

  Future<void> _register(BuildContext context) async {
    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    ref.read(authProvider.notifier).clearError();

    try {
      await ref
          .read(authProvider.notifier)
          .registerWithEmail(email: email, password: password);

      final authState = ref.read(authProvider);

      if (authState.status == AuthStatus.authenticated && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created! Please check your email for verification.',
            ),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );

        await Future.delayed(const Duration(seconds: 2), () {
          Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
        });
      }
    } catch (e) {
      debugPrint('Registration error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ─── Create Account button with inline loading state ─────────────────────────
class _CreateAccountButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;

  const _CreateAccountButton({
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool active = enabled && !isLoading;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: active
              ? const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF2E7D32), Color(0xFF4CAF50)],
                )
              : LinearGradient(
                  colors: [
                    const Color(0xFF2E7D32).withOpacity(0.5),
                    const Color(0xFF4CAF50).withOpacity(0.5),
                  ],
                ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: const Color(0xFF2E7D32).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: active ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? LoadingAnimationWidget.staggeredDotsWave(
                  color: Colors.white,
                  size: 28,
                )
              : const Text(
                  'CREATE ACCOUNT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Green background painter ─────────────────────────────────────────────────
class _GreenBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF1B5E20),
          Color(0xFF2E7D32),
          Color(0xFF388E3C),
          Color(0xFF1B5E20),
        ],
        stops: [0.0, 0.35, 0.65, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final rng = math.Random(42);
    final dotPaint = Paint()..color = Colors.white.withOpacity(0.025);
    for (int i = 0; i < 600; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), rng.nextDouble() * 1.8, dotPaint);
    }

    final cx = size.width / 2;
    final cy = size.height * 0.18;
    final highlightPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [Colors.white.withOpacity(0.10), Colors.transparent],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.7),
          );
    canvas.drawCircle(Offset(cx, cy), size.width * 0.7, highlightPaint);

    final streakPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 80
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(-size.width * 0.1, 0),
      Offset(size.width * 0.6, size.height),
      streakPaint,
    );
    canvas.drawLine(
      Offset(size.width * 0.5, 0),
      Offset(size.width * 1.2, size.height),
      streakPaint,
    );
  }

  @override
  bool shouldRepaint(_GreenBgPainter old) => false;
}
