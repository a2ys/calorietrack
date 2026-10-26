import 'dart:math' as math;

import 'package:calorie_app/core/data/common_foods.dart';
import 'package:calorie_app/core/data/food.dart';
import 'package:calorie_app/core/data/food_catalog.dart';
import 'package:calorie_app/core/data/preset_meals.dart';
import 'package:calorie_app/core/widgets/emoji_assets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Accuracy guards for the hand-curated food library and preset meals.
void main() {
  // Alcohol is the one legitimate gap between kcal and the 4/4/9 macro sum:
  // ethanol is 7 kcal/g and is not one of the tracked macros.
  const alcohol = {'Beer', 'Wine', 'Whisky / vodka / rum'};

  String emojiKey(String emoji) => [
        for (final r in emoji.runes)
          if (r != 0xFE0F) r.toRadixString(16),
      ].join('-');

  test('library is large', () {
    expect(kCommonFoods.length, greaterThan(600));
    expect(kPresetMeals.length, greaterThan(55));
  });

  test('food names are unique (case-insensitive)', () {
    final seen = <String, String>{};
    final dupes = <String>[];
    for (final f in kCommonFoods) {
      final key = f.name.toLowerCase().trim();
      final prev = seen[key];
      if (prev != null) dupes.add('${f.name} (also $prev)');
      seen[key] = f.name;
    }
    expect(dupes, isEmpty);
  });

  test('calories roughly match macros (4/4/9)', () {
    final off = <String>[];
    for (final f in kCommonFoods) {
      expect(f.kcal, greaterThanOrEqualTo(0), reason: f.name);
      expect(f.protein, greaterThanOrEqualTo(0), reason: f.name);
      expect(f.carbs, greaterThanOrEqualTo(0), reason: f.name);
      expect(f.fat, greaterThanOrEqualTo(0), reason: f.name);
      if (f.kcal < 20 || alcohol.contains(f.name)) continue;
      final fromMacros = f.protein * 4 + f.carbs * 4 + f.fat * 9;
      final tolerance = math.max(25, 0.2 * f.kcal);
      if ((fromMacros - f.kcal).abs() > tolerance) {
        off.add('${f.name}: ${f.kcal} kcal vs macros ${fromMacros.round()}');
      }
    }
    expect(off, isEmpty);
  });

  test('every solid-food serving states its weight in grams', () {
    // Drinks are served by volume (ml), so they are exempt.
    final missing = [
      for (final f in kCommonFoods)
        if (f.group != FoodGroup.drinks && f.grams == null) '${f.name}: "${f.serving}"',
    ];
    expect(missing, isEmpty);
  });

  test('stated weights are plausible', () {
    for (final f in kCommonFoods) {
      final g = f.grams;
      if (g == null) continue;
      expect(g, inInclusiveRange(3, 1000), reason: f.name);
      // Nothing is denser than oil (9 kcal/g).
      expect(f.kcal / g, lessThan(9.5), reason: '${f.name}: ${f.kcal} kcal in $g g');
    }
  });

  test('every food has a serving, a group and emoji that has art', () {
    final bad = <String>[];
    for (final f in kCommonFoods) {
      expect(f.serving.trim(), isNotEmpty, reason: f.name);
      if (!kEmojiAssetKeys.contains(emojiKey(f.emoji))) {
        bad.add('${f.name}: ${f.emoji}');
      }
    }
    for (final m in kPresetMeals) {
      if (!kEmojiAssetKeys.contains(emojiKey(m.emoji))) bad.add('${m.name}: ${m.emoji}');
    }
    expect(bad, isEmpty);
  });

  test('every browse group has plenty of foods', () {
    for (final g in FoodGroup.values) {
      final n = kCommonFoods.where((f) => f.group == g).length;
      expect(n, greaterThan(8), reason: g.label);
    }
  });

  group('preset meals', () {
    final catalog = FoodCatalog.curated;

    test('names are unique', () {
      final names = kPresetMeals.map((m) => m.name.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
    });

    test('every part resolves to a catalog food', () {
      final unresolved = <String>[];
      for (final m in kPresetMeals) {
        for (final (food, qty) in m.parts) {
          if (catalog.byName(food) == null) unresolved.add('${m.name}: $food');
          expect(qty, greaterThan(0), reason: '${m.name}: $food');
        }
      }
      expect(unresolved, isEmpty);
    });

    test('each preset has at least two items and sane totals', () {
      for (final m in kPresetMeals) {
        expect(m.items(catalog).length, greaterThanOrEqualTo(2), reason: m.name);
        final kcal = m.totals(catalog).kcal;
        expect(kcal, inInclusiveRange(100, 1800), reason: '${m.name}: $kcal kcal');
      }
    });
  });

  test('popular foods exist', () {
    for (final name in kPopularFoodNames) {
      expect(FoodCatalog.curated.byName(name), isNotNull, reason: name);
    }
  });
}
