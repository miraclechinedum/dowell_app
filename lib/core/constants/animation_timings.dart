class AnimationTimings {
  // SCREEN 0 — INITIAL LOAD (PRE-SPLASH STATE)
  static const initialLoadDelay = Duration(milliseconds: 350); // 250-400ms

  // SCREEN 1 — APP ICON INTRO (PRIMARY SPLASH)
  static const iconIntroDuration = Duration(milliseconds: 550); // 500-600ms

  // SCREEN 2 — APP NAME REVEAL
  static const nameRevealStartDelay = Duration(milliseconds: 100); // 100-150ms
  static const nameRevealDuration = Duration(milliseconds: 450); // 400-500ms

  // SCREEN 3 — MASCOT SEPARATION & FLOAT
  static const mascotFloatStartDelay = Duration(
    milliseconds: 200,
  ); // after text settles
  static const mascotFloatDuration = Duration(milliseconds: 350); // 300-400ms

  // SCREEN 4 — TAGLINE REVEAL
  static const taglineStartDelay = Duration(
    milliseconds: 100,
  ); // after mascot settles
  static const taglineLine1Duration = Duration(milliseconds: 300); // 300ms
  static const taglineLine2Delay = Duration(
    milliseconds: 100,
  ); // 100ms after line 1
  static const taglineLine2Duration = Duration(milliseconds: 300); // 300ms

  // SCREEN 5 — CTA BUTTON APPEARANCE
  static const buttonsStartDelay = Duration(
    milliseconds: 200,
  ); // after tagline completes
  static const buttonsDuration = Duration(milliseconds: 450); // 400-500ms
}
