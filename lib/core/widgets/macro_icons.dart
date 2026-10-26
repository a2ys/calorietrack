import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'emoji.dart';

enum MacroKind { protein, carbs, fat }

extension MacroKindStyle on MacroKind {
  String get label => switch (this) {
        MacroKind.protein => 'Protein',
        MacroKind.carbs => 'Carbs',
        MacroKind.fat => 'Fat',
      };

  String get emoji => switch (this) {
        MacroKind.protein => AppEmoji.protein,
        MacroKind.carbs => AppEmoji.carbs,
        MacroKind.fat => AppEmoji.fat,
      };

  Color color(AppPalette p) => switch (this) {
        MacroKind.protein => p.protein,
        MacroKind.carbs => p.carbs,
        MacroKind.fat => p.fat,
      };
}
