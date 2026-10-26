import 'package:intl/intl.dart';

/// Midnight (local) of [d].
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime addDays(DateTime d, int days) =>
    DateTime(d.year, d.month, d.day + days);

/// Monday of the week containing [d].
DateTime startOfWeek(DateTime d) =>
    addDays(dateOnly(d), -(d.weekday - DateTime.monday));

bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String weekdayShort(DateTime d) => DateFormat('E').format(d);
String weekdayInitial(DateTime d) => DateFormat('E').format(d).substring(0, 1);
String longDateLabel(DateTime d) => DateFormat('EEEE, MMMM d').format(d);
String timeLabel(DateTime d) => DateFormat('h:mma').format(d).toLowerCase();

String dayLabel(DateTime d, {DateTime? now}) {
  final today = dateOnly(now ?? DateTime.now());
  if (isSameDay(d, today)) return 'Today';
  if (isSameDay(d, addDays(today, -1))) return 'Yesterday';
  if (isSameDay(d, addDays(today, 1))) return 'Tomorrow';
  return DateFormat('EEEE, MMM d').format(d);
}

String weekRangeLabel(DateTime weekStart) {
  final end = addDays(weekStart, 6);
  final sameMonth = weekStart.month == end.month;
  final start = DateFormat('MMM d').format(weekStart);
  final finish = sameMonth ? DateFormat('d').format(end) : DateFormat('MMM d').format(end);
  return '$start – $finish';
}
