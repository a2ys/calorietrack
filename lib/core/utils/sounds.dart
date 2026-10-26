import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// The app's sound cues. Files are Kenney "Interface Sounds" (CC0), in
/// assets/sfx. Most cues fire through [Haptics], so anything that already
/// has a haptic gets its sound for free; [water] is played directly.
enum Sfx {
  /// Selection: steppers, chips, tabs. Fires constantly, so it is the
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
/// previews never touch the audio plugin) and whenever [enabled] is false.
///
/// Sounds never interrupt the user's music: on Android they use the
/// sonification stream with no audio focus, which also follows silent mode;
/// on iOS the ambient session mixes with other audio and obeys the mute switch.
abstract final class Sounds {
  /// User preference (Settings > Sounds). On by default.
  static bool enabled = true;

  static final Map<Sfx, AudioPool> _pools = {};
  static final Map<Sfx, DateTime> _lastPlayed = {};

  /// The same cue never repeats faster than this (held steppers, fast taps).
  static const Duration _minGap = Duration(milliseconds: 45);

  static Future<void> init() async {
    final context = AudioContext(
      android: const AudioContextAndroid(
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.assistanceSonification,
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
    try {
      await AudioPlayer.global.setAudioContext(context);
      for (final s in Sfx.values) {
        _pools[s] = await AudioPool.create(
          source: AssetSource('sfx/${s.file}'),
          audioContext: context,
          // Low latency (SoundPool on Android) so the sound lands with the
          // haptic and the visual on the same frame.
          playerMode: PlayerMode.lowLatency,
          minPlayers: 1,
          maxPlayers: s == Sfx.tick ? 4 : 2,
        );
      }
    } catch (e) {
      // No audio is better than a crash; the app works fine without it.
      debugPrint('Sounds disabled: $e');
      _pools.clear();
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
    _pools[s]?.start(volume: s.volume).ignore();
  }
}
