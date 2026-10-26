import 'package:flutter/material.dart';

import '../../core/db/database.dart';
import '../../core/db/models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/count_up_text.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/macro_icons.dart';
import '../../core/widgets/progress_ring.dart';

/// Hero card: big "calories left" (or eaten) number with the main ring.
class CalorieHero extends StatelessWidget {
  const CalorieHero({
    super.key,
    required this.profile,
    required this.eaten,
    this.view = CalorieView.left,
  });

  final UserProfile profile;
  final Totals eaten;
  final CalorieView view;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final target = profile.calorieTarget;
    final left = target - eaten.kcal;
    final over = left < 0;
    final progress = target == 0 ? 0.0 : eaten.kcal / target;
    final showEaten = view == CalorieView.eaten;

    final big = showEaten ? eaten.kcal : left.abs();
    final label = showEaten ? 'Calories eaten' : (over ? 'Calories over' : 'Calories left');
    final sub = showEaten
        ? (over ? '${left.abs()} over $target goal' : '$left left of $target')
        : '${eaten.kcal} of $target eaten';

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountUpText(
                  value: big,
                  style: t.numeralXL.copyWith(
                    color: over ? p.accent : p.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(label, style: t.label),
                const SizedBox(height: AppSpacing.xxs),
                Text(sub, style: t.caption),
              ],
            ),
          ),
          ProgressRing(
            progress: progress,
            size: AppSizes.heroRing,
            strokeWidth: AppSizes.heroRingStroke,
            color: over ? p.accent : p.ink,
            child: Container(
              width: AppSizes.iconTile + AppSpacing.md,
              height: AppSizes.iconTile + AppSpacing.md,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
              child: const Emoji(AppEmoji.calories, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

/// Three small rings: protein / carbs / fat.
class MacroRow extends StatelessWidget {
  const MacroRow({super.key, required this.profile, required this.eaten});

  final UserProfile profile;
  final Totals eaten;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MacroTile(
            kind: MacroKind.protein,
            eaten: eaten.protein,
            target: profile.proteinTarget,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MacroTile(
            kind: MacroKind.carbs,
            eaten: eaten.carbs,
            target: profile.carbsTarget,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _MacroTile(
            kind: MacroKind.fat,
            eaten: eaten.fat,
            target: profile.fatTarget,
          ),
        ),
      ],
    );
  }
}

class _MacroTile extends StatelessWidget {
  const _MacroTile({
    required this.kind,
    required this.eaten,
    required this.target,
  });

  final MacroKind kind;
  final double eaten;
  final int target;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final left = target - eaten;
    final over = left < 0;
    final color = over ? p.accent : kind.color(p);

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      radius: BorderRadius.circular(AppRadii.lg - AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountUpText(
            value: left.abs().round(),
            suffix: 'g',
            style: t.numeralM,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '${kind.label} ${over ? 'over' : 'left'}',
            style: t.caption.copyWith(color: p.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: ProgressRing(
              progress: target == 0 ? 0 : eaten / target,
              size: AppSizes.macroRing,
              strokeWidth: AppSizes.macroRingStroke,
              color: color,
              child: Emoji(kind.emoji, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}
