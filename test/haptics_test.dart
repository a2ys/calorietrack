import 'package:calorie_app/core/utils/haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final played = <String>[];

  setUp(() {
    played.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') played.add(call.arguments as String);
      return null;
    });
  });

  tearDown(() => Haptics.level = Haptics.defaultLevel);

  test('default strength is 70%', () {
    expect(Haptics.defaultLevel, 70);
  });

  test('level -> how many rungs everything shifts', () {
    int shiftAt(int level) {
      Haptics.level = level;
      return Haptics.shift;
    }

    expect(shiftAt(1), -1);
    expect(shiftAt(29), -1);
    expect(shiftAt(30), 0);
    expect(shiftAt(59), 0);
    expect(shiftAt(60), 1);
    expect(shiftAt(70), 1);
    expect(shiftAt(84), 1);
    expect(shiftAt(85), 2);
    expect(shiftAt(100), 2);
  });

  test('0% is completely off', () {
    Haptics.level = 0;
    expect(Haptics.enabled, isFalse);
    Haptics.tap();
    Haptics.light();
    Haptics.medium();
    Haptics.warning();
    expect(played, isEmpty);
  });

  test('the original feel sits at 50%', () {
    Haptics.level = 50;
    Haptics.tap();
    Haptics.light();
    Haptics.medium();
    expect(played, [
      'HapticFeedbackType.selectionClick',
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
    ]);
  });

  test('the 70% default is one notch stronger than the original', () {
    Haptics.level = 70;
    Haptics.tap();
    Haptics.light();
    Haptics.medium();
    expect(played, [
      'HapticFeedbackType.lightImpact',
      'HapticFeedbackType.mediumImpact',
      'HapticFeedbackType.heavyImpact',
    ]);
  });

  test('100% is two notches stronger; ladder never runs past the top', () {
    Haptics.level = 100;
    expect(Haptics.rungFor(0), 2);
    expect(Haptics.rungFor(3), 4);
    expect(Haptics.rungFor(4), 4);
  });

  test('soft levels never go below the lightest tick', () {
    Haptics.level = 20;
    expect(Haptics.rungFor(0), 0);
    Haptics.tap();
    expect(played, ['HapticFeedbackType.selectionClick']);
  });
}
