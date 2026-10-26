import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/entry_tile.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/press_scale.dart';
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
                totals: totals,
                target: profile.calorieTarget,
                selected: selected,
                onSelect: (d) => ref.read(selectedDayProvider.notifier).select(d),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _WeekStats(totals: totals, target: profile.calorieTarget),
          const SizedBox(height: AppSpacing.xxl),
          _DayHeader(
            day: selected,
            totals: sumEntries(entries),
            target: profile.calorieTarget,
          ),
          const SizedBox(height: AppSpacing.md),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
              child: Column(
                children: [
                  const PopIn(child: Emoji('🍽️', size: 40)),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Nothing logged this day', style: t.label),
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
        Expanded(child: _Stat(label: 'Daily average', value: avg, suffix: ' kcal')),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _Stat(
            label: 'Days within goal',
            value: onTrack,
            suffix: ' / ${logged.length}',
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.suffix});

  final String label;
  final int value;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AppCard(
      shadow: false,
      radius: AppRadii.tile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: t.label),
          const SizedBox(height: AppSpacing.xs),
          CountUpText(value: value, suffix: suffix, style: t.numeralM),
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
