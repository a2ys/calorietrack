import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Segmented control with a sliding ink indicator.
class SegmentedPills<T> extends StatelessWidget {
  const SegmentedPills({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final List<T> options;
  final String Function(T) labelOf;
  final T selected;
  final ValueChanged<T> onChanged;
  final bool compact;

  static const double _height = 48;
  static const double _heightCompact = 40;
  static const double _inset = 4;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final height = compact ? _heightCompact : _height;
    final index = options.indexOf(selected).clamp(0, options.length - 1);

    return LayoutBuilder(builder: (context, constraints) {
      final slot = (constraints.maxWidth - _inset * 2) / options.length;
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: p.surfaceAlt,
          borderRadius: AppRadii.chip,
        ),
        child: Stack(
          children: [
            AnimatedPositioned(
              duration: AppMotion.normal,
              curve: AppMotion.easeOut,
              left: _inset + slot * index,
              top: _inset,
              bottom: _inset,
              width: slot,
              child: Container(
                decoration: BoxDecoration(
                  color: p.ink,
                  borderRadius: AppRadii.chip,
                ),
              ),
            ),
            Row(
              children: [
                const SizedBox(width: _inset),
                for (final option in options)
                  SizedBox(
                    width: slot,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        if (option == selected) return;
                        Haptics.tap();
                        onChanged(option);
                      },
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: AppMotion.fast,
                          curve: AppMotion.easeOut,
                          style: t.label.copyWith(
                            color: option == selected ? p.onInk : p.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                          child: Text(labelOf(option), maxLines: 1),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      );
    });
  }
}
