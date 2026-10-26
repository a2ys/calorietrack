import 'package:calorie_app/core/utils/water.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatWater switches to litres at 1000 ml', () {
    expect(formatWater(150), '150 ml');
    expect(formatWater(250), '250 ml');
    expect(formatWater(999), '999 ml');
    expect(formatWater(1000), '1 L');
    expect(formatWater(1250), '1.25 L');
    expect(formatWater(1500), '1.5 L');
    expect(formatWater(3000), '3 L');
    expect(formatWater(3750), '3.75 L');
  });

  test('formatLiters trims trailing zeros', () {
    expect(formatLiters(0), '0');
    expect(formatLiters(500), '0.5');
    expect(formatLiters(2000), '2');
    expect(formatLiters(2100), '2.1');
  });

  test('goal limits and presets are consistent', () {
    expect(WaterLimits.minGoal % WaterLimits.goalStep, 0);
    expect(WaterLimits.maxGoal % WaterLimits.goalStep, 0);
    expect(WaterLimits.presets, isNotEmpty);
    expect(WaterLimits.presets.every((p) => p > 0 && p <= 1000), isTrue);
    expect(WaterLimits.glassSizes, contains(250));
  });
}
