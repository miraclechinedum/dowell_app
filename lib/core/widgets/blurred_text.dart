import 'package:flutter/material.dart';

class BlurredText extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final Color color;
  final double blurAmount;
  final double opacity;

  const BlurredText({
    super.key, // Fixed: Use super.key
    required this.text,
    this.fontSize = 32,
    this.fontWeight = FontWeight.w700,
    this.color = const Color(0xFF2C3E50),
    this.blurAmount = 0,
    this.opacity = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity,
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          shadows: blurAmount > 0
              ? [
                  Shadow(
                    blurRadius: blurAmount,
                    color: Colors.black.withOpacity(0.3),
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
