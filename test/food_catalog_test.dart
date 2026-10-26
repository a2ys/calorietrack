import 'dart:io';

import 'package:calorie_app/core/data/common_foods.dart';
import 'package:calorie_app/core/data/food.dart';
import 'package:calorie_app/core/data/food_catalog.dart';
import 'package:calorie_app/core/data/preset_meals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FoodCatalog full;

  setUpAll(() {
    final usda = FoodCatalog.parseUsda(
      File('assets/data/usda_foods.json').readAsStringSync(),
    );
    full = FoodCatalog([...kCommonFoods, ...usda]);
  });

  test('curated list is large and sane', () {
    expect(kCommonFoods.length, greaterThan(250));
    // Calories should roughly match the macros (4/4/9). Alcohol is the one
    // legitimate exception (7 kcal/g that no macro accounts for).
    const alcohol = {'Beer', 'Wine', 'Whisky / vodka / rum'};
    final off = <String>[];
    for (final f in kCommonFoods) {
      expect(f.kcal, greaterThanOrEqualTo(0), reason: f.name);
      if (f.kcal > 60 && !alcohol.contains(f.name)) {
        final fromMacros = f.protein * 4 + f.carbs * 4 + f.fat * 9;
        if ((fromMacros - f.kcal).abs() / f.kcal > 0.3) {
          off.add('${f.name}: ${f.kcal} kcal vs macros ${fromMacros.round()}');
        }
      }
    }
    expect(off, isEmpty);
  });

  test('every curated group is browsable', () {
    for (final g in FoodGroup.values) {
      expect(full.inGroup(g), isNotEmpty, reason: g.label);
    }
  });

  test('USDA asset parses and is big', () {
    expect(full.all.length, greaterThan(6000));
    final egg = full.all.firstWhere((f) => f.name == 'Egg, whole, cooked, hard-boiled');
    // 1 large egg = 50 g at 155 kcal / 100 g.
    expect(egg.kcal, 78);
    expect(egg.serving, '1 large');
  });

  group('search', () {
    test('curated foods win', () {
      expect(full.search('roti').first.name, 'Roti');
      expect(full.search('egg').first.curated, isTrue);
    });

    test('aliases work', () {
      expect(full.search('chawal').first.name, 'Steamed rice');
      expect(full.search('anda').first.name.toLowerCase(), contains('egg'));
      expect(full.search('dahi').map((f) => f.name), contains('Curd (dahi)'));
      expect(full.search('chapati').first.name, 'Roti');
    });

    test('multi-word and punctuation', () {
      final r = full.search('dal tadka');
      expect(r.first.name, 'Dal tadka');
      expect(full.search('toor').first.name, 'Dal (toor / arhar)');
    });

    test('finds long-tail USDA foods', () {
      expect(full.search('pumpkin seeds'), isNotEmpty);
      expect(full.search('lentils cooked').first.name.toLowerCase(), contains('lentil'));
    });

    test('empty and no-match', () {
      expect(full.search('  '), isEmpty);
      expect(full.search('zzzzqq'), isEmpty);
    });

    test('respects the limit', () {
      expect(full.search('a', limit: 10).length, lessThanOrEqualTo(10));
    });
  });

  test('every preset meal resolves fully', () {
    for (final m in kPresetMeals) {
      final items = m.items(full);
      expect(items.length, m.parts.length, reason: '${m.name} has unresolved foods');
      expect(m.totals(full).kcal, greaterThan(100), reason: m.name);
    }
  });

  test('every popular food exists', () {
    for (final name in kPopularFoodNames) {
      expect(full.byName(name), isNotNull, reason: name);
    }
  });

  test('qty formatting', () {
    expect(formatQty(1), '1');
    expect(formatQty(1.5), '1½');
    expect(formatQty(0.5), '½');
    expect(formatQty(0.25), '¼');
    expect(formatQty(2.75), '2¾');
  });

  test('scaling', () {
    final roti = full.byName('Roti')!;
    final t = roti.scaled(2.5);
    expect(t.kcal, 250);
    expect(t.protein, closeTo(7.5, 0.01));
  });
}
