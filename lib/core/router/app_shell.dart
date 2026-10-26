import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../db/providers.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import '../widgets/press_scale.dart';
import '../widgets/app_icon.dart';

/// Bottom navigation around the four main tabs. Tab switches are instant
/// (they happen constantly) but the selected icon gives a small spring pop.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const _items = [
    (AppIcons.houseFill, 'Today'),
    (AppIcons.forkKnifeFill, 'Meals'),
    (AppIcons.chartBarFill, 'Progress'),
    (AppIcons.gearFill, 'Settings'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;

    return Scaffold(
      body: shell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(top: BorderSide(color: p.border, width: AppSizes.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AppSizes.navHeight,
            child: Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: PressScale(
                      scale: 0.94,
                      onTap: () {
                        if (i != shell.currentIndex) Haptics.tap();
                        // Tapping Today again while there returns to today.
                        if (i == 0 && i == shell.currentIndex) {
                          ref.read(selectedDayProvider.notifier).select(DateTime.now());
                        }
                        shell.goBranch(i, initialLocation: i == shell.currentIndex);
                      },
                      child: _TabItem(
                        icon: _items[i].$1,
                        label: _items[i].$2,
                        selected: i == shell.currentIndex,
                        color: i == shell.currentIndex ? p.textPrimary : p.textTertiary,
                        style: t.caption,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.style,
  });

  /// Solid in both states, like Uber's tab bar: only the colour changes, so
  /// the four glyphs always read as one family.
  final AppIconData icon;
  final String label;
  final bool selected;
  final Color color;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Re-keyed on selection so the icon pops each time it becomes active.
        TweenAnimationBuilder<double>(
          key: ValueKey(selected),
          tween: Tween(begin: selected ? 0.72 : 1, end: 1),
          duration: AppMotion.springDuration,
          curve: AppMotion.springBouncy,
          builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
          child: AppIcon(icon, size: 24, color: color),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(label, style: style.copyWith(color: color)),
      ],
    );
  }
}
