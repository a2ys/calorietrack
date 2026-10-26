import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'press_scale.dart';
import 'app_icon.dart';

/// The round "+" on food rows. After something was added it shows how many
/// times, popping with a spring each time the count changes.
class AddCircle extends StatelessWidget {
  const AddCircle({super.key, required this.onTap, this.count = 0});

  final VoidCallback onTap;
  final int count;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final added = count > 0;

    return PressScale(
      scale: 0.88,
      onTap: onTap,
      child: SizedBox(
        // A generous hit area around a compact visual.
        width: 48,
        height: 48,
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: ValueKey(count),
            tween: Tween(begin: added ? 0.7 : 1, end: 1),
            duration: AppMotion.springDuration,
            curve: AppMotion.springBouncy,
            builder: (context, scale, child) =>
                Transform.scale(scale: scale, child: child),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              width: _size,
              height: _size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: added ? p.ink : p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: added
                  ? Text('$count', style: t.numeralS.copyWith(color: p.onInk, fontSize: 15))
                  : AppIcon(AppIcons.plus, size: 18, color: p.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}
