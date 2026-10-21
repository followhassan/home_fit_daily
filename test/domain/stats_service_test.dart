import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/domain/stats_service.dart';

import '../helpers/sessions.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

void main() {
  final today = d('2026-10-21'); // Wednesday

  test('empty history gives honest zeros', () {
    final s = StatsSnapshot.compute([], today: today, weeklyGoal: 3);
    expect(s.totalCompleted, 0);
    expect(s.totalActiveSeconds, 0);
    expect(s.currentStreak, 0);
    expect(s.longestStreak, 0);
    expect(s.thisWeekCompleted, 0);
    expect(s.hasHistory, isFalse);
    expect(s.buckets(ActivityRange.week).every((b) => b.activeSeconds == 0), isTrue);
  });

  test('only completed sessions count as workouts and streak days', () {
    final s = StatsSnapshot.compute(
      [
        sessionOn(today),
        sessionOn(today.addDays(-1), status: SessionStatus.partial),
        sessionOn(today.addDays(-2), status: SessionStatus.abandoned),
      ],
      today: today,
      weeklyGoal: 3,
    );
    expect(s.totalCompleted, 1);
    expect(s.totalPartial, 1);
    expect(s.currentStreak, 1);
    // Partial sessions add active time; abandoned ones do not.
    expect(s.totalActiveSeconds, 1200);
  });

  test('a streak continues from yesterday until today is over', () {
    final s = StatsSnapshot.compute(
      [sessionOn(today.addDays(-1)), sessionOn(today.addDays(-2)), sessionOn(today.addDays(-3))],
      today: today,
      weeklyGoal: 3,
    );
    expect(s.currentStreak, 3);
  });

  test('a missed day breaks the streak; longest streak is kept', () {
    final s = StatsSnapshot.compute(
      [
        sessionOn(today),
        sessionOn(today.addDays(-2)),
        sessionOn(today.addDays(-3)),
        sessionOn(today.addDays(-4)),
      ],
      today: today,
      weeklyGoal: 3,
    );
    expect(s.currentStreak, 1);
    expect(s.longestStreak, 3);
  });

  test('several sessions on one day count once for the streak', () {
    final s = StatsSnapshot.compute(
      [sessionOn(today), sessionOn(today)],
      today: today,
      weeklyGoal: 3,
    );
    expect(s.totalCompleted, 2);
    expect(s.currentStreak, 1);
  });

  test('streaks cross month and year boundaries', () {
    final newYear = d('2027-01-01');
    final s = StatsSnapshot.compute(
      [sessionOn(d('2026-12-30')), sessionOn(d('2026-12-31')), sessionOn(newYear)],
      today: newYear,
      weeklyGoal: 3,
    );
    expect(s.currentStreak, 3);
  });

  test('the week runs Monday to Sunday', () {
    final s = StatsSnapshot.compute(
      [
        sessionOn(d('2026-10-19')), // Monday this week
        sessionOn(d('2026-10-18')), // Sunday last week
      ],
      today: today,
      weeklyGoal: 2,
    );
    expect(s.thisWeekCompleted, 1);
    expect(s.weeklyProgress, 0.5);
  });

  test('history uses the stored local date, not the UTC timestamp', () {
    // Completed late in the evening locally; UTC is already the next day.
    final late = sessionOn(d('2026-10-20'));
    final s = StatsSnapshot.compute([late], today: today, weeklyGoal: 3);
    expect(s.activityOn(d('2026-10-20'))?.completed, 1);
    expect(s.activityOn(d('2026-10-21')), isNull);
  });

  test('weeks on target count consecutive weeks meeting the goal', () {
    final s = StatsSnapshot.compute(
      [
        // Last week: 2 sessions; the week before: 2 sessions.
        sessionOn(d('2026-10-13')),
        sessionOn(d('2026-10-15')),
        sessionOn(d('2026-10-06')),
        sessionOn(d('2026-10-08')),
        // Three weeks ago: only 1.
        sessionOn(d('2026-09-30')),
      ],
      today: today,
      weeklyGoal: 2,
    );
    // Current week not yet met, which does not break the run.
    expect(s.weeklyGoalStreak, 2);
  });

  test('chart buckets sum real activity', () {
    final s = StatsSnapshot.compute(
      [sessionOn(today, activeSeconds: 300), sessionOn(today.addDays(-1), activeSeconds: 600)],
      today: today,
      weeklyGoal: 3,
    );
    final week = s.buckets(ActivityRange.week);
    expect(week.length, 7);
    expect(week.last.activeSeconds, 300);
    expect(week[5].activeSeconds, 600);
    final months = s.buckets(ActivityRange.months);
    expect(months.length, 12);
    expect(months.last.activeSeconds, 900);
    expect(months.last.start, d('2026-10-01'));
  });
}
