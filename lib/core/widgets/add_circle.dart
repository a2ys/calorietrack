import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'press_scale.dart';
import 'app_icon.dart';
import 'rounded_animated_size.dart';

/// The round "+" on food rows. Once something was added it grows into a
/// "− 2 +" stepper (when [onRemove] is given) so a mis-tap can be taken back
/// right where it happened; otherwise it just shows the count.
class AddCircle extends StatelessWidget {
  const AddCircle({super.key, required this.onTap, this.onRemove, this.count = 0});

  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final int count;

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    final stepper = count > 0 && onRemove != null;

    return RoundedAnimatedSize(
      duration: AppMotion.slow,
      curve: AppMotion.springSoft,
      alignment: Alignment.centerRight,
      borderRadius: AppRadii.chip,
      child: AnimatedSwitcher(
        duration: AppMotion.fast,
        switchInCurve: AppMotion.easeOut,
        transitionBuilder: (child, a) => FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1).animate(a), child: child),
        ),
        layoutBuilder: (current, previous) => Stack(
          alignment: Alignment.centerRight,
          children: [...previous, ?current],
        ),
        child: stepper
            ? _Stepper(key: const ValueKey('stepper'), count: count, onAdd: onTap, onRemove: onRemove!)
            : _Circle(key: const ValueKey('circle'), count: count, onTap: onTap),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

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
          child: _Pop(
            count: count,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.easeOut,
              width: AddCircle._size,
              height: AddCircle._size,
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

/// Black pill: − count +. Each side keeps a 44px-tall hit area.
class _Stepper extends StatelessWidget {
  const _Stepper({super.key, required this.count, required this.onAdd, required this.onRemove});

  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;

    Widget side(AppIconData icon, VoidCallback onTap) => PressScale(
          scale: 0.84,
          onTap: () {
            Haptics.tap();
            onTap();
          },
          child: SizedBox(
            width: 36,
            height: 44,
            child: Center(child: AppIcon(icon, size: 14, color: p.onInk)),
          ),
        );

    // Same 6px inset as the round button's visual inside its 48px hit box,
    // so the right edge of the row's control column doesn't jump.
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: SizedBox(
      height: 48,
      child: Center(
        child: Container(
          height: AddCircle._size,
          decoration: BoxDecoration(color: p.ink, borderRadius: AppRadii.chip),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              side(count == 1 ? AppIcons.trash : AppIcons.minus, onRemove),
              SizedBox(
                width: 20,
                child: _Pop(
                  count: count,
                  child: Text(
                    '$count',
                    textAlign: TextAlign.center,
                    style: t.numeralS.copyWith(color: p.onInk, fontSize: 15),
                  ),
                ),
              ),
              side(AppIcons.plus, onAdd),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

/// Springs its child in each time [count] changes.
class _Pop extends StatelessWidget {
  const _Pop({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        key: ValueKey(count),
        tween: Tween(begin: count > 0 ? 0.7 : 1, end: 1),
        duration: AppMotion.springDuration,
        curve: AppMotion.springBouncy,
        builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
        child: child,
      );
}
