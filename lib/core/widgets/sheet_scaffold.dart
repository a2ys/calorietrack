import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/haptics.dart';

/// Shows a themed bottom sheet that follows the finger and can be dismissed by
/// dragging it down from anywhere (or flicking it). Content scrolls inside it;
/// at the top of the scroll, pulling down moves the sheet instead.
///
/// [initialSize] and [maxSize] are fractions of the available height. The
/// sheet can't be dragged taller than [maxSize] (defaults to [initialSize]).
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  double initialSize = 0.92,
  double? maxSize,
}) {
  Haptics.light();
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    useRootNavigator: true, // cover the bottom nav bar too
    enableDrag: false, // the DraggableScrollableSheet owns the drag
    backgroundColor: Colors.transparent,
    elevation: 0,
    sheetAnimationStyle: AnimationStyle(
      duration: AppMotion.sheetIn,
      reverseDuration: AppMotion.sheetOut,
      curve: AppMotion.drawer,
      reverseCurve: AppMotion.drawer.flipped,
    ),
    builder: (_) => _SheetFrame(
      initialSize: initialSize,
      maxSize: maxSize ?? initialSize,
      builder: builder,
    ),
  );
}

/// Hands the sheet's scroll controller to whatever scrollable is inside it.
class SheetScope extends InheritedWidget {
  const SheetScope({super.key, required this.controller, required super.child});

  final ScrollController controller;

  static ScrollController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SheetScope>()?.controller;

  @override
  bool updateShouldNotify(SheetScope old) => controller != old.controller;
}

/// Scroll physics for anything inside a sheet: clamping, and always
/// scrollable so short content can still be dragged down to dismiss.
const ScrollPhysics sheetScrollPhysics =
    ClampingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({
    required this.initialSize,
    required this.maxSize,
    required this.builder,
  });

  final double initialSize;
  final double maxSize;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return AnimatedPadding(
      duration: AppMotion.normal,
      curve: AppMotion.easeOut,
      padding: EdgeInsets.only(bottom: keyboard),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: initialSize,
        minChildSize: 0,
        maxChildSize: maxSize,
        snap: true,
        snapSizes: maxSize > initialSize ? [initialSize] : null,
        snapAnimationDuration: const Duration(milliseconds: 280),
        builder: (context, controller) => DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: AppRadii.sheet,
          ),
          child: ClipRRect(
            borderRadius: AppRadii.sheet,
            child: SheetScope(
              controller: controller,
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: AppSizes.handle,
        height: AppSizes.handleThickness,
        decoration: BoxDecoration(
          color: context.palette.track,
          borderRadius: AppRadii.chip,
        ),
      ),
    );
  }
}

/// Standard sheet body: drag handle, title, content. Scrolls with the sheet.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SingleChildScrollView(
      controller: SheetScope.maybeOf(context),
      physics: sheetScrollPhysics,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.md,
        AppSpacing.screen,
        AppSpacing.xxl + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SheetHandle(),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(child: Text(title, style: t.title)),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(subtitle!, style: t.label),
          ],
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}

/// A centered dialog that pops in with a spring and fades out quickly.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  Haptics.light();
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.black.withValues(alpha: 0.42),
    transitionDuration: AppMotion.dialog,
    pageBuilder: (context, _, _) => builder(context),
    transitionBuilder: (context, animation, _, child) {
      final scale = Tween<double>(begin: 0.86, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: AppMotion.spring,
          reverseCurve: Curves.easeIn,
        ),
      );
      final fade = CurvedAnimation(
        parent: animation,
        curve: const Interval(0, 0.45, curve: Curves.easeOut),
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: fade,
        child: ScaleTransition(scale: scale, child: child),
      );
    },
  );
}
