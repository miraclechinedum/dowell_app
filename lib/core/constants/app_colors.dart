import 'package:flutter/material.dart';

class AppColors {
  // Primary brand colors
  static const primary = Color(0xFF2E7D32); // Green (mascot color)
  static const secondary = Color(0xFF212121); // Dark Grey
  static const accent = Color(0xFF2E7D32); // Alias for primary

  // Warm off-white / cream background (Screen 0)
  static const warmOffWhite = Color(0xFFFDFAF6);
  static const background = Color(0xFFFDFAF6); // Alias for warmOffWhite

  // Text colors
  static const textDark = Color(0xFF2C3E50); // Near black for app name
  static const textLight = Color(0xFF7F8C8D); // Neutral gray for tagline line 1
  static const textNeutral = Color(
    0xFF7F8C8D,
  ); // Neutral gray for tagline line 1
  static const textAccent = Color(0xFF2E7D32); // Green for tagline line 2

  // Button colors
  static const buttonPrimary = Color(0xFF212121); // Black for primary button
  static const buttonSecondary = Color(
    0xFFFFFFFF,
  ); // White for secondary button
  static const buttonBorder = Color(0xFFE0E0E0); // Border for secondary button

  // Status colors
  static const success = Color(0xFF388E3C);
  static const error = Color(0xFFD32F2F);

  // Utility
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const border = Color(0xFFE0E0E0);
}
