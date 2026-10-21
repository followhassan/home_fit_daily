import '../core/utils/local_date.dart';
import '../data/models/enums.dart';
import '../data/models/workout_session.dart';

/// Activity recorded on one local calendar day.
class DayActivity {
  int completed = 0;
  int partial = 0;
  int activeSeconds = 0;

  bool get hasCompleted => completed > 0;
  bool get hasAny => completed > 0 || partial > 0;
}

/// One bar in an activity chart.
class ActivityBucket {
  const ActivityBucket({
    required this.start,
    required this.label,
    required this.activeSeconds,
    required this.completedWorkouts,
  });

  final LocalDate start;
  final String label;
  final int activeSeconds;
  final int completedWorkouts;

  double get activeMinutes => activeSeconds / 60;
}

enum ActivityRange {
  week('7 days'),
  month('30 days'),
  weeks('12 weeks'),
  months('12 months');

  const ActivityRange(this.label);
  final String label;
}

/// Statistics derived from session history.
///
/// Rules (see `docs/ARCHITECTURE.md`):
/// * Dates come from each session's stored local completion date.
/// * Weeks start on Monday.
/// * Only *completed* sessions count as completed workouts and streak days.
/// * Active time includes completed and partial sessions; abandoned
///   sessions are ignored entirely.
/// * The current streak counts consecutive days with a completed workout
///   ending today, or yesterday if nothing is done yet today.
class StatsSnapshot {
  StatsSnapshot._({
    required this.today,
    required this.weeklyGoal,
    required this.days,
    required this.totalCompleted,
    required this.totalPartial,
    required this.totalActiveSeconds,
    required this.currentStreak,
    required this.longestStreak,
    required this.thisWeekCompleted,
    required this.thisWeekActiveSeconds,
    required this.weeklyGoalStreak,
  });

  factory StatsSnapshot.compute(
    Iterable<WorkoutSession> sessions, {
    required LocalDate today,
    required int weeklyGoal,
  }) {
    final days = <LocalDate, DayActivity>{};
    var completed = 0;
    var partial = 0;
    var active = 0;
    for (final s in sessions) {
      if (s.status == SessionStatus.abandoned) continue;
      final day = days.putIfAbsent(s.localCompletionDate, DayActivity.new);
      if (s.status == SessionStatus.completed) {
        day.completed++;
        completed++;
      } else {
        day.partial++;
        partial++;
      }
      day.activeSeconds += s.activeSeconds;
      active += s.activeSeconds;
    }

    final completedDays = days.entries.where((e) => e.value.hasCompleted).map((e) => e.key).toSet();

    var current = 0;
    var cursor = completedDays.contains(today) ? today : today.addDays(-1);
    while (completedDays.contains(cursor)) {
      current++;
      cursor = cursor.addDays(-1);
    }

    final sorted = completedDays.toList()..sort();
    var longest = 0;
    var run = 0;
    LocalDate? previous;
    for (final day in sorted) {
      run = (previous != null && day.daysSince(previous) == 1) ? run + 1 : 1;
      if (run > longest) longest = run;
      previous = day;
    }

    final weekStart = today.startOfWeek;
    var weekCompleted = 0;
    var weekActive = 0;
    for (var i = 0; i < 7; i++) {
      final day = days[weekStart.addDays(i)];
      if (day == null) continue;
      weekCompleted += day.completed;
      weekActive += day.activeSeconds;
    }

    int completedInWeek(LocalDate monday) {
      var count = 0;
      for (var i = 0; i < 7; i++) {
        count += days[monday.addDays(i)]?.completed ?? 0;
      }
      return count;
    }

    final goal = weeklyGoal < 1 ? 1 : weeklyGoal;
    var goalStreak = weekCompleted >= goal ? 1 : 0;
    var week = weekStart.addDays(-7);
    while (completedInWeek(week) >= goal) {
      goalStreak++;
      week = week.addDays(-7);
    }

    return StatsSnapshot._(
      today: today,
      weeklyGoal: goal,
      days: days,
      totalCompleted: completed,
      totalPartial: partial,
      totalActiveSeconds: active,
      currentStreak: current,
      longestStreak: longest,
      thisWeekCompleted: weekCompleted,
      thisWeekActiveSeconds: weekActive,
      weeklyGoalStreak: goalStreak,
    );
  }

  final LocalDate today;
  final int weeklyGoal;
  final Map<LocalDate, DayActivity> days;
  final int totalCompleted;
  final int totalPartial;
  final int totalActiveSeconds;
  final int currentStreak;
  final int longestStreak;
  final int thisWeekCompleted;
  final int thisWeekActiveSeconds;

  /// Consecutive Monday–Sunday weeks in which the weekly goal was met. The
  /// current week counts once the goal is reached; an unfinished current
  /// week never breaks the run.
  final int weeklyGoalStreak;

  bool get hasHistory => days.isNotEmpty;
  double get weeklyProgress => (thisWeekCompleted / weeklyGoal).clamp(0.0, 1.0);

  DayActivity? activityOn(LocalDate date) => days[date];

  List<ActivityBucket> buckets(ActivityRange range) => switch (range) {
    ActivityRange.week => _daily(7),
    ActivityRange.month => _daily(30),
    ActivityRange.weeks => _weekly(12),
    ActivityRange.months => _monthly(12),
  };

  List<ActivityBucket> _daily(int count) => [
    for (var i = count - 1; i >= 0; i--)
      _bucket(today.addDays(-i), 1, _dayLabel(today.addDays(-i), count)),
  ];

  List<ActivityBucket> _weekly(int count) {
    final monday = today.startOfWeek;
    return [
      for (var i = count - 1; i >= 0; i--)
        _bucket(
          monday.addDays(-7 * i),
          7,
          '${monday.addDays(-7 * i).day}/${monday.addDays(-7 * i).month}',
        ),
    ];
  }

  List<ActivityBucket> _monthly(int count) {
    final result = <ActivityBucket>[];
    for (var i = count - 1; i >= 0; i--) {
      final start = today.startOfMonth.addMonthsToStart(-i);
      result.add(_bucket(start, start.daysInMonth, _monthLabel(start.month)));
    }
    return result;
  }

  ActivityBucket _bucket(LocalDate start, int length, String label) {
    var active = 0;
    var done = 0;
    for (var i = 0; i < length; i++) {
      final day = days[start.addDays(i)];
      if (day == null) continue;
      active += day.activeSeconds;
      done += day.completed;
    }
    return ActivityBucket(
      start: start,
      label: label,
      activeSeconds: active,
      completedWorkouts: done,
    );
  }

  static String _dayLabel(LocalDate date, int count) =>
      count <= 7 ? const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][date.weekday - 1] : '${date.day}';

  static String _monthLabel(int month) =>
      const ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'][month - 1];
}
