import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Wraps any tappable surface with a press-scale. Feedback starts on
/// touch-down, not on release, and the release springs back with a small
/// overshoot. Haptics are opt-in: reserve them for meaningful moments
/// (selection, commit), not every tap.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = false,
    this.scale = AppMotion.pressScale,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool haptic;
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: enabled ? () => _set(false) : null,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) Haptics.tap();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        // Press in fast and firm, release with a spring.
        duration: _down ? AppMotion.press : AppMotion.springDuration,
        curve: _down ? AppMotion.easeOut : AppMotion.spring,
        child: widget.child,
      ),
    );
  }
}
