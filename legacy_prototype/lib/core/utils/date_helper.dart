import 'package:intl/intl.dart';

/// Date formatting and comparison helpers.
abstract final class DateHelper {
  static String formatDate(DateTime date) => DateFormat('MMM d, yyyy').format(date);

  static String formatTime(DateTime date) => DateFormat('h:mm a').format(date);

  static String formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime startOfWeek(DateTime date) {
    final day = date.weekday;
    return startOfDay(date.subtract(Duration(days: day - 1)));
  }

  static DateTime startOfMonth(DateTime date) => DateTime(date.year, date.month, 1);

  static List<DateTime> last7Days() {
    final today = startOfDay(DateTime.now());
    return List.generate(7, (i) => today.subtract(Duration(days: 6 - i)));
  }

  static List<DateTime> daysInCurrentMonth() {
    final now = DateTime.now();
    final start = startOfMonth(now);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return List.generate(daysInMonth, (i) => start.add(Duration(days: i)));
  }
}
