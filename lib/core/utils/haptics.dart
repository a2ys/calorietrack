import 'package:flutter/services.dart';

import 'sounds.dart';

/// Thin wrapper so haptics can be tuned in one place.
///
/// Every event also plays its sound cue ([Sounds]), so new UI that uses
/// Haptics gets matching sound with no extra work. Sound follows its own
/// on/off setting, not the haptic strength.
///
/// Flutter can only ask the OS for a few fixed feedback types, so "strength" is
/// a ladder of them. Every haptic in the app has a base rung; the user's
/// [level] (0-100, Settings > Haptics) shifts all of them up or down together:
///
///   0        off
///   1-29     one rung softer
///   30-59    the original feel
///   60-84    one rung stronger   <- default (70)
///   85-100   two rungs stronger
///
/// Rungs: 0 selection tick, 1 light, 2 medium, 3 heavy, 4 double heavy.
abstract final class Haptics {
  /// Default strength for a fresh install. Only changeable in Settings.
  static const int defaultLevel = 70;

  /// 0-100. Set from the saved preference.
  static int level = defaultLevel;

  static bool get enabled => level > 0;

  static const int _top = 4;

  /// How many rungs [level] moves every haptic.
  static int get shift => level >= 85
      ? 2
      : level >= 60
          ? 1
          : level >= 30
              ? 0
              : -1;

  /// Rung actually used for an event whose base rung is [base].
  static int rungFor(int base) => (base + shift).clamp(0, _top);

  static void _play(int base) {
    if (!enabled) return;
    switch (rungFor(base)) {
      case 0:
        HapticFeedback.selectionClick();
      case 1:
        HapticFeedback.lightImpact();
      case 2:
        HapticFeedback.mediumImpact();
      case 3:
        HapticFeedback.heavyImpact();
      default:
        HapticFeedback.heavyImpact();
        Future<void>.delayed(const Duration(milliseconds: 70), () {
          if (enabled) HapticFeedback.heavyImpact();
        });
    }
  }

  /// Selection tick: segmented controls, wheels, steppers.
  static void tap() {
    Sounds.play(Sfx.tick);
    _play(0);
  }

  /// Opening something: sheets, dialogs, the + button.
  static void light() {
    Sounds.play(Sfx.open);
    _play(1);
  }

  /// Removing something.
  static void medium() {
    Sounds.play(Sfx.thunk);
    _play(2);
  }

  /// A thing was saved or logged: a firm tap followed by a soft one.
  /// [sound] lets a moment use its own cue (water plays a drop).
  static void success([Sfx sound = Sfx.success]) {
    Sounds.play(sound);
    if (!enabled) return;
    _play(2);
    Future<void>.delayed(const Duration(milliseconds: 90), () => _play(0));
  }

  static void warning() {
    Sounds.play(Sfx.warning);
    _play(3);
  }
}
