import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// iOS-style wheel with a soft selection band and a haptic detent per item.
class WheelPicker extends StatefulWidget {
  const WheelPicker({
    super.key,
    required this.count,
    required this.labelOf,
    required this.initialIndex,
    required this.onSelected,
    this.suffix,
  });

  final int count;
  final String Function(int index) labelOf;
  final int initialIndex;
  final ValueChanged<int> onSelected;
  final String? suffix;

  @override
  State<WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<WheelPicker> {
  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(initialItem: widget.initialIndex);
  late int _current = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;

    return SizedBox(
      height: AppSizes.wheelHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: AppSizes.wheelItem,
            decoration: BoxDecoration(
              color: p.surfaceAlt,
              borderRadius: AppRadii.tile,
            ),
          ),
          ListWheelScrollView.useDelegate(
            controller: _controller,
            itemExtent: AppSizes.wheelItem,
            diameterRatio: 2.2,
            perspective: 0.003,
            physics: const FixedExtentScrollPhysics(),
            onSelectedItemChanged: (i) {
              if (i == _current) return;
              _current = i;
              Haptics.tap();
              widget.onSelected(i);
              setState(() {});
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.count,
              builder: (context, i) {
                final selected = i == _current;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: AppMotion.fast,
                    curve: AppMotion.easeOut,
                    style: selected
                        ? t.numeralM
                        : t.bodyStrong.copyWith(color: p.textTertiary),
                    child: Text(
                      widget.suffix == null
                          ? widget.labelOf(i)
                          : '${widget.labelOf(i)} ${widget.suffix}',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
