import 'package:calorie_app/core/db/database.dart';
import 'package:calorie_app/core/db/providers.dart';
import 'package:calorie_app/core/theme/app_theme.dart';
import 'package:calorie_app/features/meals/meal_builder_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(routes: [
      GoRoute(
        path: '/',
        builder: (context, _) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () => context.push('/b'), child: const Text('open')),
          ),
        ),
      ),
      GoRoute(path: '/b', builder: (_, _) => const MealBuilderScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory()))],
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> back(WidgetTester tester) async {
    // System back (Android button / edge swipe) goes through PopScope.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('leaving an untouched builder needs no confirmation', (tester) async {
    await pump(tester);
    await back(tester);
    expect(find.text('open'), findsOneWidget);
    await finish(tester);
  });

  testWidgets('leaving with unsaved work asks first', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'Post-gym');
    await tester.pumpAndSettle();

    await back(tester);
    expect(find.text('Discard this meal?'), findsOneWidget);

    // Keep editing: still on the builder.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('New meal'), findsOneWidget);

    await back(tester);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('open'), findsOneWidget);
    await finish(tester);
  });
}
