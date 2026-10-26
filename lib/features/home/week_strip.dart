import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/haptics.dart';
import '../../core/widgets/press_scale.dart';

/// Swipeable week at the top of Home. One page per week; the newest page is
/// the current week, and future days can't be selected.
class WeekStrip extends ConsumerStatefulWidget {
  const WeekStrip({super.key});

  @override
  ConsumerState<WeekStrip> createState() => _WeekStripState();
}

class _WeekStripState extends ConsumerState<WeekStrip> {
  /// How far back the user can swipe.
  static const int _weeks = 104;

  final DateTime _currentWeek = startOfWeek(DateTime.now());
  late final PageController _controller = PageController(
    initialPage: _weeks - 1,
    viewportFraction: 1,
  );

  DateTime _weekForPage(int page) =>
      addDays(_currentWeek, -7 * (_weeks - 1 - page));

  int _pageForDay(DateTime day) =>
      _weeks - 1 - (_currentWeek.difference(startOfWeek(day)).inDays / 7).round();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    // Keep the same weekday when swiping between weeks, but never in the future.
    final selected = ref.read(selectedDayProvider);
    final offset = selected.weekday - DateTime.monday;
    final today = dateOnly(DateTime.now());
    var next = addDays(_weekForPage(page), offset);
    if (next.isAfter(today)) next = today;
    Haptics.tap();
    ref.read(selectedDayProvider.notifier).select(next);
  }

  @override
  Widget build(BuildContext context) {
    // Jump the strip when the selected day changes from elsewhere (e.g. History).
    ref.listen(selectedDayProvider, (_, day) {
      final page = _pageForDay(day);
      if (_controller.hasClients && _controller.page?.round() != page) {
        _controller.animateToPage(
          page,
          duration: AppMotion.slow,
          curve: AppMotion.easeOut,
        );
      }
    });

    return SizedBox(
      height: AppSizes.weekStripHeight,
      child: PageView.builder(
        controller: _controller,
        clipBehavior: Clip.none, // lets the selected chip's shadow breathe
        itemCount: _weeks,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, page) => _WeekRow(weekStart: _weekForPage(page)),
      ),
    );
  }
}

class _WeekRow extends ConsumerWidget {
  const _WeekRow({required this.weekStart});
  final DateTime weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final totals = ref.watch(dailyTotalsProvider(weekStart)).value ?? const {};
    final today = dateOnly(DateTime.now());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 7; i++)
            _DayChip(
              day: addDays(weekStart, i),
              selected: isSameDay(addDays(weekStart, i), selected),
              isToday: isSameDay(addDays(weekStart, i), today),
              future: addDays(weekStart, i).isAfter(today),
              logged: totals.containsKey(addDays(weekStart, i)),
              onTap: () => ref
                  .read(selectedDayProvider.notifier)
                  .select(addDays(weekStart, i)),
            ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.isToday,
    required this.future,
    required this.logged,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final bool isToday;
  final bool future;
  final bool logged;
  final VoidCallback onTap;

  static const double _dot = 5;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final fg = selected
        ? p.onInk
        : future
            ? p.textTertiary
            : p.textPrimary;

    return PressScale(
      haptic: !future,
      onTap: future ? null : onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.easeOut,
        width: AppSizes.dayChip - AppSpacing.sm,
        height: AppSizes.dayChipHeight,
        decoration: BoxDecoration(
          color: selected ? p.ink : p.surface,
          borderRadius: BorderRadius.circular(AppRadii.md),
          border: Border.all(
            color: selected ? p.ink : p.border,
            width: AppSizes.border,
          ),
          boxShadow: selected ? p.shadows : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              weekdayInitial(day),
              style: t.caption.copyWith(
                color: selected ? p.onInk.withValues(alpha: 0.7) : p.textTertiary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('${day.day}', style: t.numeralS.copyWith(color: fg)),
            const SizedBox(height: AppSpacing.xs),
            AnimatedContainer(
              duration: AppMotion.fast,
              width: _dot,
              height: _dot,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: logged
                    ? (selected ? p.onInk : p.ink)
                    : isToday
                        ? (selected ? p.onInk.withValues(alpha: 0.4) : p.textTertiary)
                        : Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
