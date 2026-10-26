import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Circular progress ring that animates its sweep whenever [progress] changes.
/// [progress] is 0..1 (values above 1 are clamped; callers show "over" via colour).
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    required this.size,
    required this.strokeWidth,
    required this.color,
    this.trackColor,
    this.child,
    this.duration = AppMotion.ring,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Widget? child;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final track = trackColor ?? context.palette.track;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration,
      curve: AppMotion.easeOut,
      builder: (context, value, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            progress: value,
            color: color,
            track: track,
            stroke: strokeWidth,
          ),
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
    required this.stroke,
  });

  final double progress;
  final Color color;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arc, 0, math.pi * 2, false, base..color = track);
    if (progress > 0.001) {
      canvas.drawArc(
        arc,
        -math.pi / 2,
        math.pi * 2 * progress,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
