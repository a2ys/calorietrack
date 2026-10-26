import 'dart:async';
import 'dart:convert';

import 'package:calorie_app/core/data/photo_meal_service.dart';
import 'package:calorie_app/core/db/database.dart';
import 'package:calorie_app/core/db/models.dart';
import 'package:calorie_app/core/db/providers.dart';
import 'package:calorie_app/core/theme/app_theme.dart';
import 'package:calorie_app/core/widgets/sheet_scaffold.dart';
import 'package:calorie_app/features/scan/photo_meal_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// A valid 1x1 PNG, so Image.memory decodes in tests.
final photo = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');

const meal = {
  'is_food': true,
  'dish': 'Rajma chawal',
  'emoji': '🍛',
  'meal_type': 'lunch',
  'health_score': 7,
  'items': [
    {'name': 'Rajma', 'grams': 180, 'kcal': 230, 'protein': 12, 'carbs': 30, 'fat': 6},
    {'name': 'Steamed rice', 'grams': 200, 'kcal': 260, 'protein': 5, 'carbs': 56, 'fat': 1},
  ],
};

void main() {
  late AppDatabase db;
  late List<Map<String, dynamic>> requests;
  late List<Completer<http.Response>> replies;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    requests = [];
    replies = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  /// Each request waits for the test to answer it.
  PhotoMealService service() => PhotoMealService(
        installId: 'test',
        client: MockClient((req) {
          requests.add(jsonDecode(req.body) as Map<String, dynamic>);
          final c = Completer<http.Response>();
          replies.add(c);
          return c.future;
        }),
      );

  Future<void> answer(WidgetTester tester, Object body, [int status = 200]) async {
    replies.last.complete(http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.pumpAndSettle();
  }

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final s = service();
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => showAppSheet<bool>(
                  context,
                  initialSize: 0.92,
                  maxSize: 0.96,
                  builder: (_) => PhotoMealSheet(photo: Uint8List.fromList(photo), service: s),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('reads the plate, then logs it as one meal', (tester) async {
    await open(tester);
    expect(find.text('Reading your plate…'), findsOneWidget);
    expect(requests.single['mediaType'], 'image/png');

    await answer(tester, meal);
    expect(find.text('Rajma chawal'), findsOneWidget);
    expect(find.text('Health score'), findsOneWidget);
    expect(find.text('Steamed rice'), findsOneWidget);

    final log = find.text('Log meal · 490 kcal');
    await tester.ensureVisible(log);
    await tester.pumpAndSettle();
    await tester.tap(log);
    await tester.pumpAndSettle();

    final entries = await db.entriesBetween(DateTime(2000), DateTime(2100));
    expect(entries.single.name, 'Rajma chawal');
    expect(entries.single.kcal, 490);
    expect(entries.single.mealType, MealType.lunch);
    expect(find.text('open'), findsOneWidget); // sheet closed
    await finish(tester);
  });

  testWidgets('Fix results reads it again with the correction', (tester) async {
    await open(tester);
    await answer(tester, meal);

    final fix = find.text('Fix results');
    await tester.ensureVisible(fix);
    await tester.pumpAndSettle();
    await tester.tap(fix);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'It was 2 cups of rice');
    await tester.pump();
    await tester.tap(find.text('Read it again'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Reading your plate…'), findsOneWidget);
    expect(requests.last['note'], 'It was 2 cups of rice');

    await answer(tester, {...meal, 'dish': 'Rajma with extra rice'});
    expect(find.text('Rajma with extra rice'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('failures offer a retry; no food says so', (tester) async {
    await open(tester);
    await answer(tester, {'error': 'busy', 'message': 'The service is busy.'}, 503);
    expect(find.text('Couldn’t read that'), findsOneWidget);
    expect(find.text('The service is busy.'), findsOneWidget);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    expect(requests, hasLength(2));
    await answer(tester, {'is_food': false, 'dish': '', 'emoji': '', 'meal_type': 'snack', 'health_score': 1, 'items': []});
    expect(find.text('No food here'), findsOneWidget);
    await finish(tester);
  });
}
