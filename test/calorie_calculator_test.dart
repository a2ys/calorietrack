import 'package:calorie_app/core/utils/calorie_calculator.dart';
import 'package:calorie_app/core/utils/units.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mifflin-St Jeor BMR', () {
    test('male 30y 180cm 80kg', () {
      // 10*80 + 6.25*180 - 5*30 + 5 = 1780
      expect(
        CalorieCalculator.bmr(sex: Sex.male, age: 30, heightCm: 180, weightKg: 80),
        closeTo(1780, 0.001),
      );
    });

    test('female 25y 165cm 60kg', () {
      // 10*60 + 6.25*165 - 5*25 - 161 = 1345.25
      expect(
        CalorieCalculator.bmr(sex: Sex.female, age: 25, heightCm: 165, weightKg: 60),
        closeTo(1345.25, 0.001),
      );
    });
  });

  group('targets', () {
    MacroTargets run(Goal goal, {Sex sex = Sex.male}) => CalorieCalculator.targets(
          goal: goal,
          sex: sex,
          age: 30,
          heightCm: 180,
          weightKg: 80,
          activity: ActivityLevel.moderate,
        );

    test('maintenance equals TDEE', () {
      // 1780 * 1.55 = 2759
      expect(run(Goal.maintain).calories, 2759);
    });

    test('lose subtracts 500, gain adds 300', () {
      expect(run(Goal.lose).calories, 2259);
      expect(run(Goal.gain).calories, 3059);
    });

    test('protein follows body weight per goal', () {
      expect(run(Goal.lose).proteinG, 160); // 2.0 g/kg
      expect(run(Goal.maintain).proteinG, 128); // 1.6 g/kg
      expect(run(Goal.gain).proteinG, 144); // 1.8 g/kg
    });

    test('macros add back up to the calorie target (within rounding)', () {
      for (final goal in Goal.values) {
        final t = run(goal);
        final back = CalorieCalculator.caloriesFromMacros(
          proteinG: t.proteinG,
          carbsG: t.carbsG,
          fatG: t.fatG,
        );
        expect((back - t.calories).abs(), lessThanOrEqualTo(12), reason: '$goal');
      }
    });

    test('never goes below the safety floor', () {
      final t = CalorieCalculator.targets(
        goal: Goal.lose,
        sex: Sex.female,
        age: 60,
        heightCm: 150,
        weightKg: 45,
        activity: ActivityLevel.sedentary,
      );
      expect(t.calories, CalorieCalculator.minCaloriesFemale);
      expect(t.carbsG, greaterThanOrEqualTo(0));
    });

    test('protein is capped on small budgets', () {
      final t = CalorieCalculator.macrosFor(
        calories: 1200,
        goal: Goal.lose,
        weightKg: 150,
      );
      expect(t.proteinG * 4, lessThanOrEqualTo(1200 * 0.4));
    });
  });

  group('units', () {
    test('kg <-> lb round trip', () {
      expect(Units.lbToKg(Units.kgToLb(80)), closeTo(80, 1e-9));
      expect(Units.kgToLb(100), closeTo(220.462, 0.001));
    });

    test('cm to feet and inches', () {
      expect(Units.cmToFeetInches(175.3), (5, 9));
      expect(Units.cmToFeetInches(182.9), (6, 0));
    });

    test('formatting', () {
      expect(Units.formatWeight(80, WeightUnit.kg), '80 kg');
      expect(Units.formatWeight(80.5, WeightUnit.kg), '80.5 kg');
      expect(Units.formatWeight(80, WeightUnit.lb), '176.4 lb');
      expect(Units.formatHeight(175, HeightUnit.cm), '175 cm');
      expect(Units.formatHeight(175, HeightUnit.ft), '5′ 9″');
    });
  });

  group('macroMismatch', () {
    int? check(int kcal, {num? p, num? c, num? f}) =>
        CalorieCalculator.macroMismatch(kcal: kcal, proteinG: p, carbsG: c, fatG: f);

    test('no macros: nothing to check', () {
      expect(check(500), isNull);
    });

    test('all three macros must add up, within rounding', () {
      // 20*4 + 30*4 + 10*9 = 290
      expect(check(290, p: 20, c: 30, f: 10), isNull);
      expect(check(300, p: 20, c: 30, f: 10), isNull); // within 10% / 15 kcal
      expect(check(500, p: 20, c: 30, f: 10), 290);
      expect(check(150, p: 20, c: 30, f: 10), 290);
    });

    test('some macros: calories only need to cover them', () {
      // 30 g protein = 120 kcal minimum
      expect(check(400, p: 30), isNull);
      expect(check(60, p: 30), 120);
    });
  });
}
