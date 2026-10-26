import 'package:calorie_app/core/data/food.dart';
import 'package:calorie_app/core/data/food_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final chicken = Food(
    name: 'Chicken breast, boiled',
    emoji: '🍗',
    group: FoodGroup.meat,
    serving: '100 g',
    grams: 100,
    kcal: 165,
    protein: 31,
    carbs: 0,
    fat: 3.6,
  );

  test('withGrams re-portions nutrition to the weight eaten', () {
    final half = chicken.withGrams(50);
    expect(half.serving, '50 g');
    expect(half.grams, 50);
    expect(half.kcal, 83); // 82.5 rounds up
    expect(half.protein, 15.5);
    expect(half.fat, 1.8);
    expect(half.name, chicken.name);
  });

  test('curated foods read their weight from the serving label', () {
    final roti = FoodCatalog.curated.byName('Roti')!;
    expect(roti.grams, 40);
    expect(roti.withGrams(20).kcal, 50);
  });
}
