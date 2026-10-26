import 'package:calorie_app/core/utils/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 26, h, m);

  test('greeting follows the time of day', () {
    expect(greetingFor(at(5)).text, 'Good morning');
    expect(greetingFor(at(11, 59)).text, 'Good morning');
    expect(greetingFor(at(12)).text, 'Good afternoon');
    expect(greetingFor(at(16, 59)).text, 'Good afternoon');
    expect(greetingFor(at(17)).text, 'Good evening');
    expect(greetingFor(at(20, 59)).text, 'Good evening');
    // Late night keeps the plain greeting (only the emoji changes).
    expect(greetingFor(at(21)).text, 'Good evening');
    expect(greetingFor(at(0)).text, 'Good evening');
    expect(greetingFor(at(4, 59)).text, 'Good evening');
    expect(greetingFor(at(23)).emoji, '🌙');
  });

  test('every greeting has an emoji', () {
    for (var h = 0; h < 24; h++) {
      expect(greetingFor(at(h)).emoji, isNotEmpty);
    }
  });

  test('firstName', () {
    expect(firstName('  Aayush Shukla '), 'Aayush');
    expect(firstName('Aayush'), 'Aayush');
    expect(firstName('   '), '');
    expect(firstName(''), '');
  });
}
