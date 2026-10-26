import 'package:intl/intl.dart';

import '../db/models.dart';
import 'date_utils.dart';

/// What the top of Today says: a date kicker, the day's name, and one plain
/// sentence about how the day is going. Numbers live in the hero card below,
/// so this stays in words.
({String eyebrow, String title, String line}) dayHeadline({
  required DateTime day,
  required DateTime now,
  required int eaten,
  required int target,
  required int entries,
}) {
  final today = dateOnly(now);
  final d = dateOnly(day);
  final eyebrow = DateFormat('EEEE, d MMMM').format(d).toUpperCase();
  final title = dayLabel(d, now: now).split(',').first;
  final pct = target <= 0 ? 0.0 : eaten / target;

  final String line;
  if (d.isAfter(today)) {
    line = 'Plan ahead: anything you log lands on this day.';
  } else if (d.isBefore(today)) {
    if (entries == 0) {
      line = 'Nothing was logged this day.';
    } else if (pct > 1.05) {
      line = 'Went a little over. It all evens out.';
    } else if (pct >= 0.85) {
      line = 'Finished right around your target.';
    } else {
      line = 'Finished under target.';
    }
  } else {
    // After 9pm "dinner time" reads oddly, so late hours get neutral copy.
    final late = now.hour < 5 || now.hour >= 21;
    final next = late ? 'a late bite' : MealType.forTime(now).label.toLowerCase();
    if (entries == 0) {
      line = late ? 'Nothing logged yet today.' : 'It’s $next time. What’s on your plate?';
    } else if (pct > 1.05) {
      line = 'A little over today. Tomorrow’s a fresh start.';
    } else if (pct >= 0.9) {
      line = 'Right on target. Nicely done.';
    } else if (pct >= 0.6) {
      line = late ? 'On track. Close to your target.' : 'On track. Keep $next on the lighter side.';
    } else {
      line = 'Plenty of room left for $next.';
    }
  }
  return (eyebrow: eyebrow, title: title, line: line);
}

/// First word of a name, trimmed: "  Aayush Shukla " -> "Aayush".
String firstName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '';
  return trimmed.split(RegExp(r'\s+')).first;
}
