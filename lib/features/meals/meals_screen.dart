import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/data/preset_meals.dart';
import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/db/providers.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/add_circle.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/staggered_entrance.dart';
import 'meal_detail_sheet.dart';
import '../../core/widgets/app_icon.dart';

class MealsScreen extends ConsumerWidget {
  const MealsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = context.palette;
    final saved = ref.watch(savedMealsProvider).value ?? const <SavedMeal>[];
    final catalog = catalogOf(ref);
    final day = ref.watch(selectedDayProvider);

    Future<void> openDetail(String name, String emoji, List<MealItem> items,
        {SavedMeal? meal}) {
      return showMealDetailSheet(
        context,
        name: name,
        emoji: emoji,
        items: items,
        saved: meal,
        day: day,
      );
    }

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.lg,
          AppSpacing.screen,
          AppSpacing.huge * 2,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Meals', style: t.title),
                    const SizedBox(height: AppSpacing.xxs),
                    Text('Build it once. Log it in one tap.', style: t.label),
                  ],
                ),
              ),
              // The empty state carries its own "Create a meal" CTA, so this
              // shortcut only appears once there is a list to add to.
              if (saved.isNotEmpty)
                PopIn(
                  child: PressScale(
                    scale: 0.92,
                    onTap: () {
                      Haptics.light();
                      context.push(Routes.mealBuilder);
                    },
                    child: Container(
                      height: AppSizes.iconTile + 4,
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                      decoration: BoxDecoration(color: p.ink, borderRadius: AppRadii.chip),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(AppIcons.plus, size: 16, color: p.onInk),
                          const SizedBox(width: AppSpacing.xs + 2),
                          Text('New meal', style: t.button.copyWith(fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          if (saved.isEmpty) ...[
            StaggeredEntrance(
              index: 0,
              child: _EmptyBuilder(onCreate: () => context.push(Routes.mealBuilder)),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ] else ...[
            const _SectionTitle('My meals'),
            for (var i = 0; i < saved.length; i++)
              Padding(
                key: ValueKey('saved-${saved[i].id}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: StaggeredEntrance(
                  index: i,
                  child: _MealCard(
                    emoji: saved[i].emoji,
                    name: saved[i].name,
                    items: saved[i].items,
                    onOpen: () => openDetail(saved[i].name, saved[i].emoji, saved[i].items, meal: saved[i]),
                    onLog: () => _quickLog(context, ref, day, saved[i].name, saved[i].emoji, saved[i].items),
                  ),
                ),
              ),
            // Cards end with md of padding: md + xl = xxxl, the same gap as
            // after the empty state.
            const SizedBox(height: AppSpacing.xl),
          ],
          const _SectionTitle('Quick meals', hint: 'Common plates, ready to log'),
          for (var i = 0; i < kPresetMeals.length; i++)
            if (kPresetMeals[i].items(catalog).isNotEmpty)
              Padding(
                key: ValueKey('preset-${kPresetMeals[i].name}'),
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _MealCard(
                  emoji: kPresetMeals[i].emoji,
                  name: kPresetMeals[i].name,
                  items: kPresetMeals[i].items(catalog),
                  onOpen: () => openDetail(
                    kPresetMeals[i].name,
                    kPresetMeals[i].emoji,
                    kPresetMeals[i].items(catalog),
                  ),
                  onLog: () => _quickLog(
                    context,
                    ref,
                    day,
                    kPresetMeals[i].name,
                    kPresetMeals[i].emoji,
                    kPresetMeals[i].items(catalog),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  /// Logs a whole meal as one entry for [day], with an undo.
  Future<void> _quickLog(
    BuildContext context,
    WidgetRef ref,
    DateTime day,
    String name,
    String emoji,
    List<MealItem> items,
  ) async {
    final db = ref.read(databaseProvider);
    final p = context.palette;
    final total = sumMealItems(items);
    final now = DateTime.now();
    final meal = MealType.forTime(now);
    final id = await db.addEntry(FoodEntriesCompanion.insert(
      name: name,
      kcal: total.kcal,
      protein: Value(total.protein),
      carbs: Value(total.carbs),
      fat: Value(total.fat),
      mealType: meal,
      loggedAt: DateTime(day.year, day.month, day.day, now.hour, now.minute),
      emoji: Value(emoji),
    ));
    Haptics.success();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        clipBehavior: Clip.none, // see snackBarTheme
        content: Text('Added $name to ${meal.label.toLowerCase()} · ${dayLabel(day).toLowerCase()}'),
        action: SnackBarAction(
          label: 'Undo',
          textColor: p.onInk,
          onPressed: () => db.deleteEntry(id),
        ),
      ));
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.hint});
  final String text;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: t.heading),
          if (hint != null) Text(hint!, style: t.label),
        ],
      ),
    );
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({
    required this.emoji,
    required this.name,
    required this.items,
    required this.onOpen,
    required this.onLog,
  });

  final String emoji;
  final String name;
  final List<MealItem> items;
  final VoidCallback onOpen;
  final VoidCallback onLog;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final total = sumMealItems(items);

    return AppCard(
      onTap: onOpen,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          EmojiTile(emoji, size: 60, radius: 18),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.bodyStrong, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                  items.map((i) => i.name).join(' · '),
                  style: t.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    const Emoji(AppEmoji.calories, size: 13),
                    const SizedBox(width: 2),
                    Text('${total.kcal}', style: t.numeralS.copyWith(fontSize: 15)),
                    const SizedBox(width: AppSpacing.md),
                    for (final (kind, grams) in [
                      (MacroKind.protein, total.protein),
                      (MacroKind.carbs, total.carbs),
                      (MacroKind.fat, total.fat),
                    ]) ...[
                      Emoji(kind.emoji, size: 12),
                      const SizedBox(width: 2),
                      Text('${grams.round()}g', style: t.caption.copyWith(color: context.palette.textSecondary)),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                  ],
                ),
              ],
            ),
          ),
          AddCircle(onTap: onLog),
        ],
      ),
    );
  }
}

class _EmptyBuilder extends StatelessWidget {
  const _EmptyBuilder({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        children: [
          const PopIn(child: Emoji('🍱', size: 52)),
          const SizedBox(height: AppSpacing.md),
          Text('Make your first meal', style: t.heading),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Dal + rice + salad, your usual breakfast, a post-workout shake. '
            'Save it once and log the whole thing in one tap.',
            style: t.label.copyWith(color: p.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(label: 'Create a meal', icon: AppIcons.plus, onPressed: onCreate),
        ],
      ),
    );
  }
}
