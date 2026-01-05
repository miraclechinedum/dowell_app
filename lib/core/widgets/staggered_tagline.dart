import 'package:flutter/material.dart';

class StaggeredTagline extends StatelessWidget {
  final Animation<double> line1Animation;
  final Animation<double> line2Animation;

  const StaggeredTagline({
    super.key, // Fixed: Use super.key
    required this.line1Animation,
    required this.line2Animation,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Line 1: "Refer. Earn. Repeat."
        FadeTransition(
          opacity: line1Animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(line1Animation),
            child: Text(
              'Refer. Earn. Repeat.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF7F8C8D),
                fontSize: 18,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Line 2: "Break the pest cycle."
        FadeTransition(
          opacity: line2Animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(line2Animation),
            child: Text(
              'Break the pest cycle.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF2E7D32),
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
