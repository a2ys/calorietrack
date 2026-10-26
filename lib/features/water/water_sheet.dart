import 'dart:async';

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
import '../../core/widgets/rounded_animated_size.dart';
import '../../core/widgets/rounded_dismissible.dart';
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

class WaterSheet extends ConsumerStatefulWidget {
  const WaterSheet({super.key, required this.day});

  final DateTime day;

  @override
  ConsumerState<WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends ConsumerState<WaterSheet> {
  static const _undoWindow = Duration(seconds: 4);

  // Inline undo: snackbars from the underlying scaffold are hidden by the sheet.
  String? _undoText;
  VoidCallback? _onUndo;
  Timer? _undoTimer;

  DateTime get day => widget.day;

  @override
  void dispose() {
    _undoTimer?.cancel();
    super.dispose();
  }

  void _offerUndo(String text, VoidCallback onUndo) {
    _undoTimer?.cancel();
    setState(() {
      _undoText = text;
      _onUndo = onUndo;
    });
    _undoTimer = Timer(_undoWindow, _hideUndo);
  }

  void _hideUndo() {
    _undoTimer?.cancel();
    if (mounted) setState(() => _undoText = null);
  }

  Future<void> _add(int ml) async {
    final db = ref.read(databaseProvider);
    final id = await logWater(context, ref, day, ml, showUndo: false);
    if (!mounted) return;
    _offerUndo('Added ${formatWater(ml)}', () => db.deleteWater(id));
  }

  void _remove(WaterLog log) {
    final db = ref.read(databaseProvider);
    db.deleteWater(log.id);
    Haptics.medium();
    _offerUndo(
      'Removed ${formatWater(log.amountMl)}',
      () => db.addWater(log.amountMl, log.loggedAt),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                      onTap: () => _add(ml),
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
          RoundedAnimatedSize(
            duration: AppMotion.normal,
            curve: AppMotion.easeOut,
            alignment: Alignment.topCenter,
            borderRadius: AppRadii.tile, // the pill's own radius (40px tall)
            child: _undoText == null
                ? const SizedBox(width: double.infinity)
                : _UndoPill(
                    text: _undoText!,
                    onUndo: () {
                      Haptics.tap();
                      _onUndo?.call();
                      _hideUndo();
                    },
                  ),
          ),
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
                onDelete: () => _remove(log),
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

/// Ink pill with a message and an Undo action, shown above the log list.
class _UndoPill extends StatelessWidget {
  const _UndoPill({required this.text, required this.onUndo});

  final String text;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        padding: const EdgeInsets.only(left: AppSpacing.lg, right: AppSpacing.xs),
        decoration: BoxDecoration(color: p.ink, borderRadius: AppRadii.chip),
        child: Row(
          children: [
            Expanded(child: Text(text, style: t.body.copyWith(color: p.onInk))),
            PressScale(
              onTap: onUndo,
              child: Container(
                height: AppSizes.iconTile,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: Text('Undo', style: t.bodyStrong.copyWith(color: p.onInk)),
              ),
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
    return RoundedDismissible(
      key: ValueKey('dismiss-water-${log.id}'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {DismissDirection.endToStart: AppGestures.deleteThreshold},
      onDismissed: (_) => onDelete(),
      borderRadius: AppRadii.tile,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.lg),
        color: p.accent,
        child: AppIcon(AppIcons.trash, size: 20, color: p.onInk),
      ),
      // Opaque, so the sliding row covers the background behind it.
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(color: p.surface, borderRadius: AppRadii.tile),
        child: Row(
          children: [
            const EmojiTile(AppEmoji.water, size: 36, radius: 11),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(formatWater(log.amountMl), style: t.bodyStrong)),
            Text(timeLabel(log.loggedAt), style: t.label),
            PressScale(
              semanticLabel: 'Delete ${formatWater(log.amountMl)}',
              scale: 0.9,
              onTap: onDelete,
              child: SizedBox(
                width: AppSizes.iconTile,
                height: AppSizes.iconTile,
                child: Center(child: AppIcon(AppIcons.trash, size: 18, color: p.textTertiary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
