import 'package:calorie_app/core/utils/greeting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int h, [int m = 0]) => DateTime(2026, 10, 26, h, m);

  ({String eyebrow, String title, String line}) today(int h, {int eaten = 0, int entries = 0}) =>
      dayHeadline(day: at(0), now: at(h), eaten: eaten, target: 2000, entries: entries);

  test('today is titled "Today" with the date as kicker', () {
    final h = today(9);
    expect(h.title, 'Today');
    expect(h.eyebrow, 'MONDAY, 26 OCTOBER');
  });

  test('empty day nudges toward the meal for the time', () {
    expect(today(8).line, contains('breakfast'));
    expect(today(13).line, contains('lunch'));
    expect(today(19).line, contains('dinner'));
    // Late night stays neutral instead of "dinner time".
    expect(today(23).line, isNot(contains('dinner')));
  });

  test('progress wording follows the share of target eaten', () {
    expect(today(13, eaten: 400, entries: 1).line, contains('Plenty of room'));
    expect(today(13, eaten: 1400, entries: 3).line, startsWith('On track'));
    expect(today(13, eaten: 1900, entries: 4).line, startsWith('Right on target'));
    expect(today(13, eaten: 2400, entries: 5).line, contains('over'));
  });

  test('other days', () {
    final yesterday = dayHeadline(day: at(0).subtract(const Duration(days: 1)), now: at(10), eaten: 0, target: 2000, entries: 0);
    expect(yesterday.title, 'Yesterday');
    expect(yesterday.line, 'Nothing was logged this day.');
    final older = dayHeadline(day: DateTime(2026, 10, 20), now: at(10), eaten: 1900, target: 2000, entries: 3);
    expect(older.title, 'Tuesday');
    expect(older.line, contains('target'));
  });

  test('firstName', () {
    expect(firstName('  Aayush Shukla '), 'Aayush');
    expect(firstName('Aayush'), 'Aayush');
    expect(firstName('   '), '');
    expect(firstName(''), '');
  });
}
