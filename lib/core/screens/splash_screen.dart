// lib/core/screens/splash_screen.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _rippleController;

  late Animation<double> _logoOpacity;
  late Animation<Offset> _logoSlide;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _ripple1;
  late Animation<double> _ripple2;

  @override
  void initState() {
    super.initState();

    // Background subtle pulse
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // Logo slides in from top
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _logoOpacity = CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Slides from above the screen down to center
    _logoSlide = CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ).drive(Tween(begin: const Offset(0, -3.0), end: Offset.zero));

    // Text entrance (delayed after logo lands)
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeIn,
    ).drive(Tween(begin: 0.0, end: 1.0));

    _textSlide = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ).drive(Tween(begin: const Offset(0, 0.5), end: Offset.zero));

    // Ripple rings (triggered when logo lands)
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _ripple1 = CurvedAnimation(
      parent: _rippleController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ).drive(Tween(begin: 0.0, end: 1.0));

    _ripple2 = CurvedAnimation(
      parent: _rippleController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
    ).drive(Tween(begin: 0.0, end: 1.0));

    // Sequence: logo slides in → ripples burst → text fades up
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _logoController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _rippleController.forward();
    });

    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) _textController.forward();
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _logoController.dispose();
    _textController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _bgController,
          _logoController,
          _textController,
          _rippleController,
        ]),
        builder: (context, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // ── Textured background ──────────────────────────────────────
              CustomPaint(
                painter: _TexturedBgPainter(pulseValue: _bgController.value),
              ),

              // ── Ripple rings ─────────────────────────────────────────────
              Center(
                child: CustomPaint(
                  size: const Size(400, 400),
                  painter: _RipplePainter(
                    ripple1: _ripple1.value,
                    ripple2: _ripple2.value,
                  ),
                ),
              ),

              // ── Logo + text ──────────────────────────────────────────────
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo slides in from top
                    SlideTransition(
                      position: _logoSlide,
                      child: FadeTransition(
                        opacity: _logoOpacity,
                        child: Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.25),
                                blurRadius: 32,
                                offset: const Offset(0, 8),
                              ),
                              BoxShadow(
                                color: const Color(0xFF1B5E20).withOpacity(0.5),
                                blurRadius: 48,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/images/dowell_logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // App name + tagline fade up
                    SlideTransition(
                      position: _textSlide,
                      child: FadeTransition(
                        opacity: _textOpacity,
                        child: Column(
                          children: [
                            const Text(
                              'Dowell Pest Control',
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 30,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1.5,
                                shadows: [
                                  Shadow(
                                    color: Color(0xFF1B5E20),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Protecting Your Space',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.75),
                                letterSpacing: 2.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Painters ────────────────────────────────────────────────────────────────

class _TexturedBgPainter extends CustomPainter {
  final double pulseValue;
  _TexturedBgPainter({required this.pulseValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [
          Color(0xFF1B5E20),
          Color(0xFF2E7D32),
          Color(0xFF388E3C),
          Color(0xFF1B5E20),
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
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
    final cy = size.height / 2;
    final highlightPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              Colors.white.withOpacity(0.08 + pulseValue * 0.04),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: size.width * 0.6),
          );
    canvas.drawCircle(Offset(cx, cy), size.width * 0.6, highlightPaint);

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
  bool shouldRepaint(_TexturedBgPainter old) => old.pulseValue != pulseValue;
}

class _RipplePainter extends CustomPainter {
  final double ripple1;
  final double ripple2;

  _RipplePainter({required this.ripple1, required this.ripple2});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;

    void drawRipple(double t) {
      if (t <= 0) return;
      final radius = maxRadius * t;
      final opacity = (1 - t) * 0.35;
      final paint = Paint()
        ..color = Colors.white.withOpacity(opacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawCircle(center, radius, paint);
    }

    drawRipple(ripple1);
    drawRipple(ripple2);
  }

  @override
  bool shouldRepaint(_RipplePainter old) =>
      old.ripple1 != ripple1 || old.ripple2 != ripple2;
}
