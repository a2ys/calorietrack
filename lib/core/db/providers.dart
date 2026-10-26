import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/food_catalog.dart';
import '../utils/date_utils.dart';
import 'database.dart';
import 'models.dart';

/// Overridden in `main()` with the opened database.
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final profileProvider = StreamProvider<UserProfile?>(
  (ref) => ref.watch(databaseProvider).watchProfile(),
);

final prefsProvider = StreamProvider<AppPrefs>(
  (ref) => ref.watch(databaseProvider).watchPrefs().map(AppPrefs.fromMap),
);

/// Convenience: prefs with defaults while loading.
AppPrefs readPrefs(WidgetRef ref) =>
    ref.watch(prefsProvider).value ?? const AppPrefs();

final entriesForDayProvider =
    StreamProvider.family<List<FoodEntry>, DateTime>(
  (ref, day) => ref.watch(databaseProvider).watchEntriesForDay(day),
);

final dailyTotalsProvider =
    StreamProvider.family<Map<DateTime, Totals>, DateTime>((ref, weekStart) {
  return ref
      .watch(databaseProvider)
      .watchDailyTotals(weekStart, addDays(weekStart, 7));
});

final recentFoodsProvider = StreamProvider<List<FoodEntry>>(
  (ref) => ref.watch(databaseProvider).watchRecentFoods(),
);

final customFoodsProvider = StreamProvider<List<CustomFood>>(
  (ref) => ref.watch(databaseProvider).watchCustomFoods(),
);

final waterForDayProvider = StreamProvider.family<List<WaterLog>, DateTime>(
  (ref, day) => ref.watch(databaseProvider).watchWaterForDay(day),
);

final dailyWaterProvider =
    StreamProvider.family<Map<DateTime, int>, DateTime>((ref, weekStart) {
  return ref
      .watch(databaseProvider)
      .watchDailyWater(weekStart, addDays(weekStart, 7));
});

final savedMealsProvider = StreamProvider<List<SavedMeal>>(
  (ref) => ref.watch(databaseProvider).watchSavedMeals(),
);

/// The curated list is available immediately; the USDA foods join it once the
/// asset has loaded, so search never waits.
final foodCatalogProvider = FutureProvider<FoodCatalog>(
  (ref) => FoodCatalog.load(),
);

FoodCatalog catalogOf(WidgetRef ref) =>
    ref.watch(foodCatalogProvider).value ?? FoodCatalog.curated;

/// The day currently shown on Home and History.
class SelectedDay extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  void select(DateTime day) => state = dateOnly(day);
}

final selectedDayProvider =
    NotifierProvider<SelectedDay, DateTime>(SelectedDay.new);
