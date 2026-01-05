import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class CTAButtons extends StatelessWidget {
  final Animation<double> animation;
  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  const CTAButtons({
    super.key, // Fixed: Use super.key
    required this.animation,
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.5),
        end: Offset.zero,
      ).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: Column(
          children: [
            // Primary Button (Green)
            SizedBox(
              // Fixed: Use SizedBox instead of Container for spacing
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12), // Fixed: Use SizedBox for spacing
            // Secondary Button (White with border)
            SizedBox(
              height: 56,
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onSecondaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textDark,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                    side: const BorderSide(
                      color: AppColors.buttonBorder,
                      width: 1,
                    ),
                  ),
                  elevation: 0,
                  shadowColor: Colors.transparent,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.login, size: 20),
                    SizedBox(width: 12),
                    Text(
                      'I Have an Account',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
