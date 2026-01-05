import 'package:flutter/material.dart';

class AnimatedButton extends StatelessWidget {
  final Animation<double> animation;
  final String text;
  final IconData? icon;
  final Color backgroundColor;
  final Color textColor;
  final bool hasBorder;
  final VoidCallback onPressed;

  const AnimatedButton({
    super.key, // Fixed: Use super.key
    required this.animation,
    required this.text,
    this.icon,
    this.backgroundColor = const Color(0xFF2C3E50),
    this.textColor = Colors.white,
    this.hasBorder = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
      child: FadeTransition(
        opacity: animation,
        child: Container(
          height: 56,
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor,
              foregroundColor: textColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: hasBorder
                    ? const BorderSide(color: Color(0xFFE0E0E0), width: 1)
                    : BorderSide.none,
              ),
              elevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20),
                  const SizedBox(width: 12),
                ],
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
