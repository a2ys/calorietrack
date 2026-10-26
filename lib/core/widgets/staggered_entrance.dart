import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Fades and lifts [child] in once, delayed by [index] * stagger.
/// Never blocks interaction; skipped entirely when animations are disabled.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance>
    with SingleTickerProviderStateMixin {
  static const double _lift = 12;
  static const int _maxStaggered = 8;

  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppMotion.slow);

  @override
  void initState() {
    super.initState();
    final steps = widget.index.clamp(0, _maxStaggered);
    Future<void>.delayed(AppMotion.stagger * steps, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return widget.child;
    final curved = CurvedAnimation(parent: _c, curve: AppMotion.easeOut);
    return AnimatedBuilder(
      animation: curved,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curved.value) * _lift),
          child: child,
        ),
      ),
    );
  }
}
