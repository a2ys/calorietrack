import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/water.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/emoji.dart';
import '../../core/widgets/press_scale.dart';
import 'water_actions.dart';
import 'water_sheet.dart';
import 'water_widgets.dart';

/// Compact water tracker on Today: amount vs goal, a progress bar, and a
/// one-tap "+ glass" button. Tapping the card opens the full water sheet.
class WaterCard extends ConsumerWidget {
  const WaterCard({super.key, required this.day});

  final DateTime day;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    final p = context.palette;
    final prefs = readPrefs(ref);
    final logs = ref.watch(waterForDayProvider(day)).value ?? const [];
    final total = logs.fold<int>(0, (s, l) => s + l.amountMl);
    final goal = prefs.waterGoalMl;
    final done = total >= goal;

    return AppCard(
      onTap: () => showWaterSheet(context, day: day),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              const EmojiTile(AppEmoji.water, size: 44, radius: 14),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Water', style: t.bodyStrong),
                    const SizedBox(height: 1),
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      child: Text(
                        done
                            ? 'Goal reached · ${formatWater(total)}'
                            : '${formatLiters(total)} of ${formatWater(goal)}',
                        key: ValueKey('$total-$goal'),
                        style: t.label.copyWith(color: done ? p.water : p.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              _QuickAdd(
                label: '+${formatWater(prefs.waterGlassMl)}',
                onTap: () => logWater(context, ref, day, prefs.waterGlassMl),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          WaterBar(progress: goal == 0 ? 0 : total / goal),
        ],
      ),
    );
  }
}

class _QuickAdd extends StatelessWidget {
  const _QuickAdd({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return PressScale(
      scale: 0.92,
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.water.withValues(alpha: 0.14),
          borderRadius: AppRadii.chip,
        ),
        child: Text(
          label,
          style: t.label.copyWith(color: p.water, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}
