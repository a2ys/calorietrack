import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/db/database.dart';
import 'core/db/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/haptics.dart';
import 'core/utils/sounds.dart';
import 'core/widgets/splash_overlay.dart';

class CalorieApp extends ConsumerWidget {
  const CalorieApp({super.key, required this.router});

  final GoRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Warm the food catalog so search is ready by the time Add food opens.
    ref.watch(foodCatalogProvider);

    final prefs = ref.watch(prefsProvider).value ?? const AppPrefs();
    Haptics.level = prefs.hapticLevel;
    Sounds.enabled = prefs.sounds;

    // Light unless the user picked otherwise.
    final mode = switch (prefs.themeMode) {
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.light,
    };

    return MaterialApp.router(
      title: 'CalTracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      scrollBehavior: const _AppScrollBehavior(),
      themeAnimationDuration: AppMotion.slow,
      themeAnimationCurve: AppMotion.easeOut,
      routerConfig: router,
      builder: (context, child) => Stack(
        textDirection: TextDirection.ltr,
        children: [child ?? const SizedBox.shrink(), const SplashOverlay()],
      ),
    );
  }
}

/// Lets a mouse drag scroll lists and pull sheets down, like a finger does.
/// (Flutter only accepts touch drags by default, which makes swipe-to-dismiss
/// dead on web and desktop.)
class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
      };
}
