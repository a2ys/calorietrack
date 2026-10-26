import 'dart:async';

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
  static const int minMacro = 0;
  static const int maxMacro = 999;

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
      proteinG: (protein ?? value.proteinG).clamp(minMacro, maxMacro),
      carbsG: (carbs ?? value.carbsG).clamp(minMacro, maxMacro),
      fatG: (fat ?? value.fatG).clamp(minMacro, maxMacro),
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
                enabled: value.calories > minCalories,
                label: 'Decrease calories',
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
                enabled: value.calories < maxCalories,
                label: 'Increase calories',
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
            enabled: grams > TargetEditor.minMacro,
            label: 'Decrease ${kind.label}',
            onTap: () => onChanged(grams - TargetEditor.macroStep),
          ),
          SizedBox(
            width: AppSizes.button + AppSpacing.sm,
            child: Text('${grams}g', textAlign: TextAlign.center, style: t.numeralS),
          ),
          _StepButton(
            small: true,
            icon: AppIcons.plus,
            enabled: grams < TargetEditor.maxMacro,
            label: 'Increase ${kind.label}',
            onTap: () => onChanged(grams + TargetEditor.macroStep),
          ),
        ],
      ),
    );
  }
}

/// Round +/- button. Press and hold repeats the step; dims and stops at a clamp.
class _StepButton extends StatefulWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.label,
    this.small = false,
  });

  final AppIconData icon;
  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final bool small;

  @override
  State<_StepButton> createState() => _StepButtonState();
}

class _StepButtonState extends State<_StepButton> {
  static const _repeatEvery = Duration(milliseconds: 90);

  Timer? _repeat;

  void _step() {
    Haptics.tap();
    widget.onTap();
  }

  void _startRepeat() {
    _step();
    _repeat?.cancel();
    _repeat = Timer.periodic(_repeatEvery, (_) => _step());
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void didUpdateWidget(_StepButton old) {
    super.didUpdateWidget(old);
    // Hit a clamp mid-hold: stop instead of ticking on a dead button.
    if (!widget.enabled) _stopRepeat();
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final size = widget.small ? AppSizes.iconTileSm : AppSizes.iconTile + AppSpacing.sm;
    // Visual circle stays compact; the hit box is at least AppSizes.iconTile.
    final hit = size < AppSizes.iconTile ? AppSizes.iconTile : size;
    return PressScale(
      semanticLabel: widget.label,
      onTap: widget.enabled ? _step : null,
      onLongPressStart: widget.enabled ? _startRepeat : null,
      onLongPressEnd: _stopRepeat,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: widget.enabled ? 1 : 0.3,
        child: SizedBox(
          width: hit,
          height: hit,
          child: Center(
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: AppIcon(widget.icon, size: widget.small ? 18 : 22, color: p.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
