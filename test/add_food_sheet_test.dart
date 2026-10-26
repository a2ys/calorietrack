import 'package:calorie_app/core/data/food_catalog.dart';
import 'package:calorie_app/core/db/database.dart';
import 'package:calorie_app/core/db/providers.dart';
import 'package:calorie_app/core/theme/app_theme.dart';
import 'package:calorie_app/features/add_food/add_food_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
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

    await tester.tap(find.byIcon(CupertinoIcons.add).first);
    // Let the real database write finish, then repaint.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 600));

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
    await tester.tap(find.byIcon(CupertinoIcons.add));
    await tester.tap(find.byIcon(CupertinoIcons.add));
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
