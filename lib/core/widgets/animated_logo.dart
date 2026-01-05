import 'package:flutter/material.dart';

class AnimatedLogo extends StatelessWidget {
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;

  const AnimatedLogo({
    super.key, // Fixed: Use super.key
    required this.scaleAnimation,
    required this.fadeAnimation,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: scaleAnimation,
      child: FadeTransition(
        opacity: fadeAnimation,
        child: Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2E7D32).withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: Center(
            child: Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Icon(
                  Icons.pest_control,
                  color: Color(0xFF2E7D32),
                  size: 48,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
