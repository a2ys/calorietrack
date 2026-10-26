enum Goal {
  lose('Lose weight', 'Eat a little less than you burn'),
  maintain('Maintain', 'Stay right where you are'),
  gain('Gain weight', 'Eat a little more than you burn');

  const Goal(this.label, this.hint);
  final String label;
  final String hint;
}

enum Sex {
  male('Male'),
  female('Female');

  const Sex(this.label);
  final String label;
}

enum ActivityLevel {
  sedentary('Sedentary', 'Desk job, little exercise', 1.2),
  light('Lightly active', 'Exercise 1–3 days a week', 1.375),
  moderate('Moderately active', 'Exercise 3–5 days a week', 1.55),
  very('Very active', 'Hard exercise 6–7 days a week', 1.725),
  extra('Extremely active', 'Physical job or twice-a-day training', 1.9);

  const ActivityLevel(this.label, this.hint, this.factor);
  final String label;
  final String hint;
  final double factor;
}

class MacroTargets {
  const MacroTargets({
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
  });

  final int calories;
  final int proteinG;
  final int carbsG;
  final int fatG;
}

abstract final class CalorieCalculator {
  /// Calories per gram.
  static const int kcalPerGramProtein = 4;
  static const int kcalPerGramCarbs = 4;
  static const int kcalPerGramFat = 9;

  /// Daily adjustment applied to maintenance calories.
  static const int loseDeficit = 500;
  static const int gainSurplus = 300;

  /// Safety floors so a target is never dangerously low.
  static const int minCaloriesFemale = 1200;
  static const int minCaloriesMale = 1500;

  /// Share of calories coming from fat.
  static const double fatShare = 0.27;

  /// Protein in grams per kg of body weight.
  static double proteinPerKg(Goal goal) => switch (goal) {
        Goal.lose => 2.0,
        Goal.maintain => 1.6,
        Goal.gain => 1.8,
      };

  /// Mifflin-St Jeor basal metabolic rate (kcal/day).
  static double bmr({
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
  }) {
    final base = 10 * weightKg + 6.25 * heightCm - 5 * age;
    return sex == Sex.male ? base + 5 : base - 161;
  }

  /// Total daily energy expenditure.
  static double tdee({
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
  }) =>
      bmr(sex: sex, age: age, heightCm: heightCm, weightKg: weightKg) *
      activity.factor;

  static MacroTargets targets({
    required Goal goal,
    required Sex sex,
    required int age,
    required double heightCm,
    required double weightKg,
    required ActivityLevel activity,
  }) {
    final maintenance = tdee(
      sex: sex,
      age: age,
      heightCm: heightCm,
      weightKg: weightKg,
      activity: activity,
    );

    final adjusted = switch (goal) {
      Goal.lose => maintenance - loseDeficit,
      Goal.maintain => maintenance,
      Goal.gain => maintenance + gainSurplus,
    };

    final floor = sex == Sex.male ? minCaloriesMale : minCaloriesFemale;
    final calories = adjusted.round().clamp(floor, 10000);

    return macrosFor(calories: calories, goal: goal, weightKg: weightKg);
  }

  /// Splits [calories] into macros: protein by body weight, fat by share of
  /// calories, carbs take whatever is left.
  static MacroTargets macrosFor({
    required int calories,
    required Goal goal,
    required double weightKg,
  }) {
    var protein = (weightKg * proteinPerKg(goal)).round();
    var fat = (calories * fatShare / kcalPerGramFat).round();

    // Protein can never claim more than 40% of a small budget.
    final proteinCap = (calories * 0.4 / kcalPerGramProtein).floor();
    if (protein > proteinCap) protein = proteinCap;

    final remaining =
        calories - protein * kcalPerGramProtein - fat * kcalPerGramFat;
    final carbs = (remaining / kcalPerGramCarbs).round().clamp(0, 10000);

    return MacroTargets(
      calories: calories,
      proteinG: protein,
      carbsG: carbs,
      fatG: fat,
    );
  }

  /// Calories implied by a set of macro grams.
  static int caloriesFromMacros({
    required num proteinG,
    required num carbsG,
    required num fatG,
  }) =>
      (proteinG * kcalPerGramProtein +
              carbsG * kcalPerGramCarbs +
              fatG * kcalPerGramFat)
          .round();

  /// Slack for label rounding when checking calories against macros.
  static int macroTolerance(int kcal) => kcal * 0.1 > 15 ? (kcal * 0.1).round() : 15;

  /// Checks typed calories against typed macros (null = not entered).
  /// Returns null when consistent, otherwise the calories the macros imply.
  ///
  /// With all three macros the totals must agree. With only some, calories
  /// just can't be lower than what those macros alone supply. With none
  /// there is nothing to check.
  static int? macroMismatch({
    required int kcal,
    num? proteinG,
    num? carbsG,
    num? fatG,
  }) {
    final given = [proteinG, carbsG, fatG].whereType<num>();
    if (given.isEmpty) return null;
    final implied = caloriesFromMacros(
      proteinG: proteinG ?? 0,
      carbsG: carbsG ?? 0,
      fatG: fatG ?? 0,
    );
    final slack = macroTolerance(implied);
    final complete = given.length == 3;
    if (kcal < implied - slack) return implied;
    if (complete && kcal > implied + slack) return implied;
    return null;
  }
}
