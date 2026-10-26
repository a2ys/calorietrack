import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../utils/calorie_calculator.dart';
import '../utils/date_utils.dart';
import '../utils/haptics.dart';
import '../utils/units.dart';
import 'models.dart';

part 'database.g.dart';

/// One logged food.
class FoodEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get kcal => integer()();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
  TextColumn get mealType => textEnum<MealType>()();
  DateTimeColumn get loggedAt => dateTime()();
  TextColumn get emoji => text().nullable()();

  /// Reserved for photo logging (stage 2).
  TextColumn get imagePath => text().nullable()();
}

/// Foods the user saved to re-use.
class CustomFoods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  IntColumn get kcal => integer()();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
  TextColumn get emoji => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

/// A meal the user built: a named list of foods with quantities. The items
/// are stored as JSON so a meal stays intact even if the catalog changes.
class SavedMeals extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get emoji => text()();
  TextColumn get itemsJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// One drink of water. Totals per day are summed from these.
class WaterLogs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amountMl => integer()();
  DateTimeColumn get loggedAt => dateTime()();
}

/// Foods found by barcode, from Open Food Facts or typed in by the user for a
/// code it didn't know, so scanning the same product again is instant and
/// works offline. Nutrition is for one [serving]; [grams] is its weight when
/// known (then any weight can be logged).
class ScannedFoods extends Table {
  TextColumn get barcode => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get serving => text()();
  IntColumn get grams => integer().nullable()();
  IntColumn get kcal => integer()();
  RealColumn get protein => real().withDefault(const Constant(0))();
  RealColumn get carbs => real().withDefault(const Constant(0))();
  RealColumn get fat => real().withDefault(const Constant(0))();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {barcode};
}

/// A single row (id = 1) holding the onboarding answers and daily targets.
class UserProfiles extends Table {
  IntColumn get id => integer()();
  TextColumn get goal => textEnum<Goal>()();
  TextColumn get sex => textEnum<Sex>()();
  IntColumn get age => integer()();
  RealColumn get heightCm => real()();
  RealColumn get weightKg => real()();
  TextColumn get activity => textEnum<ActivityLevel>()();
  IntColumn get calorieTarget => integer()();
  IntColumn get proteinTarget => integer()();
  IntColumn get carbsTarget => integer()();
  IntColumn get fatTarget => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key/value app preferences (theme, units).
class Prefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [FoodEntries, CustomFoods, SavedMeals, WaterLogs, ScannedFoods, UserProfiles, Prefs])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// Production database (SQLite on device, WASM in the browser).
  factory AppDatabase.open() => AppDatabase(
        driftDatabase(
          name: 'calorie_app',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) await m.createTable(savedMeals);
          if (from < 3) await m.createTable(waterLogs);
          if (from < 4) await m.createTable(scannedFoods);
        },
      );

  static const profileId = 1;

  // ------------------------------------------------------------ entries

  static DateTime _dayEnd(DateTime day) => addDays(dateOnly(day), 1);

  /// Entries logged on [day], oldest first.
  Stream<List<FoodEntry>> watchEntriesForDay(DateTime day) {
    final start = dateOnly(day);
    final q = select(foodEntries)
      ..where((e) => e.loggedAt.isBiggerOrEqualValue(start))
      ..where((e) => e.loggedAt.isSmallerThanValue(_dayEnd(day)))
      ..orderBy([(e) => OrderingTerm.asc(e.loggedAt)]);
    return q.watch();
  }

  Future<List<FoodEntry>> entriesBetween(DateTime from, DateTime toExclusive) {
    final q = select(foodEntries)
      ..where((e) => e.loggedAt.isBiggerOrEqualValue(from))
      ..where((e) => e.loggedAt.isSmallerThanValue(toExclusive))
      ..orderBy([(e) => OrderingTerm.asc(e.loggedAt)]);
    return q.get();
  }

  /// Totals for each calendar day in [from, toExclusive), keyed by date.
  /// Days without entries are absent from the map.
  Stream<Map<DateTime, Totals>> watchDailyTotals(
    DateTime from,
    DateTime toExclusive,
  ) {
    final q = select(foodEntries)
      ..where((e) => e.loggedAt.isBiggerOrEqualValue(from))
      ..where((e) => e.loggedAt.isSmallerThanValue(toExclusive));
    return q.watch().map(groupTotalsByDay);
  }

  Future<int> addEntry(FoodEntriesCompanion entry) =>
      into(foodEntries).insert(entry);

  Future<bool> updateEntry(FoodEntry entry) => update(foodEntries).replace(entry);

  Future<int> deleteEntry(int id) =>
      (delete(foodEntries)..where((e) => e.id.equals(id))).go();

  /// Most recently logged distinct foods (by name), newest first.
  Future<List<FoodEntry>> recentFoods({int limit = 12}) async {
    final rows = await (select(foodEntries)
          ..orderBy([(e) => OrderingTerm.desc(e.loggedAt)])
          ..limit(limit * 6))
        .get();
    final seen = <String>{};
    final out = <FoodEntry>[];
    for (final row in rows) {
      if (seen.add(row.name.trim().toLowerCase())) out.add(row);
      if (out.length == limit) break;
    }
    return out;
  }

  Stream<List<FoodEntry>> watchRecentFoods({int limit = 12}) =>
      select(foodEntries).watch().asyncMap((_) => recentFoods(limit: limit));

  // ------------------------------------------------------ custom foods

  Stream<List<CustomFood>> watchCustomFoods() =>
      (select(customFoods)..orderBy([(f) => OrderingTerm.asc(f.name)])).watch();

  Future<int> addCustomFood(CustomFoodsCompanion food) =>
      into(customFoods).insert(food);

  Future<int> deleteCustomFood(int id) =>
      (delete(customFoods)..where((f) => f.id.equals(id))).go();

  // ------------------------------------------------------- saved meals

  /// Newest first; `id` breaks ties because timestamps are stored in seconds.
  Stream<List<SavedMeal>> watchSavedMeals() => (select(savedMeals)
        ..orderBy([
          (m) => OrderingTerm.desc(m.createdAt),
          (m) => OrderingTerm.desc(m.id),
        ]))
      .watch();

  Future<int> addSavedMeal({
    required String name,
    required String emoji,
    required List<MealItem> items,
  }) =>
      into(savedMeals).insert(SavedMealsCompanion.insert(
        name: name,
        emoji: emoji,
        itemsJson: encodeMealItems(items),
        createdAt: DateTime.now(),
      ));

  Future<bool> updateSavedMeal(
    SavedMeal meal, {
    required String name,
    required String emoji,
    required List<MealItem> items,
  }) =>
      update(savedMeals).replace(meal.copyWith(
        name: name,
        emoji: emoji,
        itemsJson: encodeMealItems(items),
      ));

  Future<int> deleteSavedMeal(int id) =>
      (delete(savedMeals)..where((m) => m.id.equals(id))).go();

  // -------------------------------------------------------------- water

  /// Drinks logged on [day], oldest first.
  Stream<List<WaterLog>> watchWaterForDay(DateTime day) {
    final start = dateOnly(day);
    final q = select(waterLogs)
      ..where((w) => w.loggedAt.isBiggerOrEqualValue(start))
      ..where((w) => w.loggedAt.isSmallerThanValue(_dayEnd(day)))
      ..orderBy([(w) => OrderingTerm.asc(w.loggedAt), (w) => OrderingTerm.asc(w.id)]);
    return q.watch();
  }

  Future<int> addWater(int amountMl, DateTime at) => into(waterLogs)
      .insert(WaterLogsCompanion.insert(amountMl: amountMl, loggedAt: at));

  Future<int> deleteWater(int id) =>
      (delete(waterLogs)..where((w) => w.id.equals(id))).go();

  // ----------------------------------------------------------- profile

  Stream<UserProfile?> watchProfile() => (select(userProfiles)
        ..where((p) => p.id.equals(profileId)))
      .watchSingleOrNull();

  Future<UserProfile?> getProfile() => (select(userProfiles)
        ..where((p) => p.id.equals(profileId)))
      .getSingleOrNull();

  Future<void> saveProfile(UserProfilesCompanion profile) =>
      into(userProfiles).insertOnConflictUpdate(
        profile.copyWith(id: const Value(profileId)),
      );

  // ------------------------------------------------------------ barcodes

  Future<ScannedFood?> getScannedFood(String barcode) =>
      (select(scannedFoods)..where((f) => f.barcode.equals(barcode))).getSingleOrNull();

  Future<void> saveScannedFood(ScannedFoodsCompanion food) =>
      into(scannedFoods).insertOnConflictUpdate(food);

  // ------------------------------------------------------------- prefs

  Stream<Map<String, String>> watchPrefs() => select(prefs).watch().map(
        (rows) => {for (final r in rows) r.key: r.value},
      );

  Future<Map<String, String>> getPrefs() async =>
      {for (final r in await select(prefs).get()) r.key: r.value};

  Future<void> setPref(String key, String value) => into(prefs).insertOnConflictUpdate(
        PrefsCompanion.insert(key: key, value: value),
      );

  // -------------------------------------------------------------- misc

  Future<void> deleteEverything() async {
    await transaction(() async {
      for (final table in allTables) {
        await delete(table).go();
      }
    });
  }
}

/// Groups entries into per-day totals. Exposed for testing.
Map<DateTime, Totals> groupTotalsByDay(List<FoodEntry> entries) {
  final out = <DateTime, Totals>{};
  for (final e in entries) {
    final day = dateOnly(e.loggedAt);
    out[day] = (out[day] ?? Totals.zero) +
        Totals(kcal: e.kcal, protein: e.protein, carbs: e.carbs, fat: e.fat);
  }
  return out;
}

/// Sum of a list of entries.
Totals sumEntries(Iterable<FoodEntry> entries) => entries.fold(
      Totals.zero,
      (t, e) => t + Totals(kcal: e.kcal, protein: e.protein, carbs: e.carbs, fat: e.fat),
    );

String encodeMealItems(List<MealItem> items) =>
    jsonEncode([for (final i in items) i.toJson()]);

List<MealItem> decodeMealItems(String json) => [
      for (final j in jsonDecode(json) as List)
        MealItem.fromJson(j as Map<String, dynamic>),
    ];

extension SavedMealItems on SavedMeal {
  List<MealItem> get items => decodeMealItems(itemsJson);
  Totals get totals => sumMealItems(items);
}

/// Preference keys and typed access.
abstract final class PrefKeys {
  static const theme = 'theme';
  static const weightUnit = 'weight_unit';
  static const heightUnit = 'height_unit';
  static const name = 'name';
  static const avatar = 'avatar';
  static const haptics = 'haptics'; // legacy on/off, read only as a fallback
  static const hapticLevel = 'haptic_level';
  static const showMacros = 'show_macros';
  static const showWater = 'show_water';
  static const waterGoal = 'water_goal_ml';
  static const waterGlass = 'water_glass_ml';
  static const calorieView = 'calorie_view';
  static const sounds = 'sounds';
}

/// How the big number on Today reads.
enum CalorieView {
  left('Left'),
  eaten('Eaten');

  const CalorieView(this.label);
  final String label;
}

class AppPrefs {
  const AppPrefs({
    this.themeMode = 'light',
    this.weightUnit = WeightUnit.kg,
    this.heightUnit = HeightUnit.cm,
    this.name = '',
    this.avatar = defaultAvatar,
    this.hapticLevel = Haptics.defaultLevel,
    this.showMacros = true,
    this.showWater = true,
    this.waterGoalMl = defaultWaterGoalMl,
    this.waterGlassMl = defaultWaterGlassMl,
    this.calorieView = CalorieView.left,
    this.sounds = true,
  });

  static const defaultAvatar = '🥑';
  static const defaultWaterGoalMl = 3000;
  static const defaultWaterGlassMl = 250;

  final String themeMode;
  final WeightUnit weightUnit;
  final HeightUnit heightUnit;
  final String name;
  final String avatar;
  /// 0-100; 0 is off. Edited only in Settings.
  final int hapticLevel;
  final bool showMacros;
  final bool showWater;

  /// Daily water goal and the size of the one-tap "glass", in millilitres.
  final int waterGoalMl;
  final int waterGlassMl;
  final CalorieView calorieView;

  /// UI sound effects. On by default; they follow the phone's silent mode.
  final bool sounds;

  /// The saved level, else the old on/off switch (off -> 0), else the default.
  static int _parseHapticLevel(Map<String, String> m) {
    final saved = int.tryParse(m[PrefKeys.hapticLevel] ?? '');
    if (saved != null) return saved.clamp(0, 100);
    return m[PrefKeys.haptics] == '0' ? 0 : Haptics.defaultLevel;
  }

  factory AppPrefs.fromMap(Map<String, String> m) => AppPrefs(
        themeMode: m[PrefKeys.theme] ?? 'light',
        name: m[PrefKeys.name] ?? '',
        avatar: m[PrefKeys.avatar] ?? defaultAvatar,
        hapticLevel: _parseHapticLevel(m),
        showMacros: m[PrefKeys.showMacros] != '0',
        showWater: m[PrefKeys.showWater] != '0',
        sounds: m[PrefKeys.sounds] != '0',
        waterGoalMl: (int.tryParse(m[PrefKeys.waterGoal] ?? '') ?? defaultWaterGoalMl)
            .clamp(500, 10000),
        waterGlassMl: (int.tryParse(m[PrefKeys.waterGlass] ?? '') ?? defaultWaterGlassMl)
            .clamp(50, 1500),
        calorieView: CalorieView.values.firstWhere(
          (v) => v.name == m[PrefKeys.calorieView],
          orElse: () => CalorieView.left,
        ),
        weightUnit: WeightUnit.values.firstWhere(
          (u) => u.name == m[PrefKeys.weightUnit],
          orElse: () => WeightUnit.kg,
        ),
        heightUnit: HeightUnit.values.firstWhere(
          (u) => u.name == m[PrefKeys.heightUnit],
          orElse: () => HeightUnit.cm,
        ),
      );
}
