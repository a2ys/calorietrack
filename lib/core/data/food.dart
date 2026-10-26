import '../db/models.dart';

/// Browse groups shown as chips in Add food.
enum FoodGroup {
  indian('Indian', '🍛'),
  grains('Grains & bread', '🍞'),
  meat('Meat & fish', '🍗'),
  dairy('Eggs & dairy', '🥚'),
  veg('Vegetables', '🥦'),
  fruit('Fruits', '🍎'),
  legumes('Dal & beans', '🫘'),
  nuts('Nuts & seeds', '🥜'),
  snacks('Snacks & sweets', '🍪'),
  drinks('Drinks', '🥤'),
  meals('Meals & fast food', '🍔'),
  other('Oils & sauces', '🫒');

  const FoodGroup(this.label, this.emoji);
  final String label;
  final String emoji;

  static FoodGroup parse(String name) => FoodGroup.values.firstWhere(
        (g) => g.name == name,
        orElse: () => FoodGroup.other,
      );
}

/// A food in the catalog. Nutrition is for ONE serving ([serving] says how big
/// that is, e.g. "1 medium (40 g)"); [grams] is the serving weight when known.
class Food {
  Food({
    required this.name,
    required this.emoji,
    required this.group,
    required this.serving,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.grams,
    String aliases = '',
    this.curated = false,
  })  : aliasText = normalizeSearch(aliases),
        key = ' ${normalizeSearch(name)} ${normalizeSearch(aliases)} ';

  final String name;
  final String emoji;
  final FoodGroup group;
  final String serving;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;
  final int? grams;
  final bool curated;

  /// Lower-cased name + aliases, each word preceded by a space, for search.
  final String key;

  /// Normalized aliases only; the first one is the most common alternative name.
  final String aliasText;

  /// Nutrition for [qty] servings.
  Totals scaled(double qty) => Totals(
        kcal: (kcal * qty).round(),
        protein: protein * qty,
        carbs: carbs * qty,
        fat: fat * qty,
      );

  /// Builds a food from per-100 g values and a serving weight.
  factory Food.per100g({
    required String name,
    required String emoji,
    required FoodGroup group,
    required String serving,
    required int grams,
    required num kcal,
    required num protein,
    required num carbs,
    required num fat,
  }) {
    final k = grams / 100;
    return Food(
      name: name,
      emoji: emoji,
      group: group,
      serving: serving,
      grams: grams,
      kcal: (kcal * k).round(),
      protein: _round1(protein * k),
      carbs: _round1(carbs * k),
      fat: _round1(fat * k),
    );
  }

  /// The same food as one [g]-gram serving ("50 g"), for when you know the
  /// weight you ate. Needs [grams].
  Food withGrams(int g) {
    final k = g / grams!;
    return Food(
      name: name,
      emoji: emoji,
      group: group,
      serving: '$g g',
      grams: g,
      kcal: (kcal * k).round(),
      protein: _round1(protein * k),
      carbs: _round1(carbs * k),
      fat: _round1(fat * k),
      curated: curated,
    );
  }

  MealItem toMealItem(double qty) => MealItem(
        name: name,
        emoji: emoji,
        serving: serving,
        qty: qty,
        kcal: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );

  static double _round1(double v) => (v * 10).round() / 10;
}

/// Lower-case letters and digits separated by single spaces:
/// "Dal (toor / arhar)" -> "dal toor arhar".
String normalizeSearch(String s) =>
    s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();

/// 1.5 -> "1½", 2 -> "2", 0.25 -> "¼", 2.3 -> "2.3".
String formatQty(double q) {
  final whole = q.floor();
  final frac = q - whole;
  final glyph = switch ((frac * 4).round()) {
    1 => '¼',
    2 => '½',
    3 => '¾',
    _ => '',
  };
  if (glyph.isNotEmpty && (frac * 4 - (frac * 4).round()).abs() < 0.01) {
    return whole == 0 ? glyph : '$whole$glyph';
  }
  if (frac < 0.01) return '$whole';
  return q.toStringAsFixed(1);
}
