import 'package:flutter/material.dart';

/// [AnimatedSize] for revealing a rounded control (pill, tile, button).
///
/// AnimatedSize clips to a plain rectangle, so while it grows the control
/// inside is sliced by a straight edge. This clips the animating box to
/// [borderRadius] instead, so the growing edge is always round and, once
/// settled, the clip sits on or outside the control's own corners.
class RoundedAnimatedSize extends StatelessWidget {
  const RoundedAnimatedSize({
    super.key,
    required this.duration,
    required this.curve,
    required this.alignment,
    required this.borderRadius,
    required this.child,
  });

  final Duration duration;
  final Curve curve;
  final AlignmentGeometry alignment;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: AnimatedSize(
          duration: duration,
          curve: curve,
          alignment: alignment,
          clipBehavior: Clip.none,
          child: child,
        ),
      );
}
