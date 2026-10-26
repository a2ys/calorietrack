import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';
import 'emoji.dart';
import 'press_scale.dart';
import 'app_icon.dart';

/// Large selectable card: leading emoji, title, optional hint, check circle.
class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.hint,
    this.emoji,
  });

  final String title;
  final String? hint;
  final String? emoji;
  final bool selected;
  final VoidCallback onTap;

  static const double _selectedBorder = 2;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;

    return PressScale(
      onTap: () {
        if (!selected) Haptics.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: AppRadii.card,
          border: Border.all(
            color: selected ? p.ink : p.border,
            width: selected ? _selectedBorder : AppSizes.border,
          ),
          boxShadow: selected ? p.shadows : null,
        ),
        child: Row(
          children: [
            if (emoji != null) ...[
              // The emoji hops up a little when its card is picked.
              AnimatedScale(
                scale: selected ? 1.12 : 1,
                duration: AppMotion.springDuration,
                curve: AppMotion.springBouncy,
                child: EmojiTile(emoji!, radius: AppRadii.sm),
              ),
              const SizedBox(width: AppSpacing.lg),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyStrong),
                  if (hint != null) Text(hint!, style: t.label),
                ],
              ),
            ),
            AnimatedContainer(
              duration: AppMotion.normal,
              curve: AppMotion.easeOut,
              width: AppSizes.iconTileSm - AppSpacing.sm,
              height: AppSizes.iconTileSm - AppSpacing.sm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? p.ink : Colors.transparent,
                border: Border.all(
                  color: selected ? p.ink : p.track,
                  width: _selectedBorder,
                ),
              ),
              child: AnimatedOpacity(
                duration: AppMotion.fast,
                opacity: selected ? 1 : 0,
                child: AppIcon(AppIcons.check, size: 15, color: p.onInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
