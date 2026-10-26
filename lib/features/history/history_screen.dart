import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/water.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/entry_tile.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/press_scale.dart';
import '../add_food/add_food_sheet.dart';
import '../water/water_card.dart';
import 'week_bar_chart.dart';
import '../../core/widgets/app_icon.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  /// Flick speed (logical px/s) that counts as a week swipe.
  static const double _swipeVelocity = 300;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final selected = ref.watch(selectedDayProvider);
    final weekStart = startOfWeek(selected);
    final profile = ref.watch(profileProvider).value;
    final totals = ref.watch(dailyTotalsProvider(weekStart)).value ?? const {};
    final entries = ref.watch(entriesForDayProvider(selected)).value ?? const <FoodEntry>[];
    final prefs = readPrefs(ref);
    final water = ref.watch(dailyWaterProvider(weekStart)).value ?? const {};

    if (profile == null) return const SizedBox.shrink();

    final today = dateOnly(DateTime.now());
    final canGoForward = !addDays(weekStart, 7).isAfter(today);

    void shiftWeek(int weeks) {
      var next = addDays(selected, 7 * weeks);
      if (next.isAfter(today)) next = today;
      Haptics.tap();
      ref.read(selectedDayProvider.notifier).select(next);
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          AppSpacing.huge,
        ),
        children: [
          Text('Progress', style: t.title),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _RoundIcon(icon: AppIcons.caretLeft, onTap: () => shiftWeek(-1)),
              Expanded(
                child: Text(
                  weekRangeLabel(weekStart),
                  textAlign: TextAlign.center,
                  style: t.bodyStrong,
                ),
              ),
              _RoundIcon(
                icon: AppIcons.caretRight,
                onTap: canGoForward ? () => shiftWeek(1) : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
            onHorizontalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v > _swipeVelocity) shiftWeek(-1);
              if (v < -_swipeVelocity && canGoForward) shiftWeek(1);
            },
            child: AppCard(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xxl,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: WeekBarChart(
                weekStart: weekStart,
                values: {for (final e in totals.entries) e.key: e.value.kcal},
                target: profile.calorieTarget,
                selected: selected,
                onSelect: (d) => ref.read(selectedDayProvider.notifier).select(d),
                goalLabel: 'Goal ${profile.calorieTarget} kcal',
                formatValue: (v) => '$v',
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _WeekStats(totals: totals, target: profile.calorieTarget),
          if (prefs.showWater) ...[
            const SizedBox(height: AppSpacing.md),
            _WaterWeek(
              weekStart: weekStart,
              water: water,
              goal: prefs.waterGoalMl,
              selected: selected,
              onSelect: (d) => ref.read(selectedDayProvider.notifier).select(d),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          _DayHeader(
            day: selected,
            totals: sumEntries(entries),
            target: profile.calorieTarget,
          ),
          const SizedBox(height: AppSpacing.md),
          if (prefs.showWater) ...[
            WaterCard(day: selected),
            const SizedBox(height: AppSpacing.md),
          ],
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Column(
                children: [
                  const PopIn(child: Emoji('🍽️', size: 40)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Nothing logged this day', style: t.label),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(
                    label: 'Add food',
                    icon: AppIcons.plus,
                    style: AppButtonStyle.outline,
                    onPressed: () => showAddFoodSheet(context, day: selected),
                  ),
                ],
              ),
            )
          else
            for (final e in entries)
              Padding(
                key: ValueKey('hist-${e.id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: EntryTile(entry: e),
              ),
        ],
      ),
    );
  }
}

class _WeekStats extends StatelessWidget {
  const _WeekStats({required this.totals, required this.target});

  final Map<DateTime, Totals> totals;
  final int target;

  @override
  Widget build(BuildContext context) {
    final logged = totals.values.where((t) => t.kcal > 0).toList();
    final avg = logged.isEmpty
        ? 0
        : (logged.fold<int>(0, (s, t) => s + t.kcal) / logged.length).round();
    final onTrack = logged.where((t) => t.kcal <= target).length;

    return Row(
      children: [
        Expanded(
          child: _Stat(
            label: 'Daily average',
            value: logged.isEmpty ? null : avg,
            unit: 'kcal',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Stat(
            label: 'Days within goal',
            value: logged.isEmpty ? null : onTrack,
            unit: '/ ${logged.length}',
          ),
        ),
      ],
    );
  }
}

/// Week of water: seven slim bars against the daily goal, plus the average
/// over the days that have a drink logged.
class _WaterWeek extends StatelessWidget {
  const _WaterWeek({
    required this.weekStart,
    required this.water,
    required this.goal,
    required this.selected,
    required this.onSelect,
  });

  final DateTime weekStart;
  final Map<DateTime, int> water;
  final int goal;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final logged = water.values.where((v) => v > 0).toList();
    final avg = logged.isEmpty ? 0 : (logged.fold<int>(0, (s, v) => s + v) / logged.length).round();
    final hit = logged.where((v) => v >= goal).length;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Emoji(AppEmoji.water, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: Text('Water', style: t.bodyStrong)),
              Text(
                logged.isEmpty ? 'No water logged' : '${formatWater(avg)} avg · $hit/${logged.length} on goal',
                style: t.label.copyWith(color: p.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          WeekBarChart(
            weekStart: weekStart,
            values: water,
            target: goal,
            selected: selected,
            onSelect: onSelect,
            goalLabel: 'Goal ${formatWater(goal)}',
            formatValue: formatWater,
            color: p.water,
            overIsBad: false,
            height: 170,
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.unit});

  final String label;

  /// Null for an empty week: shows a dash instead of a misleading zero.
  final int? value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return AppCard(
      shadow: false,
      radius: AppRadii.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.label),
          const SizedBox(height: AppSpacing.xs),
          if (value == null)
            Text('–', style: t.numeralM.copyWith(color: p.textSecondary))
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                CountUpText(value: value!, style: t.numeralM),
                const SizedBox(width: AppSpacing.xs),
                Text(unit, style: t.label),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.totals, required this.target});

  final DateTime day;
  final Totals totals;
  final int target;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dayLabel(day), style: t.heading),
              const SizedBox(height: AppSpacing.xxs),
              Row(
                children: [
                  for (final (kind, grams) in [
                    (MacroKind.protein, totals.protein),
                    (MacroKind.carbs, totals.carbs),
                    (MacroKind.fat, totals.fat),
                  ]) ...[
                    Emoji(kind.emoji, size: 13),
                    const SizedBox(width: AppSpacing.xxs),
                    Text('${grams.round()}g', style: t.label),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            ],
          ),
        ),
        Text('${totals.kcal}', style: t.numeralL.copyWith(fontSize: 30)),
        const SizedBox(width: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text('/ $target kcal', style: t.label),
        ),
      ],
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});

  final AppIconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      onTap: onTap,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: onTap == null ? 0.3 : 1,
        child: Container(
          width: AppSizes.iconTile,
          height: AppSizes.iconTile,
          decoration: BoxDecoration(
            color: p.surface,
            shape: BoxShape.circle,
            border: Border.all(color: p.border),
          ),
          child: AppIcon(icon, size: 18, color: p.textPrimary),
        ),
      ),
    );
  }
}
