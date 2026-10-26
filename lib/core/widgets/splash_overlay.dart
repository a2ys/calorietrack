import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_logo.dart';

/// Brief branded splash drawn over the first screen: the logo draws itself in,
/// "CalTracker / by a2ys" fades up, then the whole thing fades away.
/// Matches the black native launch screen so there is no white flash.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key});

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with SingleTickerProviderStateMixin {
  static const Duration _full = Duration(milliseconds: 2500);
  static const Duration _reduced = Duration(milliseconds: 350);
  static const double _logoSize = 224;

  late final AnimationController _c = AnimationController(vsync: this);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _c.duration = MediaQuery.disableAnimationsOf(context) ? _reduced : _full;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bg = AppPalette.light.ink;
    final fg = AppPalette.dark.ink;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final type = context.type;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        if (_c.isCompleted) return const SizedBox.shrink();
        final v = _c.value;
        final draw = reduce ? 1.0 : const Interval(0, 0.3, curve: AppMotion.easeOut).transform(v);
        final text = reduce ? 1.0 : const Interval(0.2, 0.4, curve: AppMotion.easeOut).transform(v);
        final fade = Interval(reduce ? 0.3 : 0.9, 1, curve: AppMotion.easeOut).transform(v);
        return Opacity(
          opacity: 1 - fade,
          child: ColoredBox(
            color: bg,
            child: SizedBox.expand(
              // The logo sits dead centre at the size of the native launch
              // screen's logo, so the handoff doesn't jump.
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AppLogo(size: _logoSize, color: fg, progress: draw),
                  Transform.translate(
                    offset: const Offset(0, _logoSize * 0.33 + 52),
                    child: Opacity(
                      opacity: text,
                      child: Transform.translate(
                        offset: Offset(0, (1 - text) * 6),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'CalTracker',
                              style: type.heading.copyWith(color: fg, decoration: TextDecoration.none),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              'by a2ys',
                              style: type.caption.copyWith(
                                color: fg.withValues(alpha: 0.55),
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
