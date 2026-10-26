import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_button.dart';
import 'press_scale.dart';

/// A destructive confirmation. Show it with `showAppDialog`; it completes with
/// `true` when the user confirms.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;
    return Dialog(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      insetPadding: const EdgeInsets.all(AppSpacing.screen),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: t.heading),
            const SizedBox(height: AppSpacing.sm),
            Text(message, style: t.body.copyWith(color: p.textSecondary)),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Cancel',
              style: AppButtonStyle.outline,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: AppSpacing.sm),
            PressScale(
              onTap: () => Navigator.of(context).pop(true),
              child: Container(
                height: AppSizes.button,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.accent, borderRadius: AppRadii.chip),
                child: Text(confirmLabel, style: t.button.copyWith(color: p.onInk)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
