import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Number that counts up from 0 on first build, and glides between values
/// afterwards (TweenAnimationBuilder retargets from the current value).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.suffix = '',
    this.duration = AppMotion.countUp,
  });

  final num value;
  final TextStyle style;
  final String suffix;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration,
      curve: AppMotion.easeOut,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}
