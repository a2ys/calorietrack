import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_icon.dart';
import 'press_scale.dart';

enum AppButtonStyle { primary, outline }

/// Full-width pill button: solid ink (black / white) or outlined.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final AppIconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final primary = style == AppButtonStyle.primary;
    final enabled = onPressed != null;
    final fg = primary ? p.onInk : p.textPrimary;

    return PressScale(
      onTap: onPressed,
      child: AnimatedOpacity(
        opacity: enabled ? 1 : 0.35,
        duration: AppMotion.fast,
        child: Container(
          height: AppSizes.button,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: primary ? p.ink : Colors.transparent,
            borderRadius: AppRadii.chip,
            border: primary ? null : Border.all(color: p.ink, width: 1.5),
          ),
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
    );
  }
}
