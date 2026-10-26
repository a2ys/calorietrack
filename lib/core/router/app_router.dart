import 'package:go_router/go_router.dart';

import '../../features/history/history_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/meals/meal_builder_screen.dart';
import '../../features/meals/meals_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../db/database.dart';
import 'app_shell.dart';

abstract final class Routes {
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const meals = '/meals';
  static const history = '/history';
  static const settings = '/settings';

  /// Full-screen, above the tab bar. Pass a [SavedMeal] as `extra` to edit.
  static const mealBuilder = '/meal-builder';
}

GoRouter createRouter({required bool onboarded}) {
  return GoRouter(
    initialLocation: onboarded ? Routes.home : Routes.onboarding,
    routes: [
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(
        path: Routes.mealBuilder,
        builder: (_, state) => MealBuilderScreen(meal: state.extra as SavedMeal?),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.meals, builder: (_, _) => const MealsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.history, builder: (_, _) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen()),
          ]),
        ],
      ),
    ],
  );
}
