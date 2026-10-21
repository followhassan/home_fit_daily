import 'package:intl/intl.dart';

import 'local_date.dart';

/// Display formatting for durations and dates.
abstract final class Formatters {
  /// `m:ss` for timers, e.g. `1:05`. Negative values are shown as `0:00`.
  static String clock(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    final minutes = s ~/ 60;
    final secs = s % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  /// Rounds milliseconds *up* to whole seconds so a countdown reads `1`
  /// until the last millisecond instead of showing `0` early.
  static int ceilSeconds(int milliseconds) => milliseconds <= 0 ? 0 : (milliseconds + 999) ~/ 1000;

  /// Human duration such as `45 sec`, `12 min`, `1 h 5 min`.
  static String duration(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final totalMinutes = (seconds / 60).round();
    if (totalMinutes < 60) return '$totalMinutes min';
    final h = totalMinutes ~/ 60;
    final m = totalMinutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// Minutes for stat tiles, e.g. `0`, `42`, `1,250`.
  static String minutes(int seconds) =>
      NumberFormat.decimalPattern().format((seconds / 60).floor());

  static String date(LocalDate date) => DateFormat.yMMMd().format(date.toDateTime());

  static String shortDate(LocalDate date) => DateFormat.MMMd().format(date.toDateTime());

  static String weekdayShort(int isoWeekday) =>
      const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][isoWeekday - 1];

  static String weekdayLong(int isoWeekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][isoWeekday - 1];

  static String timeOfDay(int hour, int minute) =>
      DateFormat.jm().format(DateTime(2000, 1, 1, hour, minute));

  static String dateTime(DateTime local) => DateFormat.yMMMd().add_jm().format(local);

  /// "Today", "Yesterday" or a short date.
  static String relativeDay(LocalDate date, LocalDate today) {
    final diff = today.daysSince(date);
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff == -1) return 'Tomorrow';
    return date.year == today.year
        ? DateFormat.MMMEd().format(date.toDateTime())
        : DateFormat.yMMMd().format(date.toDateTime());
  }
}
