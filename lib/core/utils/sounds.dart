import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The app's sound cues. Files are Kenney "Interface Sounds" (CC0), in
/// assets/sfx, converted to short mono 48 kHz PCM with the leading silence
/// trimmed so they start on the tap. Most cues fire through [Haptics], so
/// anything that already has a haptic gets its sound for free; [water] is
/// played directly.
enum Sfx {
  /// Selection: steppers, chips, tabs, wheels. Fires constantly, so it is the
  /// quietest and is throttled.
  tick('click_005.wav', 0.3),

  /// Opening something: sheets, dialogs, the + button.
  open('select_002.wav', 0.45),

  /// Removing something.
  thunk('back_002.wav', 0.55),

  /// Logged or saved.
  success('confirmation_001.wav', 0.5),

  warning('error_004.wav', 0.5),

  /// Water logged: a drop.
  water('drop_002.wav', 0.6);

  const Sfx(this.file, this.volume);
  final String file;
  final double volume;
}

/// Plays short UI sounds. Silent until [init] has run (so widget tests and
/// previews never touch the platform) and whenever [enabled] is false.
///
/// On Android the cues are decoded once into a SoundPool (MainActivity.kt), so
/// a play is one fire-and-forget message: nothing is awaited and no player is
/// created per tap. They use the sonification stream with no audio focus, so
/// the user's music keeps playing, and stay muted in silent or vibrate mode.
/// Other platforms (web previews) are silent.
abstract final class Sounds {
  /// User preference (Settings > Sounds). On by default.
  static bool enabled = true;

  static const _channel = MethodChannel('calorie/sfx');
  static bool _loaded = false;
  static final Map<Sfx, DateTime> _lastPlayed = {};

  /// The same cue never repeats faster than this (held steppers, fast wheels).
  static const Duration _minGap = Duration(milliseconds: 45);

  static bool get _supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Loads the cues natively. Call after the first frame; taps before the
  /// load finishes are silent.
  static Future<void> init() async {
    if (_loaded || !_supported) return;
    try {
      await _channel.invokeMethod<void>('load', [for (final s in Sfx.values) 'assets/sfx/${s.file}']);
      _loaded = true;
    } catch (e) {
      // No audio is better than a crash; the app works fine without it.
      debugPrint('Sounds disabled: $e');
    }
  }

  /// Sees every cue that would play, even before [init] (tests only).
  @visibleForTesting
  static void Function(Sfx)? debugOnPlay;

  static void play(Sfx s) {
    if (!enabled) return;
    final now = DateTime.now();
    final last = _lastPlayed[s];
    if (last != null && now.difference(last) < _minGap) return;
    _lastPlayed[s] = now;
    debugOnPlay?.call(s);
    if (_loaded) _channel.invokeMethod<void>('play', [s.index, s.volume]).ignore();
  }
}
