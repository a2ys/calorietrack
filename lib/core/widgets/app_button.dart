import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

enum AppButtonStyle { primary, outline, danger }

/// Full-width pill button: solid ink (black / white), outlined, or a
/// destructive outline (accent text and border, transparent fill).
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
    this.fill,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppIconData? icon;

  /// Fill for outline/danger buttons that float over scrolling content.
  final Color? fill;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final primary = style == AppButtonStyle.primary;
    final enabled = onPressed != null;
    final danger = style == AppButtonStyle.danger;
    final fg = primary ? p.onInk : (danger ? p.accent : p.textPrimary);

    return PressScale(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: AppMotion.fast,
        child: Container(
          height: AppSizes.button,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? p.ink : (fill ?? Colors.transparent),
            borderRadius: AppRadii.chip,
            border: primary ? null : Border.all(color: danger ? p.accent : p.ink, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          // Long labels ("Done · 1,250 kcal" in a half-width button) shrink
          // a little instead of overflowing.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  AppIcon(icon!, color: fg, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Text(label, style: t.button.copyWith(color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
