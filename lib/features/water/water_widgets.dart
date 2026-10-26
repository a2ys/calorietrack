import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/utils/water.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/press_scale.dart';

/// Slim rounded progress bar in the water colour. Springs to its value.
class WaterBar extends StatelessWidget {
  const WaterBar({super.key, required this.progress, this.height = 10});

  final double progress;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ClipRRect(
      borderRadius: AppRadii.chip,
      child: Container(
        height: height,
        color: p.track,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 700),
          curve: AppMotion.springSoft,
          // heightFactor matters: the Container's alignment hands its child
          // loose constraints, and a childless DecoratedBox would collapse to
          // zero height (the bar used to never visibly fill).
          builder: (context, v, _) => FractionallySizedBox(
            widthFactor: v.clamp(0.0, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(color: p.water, borderRadius: AppRadii.chip),
            ),
          ),
        ),
      ),
    );
  }
}

/// "− 3 L +" control for the daily goal (250 ml steps).
class WaterGoalStepper extends StatelessWidget {
  const WaterGoalStepper({super.key, required this.goalMl, required this.onChanged});

  final int goalMl;
  final ValueChanged<int> onChanged;

  void _step(int delta) {
    final next = (goalMl + delta).clamp(WaterLimits.minGoal, WaterLimits.maxGoal);
    if (next == goalMl) return;
    Haptics.tap();
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundButton(
          icon: AppIcons.minus,
          enabled: goalMl > WaterLimits.minGoal,
          onTap: () => _step(-WaterLimits.goalStep),
        ),
        SizedBox(
          width: 76,
          child: AnimatedSwitcher(
            duration: AppMotion.fast,
            transitionBuilder: (c, a) => FadeTransition(
              opacity: a,
              child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(a), child: c),
            ),
            child: Text(
              formatWater(goalMl),
              key: ValueKey(goalMl),
              textAlign: TextAlign.center,
              style: t.numeralS,
            ),
          ),
        ),
        _RoundButton(
          icon: AppIcons.plus,
          enabled: goalMl < WaterLimits.maxGoal,
          onTap: () => _step(WaterLimits.goalStep),
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, required this.enabled});

  final AppIconData icon;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PressScale(
      scale: 0.88,
      onTap: enabled ? onTap : null,
      child: AnimatedOpacity(
        duration: AppMotion.fast,
        opacity: enabled ? 1 : 0.3,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(color: p.surfaceAlt, shape: BoxShape.circle),
          child: Center(child: AppIcon(icon, size: 14, color: p.textPrimary)),
        ),
      ),
    );
  }
}
