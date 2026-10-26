import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'press_scale.dart';

/// Rounded white (or charcoal) surface with a hairline border and soft shadow.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.onTap,
    this.radius,
    this.shadow = true,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final BorderRadius? radius;
  final bool shadow;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? p.surface,
        borderRadius: radius ?? AppRadii.card,
        border: Border.all(color: p.border, width: AppSizes.border),
        boxShadow: shadow ? p.shadows : null,
      ),
      child: child,
    );
    return onTap == null ? card : PressScale(onTap: onTap, child: card);
  }
}
