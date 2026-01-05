import 'package:flutter/material.dart';

class StaggeredText extends StatelessWidget {
  final Animation<double> animation;
  final String line1;
  final String line2;
  final Color line1Color;
  final Color line2Color;

  const StaggeredText({
    super.key, // Fixed: Use super.key
    required this.animation,
    required this.line1,
    required this.line2,
    this.line1Color = const Color(0xFF7F8C8D),
    this.line2Color = const Color(0xFF2E7D32),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
            ),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                  ),
                ),
            child: Text(
              line1,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: line1Color,
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        FadeTransition(
          opacity: Tween<double>(begin: 0, end: 1).animate(
            CurvedAnimation(
              parent: animation,
              curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
            ),
          ),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
                  ),
                ),
            child: Text(
              line2,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: line2Color,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
