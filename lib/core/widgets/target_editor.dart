import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/calorie_calculator.dart';
import '../utils/haptics.dart';
import 'app_card.dart';
import 'count_up_text.dart';
import 'emoji.dart';
import 'macro_icons.dart';
import 'press_scale.dart';
import 'app_icon.dart';

/// Edit a daily calorie target and its macro split with +/- steppers.
/// Changing calories rescales macros; macros can then be nudged individually.
class TargetEditor extends StatelessWidget {
  const TargetEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.goal,
    required this.weightKg,
  });

  final MacroTargets value;
  final ValueChanged<MacroTargets> onChanged;
  final Goal goal;
  final double weightKg;

  static const int calorieStep = 50;
  static const int macroStep = 5;
  static const int minCalories = 800;
  static const int maxCalories = 6000;

  void _setCalories(int kcal) {
    final next = kcal.clamp(minCalories, maxCalories);
    if (next == value.calories) return;
    onChanged(CalorieCalculator.macrosFor(
      calories: next,
      goal: goal,
      weightKg: weightKg,
    ));
  }

  void _setMacro({int? protein, int? carbs, int? fat}) {
    onChanged(MacroTargets(
      calories: value.calories,
      proteinG: (protein ?? value.proteinG).clamp(0, 999),
      carbsG: (carbs ?? value.carbsG).clamp(0, 999),
      fatG: (fat ?? value.fatG).clamp(0, 999),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final macroKcal = CalorieCalculator.caloriesFromMacros(
      proteinG: value.proteinG,
      carbsG: value.carbsG,
      fatG: value.fatG,
    );

    return Column(
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Row(
            children: [
              _StepButton(
                icon: AppIcons.minus,
                onTap: () => _setCalories(value.calories - calorieStep),
              ),
              Expanded(
                child: Column(
                  children: [
                    CountUpText(value: value.calories, style: t.numeralXL),
                    const SizedBox(height: AppSpacing.xs),
                    Text('calories per day', style: t.label),
                  ],
                ),
              ),
              _StepButton(
                icon: AppIcons.plus,
                onTap: () => _setCalories(value.calories + calorieStep),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _MacroStepper(
          kind: MacroKind.protein,
          grams: value.proteinG,
          onChanged: (g) => _setMacro(protein: g),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MacroStepper(
          kind: MacroKind.carbs,
          grams: value.carbsG,
          onChanged: (g) => _setMacro(carbs: g),
        ),
        const SizedBox(height: AppSpacing.sm),
        _MacroStepper(
          kind: MacroKind.fat,
          grams: value.fatG,
          onChanged: (g) => _setMacro(fat: g),
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Macros add up to $macroKcal kcal', style: t.caption),
      ],
    );
  }
}

class _MacroStepper extends StatelessWidget {
  const _MacroStepper({
    required this.kind,
    required this.grams,
    required this.onChanged,
  });

  final MacroKind kind;
  final int grams;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return AppCard(
      shadow: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      radius: AppRadii.tile,
      child: Row(
        children: [
          EmojiTile(kind.emoji, size: AppSizes.iconTileSm + 4),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Text(kind.label, style: t.bodyStrong)),
          _StepButton(
            small: true,
            icon: AppIcons.minus,
            onTap: () => onChanged(grams - TargetEditor.macroStep),
          ),
          SizedBox(
            width: AppSizes.button + AppSpacing.sm,
            child: Text('${grams}g', textAlign: TextAlign.center, style: t.numeralS),
          ),
          _StepButton(
            small: true,
            icon: AppIcons.plus,
            onTap: () => onChanged(grams + TargetEditor.macroStep),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, this.small = false});

  final AppIconData icon;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = small ? AppSizes.iconTileSm : AppSizes.iconTile + AppSpacing.sm;
    return PressScale(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          shape: BoxShape.circle,
        ),
        child: AppIcon(icon, size: small ? 18 : 22, color: p.textPrimary),
      ),
    );
  }
}
