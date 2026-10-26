import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_theme.dart';
import 'emoji_assets.dart';

/// The app's icon language: food and nutrition use emoji (bundled Twemoji, so they
/// look the same everywhere); UI chrome uses Phosphor icons.
abstract final class AppEmoji {
  static const calories = '🔥';
  static const protein = '🥩';
  static const carbs = '🍞';
  static const fat = '🥑';
  static const water = '💧';
  static const meal = '🍽️';
  static const search = '🔎';
  static const recent = '🕘';
  static const saved = '⭐';
  static const custom = '✏️';

  /// Packaged food found by barcode.
  static const packaged = '🥫';
  static const welcome = '🥑';

  /// Avatars and meal covers the user can pick from.
  static const avatars = [
    '🥑', '🍓', '🍋', '🥕', '🌶️', '🍜', '🥐', '🍳',
    '🧁', '🥭', '🍉', '🥥', '🍕', '🌮', '🍣',
  ];

  static const mealCovers = [
    '🍛', '🍚', '🍲', '🥣', '🍳', '🥗', '🥪', '🍝',
    '🍜', '🌯', '🥙', '🍱', '🥘', '🍕', '🍔', '🍗',
    '🫓', '🥞', '🥤', '🍎', '🥜', '🥚', '🐟', '🍰',
  ];
}

/// An emoji drawn from bundled Twemoji artwork (assets/emoji, CC-BY 4.0), so
/// it looks identical on every device instead of following the system font.
/// Emoji without bundled art fall back to the system font. Fixed box, so it
/// never shifts surrounding text.
class Emoji extends StatelessWidget {
  const Emoji(this.emoji, {super.key, this.size = 20});

  final String emoji;
  final double size;

  /// "🍛" -> "1f35b"; "🙋‍♂️" -> "1f64b-200d-2642" (variation selector dropped).
  static String keyOf(String emoji) => [
        for (final r in emoji.runes)
          if (r != 0xFE0F) r.toRadixString(16),
      ].join('-');

  @override
  Widget build(BuildContext context) {
    final key = keyOf(emoji);
    final box = size * 1.25;
    final art = size * 1.12;

    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: kEmojiAssetKeys.contains(key)
            ? SvgPicture.asset(
                'assets/emoji/$key.svg',
                width: art,
                height: art,
                excludeFromSemantics: true,
              )
            : Text(
                emoji,
                textScaler: TextScaler.noScaling,
                style: TextStyle(fontSize: size, height: 1, letterSpacing: 0),
              ),
      ),
    );
  }
}

/// Emoji on a soft rounded tile. Used for foods, meals and settings rows.
class EmojiTile extends StatelessWidget {
  const EmojiTile(
    this.emoji, {
    super.key,
    this.size = AppSizes.iconTile + AppSpacing.sm,
    this.radius,
    this.color,
  });

  final String emoji;
  final double size;
  final double? radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color ?? p.surfaceAlt,
        borderRadius: BorderRadius.circular(radius ?? size * 0.3),
      ),
      child: Emoji(emoji, size: size * 0.5),
    );
  }
}

/// Scales and fades [child] in with a spring when it first appears.
/// Change [key] to replay it (e.g. when the emoji changes).
class PopIn extends StatefulWidget {
  const PopIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.from = 0.6,
    this.curve = AppMotion.springBouncy,
  });

  final Widget child;
  final Duration delay;
  final double from;
  final Curve curve;

  @override
  State<PopIn> createState() => _PopInState();
}

class _PopInState extends State<PopIn> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
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
    final scale = CurvedAnimation(parent: _c, curve: widget.curve);
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.35, curve: Curves.easeOut),
    );
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: fade.value.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: widget.from + (1 - widget.from) * scale.value,
          child: child,
        ),
      ),
    );
  }
}
