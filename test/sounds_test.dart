import 'package:calorie_app/core/utils/haptics.dart';
import 'package:calorie_app/core/utils/sounds.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final played = <Sfx>[];

  setUp(() {
    played.clear();
    Sounds.debugOnPlay = played.add;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  tearDown(() {
    Sounds.debugOnPlay = null;
    Sounds.enabled = true;
    Haptics.level = Haptics.defaultLevel;
  });

  // Each test waits out the per-cue throttle left by the previous one.
  Future<void> gap() => Future<void>.delayed(const Duration(milliseconds: 60));

  test('every haptic event plays its sound cue', () async {
    await gap();
    Haptics.tap();
    Haptics.light();
    Haptics.medium();
    Haptics.success();
    Haptics.warning();
    expect(played, [Sfx.tick, Sfx.open, Sfx.thunk, Sfx.success, Sfx.warning]);
  });

  test('a moment can pick its own cue', () async {
    await gap();
    Haptics.success(Sfx.water);
    expect(played, [Sfx.water]);
  });

  test('sound follows its own switch, not haptic strength', () async {
    await gap();
    Haptics.level = 0; // haptics off
    Haptics.tap();
    expect(played, [Sfx.tick]);

    await gap();
    Sounds.enabled = false;
    Haptics.level = Haptics.defaultLevel;
    Haptics.tap();
    expect(played, [Sfx.tick]);
  });

  test('rapid repeats of one cue are throttled', () async {
    await gap();
    for (var i = 0; i < 5; i++) {
      Haptics.tap();
    }
    expect(played, [Sfx.tick]);
  });
}
