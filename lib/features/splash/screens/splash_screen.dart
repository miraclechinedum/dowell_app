import 'dart:async';
import 'package:flutter/material.dart';

import '../../../core/navigation/auth_wrapper.dart';
import '../../../core/widgets/logo_image.dart';

/// Cold-launch splash. Mounted at `/`, holds a branded splash screen for
/// [_holdFor] then swaps its child to [AuthWrapper] in place — no Navigator
/// manipulation, so every existing named route and auth state transition
/// behaves exactly as before.
///
/// Design: diagonal Dowell-green gradient with a scattered translucent-circle
/// pattern, the dark logo wrapped in a white rounded card (so it stays legible
/// against the green and the handoff from the native white splash feels like
/// the white "shrinking" into the card).
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate>
    with SingleTickerProviderStateMixin {
  static const Duration _holdFor = Duration(milliseconds: 2500);

  // Brand green family — top-left lighter (success) to bottom-right darker.
  static const Color _gradientTop = Color(0xFF388E3C);
  static const Color _gradientBottom = Color(0xFF1B5E20);

  late final AnimationController _controller;
  late final Animation<double> _textFade;
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
    );
    _controller.forward();

    _timer = Timer(_holdFor, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const AuthWrapper();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_gradientTop, _gradientBottom],
          ),
        ),
        child: Stack(
          children: [
            // Decorative scattered-circle pattern overlay.
            const Positioned.fill(
              child: CustomPaint(painter: _SplashPatternPainter()),
            ),
            SafeArea(
              child: Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo in white rounded card — keeps the dark logo
                        // legible on green and bridges the native splash.
                        Container(
                          width: 156,
                          height: 156,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.22),
                                blurRadius: 32,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: LogoImage(size: 110),
                          ),
                        ),
                        const SizedBox(height: 28),
                        FadeTransition(
                          opacity: _textFade,
                          child: const Text(
                            'Dowell Pest Control',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FadeTransition(
                          opacity: _textFade,
                          child: Text(
                            'Smarter referrals. Better service.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.80),
                              fontSize: 13,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 48),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Scattered translucent-circle pattern for the splash background.
/// Positions are fractions of (width, height) — deterministic so the pattern
/// stays stable across rebuilds and at every screen size.
class _SplashPatternPainter extends CustomPainter {
  const _SplashPatternPainter();

  // Each entry: [fx, fy, radiusFactor (of width), alpha].
  static const List<List<double>> _circles = [
    [0.08, 0.10, 0.20, 0.06],
    [0.88, 0.18, 0.32, 0.05],
    [0.18, 0.82, 0.24, 0.06],
    [0.78, 0.86, 0.18, 0.07],
    [0.50, 0.50, 0.50, 0.03],
    [0.95, 0.55, 0.10, 0.08],
    [0.04, 0.52, 0.08, 0.09],
    [0.42, 0.04, 0.13, 0.06],
    [0.62, 0.30, 0.07, 0.10],
    [0.30, 0.40, 0.05, 0.10],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final c in _circles) {
      final paint = Paint()..color = Colors.white.withOpacity(c[3]);
      canvas.drawCircle(
        Offset(size.width * c[0], size.height * c[1]),
        size.width * c[2],
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SplashPatternPainter oldDelegate) => false;
}
