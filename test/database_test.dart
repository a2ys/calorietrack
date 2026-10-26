import 'package:calorie_app/core/db/database.dart';
import 'package:calorie_app/core/db/models.dart';
import 'package:calorie_app/core/utils/calorie_calculator.dart';
import 'package:calorie_app/core/utils/date_utils.dart';
import 'package:calorie_app/core/utils/units.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

FoodEntriesCompanion entry(
  String name,
  int kcal,
  DateTime at, {
  double protein = 0,
  double carbs = 0,
  double fat = 0,
  MealType meal = MealType.lunch,
}) =>
    FoodEntriesCompanion.insert(
      name: name,
      kcal: kcal,
      protein: Value(protein),
      carbs: Value(carbs),
      fat: Value(fat),
      mealType: meal,
      loggedAt: at,
    );

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  final monday = DateTime(2026, 10, 19);

  group('entries', () {
    test('watchEntriesForDay only returns that day, oldest first', () async {
      await db.addEntry(entry('late', 300, DateTime(2026, 10, 20, 21)));
      await db.addEntry(entry('early', 200, DateTime(2026, 10, 20, 8)));
      await db.addEntry(entry('other day', 999, DateTime(2026, 10, 21, 8)));
      await db.addEntry(entry('prev day', 999, DateTime(2026, 10, 19, 23, 59)));

      final rows = await db.watchEntriesForDay(DateTime(2026, 10, 20)).first;
      expect(rows.map((e) => e.name), ['early', 'late']);
    });

    test('day boundaries: midnight belongs to the new day', () async {
      await db.addEntry(entry('midnight', 100, DateTime(2026, 10, 21)));
      final d20 = await db.watchEntriesForDay(DateTime(2026, 10, 20)).first;
      final d21 = await db.watchEntriesForDay(DateTime(2026, 10, 21)).first;
      expect(d20, isEmpty);
      expect(d21, hasLength(1));
    });

    test('stream emits again after an insert', () async {
      final stream = db.watchEntriesForDay(monday);
      final expectation = expectLater(
        stream.map((l) => l.length),
        emitsInOrder([0, 1]),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await db.addEntry(entry('x', 1, monday.add(const Duration(hours: 9))));
      await expectation;
    });

    test('update and delete', () async {
      final id = await db.addEntry(entry('toast', 120, monday.add(const Duration(hours: 8))));
      var row = (await db.watchEntriesForDay(monday).first).single;
      await db.updateEntry(row.copyWith(kcal: 180, name: 'toast + butter'));
      row = (await db.watchEntriesForDay(monday).first).single;
      expect(row.kcal, 180);
      expect(row.name, 'toast + butter');

      expect(await db.deleteEntry(id), 1);
      expect(await db.watchEntriesForDay(monday).first, isEmpty);
    });

    test('macros default to zero', () async {
      await db.addEntry(entry('water', 0, monday.add(const Duration(hours: 8))));
      final row = (await db.watchEntriesForDay(monday).first).single;
      expect([row.protein, row.carbs, row.fat], [0, 0, 0]);
    });
  });

  group('daily totals', () {
    test('sums per day and skips empty days', () async {
      await db.addEntry(entry('a', 400, DateTime(2026, 10, 19, 8), protein: 20, carbs: 40, fat: 10));
      await db.addEntry(entry('b', 600, DateTime(2026, 10, 19, 13), protein: 30, carbs: 60, fat: 20));
      await db.addEntry(entry('c', 250, DateTime(2026, 10, 21, 19), protein: 5));

      final totals = await db
          .watchDailyTotals(monday, addDays(monday, 7))
          .first;

      expect(totals.keys, containsAll([DateTime(2026, 10, 19), DateTime(2026, 10, 21)]));
      expect(totals.containsKey(DateTime(2026, 10, 20)), isFalse);

      final mon = totals[DateTime(2026, 10, 19)]!;
      expect(mon.kcal, 1000);
      expect(mon.protein, 50);
      expect(mon.carbs, 100);
      expect(mon.fat, 30);
      expect(totals[DateTime(2026, 10, 21)]!.kcal, 250);
    });

    test('range is end-exclusive', () async {
      await db.addEntry(entry('in', 100, DateTime(2026, 10, 25, 23)));
      await db.addEntry(entry('out', 100, DateTime(2026, 10, 26, 0)));
      final totals = await db.watchDailyTotals(monday, addDays(monday, 7)).first;
      expect(totals.values.fold<int>(0, (s, t) => s + t.kcal), 100);
    });

    test('sumEntries', () async {
      await db.addEntry(entry('a', 100, monday.add(const Duration(hours: 8)), protein: 1));
      await db.addEntry(entry('b', 50, monday.add(const Duration(hours: 9)), protein: 2));
      final rows = await db.watchEntriesForDay(monday).first;
      final t = sumEntries(rows);
      expect(t.kcal, 150);
      expect(t.protein, 3);
    });
  });

  group('recent foods', () {
    test('distinct by name (case-insensitive), newest first, honours limit', () async {
      await db.addEntry(entry('Banana', 100, DateTime(2026, 10, 19, 8)));
      await db.addEntry(entry('Rice', 200, DateTime(2026, 10, 19, 12)));
      await db.addEntry(entry('banana', 105, DateTime(2026, 10, 20, 8)));
      await db.addEntry(entry('Egg', 70, DateTime(2026, 10, 21, 8)));

      final recent = await db.recentFoods();
      expect(recent.map((e) => e.name), ['Egg', 'banana', 'Rice']);
      expect(recent[1].kcal, 105, reason: 'keeps the latest version');

      expect(await db.recentFoods(limit: 2), hasLength(2));
    });
  });

  group('custom foods', () {
    test('add, list alphabetically, delete', () async {
      await db.addCustomFood(CustomFoodsCompanion.insert(
        name: 'Protein shake', kcal: 180, createdAt: DateTime(2026, 10, 1)));
      final id = await db.addCustomFood(CustomFoodsCompanion.insert(
        name: 'Almonds', kcal: 160, createdAt: DateTime(2026, 10, 2)));

      var foods = await db.watchCustomFoods().first;
      expect(foods.map((f) => f.name), ['Almonds', 'Protein shake']);

      await db.deleteCustomFood(id);
      foods = await db.watchCustomFoods().first;
      expect(foods.map((f) => f.name), ['Protein shake']);
    });
  });

  group('haptics + water prefs edge cases', () {
    test('old on/off haptics switch still honoured when no level is saved', () async {
      await db.setPref(PrefKeys.haptics, '0');
      expect(AppPrefs.fromMap(await db.getPrefs()).hapticLevel, 0);
      // An explicit level wins over the legacy flag.
      await db.setPref(PrefKeys.hapticLevel, '80');
      expect(AppPrefs.fromMap(await db.getPrefs()).hapticLevel, 80);
    });

    test('values are clamped to sane ranges', () async {
      await db.setPref(PrefKeys.hapticLevel, '999');
      await db.setPref(PrefKeys.waterGoal, '5');
      await db.setPref(PrefKeys.waterGlass, '99999');
      final prefs = AppPrefs.fromMap(await db.getPrefs());
      expect(prefs.hapticLevel, 100);
      expect(prefs.waterGoalMl, 500);
      expect(prefs.waterGlassMl, 1500);
    });
  });

  group('water', () {
    test('lists only that day, oldest first, and sums by hand', () async {
      await db.addWater(250, DateTime(2026, 10, 20, 15));
      await db.addWater(500, DateTime(2026, 10, 20, 9));
      await db.addWater(750, DateTime(2026, 10, 21, 0, 0)); // midnight: next day
      await db.addWater(300, DateTime(2026, 10, 19, 23, 59)); // previous day

      final logs = await db.watchWaterForDay(DateTime(2026, 10, 20)).first;
      expect(logs.map((l) => l.amountMl), [500, 250]);
      expect(logs.fold<int>(0, (s, l) => s + l.amountMl), 750);
    });

    test('delete removes one drink', () async {
      final id = await db.addWater(250, DateTime(2026, 10, 20, 9));
      await db.addWater(250, DateTime(2026, 10, 20, 10));
      expect(await db.deleteWater(id), 1);
      expect(await db.watchWaterForDay(DateTime(2026, 10, 20)).first, hasLength(1));
    });

    test('erase everything clears water too', () async {
      await db.addWater(250, DateTime(2026, 10, 20, 9));
      await db.deleteEverything();
      expect(await db.watchWaterForDay(DateTime(2026, 10, 20)).first, isEmpty);
    });
  });

  group('saved meals', () {
    MealItem item(String name, double qty) => MealItem(
          name: name,
          emoji: '🍛',
          serving: '1 katori',
          qty: qty,
          kcal: 150,
          protein: 8,
          carbs: 20,
          fat: 3.5,
        );

    test('items round-trip through JSON and totals scale by qty', () async {
      await db.addSavedMeal(
        name: 'Dal Chawal',
        emoji: '🍛',
        items: [item('Dal', 1.5), item('Rice', 1)],
      );
      final meals = await db.watchSavedMeals().first;
      expect(meals, hasLength(1));
      final m = meals.single;
      expect(m.name, 'Dal Chawal');
      expect(m.items.map((i) => i.name), ['Dal', 'Rice']);
      expect(m.items.first.qty, 1.5);
      // 150 * 1.5 + 150 * 1
      expect(m.totals.kcal, 375);
      expect(m.totals.protein, closeTo(20, 0.001));
    });

    test('newest first, update and delete', () async {
      await db.addSavedMeal(name: 'Old', emoji: '🍚', items: [item('a', 1)]);
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final id = await db.addSavedMeal(name: 'New', emoji: '🍲', items: [item('b', 1)]);

      var meals = await db.watchSavedMeals().first;
      expect(meals.map((m) => m.name), ['New', 'Old']);

      await db.updateSavedMeal(meals.first, name: 'Newer', emoji: '🥣', items: [item('c', 2)]);
      meals = await db.watchSavedMeals().first;
      expect(meals.first.name, 'Newer');
      expect(meals.first.emoji, '🥣');
      expect(meals.first.items.single.qty, 2);

      expect(await db.deleteSavedMeal(id), 1);
      expect((await db.watchSavedMeals().first).map((m) => m.name), ['Old']);
    });

    test('erase everything clears meals too', () async {
      await db.addSavedMeal(name: 'x', emoji: '🍚', items: [item('a', 1)]);
      await db.deleteEverything();
      expect(await db.watchSavedMeals().first, isEmpty);
    });
  });

  group('profile', () {
    UserProfilesCompanion profile(int kcal) => UserProfilesCompanion.insert(
          id: const Value(1),
          goal: Goal.lose,
          sex: Sex.female,
          age: 28,
          heightCm: 168,
          weightKg: 64.5,
          activity: ActivityLevel.light,
          calorieTarget: kcal,
          proteinTarget: 120,
          carbsTarget: 180,
          fatTarget: 55,
        );

    test('null before onboarding, upsert afterwards', () async {
      expect(await db.getProfile(), isNull);

      await db.saveProfile(profile(1800));
      var p = (await db.getProfile())!;
      expect(p.calorieTarget, 1800);
      expect(p.goal, Goal.lose);
      expect(p.weightKg, 64.5);

      await db.saveProfile(profile(1900));
      p = (await db.getProfile())!;
      expect(p.calorieTarget, 1900);
      expect(await db.select(db.userProfiles).get(), hasLength(1));
    });
  });

  group('prefs', () {
    test('personalization defaults: light theme, haptics on, macros shown', () async {
      final prefs = AppPrefs.fromMap(await db.getPrefs());
      expect(prefs.themeMode, 'light');
      expect(prefs.name, '');
      expect(prefs.avatar, AppPrefs.defaultAvatar);
      expect(prefs.hapticLevel, 70);
      expect(prefs.showWater, isTrue);
      expect(prefs.waterGoalMl, 3000);
      expect(prefs.waterGlassMl, 250);
      expect(prefs.showMacros, isTrue);
      expect(prefs.calorieView, CalorieView.left);
    });

    test('personalization round-trips', () async {
      await db.setPref(PrefKeys.name, 'Aayush');
      await db.setPref(PrefKeys.avatar, '🥭');
      await db.setPref(PrefKeys.hapticLevel, '45');
      await db.setPref(PrefKeys.waterGoal, '3500');
      await db.setPref(PrefKeys.waterGlass, '330');
      await db.setPref(PrefKeys.showWater, '0');
      await db.setPref(PrefKeys.showMacros, '0');
      await db.setPref(PrefKeys.calorieView, CalorieView.eaten.name);
      final prefs = AppPrefs.fromMap(await db.getPrefs());
      expect(prefs.name, 'Aayush');
      expect(prefs.avatar, '🥭');
      expect(prefs.hapticLevel, 45);
      expect(prefs.waterGoalMl, 3500);
      expect(prefs.waterGlassMl, 330);
      expect(prefs.showWater, isFalse);
      expect(prefs.showMacros, isFalse);
      expect(prefs.calorieView, CalorieView.eaten);
    });

    test('defaults then overrides', () async {
      expect(AppPrefs.fromMap(await db.getPrefs()).weightUnit, WeightUnit.kg);

      await db.setPref(PrefKeys.weightUnit, WeightUnit.lb.name);
      await db.setPref(PrefKeys.theme, 'dark');
      await db.setPref(PrefKeys.theme, 'light');

      final prefs = AppPrefs.fromMap(await db.getPrefs());
      expect(prefs.weightUnit, WeightUnit.lb);
      expect(prefs.heightUnit, HeightUnit.cm);
      expect(prefs.themeMode, 'light');
    });
  });

  test('deleteEverything wipes all tables', () async {
    await db.addEntry(entry('a', 1, monday));
    await db.setPref('k', 'v');
    await db.deleteEverything();
    expect(await db.select(db.foodEntries).get(), isEmpty);
    expect(await db.getPrefs(), isEmpty);
  });
}
