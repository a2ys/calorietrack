import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Wraps any tappable surface with a press-scale. Feedback starts on
/// touch-down, not on release, and the release springs back with a small
/// overshoot. Haptics are opt-in: reserve them for meaningful moments
/// (selection, commit), not every tap. Pass [semanticLabel] for icon-only
/// targets so screen readers announce them as a labelled button.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressEnd,
    this.haptic = false,
    this.scale = AppMotion.pressScale,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Hold begins / ends (or is cancelled). Used for press-and-hold auto-repeat.
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;
  final bool haptic;
  final double scale;
  final String? semanticLabel;

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
    final enabled = widget.onTap != null ||
        widget.onLongPress != null ||
        widget.onLongPressStart != null;
    final onEnd = widget.onLongPressEnd;
    Widget result = GestureDetector(
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
      onLongPressStart:
          widget.onLongPressStart == null ? null : (_) => widget.onLongPressStart!(),
      onLongPressEnd: onEnd == null ? null : (_) => onEnd(),
      onLongPressCancel: onEnd,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        // Press in fast and firm, release with a spring.
        duration: _down ? AppMotion.press : AppMotion.springDuration,
        curve: _down ? AppMotion.easeOut : AppMotion.spring,
        child: widget.child,
      ),
    );
    if (widget.semanticLabel != null) {
      result = Semantics(
        button: true,
        enabled: enabled,
        label: widget.semanticLabel,
        child: result,
      );
    }
    return result;
  }
}
