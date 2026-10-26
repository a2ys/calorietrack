import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/press_scale.dart';

/// Seven bars for one week with a dashed goal line (calories by default,
/// water via [color] / [goalLabel] / [formatValue]).
/// Tap a bar to select that day; future days are inert.
class WeekBarChart extends StatelessWidget {
  const WeekBarChart({
    super.key,
    required this.weekStart,
    required this.values,
    required this.target,
    required this.selected,
    required this.onSelect,
    required this.goalLabel,
    required this.formatValue,
    this.color,
    this.overIsBad = true,
    this.height = AppSizes.barChartHeight,
  });

  final DateTime weekStart;

  /// Value per day (kcal or ml); days without data are absent.
  final Map<DateTime, int> values;
  final int target;
  final DateTime selected;
  final ValueChanged<DateTime> onSelect;
  final String goalLabel;
  final String Function(int value) formatValue;

  /// Fill of the selected bar; defaults to the ink colour.
  final Color? color;

  /// Calories turn red above the goal; for water, going over is fine.
  final bool overIsBad;
  final double height;

  static const double _labelAreaHeight = 44;
  static const double _valueLabelGap = 6;
  static const double _headroom = 1.18;
  static const double _minBar = 6;
  static const double _goalLabelHeight = 22;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final today = dateOnly(DateTime.now());

    final days = [for (var i = 0; i < 7; i++) addDays(weekStart, i)];
    final peak = days.fold<int>(0, (m, d) => (values[d] ?? 0) > m ? values[d]! : m);
    final maxY = (target > peak ? target : peak) * _headroom;

    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, constraints) {
        final barsHeight = constraints.maxHeight - _labelAreaHeight;
        final goalY = barsHeight * (1 - target / maxY);

        return Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: barsHeight,
              child: CustomPaint(
                painter: _GoalLinePainter(y: goalY, color: p.textTertiary),
              ),
            ),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: _Bar(
                      day: days[i],
                      index: i,
                      value: values[days[i]] ?? 0,
                      label: formatValue(values[days[i]] ?? 0),
                      color: color,
                      barsHeight: barsHeight,
                      fraction: (values[days[i]] ?? 0) / maxY,
                      selected: isSameDay(days[i], selected),
                      over: overIsBad && (values[days[i]] ?? 0) > target,
                      future: days[i].isAfter(today),
                      onTap: () {
                        Haptics.tap();
                        onSelect(days[i]);
                      },
                    ),
                  ),
              ],
            ),
            // Painted after the bars so a tall bar never hides it.
            Positioned(
              left: 0,
              top: math.max(0, goalY - _goalLabelHeight),
              child: IgnorePointer(
                child: Text(goalLabel, style: t.caption.copyWith(color: p.textSecondary)),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.day,
    required this.index,
    required this.value,
    required this.label,
    required this.color,
    required this.barsHeight,
    required this.fraction,
    required this.selected,
    required this.over,
    required this.future,
    required this.onTap,
  });

  final DateTime day;
  final int index;
  final int value;
  final String label;
  final Color? color;
  final double barsHeight;
  final double fraction;
  final bool selected;
  final bool over;
  final bool future;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final reduce = MediaQuery.disableAnimationsOf(context);

    final barColor = selected
        ? (over ? p.accent : (color ?? p.ink))
        : (over ? p.accent.withValues(alpha: 0.35) : (color?.withValues(alpha: 0.3) ?? p.track));
    final target = value == 0 ? 0.0 : (barsHeight * fraction).clamp(WeekBarChart._minBar, barsHeight);

    return PressScale(
      onTap: future ? null : onTap,
      scale: 0.94,
      child: Column(
        children: [
          SizedBox(
            height: barsHeight,
            child: TweenAnimationBuilder<double>(
              key: ValueKey(day),
              tween: Tween(begin: 0, end: target),
              duration: reduce ? Duration.zero : AppMotion.slow + AppMotion.stagger * index,
              curve: AppMotion.easeOut,
              builder: (context, h, _) => Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: AppSizes.barWidth,
                    height: h,
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(AppRadii.xs),
                    ),
                  ),
                  if (selected && value > 0)
                    Positioned(
                      bottom: h + WeekBarChart._valueLabelGap,
                      child: Text(label, style: t.caption.copyWith(color: p.textPrimary)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            weekdayInitial(day),
            style: t.caption.copyWith(
              color: selected
                  ? p.textPrimary
                  : future
                      ? p.textTertiary
                      : p.textSecondary,
            ),
          ),
          Text(
            '${day.day}',
            style: t.label.copyWith(
              color: future
                  ? p.textTertiary
                  : selected
                      ? p.textPrimary
                      : p.textSecondary,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalLinePainter extends CustomPainter {
  _GoalLinePainter({required this.y, required this.color});

  final double y;
  final Color color;

  static const double _dash = 5;
  static const double _gap = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2;
    for (double x = 0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(Offset(x, y), Offset(x + _dash, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GoalLinePainter old) => old.y != y || old.color != color;
}
