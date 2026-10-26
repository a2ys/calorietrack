enum MealType {
  breakfast('Breakfast', '🍳'),
  lunch('Lunch', '🥗'),
  dinner('Dinner', '🍝'),
  snack('Snack', '🍎');

  const MealType(this.label, this.emoji);
  final String label;
  final String emoji;

  /// Sensible default for logging "right now".
  static MealType forTime(DateTime t) {
    final h = t.hour;
    if (h < 11) return MealType.breakfast;
    if (h < 15) return MealType.lunch;
    if (h < 18) return MealType.snack;
    return MealType.dinner;
  }
}

/// One ingredient inside a saved meal. Nutrition is per single serving;
/// [qty] is how many servings the meal contains.
class MealItem {
  const MealItem({
    required this.name,
    required this.emoji,
    required this.serving,
    required this.qty,
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final String name;
  final String emoji;
  final String serving;
  final double qty;
  final int kcal;
  final double protein;
  final double carbs;
  final double fat;

  Totals get total => Totals(
        kcal: (kcal * qty).round(),
        protein: protein * qty,
        carbs: carbs * qty,
        fat: fat * qty,
      );

  MealItem withQty(double q) => MealItem(
        name: name,
        emoji: emoji,
        serving: serving,
        qty: q,
        kcal: kcal,
        protein: protein,
        carbs: carbs,
        fat: fat,
      );

  Map<String, Object> toJson() => {
        'n': name,
        'e': emoji,
        's': serving,
        'q': qty,
        'k': kcal,
        'p': protein,
        'c': carbs,
        'f': fat,
      };

  factory MealItem.fromJson(Map<String, dynamic> j) => MealItem(
        name: j['n'] as String,
        emoji: j['e'] as String,
        serving: j['s'] as String,
        qty: (j['q'] as num).toDouble(),
        kcal: (j['k'] as num).round(),
        protein: (j['p'] as num).toDouble(),
        carbs: (j['c'] as num).toDouble(),
        fat: (j['f'] as num).toDouble(),
      );
}

/// Sum of the items in a meal.
Totals sumMealItems(Iterable<MealItem> items) =>
    items.fold(Totals.zero, (t, i) => t + i.total);

/// Sum of calories and macros, e.g. for a day.
class Totals {
  const Totals({
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  final int kcal;
  final double protein;
  final double carbs;
  final double fat;

  static const zero = Totals();

  Totals operator +(Totals o) => Totals(
        kcal: kcal + o.kcal,
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        fat: fat + o.fat,
      );
}
