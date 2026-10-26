import 'package:calorie_app/core/data/food_catalog.dart';
import 'package:calorie_app/core/db/database.dart';
import 'package:calorie_app/core/db/providers.dart';
import 'package:calorie_app/core/theme/app_theme.dart';
import 'package:calorie_app/core/widgets/add_circle.dart';
import 'package:calorie_app/core/widgets/app_icon.dart';
import 'package:calorie_app/features/add_food/add_food_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));

  Future<void> pumpHarness(WidgetTester tester) async {
    // A tall phone so the sheet has room.
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          // Skip the asset load; the curated list is what these tests need.
          foodCatalogProvider.overrideWith((ref) => FoodCatalog.curated),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => showAddFoodSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder icon(AppIconData data) =>
      find.byWidgetPredicate((w) => w is AppIcon && w.icon == data);

  /// Let a real database write finish, then repaint.
  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  }

  /// Tear the tree down and let Drift's stream-cleanup timers fire. The
  /// in-memory database is left to the GC: closing it while those timers are
  /// parked in fake-async would wait forever.
  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('opens on Popular with foods listed', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('Roti'), findsOneWidget);
    expect(find.text('Steamed rice'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('searching by an alias finds the food', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'chawal');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Steamed rice'), findsOneWidget);
    expect(find.text('Roti'), findsNothing);
    await finish(tester);
  });

  testWidgets('quick add logs an entry and keeps the sheet open', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    await tester.tap(find.byType(AddCircle).first);
    await settleDb(tester);

    final rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows, hasLength(1));
    expect(rows!.single.name, 'Banana');
    expect(rows.single.kcal, 105);

    // Sheet stays open and shows a running total.
    expect(find.text('Add food'), findsOneWidget);
    expect(find.text('Done · 105 kcal'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('tapping a row opens quantity, and adds the chosen amount', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    await tester.tap(find.text('Roti'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('1 serving ='), findsOneWidget);

    // Two taps on "+" -> 2 servings (0.5 steps).
    await tester.tap(icon(AppIcons.plus));
    await tester.tap(icon(AppIcons.plus));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('2'), findsOneWidget);
    expect(find.textContaining('· 200 kcal'), findsOneWidget);

    await tester.tap(find.textContaining('Add to'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows!.single.name, 'Roti × 2');
    expect(rows.single.kcal, 200);
    // Back on the list.
    expect(find.text('Done · 200 kcal'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a food can be logged by weight', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    // Roti: 1 medium (40 g) = 100 kcal, so 20 g = 50 kcal.
    await tester.tap(find.text('Roti'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('Grams'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), '20');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('· 50 kcal'), findsOneWidget);

    await tester.ensureVisible(find.textContaining('Add to'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.textContaining('Add to'));
    await settleDb(tester);
    final rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows!.single.name, 'Roti · 20 g');
    expect(rows.single.kcal, 50);
    await finish(tester);
  });

  testWidgets('an add can be taken back from the row stepper', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Add twice: the "+" grows into a "− 2 +" stepper.
    await tester.tap(find.byType(AddCircle).first);
    await settleDb(tester);
    await tester.tap(icon(AppIcons.plus).first);
    await settleDb(tester);
    expect(find.text('Done · 210 kcal'), findsOneWidget);
    var rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows, hasLength(2));

    // "−" deletes the latest entry; at one left it shows a trash icon.
    await tester.tap(icon(AppIcons.minus).first);
    await settleDb(tester);
    rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows, hasLength(1));
    expect(find.text('Done · 105 kcal'), findsOneWidget);

    await tester.tap(icon(AppIcons.trash).first);
    await settleDb(tester);
    rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows, isEmpty);
    expect(find.textContaining('Done ·'), findsNothing);
    await finish(tester);
  });

  testWidgets('swiping left on the list moves to the next chip', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);
    expect(find.text('Roti'), findsOneWidget); // Popular

    await tester.fling(find.text('Roti'), const Offset(-300, 0), 1500);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // Popular -> Meals: preset plates replace the food list.
    expect(find.text('QUICK MEALS'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('a short sideways twitch does not change the chip', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    // Fast but tiny: inside the slop + minimum travel, so still Popular.
    await tester.fling(find.text('Roti'), const Offset(-40, 0), 2000);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Roti'), findsOneWidget);
    expect(find.text('QUICK MEALS'), findsNothing);
    await finish(tester);
  });

  testWidgets('custom food is blocked until calories match its macros', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);
    await tester.tap(find.text('Custom food'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Protein bar');
    await tester.enterText(fields.at(1), '500');
    await tester.enterText(fields.at(2), '20');
    await tester.enterText(fields.at(3), '30');
    await tester.enterText(fields.at(4), '10');
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    // 20/30/10 g = 290 kcal, not 500: explained inline, Add disabled.
    expect(find.textContaining('add up to 290 kcal'), findsOneWidget);
    await tester.tap(find.textContaining('Add to'));
    await settleDb(tester);
    var rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows, isEmpty);

    // One tap takes the macros' number, and it can be added.
    await tester.tap(find.text('Use 290'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.textContaining('add up to'), findsNothing);
    await tester.ensureVisible(find.textContaining('Add to'));
    await tester.tap(find.textContaining('Add to'));
    await settleDb(tester);
    rows = await tester.runAsync(() => db.select(db.foodEntries).get());
    expect(rows!.single.kcal, 290);
    await finish(tester);
  });

  testWidgets('dragging the sheet down dismisses it', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);
    expect(find.text('Add food'), findsOneWidget);

    // Drag from the header area (handle + title) well past the snap point.
    await tester.fling(find.text('Add food'), const Offset(0, 900), 2500);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Add food'), findsNothing);
    expect(find.text('open'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('dragging down from the food list also dismisses', (tester) async {
    await pumpHarness(tester);
    await openSheet(tester);

    // Start the drag on a row inside the scrolling list (scrolled to top).
    await tester.fling(find.text('Roti'), const Offset(0, 900), 2500);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('Add food'), findsNothing);
    await finish(tester);
  });
}
