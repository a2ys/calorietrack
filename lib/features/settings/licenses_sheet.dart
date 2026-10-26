import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/press_scale.dart';
import '../../core/widgets/sheet_scaffold.dart';

/// Third-party work the app is built on. Shown from Settings.
Future<void> showLicensesSheet(BuildContext context) => showAppSheet<void>(
      context,
      initialSize: 0.75,
      builder: (_) => const _LicensesSheet(),
    );

/// (name, what it's used for, licence, author)
const List<(String, String, String, String)> kCredits = [
  ('Twemoji', 'Food and emoji art', 'CC-BY 4.0', 'Twitter, Inc. and contributors'),
  ('Phosphor Icons', 'Interface icons', 'MIT', 'Phosphor Icons'),
  ('Plus Jakarta Sans', 'Typeface', 'SIL Open Font License 1.1', 'Tokotype'),
  ('Interface Sounds', 'Sound effects', 'CC0 1.0 (public domain)', 'Kenney (kenney.nl)'),
  ('FoodData Central', 'Nutrition data', 'Public domain (CC0)', 'U.S. Department of Agriculture'),
  ('Open Food Facts', 'Barcode product data', 'Open Database License (ODbL)', 'Open Food Facts contributors'),
];

class _LicensesSheet extends StatelessWidget {
  const _LicensesSheet();

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final p = context.palette;

    return SheetScaffold(
      title: 'Open-source licenses',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('This app is built on the generous work of others.', style: t.label),
          const SizedBox(height: AppSpacing.lg),
          Container(
            decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: AppRadii.tile),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < kCredits.length; i++) ...[
                  if (i > 0) Divider(height: 1, indent: AppSpacing.lg, color: p.border),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(kCredits[i].$1, style: t.bodyStrong),
                        Text('${kCredits[i].$2} · ${kCredits[i].$4}', style: t.label),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(kCredits[i].$3, style: t.caption.copyWith(color: p.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PressScale(
            onTap: () {
              Haptics.light();
              showLicensePage(context: context, applicationName: 'Calorie');
            },
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(color: p.surfaceAlt, borderRadius: AppRadii.tile),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Software packages', style: t.bodyStrong),
                        Text('Flutter and every library the app uses', style: t.label),
                      ],
                    ),
                  ),
                  AppIcon(AppIcons.caretRight, size: 16, color: p.textTertiary),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
