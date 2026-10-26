import 'package:flutter/material.dart';

import '../utils/haptics.dart';

/// Swipe-to-act row whose action background stays round through the whole
/// gesture.
///
/// Flutter's [Dismissible] clips its background with a plain rectangle that
/// follows the sliding child's edge, so a rounded card slides past a square
/// cut. Here the background is drawn behind the whole row, clipped to
/// [borderRadius], and only while a drag is under way (at rest it would show
/// as a colored fringe around the card's anti-aliased corners). The sliding
/// child covers it, so its rounded corners reveal the same rounded shape.
class RoundedDismissible extends StatefulWidget {
  const RoundedDismissible({
    required super.key,
    required this.child,
    required this.borderRadius,
    this.background,
    this.secondaryBackground,
    this.margin = EdgeInsets.zero,
    this.direction = DismissDirection.horizontal,
    this.dismissThresholds = const {},
    this.confirmDismiss,
    this.onDismissed,
  });

  final Widget child;
  final BorderRadius borderRadius;

  /// Shown when swiping start to end.
  final Widget? background;

  /// Shown when swiping end to start; falls back to [background].
  final Widget? secondaryBackground;

  /// Space around the visible card inside [child] (e.g. its bottom margin),
  /// so the background lines up with the card, not the row.
  final EdgeInsetsGeometry margin;

  final DismissDirection direction;
  final Map<DismissDirection, double> dismissThresholds;
  final ConfirmDismissCallback? confirmDismiss;
  final DismissDirectionCallback? onDismissed;

  @override
  State<RoundedDismissible> createState() => _RoundedDismissibleState();
}

class _RoundedDismissibleState extends State<RoundedDismissible> {
  /// Direction of the drag in progress; null while the child is at rest.
  DismissDirection? _showing;

  void _onUpdate(DismissUpdateDetails d) {
    // A light tick as the swipe crosses its threshold, either way.
    if (d.reached != d.previousReached && d.reached) Haptics.light();
    final showing = d.progress > 0 ? d.direction : null;
    if (showing != _showing) setState(() => _showing = showing);
  }

  @override
  Widget build(BuildContext context) {
    final bg = _showing == DismissDirection.endToStart
        ? widget.secondaryBackground ?? widget.background
        : widget.background;
    return Stack(
      children: [
        if (_showing != null && bg != null)
          Positioned.fill(
            child: Padding(
              padding: widget.margin,
              child: ClipRRect(
                borderRadius: widget.borderRadius,
                clipBehavior: Clip.antiAlias,
                child: bg,
              ),
            ),
          ),
        Dismissible(
          key: widget.key!,
          direction: widget.direction,
          dismissThresholds: widget.dismissThresholds,
          onUpdate: _onUpdate,
          confirmDismiss: widget.confirmDismiss,
          onDismissed: widget.onDismissed,
          child: widget.child,
        ),
      ],
    );
  }
}
