import '../db/models.dart';
import 'food_catalog.dart';

/// A ready-made meal built from catalog foods, so Meals is useful on day one.
class PresetMeal {
  const PresetMeal(this.name, this.emoji, this.parts);

  final String name;
  final String emoji;

  /// (catalog food name, servings)
  final List<(String, double)> parts;

  /// Resolves each part against [catalog]; parts it can't find are skipped.
  List<MealItem> items(FoodCatalog catalog) => [
        for (final (food, qty) in parts)
          if (catalog.byName(food) case final f?) f.toMealItem(qty),
      ];

  Totals totals(FoodCatalog catalog) => sumMealItems(items(catalog));
}

const List<PresetMeal> kPresetMeals = [
  PresetMeal('Dal Chawal', '🍛', [
    ('Steamed rice', 1),
    ('Dal tadka', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Roti Sabzi', '🫓', [
    ('Roti', 2),
    ('Mixed veg curry', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Paneer & Roti', '🧀', [
    ('Roti', 2),
    ('Palak paneer', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Idli Sambar', '🍙', [
    ('Idli', 3),
    ('Sambar', 1),
    ('Coconut chutney', 1),
  ]),
  PresetMeal('Dosa & Sambar', '🥞', [
    ('Plain dosa', 2),
    ('Sambar', 1),
    ('Coconut chutney', 1),
  ]),
  PresetMeal('Poha & Chai', '🥣', [
    ('Poha', 1),
    ('Chai (with milk & sugar)', 1),
  ]),
  PresetMeal('Oats & Milk Bowl', '🥣', [
    ('Oats (dry)', 1),
    ('Milk (whole)', 1),
    ('Banana', 1),
    ('Almonds', 1),
  ]),
  PresetMeal('Egg Toast Breakfast', '🍳', [
    ('Scrambled eggs', 1),
    ('Whole wheat bread', 2),
    ('Banana', 1),
  ]),
  PresetMeal('Peanut Butter Toast', '🥜', [
    ('Whole wheat bread', 2),
    ('Peanut butter', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Chicken & Rice', '🍗', [
    ('Chicken breast (grilled)', 1.5),
    ('Steamed rice', 1),
    ('Broccoli (cooked)', 1),
  ]),
  PresetMeal('Rice & Fish Curry', '🐟', [
    ('Steamed rice', 1),
    ('Fish curry', 1),
    ('Green salad', 1),
  ]),
  PresetMeal('Biryani & Raita', '🍛', [
    ('Chicken biryani', 1),
    ('Raita', 1),
  ]),
  PresetMeal('Khichdi & Curd', '🍲', [
    ('Khichdi', 1),
    ('Curd (dahi)', 1),
    ('Papad (roasted)', 1),
  ]),
  PresetMeal('Moong Chilla Plate', '🥞', [
    ('Moong dal chilla', 2),
    ('Green chutney', 1),
    ('Curd (dahi)', 1),
  ]),
  PresetMeal('Greek Yogurt Bowl', '🫐', [
    ('Greek yogurt', 1),
    ('Blueberries', 0.5),
    ('Almonds', 1),
    ('Honey', 1),
  ]),
  PresetMeal('Protein Shake', '🥤', [
    ('Whey protein', 1),
    ('Milk (toned)', 1),
    ('Banana', 1),
  ]),
  PresetMeal('Tea Time', '🍵', [
    ('Chai (with milk & sugar)', 1),
    ('Marie biscuit', 4),
  ]),
  PresetMeal('Fruit Bowl', '🍎', [
    ('Apple', 1),
    ('Banana', 1),
    ('Papaya', 1),
  ]),
];
