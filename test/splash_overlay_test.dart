import 'package:calorie_app/core/theme/app_theme.dart';
import 'package:calorie_app/core/widgets/splash_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host() => MaterialApp(
        theme: AppTheme.light,
        home: const Stack(children: [Text('home'), SplashOverlay()]),
      );

  testWidgets('shows the name and byline, then clears itself', (tester) async {
    await tester.pumpWidget(host());
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('CalTracker'), findsOneWidget);
    expect(find.text('by a2ys'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('CalTracker'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('reduced motion still shows it briefly and clears it', (tester) async {
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: host(),
    ));
    expect(find.text('CalTracker'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('CalTracker'), findsNothing);
  });
}
