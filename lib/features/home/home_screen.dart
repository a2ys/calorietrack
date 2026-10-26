import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/greeting.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/entry_tile.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/staggered_entrance.dart';
import '../add_food/add_food_sheet.dart';
import '../water/water_card.dart';
import 'calorie_summary.dart';
import 'week_strip.dart';
import '../../core/widgets/app_icon.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  /// Room under the list so the FAB never covers the last card.
  static const double _fabClearance = 112;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final day = ref.watch(selectedDayProvider);
    final profile = ref.watch(profileProvider).value;
    final prefs = readPrefs(ref);
    final entries = ref.watch(entriesForDayProvider(day)).value ?? const <FoodEntry>[];
    // Keep recents warm so Add food opens with them ready.
    ref.watch(recentFoodsProvider);

    if (profile == null) return const SizedBox.shrink();
    final eaten = sumEntries(entries);
    final now = DateTime.now();
    final headline = dayHeadline(
      day: day,
      now: now,
      eaten: eaten.kcal,
      target: profile.calorieTarget,
      entries: entries.length,
    );
    final isToday = isSameDay(day, now);

    // Own messenger: snackbars raised from Today land in this Scaffold, which
    // floats them above the + button instead of on top of it.
    return ScaffoldMessenger(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: _AddButton(
        onTap: () => showAddFoodSheet(context, day: day),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: _fabClearance),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.lg,
                AppSpacing.screen,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    // Re-keyed per day so switching days cross-fades the
                    // whole block instead of swapping text in place.
                    child: AnimatedSwitcher(
                      duration: AppMotion.normal,
                      switchInCurve: AppMotion.easeOut,
                      layoutBuilder: (current, previous) => Stack(
                        alignment: Alignment.topLeft,
                        children: [...previous, ?current],
                      ),
                      child: Column(
                        key: ValueKey(day),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(headline.eyebrow, style: t.eyebrow),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            headline.title,
                            style: t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            headline.line,
                            style: t.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Looking at another day: one tap back to today.
                  AnimatedSwitcher(
                    duration: AppMotion.normal,
                    transitionBuilder: (c, a) => FadeTransition(
                      opacity: a,
                      child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(a), child: c),
                    ),
                    child: isToday
                        ? const SizedBox.shrink()
                        : Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: PressScale(
                              scale: 0.92,
                              semanticLabel: 'Go to today',
                              onTap: () {
                                Haptics.tap();
                                ref.read(selectedDayProvider.notifier).select(now);
                              },
                              child: Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md + 2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: p.ink, borderRadius: AppRadii.chip),
                                child: Text(
                                  'Today',
                                  style: t.label.copyWith(color: p.onInk, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  PressScale(
                    scale: 0.92,
                    semanticLabel: 'Settings',
                    onTap: () => context.go(Routes.settings),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: p.border),
                        boxShadow: p.shadows,
                      ),
                      child: EmojiTile(
                        prefs.avatar,
                        size: 52,
                        radius: 26,
                        color: p.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const WeekStrip(),
            const SizedBox(height: AppSpacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
              child: Column(
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: CalorieHero(profile: profile, eaten: eaten, view: prefs.calorieView),
                  ),
                  if (prefs.showMacros) ...[
                    const SizedBox(height: AppSpacing.md),
                    StaggeredEntrance(
                      index: 1,
                      child: MacroRow(profile: profile, eaten: eaten),
                    ),
                  ],
                  if (prefs.showWater) ...[
                    const SizedBox(height: AppSpacing.md),
                    StaggeredEntrance(
                      index: 2,
                      child: WaterCard(day: day),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.xxl,
                AppSpacing.screen,
                AppSpacing.md,
              ),
              child: Text(entries.isEmpty ? 'Food log' : 'Food log · ${entries.length}',
                  style: t.heading),
            ),
            if (entries.isEmpty)
              _EmptyMeals(isToday: isToday, color: p.textSecondary)
            else
              for (var i = 0; i < entries.length; i++)
                Padding(
                  key: ValueKey('meal-${entries[i].id}'),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.screen,
                    0,
                    AppSpacing.screen,
                    AppSpacing.md,
                  ),
                  child: StaggeredEntrance(
                    index: i + 3,
                    child: EntryTile(entry: entries[i]),
                  ),
                ),
          ],
        ),
      ),
      ),
    );
  }
}

class _EmptyMeals extends StatelessWidget {
  const _EmptyMeals({required this.isToday, required this.color});
  final bool isToday;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screen,
        vertical: AppSpacing.xxxl,
      ),
      child: Column(
        children: [
          const PopIn(child: Emoji('🥣', size: 48)),
          const SizedBox(height: AppSpacing.md),
          Text(isToday ? 'Nothing logged yet' : 'Nothing logged this day',
              style: t.bodyStrong),
          const SizedBox(height: AppSpacing.xs),
          Text('Tap + to add your first meal.', style: t.label.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.9,
      semanticLabel: 'Add food',
      onTap: onTap,
      child: Container(
        width: AppSizes.fab,
        height: AppSizes.fab,
        decoration: BoxDecoration(
          color: p.ink,
          shape: BoxShape.circle,
          boxShadow: p.shadows,
        ),
        child: AppIcon(AppIcons.plus, color: p.onInk, size: 24),
      ),
    );
  }
}
