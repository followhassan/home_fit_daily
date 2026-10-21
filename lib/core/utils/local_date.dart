/// A calendar date without a time or time zone (e.g. `2026-03-31`).
///
/// History, streaks and plan schedules are keyed by the *local* calendar date
/// on which something happened, so this type is used instead of [DateTime]
/// wherever only the day matters. Arithmetic is done on UTC midnights, which
/// have no daylight-saving transitions.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  factory LocalDate.today([DateTime? now]) => LocalDate.fromDateTime(now ?? DateTime.now());

  /// Parses an ISO `yyyy-MM-dd` string. Throws [FormatException] if invalid.
  factory LocalDate.parse(String value) {
    final parts = value.split('-');
    if (parts.length != 3) throw FormatException('Invalid date', value);
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) {
      throw FormatException('Invalid date', value);
    }
    final date = LocalDate(y, m, d);
    // Reject impossible dates such as 2026-02-30.
    if (LocalDate.fromDateTime(date._utc) != date) {
      throw FormatException('Invalid date', value);
    }
    return date;
  }

  static LocalDate? tryParse(Object? value) {
    if (value is! String) return null;
    try {
      return LocalDate.parse(value);
    } on FormatException {
      return null;
    }
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// Local midnight of this date, for display and scheduling.
  DateTime toDateTime() => DateTime(year, month, day);

  /// ISO weekday: Monday = 1 … Sunday = 7.
  int get weekday => _utc.weekday;

  LocalDate addDays(int days) => LocalDate.fromDateTime(_utc.add(Duration(days: days)));

  /// Whole days from [other] to this date (positive when this is later).
  int daysSince(LocalDate other) => _utc.difference(other._utc).inDays;

  /// Monday of the week containing this date. Weeks start on Monday.
  LocalDate get startOfWeek => addDays(-(weekday - 1));

  LocalDate get startOfMonth => LocalDate(year, month, 1);

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// First day of the month [months] months after this date's month.
  LocalDate addMonthsToStart(int months) {
    final total = year * 12 + (month - 1) + months;
    return LocalDate(total ~/ 12, total % 12 + 1, 1);
  }

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}
