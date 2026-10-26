import 'package:drift/drift.dart';

import '../utils/calorie_calculator.dart';
import '../utils/date_utils.dart';
import 'database.dart';
import 'models.dart';

/// Development-only sample data, enabled with `--dart-define=SEED=true`.
/// Never runs when a profile already exists.
Future<void> seedSampleData(AppDatabase db) async {
  if (await db.getProfile() != null) return;

  const weightKg = 72.0;
  final t = CalorieCalculator.targets(
    goal: Goal.lose,
    sex: Sex.male,
    age: 27,
    heightCm: 178,
    weightKg: weightKg,
    activity: ActivityLevel.moderate,
  );

  await db.saveProfile(UserProfilesCompanion.insert(
    id: const Value(AppDatabase.profileId),
    goal: Goal.lose,
    sex: Sex.male,
    age: 27,
    heightCm: 178,
    weightKg: weightKg,
    activity: ActivityLevel.moderate,
    calorieTarget: t.calories,
    proteinTarget: t.proteinG,
    carbsTarget: t.carbsG,
    fatTarget: t.fatG,
  ));

  final today = dateOnly(DateTime.now());

  Future<void> add(int daysAgo, int hour, int minute, String name, int kcal,
      double p, double c, double f, MealType meal, String emoji) {
    final day = addDays(today, -daysAgo);
    return db.addEntry(FoodEntriesCompanion.insert(
      name: name,
      kcal: kcal,
      protein: Value(p),
      carbs: Value(c),
      fat: Value(f),
      mealType: meal,
      loggedAt: DateTime(day.year, day.month, day.day, hour, minute),
      emoji: Value(emoji),
    ));
  }

  const b = MealType.breakfast;
  const l = MealType.lunch;
  const d = MealType.dinner;
  const s = MealType.snack;

  await add(0, 8, 5, 'Greek yogurt & berries', 240, 20, 28, 5, b, '🫐');
  await add(0, 10, 40, 'Flat white', 120, 6, 10, 6, s, '☕');
  await add(0, 13, 10, 'Chicken burrito bowl', 640, 46, 62, 22, l, '🌯');

  for (var i = 1; i <= 6; i++) {
    final scale = [1.0, 0.85, 1.1, 0.95, 1.2, 0.7][i - 1];
    await add(i, 8, 30, 'Oats & banana', (380 * scale).round(), 14, 66, 8, b, '🥣');
    await add(i, 13, 0, 'Salmon salad', (620 * scale).round(), 38, 30, 34, l, '🥗');
    await add(i, 19, 30, 'Pasta pomodoro', (780 * scale).round(), 24, 110, 22, d, '🍝');
  }

  await db.addCustomFood(CustomFoodsCompanion.insert(
    name: 'Protein shake',
    kcal: 180,
    protein: const Value(30),
    carbs: const Value(6),
    fat: const Value(3),
    emoji: const Value('🥤'),
    createdAt: DateTime.now(),
  ));
}
