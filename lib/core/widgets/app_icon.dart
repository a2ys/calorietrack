import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';

/// A UI icon: a Phosphor SVG (MIT, https://phosphoricons.com) in one weight.
/// Bold for controls, Regular + Fill for the tab bar (outline idle, solid active).
@immutable
class AppIconData {
  const AppIconData(this.asset);

  /// File name (without extension) in assets/icons.
  final String asset;
}

abstract final class AppIcons {
  // Controls (bold)
  static const plus = AppIconData('bold-plus');
  static const minus = AppIconData('bold-minus');
  static const trash = AppIconData('bold-trash');
  static const pencil = AppIconData('bold-pencil-simple');
  static const caretRight = AppIconData('bold-caret-right');
  static const caretLeft = AppIconData('bold-caret-left');
  static const caretDown = AppIconData('bold-caret-down');
  static const close = AppIconData('bold-x');
  static const search = AppIconData('bold-magnifying-glass');
  static const check = AppIconData('bold-check');
  static const bookmark = AppIconData('bold-bookmark-simple');
  static const clearFill = AppIconData('fill-x-circle');
  static const barcode = AppIconData('bold-barcode');
  static const lightning = AppIconData('bold-lightning');
  static const lightningFill = AppIconData('fill-lightning');

  // Tabs: solid in both states; colour marks the active one.
  static const houseFill = AppIconData('fill-house');
  static const forkKnifeFill = AppIconData('fill-fork-knife');
  static const chartBarFill = AppIconData('fill-chart-bar');
  static const gearFill = AppIconData('fill-gear-six');
}

class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.size = 20, this.color});

  final AppIconData icon;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? IconTheme.of(context).color ?? context.palette.textPrimary;
    // Center(+factors) loosens tight parent constraints, so the icon keeps its
    // own size inside fixed-size circles instead of stretching to fill them.
    return Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SvgPicture.asset(
        'assets/icons/${icon.asset}.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(tint, BlendMode.srcIn),
        excludeFromSemantics: true,
      ),
    );
  }
}
