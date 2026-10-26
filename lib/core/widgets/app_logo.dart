import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The CalTracker mark: three nested progress arcs, all starting at 12 o'clock.
/// Mirrors the launcher icon (see android/app/src/main/res/mipmap-*).
/// [progress] 0..1 draws the arcs in one after another.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, required this.size, required this.color, this.progress = 1});

  final double size;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(color: color, progress: progress),
      );
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  static const List<double> _sweeps = [300, 225, 150];
  static const double _outerRadius = 0.33;
  static const double _stroke = 0.07;
  static const double _gap = 0.03;
  static const double _stagger = 0.2;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _stroke * s;
    final centre = Offset(s / 2, s / 2);
    for (var k = 0; k < _sweeps.length; k++) {
      final t = ((progress - k * _stagger) / (1 - _stagger * (_sweeps.length - 1))).clamp(0.0, 1.0);
      if (t == 0) continue;
      final radius = (_outerRadius - k * (_stroke + _gap) - _stroke / 2) * s;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        _sweeps[k] * math.pi / 180 * AppMotion.easeOut.transform(t),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_LogoPainter old) => old.color != color || old.progress != progress;
}
