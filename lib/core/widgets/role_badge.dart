import 'package:flutter/material.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  final double fontSize;

  const RoleBadge({super.key, required this.role, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String displayText;

    switch (role.toLowerCase()) {
      case 'admin':
        badgeColor = const Color(0xFF9C27B0);
        displayText = 'Admin';
        break;
      case 'employee':
        badgeColor = const Color(0xFF2196F3);
        displayText = 'Employee';
        break;
      case 'customer':
        badgeColor = const Color(0xFF4CAF50);
        displayText = 'Customer';
        break;
      default:
        badgeColor = Colors.grey;
        displayText = role;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor.withOpacity(0.3), width: 1),
      ),
      child: Text(
        displayText.toUpperCase(),
        style: TextStyle(
          color: badgeColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
