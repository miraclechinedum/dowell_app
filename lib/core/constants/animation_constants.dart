import 'package:flutter/material.dart';

class AnimationConstants {
  // Durations
  static const initialDelay = Duration(milliseconds: 300);
  static const iconScaleDuration = Duration(milliseconds: 600);
  static const textFadeDuration = Duration(milliseconds: 500);
  static const mascotFloatDuration = Duration(milliseconds: 400);
  static const taglineDelay = Duration(milliseconds: 200);
  static const buttonSlideDuration = Duration(milliseconds: 500);
  static const buttonDelay = Duration(milliseconds: 300);

  // Curves
  static const easeOut = Curves.easeOut;
  static const easeOutCubic = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}
