import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single source of truth for colours, radii, spacing, type and motion.
/// Widgets must read from here instead of hard-coding values.

// ---------------------------------------------------------------- spacing

abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 48;

  /// Horizontal gutter for every screen.
  static const double screen = 20;
}

// ------------------------------------------------------------------ radii

abstract final class AppRadii {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 28;
  static const double xl = 36;
  static const double pill = 999;

  static BorderRadius get card => BorderRadius.circular(lg);
  static BorderRadius get tile => BorderRadius.circular(md);
  static BorderRadius get chip => BorderRadius.circular(pill);
  static BorderRadius get sheet =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}

// ------------------------------------------------------------------ sizes

abstract final class AppSizes {
  static const double button = 56;
  static const double fab = 64;
  static const double iconTile = 40;
  static const double iconTileSm = 32;
  static const double foodThumb = 64;
  static const double heroRing = 112;
  static const double heroRingStroke = 13;
  static const double macroRing = 64;
  static const double macroRingStroke = 8;
  static const double dayChip = 52;
  static const double dayChipHeight = 76;
  static const double weekStripHeight = 84;
  static const double barChartHeight = 190;
  static const double barWidth = 28;
  static const double handle = 40;
  static const double handleThickness = 4;
  static const double border = 1;
  static const double navHeight = 64;
  static const double wheelItem = 52;
  static const double wheelHeight = 220;
}

// ----------------------------------------------------------------- motion

/// A damped spring as a [Curve]: overshoots the target, then settles. Lets
/// every implicit animation (AnimatedScale, AnimatedContainer...) feel
/// physical. [damping] is the damping ratio: 1 = no overshoot, lower = bouncier.
/// Roughly: 0.7 -> 5% overshoot, 0.6 -> 10%, 0.5 -> 16%.
class SpringCurve extends Curve {
  const SpringCurve([this.damping = 0.62]);

  final double damping;

  /// Envelope decays to ~1% by t = 1, so the duration you pick is the settle time.
  static const double _settle = 4.6;

  @override
  double transformInternal(double t) {
    final z = damping.clamp(0.05, 0.999);
    final w = _settle / z;
    final wd = w * math.sqrt(1 - z * z);
    return 1 -
        math.exp(-z * w * t) *
            (math.cos(wd * t) + (z * w / wd) * math.sin(wd * t));
  }
}

abstract final class AppMotion {
  /// Strong ease-out: instant-feeling response for anything entering.
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  /// For things that move on screen.
  static const Curve easeInOut = Cubic(0.77, 0, 0.175, 1);

  /// iOS drawer curve: fast start, long soft landing. Used for sheets.
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  /// Springs. Soft for layout and selection, bouncy for pop-ins and dialogs.
  static const Curve springSoft = SpringCurve(0.78);
  static const Curve spring = SpringCurve(0.62);
  static const Curve springBouncy = SpringCurve(0.5);

  static const Duration springDuration = Duration(milliseconds: 520);
  static const Duration sheetIn = Duration(milliseconds: 440);
  static const Duration sheetOut = Duration(milliseconds: 260);
  static const Duration dialog = Duration(milliseconds: 420);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration normal = Duration(milliseconds: 240);
  static const Duration slow = Duration(milliseconds: 360);
  // Glanceable data seen many times a day: strong ease-out, kept short.
  static const Duration ring = Duration(milliseconds: 700);
  static const Duration countUp = Duration(milliseconds: 600);
  static const Duration stagger = Duration(milliseconds: 45);

  static const double pressScale = 0.97;
}

// ----------------------------------------------------------------- colour

@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.track,
    required this.ink,
    required this.onInk,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accent,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
    required this.shadows,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color track;

  /// Primary action colour (black in light mode, white in dark mode).
  final Color ink;
  final Color onInk;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// The single accent: over-budget and destructive states.
  final Color accent;

  /// Muted macro colours, only used inside macro tiles and rings.
  final Color protein;
  final Color carbs;
  final Color fat;

  /// Water tracking.
  final Color water;

  final List<BoxShadow> shadows;

  static const AppPalette light = AppPalette(
    background: Color(0xFFF6F6F7),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF1F1F3),
    border: Color(0xFFECECEF),
    track: Color(0xFFE9E9EC),
    ink: Color(0xFF0B0B0C),
    onInk: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF0B0B0C),
    textSecondary: Color(0xFF6C6C73),
    textTertiary: Color(0xFFA4A4AC),
    accent: Color(0xFFE5655F),
    protein: Color(0xFFE5655F),
    carbs: Color(0xFFD9A066),
    fat: Color(0xFF6E9BE0),
    water: Color(0xFF4FA3E8),
    shadows: [
      BoxShadow(color: Color(0x0F000000), blurRadius: 28, offset: Offset(0, 10)),
      BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
    ],
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0E0E10),
    surface: Color(0xFF1A1A1D),
    surfaceAlt: Color(0xFF242428),
    border: Color(0xFF2B2B30),
    track: Color(0xFF2D2D33),
    ink: Color(0xFFFFFFFF),
    onInk: Color(0xFF0B0B0C),
    textPrimary: Color(0xFFF5F5F6),
    textSecondary: Color(0xFF9B9BA4),
    textTertiary: Color(0xFF63636B),
    accent: Color(0xFFEE7A74),
    protein: Color(0xFFEE7A74),
    carbs: Color(0xFFE2AE78),
    fat: Color(0xFF82A9E8),
    water: Color(0xFF63B4F2),
    shadows: [
      BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  @override
  AppPalette copyWith({Color? background}) => this;

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      track: Color.lerp(track, other.track, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      onInk: Color.lerp(onInk, other.onInk, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      water: Color.lerp(water, other.water, t)!,
      shadows: t < 0.5 ? shadows : other.shadows,
    );
  }
}

// ------------------------------------------------------------------- type

@immutable
class AppTypography {
  AppTypography(AppPalette p)
      : numeralXL = _style(64, FontWeight.w800, p.textPrimary, spacing: -2.5, height: 1),
        numeralL = _style(40, FontWeight.w800, p.textPrimary, spacing: -1.5, height: 1.05),
        numeralM = _style(24, FontWeight.w800, p.textPrimary, spacing: -0.6, height: 1.1),
        numeralS = _style(17, FontWeight.w700, p.textPrimary, spacing: -0.2, height: 1.15),
        title = _style(28, FontWeight.w800, p.textPrimary, spacing: -0.8, height: 1.15),
        heading = _style(19, FontWeight.w700, p.textPrimary, spacing: -0.3, height: 1.25),
        body = _style(15, FontWeight.w500, p.textPrimary, height: 1.35),
        bodyStrong = _style(15, FontWeight.w700, p.textPrimary, height: 1.35),
        label = _style(13, FontWeight.w600, p.textSecondary, height: 1.3),
        caption = _style(12, FontWeight.w600, p.textTertiary, height: 1.3),
        button = _style(16, FontWeight.w700, p.onInk, height: 1.2);

  final TextStyle numeralXL;
  final TextStyle numeralL;
  final TextStyle numeralM;
  final TextStyle numeralS;
  final TextStyle title;
  final TextStyle heading;
  final TextStyle body;
  final TextStyle bodyStrong;
  final TextStyle label;
  final TextStyle caption;
  final TextStyle button;

  /// Bundled in assets/fonts (SIL OFL), so it renders offline and in release
  /// builds. Do not switch back to runtime fetching.
  static const String fontFamily = 'PlusJakartaSans';

  static TextStyle _style(
    double size,
    FontWeight weight,
    Color color, {
    double spacing = 0,
    double height = 1.3,
  }) =>
      TextStyle(
        fontFamily: fontFamily,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: spacing,
        height: height,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
  AppTypography get type => AppTypography(palette);
}

// ------------------------------------------------------------------ theme

abstract final class AppTheme {
  static ThemeData get light => _build(AppPalette.light, Brightness.light);
  static ThemeData get dark => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final type = AppTypography(p);
    final scheme = ColorScheme.fromSeed(
      seedColor: p.ink,
      brightness: brightness,
    ).copyWith(
      primary: p.ink,
      onPrimary: p.onInk,
      surface: p.surface,
      onSurface: p.textPrimary,
      error: p.accent,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [p],
      textTheme: TextTheme(
        displayLarge: type.numeralXL,
        headlineMedium: type.title,
        titleLarge: type.heading,
        bodyLarge: type.body,
        bodyMedium: type.body,
        labelLarge: type.button,
        bodySmall: type.caption,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: p.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      dividerColor: p.border,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: p.ink,
        contentTextStyle: type.body.copyWith(color: p.onInk),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.tile),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: p.surface,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.sheet),
        showDragHandle: false,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.surfaceAlt,
        hintStyle: type.body.copyWith(color: p.textTertiary),
        labelStyle: type.label,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadii.tile,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.tile,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.tile,
          borderSide: BorderSide(color: p.ink, width: 1.5),
        ),
      ),
    );
  }
}
