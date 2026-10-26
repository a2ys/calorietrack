import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/add_food/add_food_sheet.dart';
import '../db/database.dart';
import '../db/providers.dart';
import '../theme/app_theme.dart';
import '../utils/date_utils.dart';
import '../utils/haptics.dart';
import 'app_card.dart';
import 'emoji.dart';
import 'macro_icons.dart';
import 'app_icon.dart';

/// A logged food as a card. Tap or swipe right to edit, swipe left to delete
/// (with undo); the edit sheet also has a Delete button.
class EntryTile extends ConsumerWidget {
  const EntryTile({super.key, required this.entry});

  final FoodEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;

    Widget swipeBackground({required bool edit}) => Container(
          alignment: edit ? Alignment.centerLeft : Alignment.centerRight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          decoration: BoxDecoration(
            color: edit ? p.ink : p.accent,
            borderRadius: AppRadii.card,
          ),
          child: AppIcon(
            edit ? AppIcons.pencil : AppIcons.trash,
            color: p.onInk,
          ),
        );

    return Dismissible(
      key: ValueKey('entry-${entry.id}'),
      background: swipeBackground(edit: true),
      secondaryBackground: swipeBackground(edit: false),
      dismissThresholds: const {
        DismissDirection.startToEnd: AppGestures.actionThreshold,
        DismissDirection.endToStart: AppGestures.deleteThreshold,
      },
      onUpdate: (d) {
        if (d.reached && !d.previousReached) Haptics.light();
      },
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          showAddFoodSheet(context, editing: entry);
          return false;
        }
        return true;
      },
      onDismissed: (_) {
        final db = ref.read(databaseProvider);
        Haptics.medium();
        db.deleteEntry(entry.id);
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text('Deleted ${entry.name}'),
              action: SnackBarAction(
                label: 'Undo',
                textColor: p.onInk,
                onPressed: () => db.addEntry(entry.toCompanion(false)),
              ),
            ),
          );
      },
      child: AppCard(
        onTap: () => showAddFoodSheet(context, editing: entry),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            _Thumb(emoji: entry.emoji ?? entry.mealType.emoji),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.name,
                          style: t.bodyStrong,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _TimePill(label: timeLabel(entry.loggedAt)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      const Emoji(AppEmoji.calories, size: 14),
                      const SizedBox(width: AppSpacing.xxs),
                      Text('${entry.kcal} kcal', style: t.numeralS),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _Macro(kind: MacroKind.protein, grams: entry.protein),
                      const SizedBox(width: AppSpacing.md),
                      _Macro(kind: MacroKind.carbs, grams: entry.carbs),
                      const SizedBox(width: AppSpacing.md),
                      _Macro(kind: MacroKind.fat, grams: entry.fat),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.emoji});
  final String emoji;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: AppSizes.foodThumb,
      height: AppSizes.foodThumb,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: AppRadii.tile,
      ),
      child: Emoji(emoji, size: 32),
    );
  }
}

class _TimePill extends StatelessWidget {
  const _TimePill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm + 2,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: AppRadii.chip),
      child: Text(label, style: context.type.caption.copyWith(color: p.textSecondary)),
    );
  }
}

class _Macro extends StatelessWidget {
  const _Macro({required this.kind, required this.grams});
  final MacroKind kind;
  final double grams;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Emoji(kind.emoji, size: 13),
        const SizedBox(width: AppSpacing.xxs),
        Text('${grams.round()}g', style: context.type.label),
      ],
    );
  }
}
