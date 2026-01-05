import 'package:flutter/material.dart';

class LogoImage extends StatelessWidget {
  final double size;

  const LogoImage({super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/dowell_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        // Fallback if image fails to load
        return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: const Color(0xFF2E7D32),
            borderRadius: BorderRadius.circular(size * 0.2),
          ),
          child: const Center(
            child: Icon(Icons.pest_control, color: Colors.white, size: 48),
          ),
        );
      },
    );
  }
}
