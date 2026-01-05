import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/logo_image.dart';
import '../../../core/widgets/cta_buttons.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _bounceController;
  late AnimationController _sequenceController;

  // Bounce animations
  late Animation<double> _bounceScale;
  late Animation<double> _bounceOpacity;

  // Sequence animations (for staggered entrance)
  late Animation<double> _titleAnimation;
  late Animation<double> _taglineAnimation;
  late Animation<double> _buttonAnimation;
  late Animation<double> _termsAnimation;

  @override
  void initState() {
    super.initState();

    // Bounce animation controller (for logo)
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Sequence animation controller (for staggered text/buttons)
    _sequenceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Setup animations
    _setupBounceAnimation();
    _setupSequenceAnimation();

    // Start animation sequence
    _startAnimationSequence();
  }

  void _setupBounceAnimation() {
    // Triple bounce animation
    _bounceScale =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 0.3),
          TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.9), weight: 0.2),
          TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.1), weight: 0.2),
          TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 0.3),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeInOut),
        );

    _bounceOpacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _bounceController, curve: Curves.easeIn));
  }

  void _setupSequenceAnimation() {
    // Staggered animations with perfect timing
    _titleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOut),
      ),
    );

    _taglineAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.25, 0.5, curve: Curves.easeOut),
      ),
    );

    _buttonAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.5, 0.75, curve: Curves.easeOut),
      ),
    );

    _termsAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _sequenceController,
        curve: const Interval(0.75, 1.0, curve: Curves.easeOut),
      ),
    );
  }

  void _startAnimationSequence() async {
    // Initial delay
    await Future.delayed(const Duration(milliseconds: 300));

    // Start bounce animation
    _bounceController.forward().then((_) {
      // After bounce completes, start sequence animations
      Future.delayed(const Duration(milliseconds: 200), () {
        _sequenceController.forward();
      });
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _sequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.warmOffWhite,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Top spacer
                const Expanded(flex: 2, child: SizedBox()),

                // Logo with triple bounce animation
                ScaleTransition(
                  scale: _bounceScale,
                  child: FadeTransition(
                    opacity: _bounceOpacity,
                    child: const LogoImage(size: 140),
                  ),
                ),

                const SizedBox(height: 40),

                // App Title - "Dowell"
                FadeTransition(
                  opacity: _titleAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_titleAnimation),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: const Text(
                        'Dowell',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 42,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Tagline - "Earn Rewards by referring potential clients."
                FadeTransition(
                  opacity: _taglineAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.3),
                      end: Offset.zero,
                    ).animate(_taglineAnimation),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: const Text(
                        'Earn Rewards by referring potential clients.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: AppColors.textNeutral,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom spacer
                Expanded(flex: 3, child: Container()),

                // CTA Button - "Get Started"
                FadeTransition(
                  opacity: _buttonAnimation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.5),
                      end: Offset.zero,
                    ).animate(_buttonAnimation),
                    child: SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _navigateToLogin(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Get Started',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Terms text
                Padding(
                  padding: const EdgeInsets.only(top: 20.0),
                  child: FadeTransition(
                    opacity: _termsAnimation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(_termsAnimation),
                      child: RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textNeutral.withOpacity(0.7),
                            height: 1.4,
                          ),
                          children: const [
                            TextSpan(
                              text:
                                  'Clicking "Get Started" means you agree to our ',
                            ),
                            TextSpan(
                              text: 'Terms',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                            TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Small bottom spacer
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _navigateToLogin(BuildContext context) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Navigate to login screen with custom transition
    Navigator.pushNamed(context, '/login');
  }
}
