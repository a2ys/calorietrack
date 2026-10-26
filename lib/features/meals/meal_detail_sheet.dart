import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/food.dart';
import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/db/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/segmented_pills.dart';
import '../../core/widgets/sheet_scaffold.dart';
import '../../core/widgets/app_icon.dart';

/// Shows a meal's ingredients and totals and logs it in one tap.
/// Completes with `true` if the meal was logged. Pass [saved] for a meal the
/// user built (enables Edit / Delete); otherwise it is a quick meal that can
/// be copied into "My meals".
Future<bool?> showMealDetailSheet(
  BuildContext context, {
  required String name,
  required String emoji,
  required List<MealItem> items,
  SavedMeal? saved,
  DateTime? day,
  MealType? mealType,
}) {
  return showAppSheet<bool>(
    context,
    initialSize: 0.82,
    maxSize: 0.94,
    builder: (_) => MealDetailSheet(
      name: name,
      emoji: emoji,
      items: items,
      saved: saved,
      day: day,
      mealType: mealType,
    ),
  );
}

class MealDetailSheet extends ConsumerStatefulWidget {
  const MealDetailSheet({
    super.key,
    required this.name,
    required this.emoji,
    required this.items,
    this.saved,
    this.day,
    this.mealType,
  });

  final String name;
  final String emoji;
  final List<MealItem> items;
  final SavedMeal? saved;
  final DateTime? day;
  final MealType? mealType;

  @override
  ConsumerState<MealDetailSheet> createState() => _MealDetailSheetState();
}

class _MealDetailSheetState extends ConsumerState<MealDetailSheet> {
  late MealType _meal = widget.mealType ?? MealType.forTime(DateTime.now());
  double _scale = 1;

  Totals get _total {
    final t = sumMealItems(widget.items);
    return Totals(
      kcal: (t.kcal * _scale).round(),
      protein: t.protein * _scale,
      carbs: t.carbs * _scale,
      fat: t.fat * _scale,
    );
  }

  void _changeScale(double delta) {
    final next = (_scale + delta).clamp(0.5, 10.0);
    if (next == _scale) return;
    Haptics.tap();
    setState(() => _scale = next);
  }

  DateTime _loggedAt() {
    final now = DateTime.now();
    final d = widget.day;
    if (d == null) return now;
    return DateTime(d.year, d.month, d.day, now.hour, now.minute);
  }

  Future<void> _log() async {
    final t = _total;
    final name = _scale == 1 ? widget.name : '${widget.name} × ${formatQty(_scale)}';
    await ref.read(databaseProvider).addEntry(FoodEntriesCompanion.insert(
          name: name,
          kcal: t.kcal,
          protein: Value(t.protein),
          carbs: Value(t.carbs),
          fat: Value(t.fat),
          mealType: _meal,
          loggedAt: _loggedAt(),
          emoji: Value(widget.emoji),
        ));
    Haptics.success();
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _saveCopy() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(databaseProvider).addSavedMeal(
          name: widget.name,
          emoji: widget.emoji,
          items: widget.items,
        );
    Haptics.success();
    if (!mounted) return;
    Navigator.of(context).pop(false);
    messenger
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Saved to My meals')));
  }

  void _edit() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop(false);
    router.push(Routes.mealBuilder, extra: widget.saved);
  }

  Future<void> _delete() async {
    final saved = widget.saved!;
    final ok = await showAppDialog<bool>(
      context,
      builder: (_) => const ConfirmDialog(
        title: 'Delete this meal?',
        message: 'It will be removed from My meals. Foods you already logged stay.',
        confirmLabel: 'Delete',
      ),
    );
    if (ok != true || !mounted) return;
    final db = ref.read(databaseProvider);
    final messenger = ScaffoldMessenger.of(context);
    final p = context.palette;
    await db.deleteSavedMeal(saved.id);
    Haptics.warning();
    if (!mounted) return;
    Navigator.of(context).pop(false);
    messenger
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('Deleted ${saved.name}'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: p.onInk,
          onPressed: () =>
              db.addSavedMeal(name: saved.name, emoji: saved.emoji, items: saved.items),
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    final total = _total;

    return SheetScaffold(
      title: widget.name,
      subtitle: '${widget.items.length} ${widget.items.length == 1 ? 'item' : 'items'}',
      trailing: PopIn(child: EmojiTile(widget.emoji, size: 52, radius: 16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Totals
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: AppRadii.tile),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    const Emoji(AppEmoji.calories, size: 22),
                    const SizedBox(width: AppSpacing.xs),
                    CountUpText(value: total.kcal, duration: AppMotion.normal, style: t.numeralL),
                    const SizedBox(width: AppSpacing.xs),
                    Text('kcal', style: t.label),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    for (final (kind, grams) in [
                      (MacroKind.protein, total.protein),
                      (MacroKind.carbs, total.carbs),
                      (MacroKind.fat, total.fat),
                    ])
                      Expanded(
                        child: Column(
                          children: [
                            Emoji(kind.emoji, size: 18),
                            const SizedBox(height: AppSpacing.xxs),
                            Text('${grams.round()}g', style: t.numeralS),
                            Text(kind.label, style: t.caption),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          // Portion
          Row(
            children: [
              Expanded(child: Text('Portion', style: t.bodyStrong)),
              _MiniStep(icon: AppIcons.minus, onTap: () => _changeScale(-0.5), enabled: _scale > 0.5),
              SizedBox(
                width: 64,
                child: AnimatedSwitcher(
                  duration: AppMotion.fast,
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween<double>(begin: 0.8, end: 1).animate(a), child: c),
                  ),
                  child: Text(
                    '${formatQty(_scale)}×',
                    key: ValueKey(_scale),
                    textAlign: TextAlign.center,
                    style: t.numeralM,
                  ),
                ),
              ),
              _MiniStep(icon: AppIcons.plus, onTap: () => _changeScale(0.5), enabled: _scale < 10),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Items
          Text('IN THIS MEAL', style: t.caption.copyWith(letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          for (final item in widget.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs + 1),
              child: Row(
                children: [
                  EmojiTile(item.emoji, size: 40),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text('${formatQty(item.qty * _scale)} × ${item.serving}',
                            style: t.label, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Text('${(item.total.kcal * _scale).round()}', style: t.numeralS),
                  const SizedBox(width: AppSpacing.xs),
                  Text('kcal', style: t.caption),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.lg),

          Text('LOG AS', style: t.caption.copyWith(letterSpacing: 0.8)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedPills<MealType>(
            compact: true,
            options: MealType.values,
            labelOf: (m) => m.label,
            selected: _meal,
            onChanged: (m) => setState(() => _meal = m),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(label: 'Log meal · ${total.kcal} kcal', onPressed: _log),
          const SizedBox(height: AppSpacing.sm),
          if (widget.saved != null)
            Row(
              children: [
                Expanded(
                  child: AppButton(label: 'Edit', icon: AppIcons.pencil, style: AppButtonStyle.outline, onPressed: _edit),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: AppButton(label: 'Delete', icon: AppIcons.trash, style: AppButtonStyle.danger, onPressed: _delete),
                ),
              ],
            )
          else
            AppButton(label: 'Save to my meals', icon: AppIcons.bookmark, style: AppButtonStyle.outline, onPressed: _saveCopy),
        ],
      ),
    );
  }
}

class _MiniStep extends StatelessWidget {
  const _MiniStep({required this.icon, required this.onTap, required this.enabled});
  final AppIconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.9,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.3,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
          child: AppIcon(icon, size: 17, color: p.textPrimary),
        ),
      ),
    );
  }
}
