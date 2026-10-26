import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/database.dart';
import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/water.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/progress_ring.dart';
import '../../core/widgets/sheet_scaffold.dart';
import 'water_actions.dart';
import 'water_widgets.dart';

Future<void> showWaterSheet(BuildContext context, {required DateTime day}) {
  return showAppSheet<void>(
    context,
    initialSize: 0.9,
    builder: (_) => WaterSheet(day: day),
  );
}

class WaterSheet extends ConsumerWidget {
  const WaterSheet({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = context.palette;
    final prefs = readPrefs(ref);
    final logs = ref.watch(waterForDayProvider(day)).value ?? const <WaterLog>[];
    final db = ref.read(databaseProvider);
    final total = logs.fold<int>(0, (s, l) => s + l.amountMl);
    final goal = prefs.waterGoalMl;

    return SheetScaffold(
      title: 'Water',
      subtitle: dayLabel(day),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ProgressRing(
              progress: goal == 0 ? 0 : total / goal,
              size: 176,
              strokeWidth: 14,
              color: p.water,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const PopIn(child: Emoji(AppEmoji.water, size: 26)),
                  const SizedBox(height: AppSpacing.xs),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: total.toDouble()),
                    duration: AppMotion.slow,
                    curve: AppMotion.easeOut,
                    builder: (context, v, _) => Text(
                      formatWater(v.round()),
                      style: t.numeralM.copyWith(fontSize: 28),
                    ),
                  ),
                  Text(
                    total >= goal ? 'Goal reached' : 'of ${formatWater(goal)}',
                    style: t.caption.copyWith(color: total >= goal ? p.water : null),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('ADD', style: t.caption.copyWith(letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(builder: (context, c) {
            const gap = AppSpacing.sm;
            final w = (c.maxWidth - gap * 2) / 3;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final ml in WaterLimits.presets)
                  SizedBox(
                    width: w,
                    child: _PresetTile(
                      ml: ml,
                      highlight: ml == prefs.waterGlassMl,
                      onTap: () => logWater(context, ref, day, ml),
                    ),
                  ),
              ],
            );
          }),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(child: Text('Daily goal', style: t.bodyStrong)),
              WaterGoalStepper(
                goalMl: goal,
                onChanged: (v) => db.setPref(PrefKeys.waterGoal, '$v'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(isSameDay(day, DateTime.now()) ? 'TODAY' : dayLabel(day).toUpperCase(),
              style: t.caption.copyWith(letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          if (logs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Text('Nothing yet. Tap an amount above.', style: t.label),
            )
          else
            for (final log in logs.reversed)
              _LogRow(
                key: ValueKey('water-${log.id}'),
                log: log,
                onDelete: () {
                  db.deleteWater(log.id);
                  Haptics.medium();
                  ScaffoldMessenger.of(context)
                    ..clearSnackBars()
                    ..showSnackBar(SnackBar(
                      content: Text('Removed ${formatWater(log.amountMl)}'),
                      action: SnackBarAction(
                        label: 'Undo',
                        textColor: p.onInk,
                        onPressed: () => db.addWater(log.amountMl, log.loggedAt),
                      ),
                    ));
                },
              ),
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.ml, required this.highlight, required this.onTap});

  final int ml;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return PressScale(
      scale: 0.94,
      onTap: onTap,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: highlight ? p.water.withValues(alpha: 0.14) : p.surfaceAlt,
          borderRadius: AppRadii.tile,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppIcon(AppIcons.plus, size: 12, color: highlight ? p.water : p.textSecondary),
            const SizedBox(width: AppSpacing.xs),
            Text(
              formatWater(ml),
              style: t.bodyStrong.copyWith(color: highlight ? p.water : p.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({super.key, required this.log, required this.onDelete});

  final WaterLog log;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return Dismissible(
      key: ValueKey('dismiss-water-${log.id}'),
      direction: DismissDirection.endToStart,
      onUpdate: (d) {
        if (d.reached && !d.previousReached) Haptics.light();
      },
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        child: AppIcon(AppIcons.trash, size: 20, color: p.accent),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            const EmojiTile(AppEmoji.water, size: 36, radius: 11),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(formatWater(log.amountMl), style: t.bodyStrong)),
            Text(timeLabel(log.loggedAt), style: t.label),
          ],
        ),
      ),
    );
  }
}
