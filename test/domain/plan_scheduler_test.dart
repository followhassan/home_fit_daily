import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/plan_enrollment.dart';
import 'package:home_fit_daily/data/models/training_plan.dart';
import 'package:home_fit_daily/domain/plan_scheduler.dart';

import '../helpers/sessions.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

TrainingPlan _plan() => TrainingPlan(
  id: 'plan',
  title: 'Plan',
  summary: 'summary',
  description: 'description',
  difficulty: Difficulty.beginner,
  goal: FitnessGoal.consistency,
  weeklySchedule: 'schedule',
  progressionNotes: 'progression',
  recoveryGuidance: 'recovery',
  weeks: const [],
  days: [
    for (var day = 1; day <= 28; day++)
      day % 2 == 1
          ? PlanDay(dayNumber: day, type: PlanDayType.workout, workoutId: 'w$day')
          : PlanDay(dayNumber: day, type: PlanDayType.rest),
  ],
  tags: const [],
  contentVersion: 1,
);

void main() {
  final start = d('2026-10-01');
  final now = DateTime.utc(2026, 10, 1);
  late PlanEnrollment enrollment;

  setUp(() {
    enrollment = PlanScheduler.enroll(_plan(), enrollmentId: 'e1', startDate: start, nowUtc: now);
  });

  test('every calendar day is an explicit assignment', () {
    expect(enrollment.assignments.length, 28);
    expect(enrollment.assignments.first.scheduledDate, start);
    expect(enrollment.assignments.last.scheduledDate, start.addDays(27));
    expect(enrollment.assignments[1].type, PlanDayType.rest);
    expect(enrollment.assignments[1].workoutId, isNull);
  });

  test('only a completed session linked to the assignment completes it', () {
    final day1 = enrollment.assignments.first;
    final sessions = [
      // Same workout done independently: must NOT complete the plan day.
      sessionOn(start, workoutId: day1.workoutId!),
      // Linked but only partial: must not complete it either.
      sessionOn(
        start,
        workoutId: day1.workoutId!,
        assignmentId: day1.id,
        status: SessionStatus.partial,
      ),
    ];
    var p = PlanScheduler.progress(enrollment, sessions, start);
    expect(p.views.first.status, AssignmentStatus.today);

    sessions.add(sessionOn(start, assignmentId: day1.id, workoutId: day1.workoutId!));
    p = PlanScheduler.progress(enrollment, sessions, start);
    expect(p.views.first.status, AssignmentStatus.completed);
    expect(p.completedCount, 1);
  });

  test('one repeated workout cannot complete several plan days', () {
    final a1 = enrollment.assignments[0];
    final sessions = [
      sessionOn(start, assignmentId: a1.id, workoutId: a1.workoutId!),
      sessionOn(start.addDays(2), assignmentId: a1.id, workoutId: a1.workoutId!),
    ];
    final p = PlanScheduler.progress(enrollment, sessions, start.addDays(2));
    expect(p.completedCount, 1);
  });

  test('rest days are not counted in completion percentage', () {
    final p = PlanScheduler.progress(enrollment, const [], start);
    expect(p.eligibleCount, 14);
    expect(p.views[1].status, AssignmentStatus.rest);
  });

  test('past unfinished training days are missed and stay visible', () {
    final p = PlanScheduler.progress(enrollment, const [], start.addDays(4));
    expect(p.missedCount, 2); // days 1 and 3
    expect(p.missed.map((v) => v.assignment.dayNumber), [1, 3]);
    expect(p.currentDay, 5);
    expect(p.todayView?.assignment.dayNumber, 5);
  });

  test('rescheduling shifts later unfinished days without doubling up', () {
    final today = start.addDays(4); // day 5
    final day3 = enrollment.assignments[2];
    final moved = PlanScheduler.reschedule(
      enrollment,
      day3.id,
      today,
      sessions: const [],
      today: today,
      nowUtc: now,
    );
    final byDay = {for (final a in moved.assignments) a.dayNumber: a};
    expect(byDay[3]!.scheduledDate, today);
    expect(byDay[3]!.originalDate, start.addDays(2));
    expect(byDay[3]!.wasRescheduled, isTrue);
    // Every later day moved by the same two days, keeping the order.
    expect(byDay[5]!.scheduledDate, start.addDays(6));
    expect(byDay[28]!.scheduledDate, start.addDays(29));
    // Earlier days are untouched.
    expect(byDay[1]!.scheduledDate, start);
    // No two training days share a date.
    final trainingDates = moved.assignments
        .where((a) => a.isTraining)
        .map((a) => a.scheduledDate)
        .toList();
    expect(trainingDates.toSet().length, trainingDates.length);
  });

  test('completed later days do not move when rescheduling', () {
    final day3 = enrollment.assignments[2];
    final day5 = enrollment.assignments[4];
    final sessions = [sessionOn(start.addDays(4), assignmentId: day5.id)];
    final moved = PlanScheduler.reschedule(
      enrollment,
      day3.id,
      start.addDays(5),
      sessions: sessions,
      today: start.addDays(5),
      nowUtc: now,
    );
    expect(moved.assignmentById(day5.id)!.scheduledDate, start.addDays(4));
  });

  test('invalid reschedules are rejected with a message', () {
    final today = start.addDays(4);
    expect(
      () => PlanScheduler.reschedule(
        enrollment,
        enrollment.assignments[1].id, // rest day
        today,
        sessions: const [],
        today: today,
        nowUtc: now,
      ),
      throwsA(isA<ScheduleException>()),
    );
    expect(
      () => PlanScheduler.reschedule(
        enrollment,
        enrollment.assignments[2].id,
        today.addDays(-1), // in the past
        sessions: const [],
        today: today,
        nowUtc: now,
      ),
      throwsA(isA<ScheduleException>()),
    );
  });

  test('pausing puts days on hold; resuming shifts them by the pause length', () {
    final paused = PlanScheduler.pause(enrollment, today: start.addDays(2), nowUtc: now);
    expect(paused.status, EnrollmentStatus.paused);
    var p = PlanScheduler.progress(paused, const [], start.addDays(6));
    expect(p.views[2].status, AssignmentStatus.onHold); // day 3, scheduled on pause day
    expect(p.views[0].status, AssignmentStatus.missed); // before the pause

    final resumed = PlanScheduler.resume(
      paused,
      sessions: const [],
      today: start.addDays(6),
      nowUtc: now,
    );
    expect(resumed.status, EnrollmentStatus.active);
    expect(resumed.assignments[2].scheduledDate, start.addDays(6));
    p = PlanScheduler.progress(resumed, const [], start.addDays(6));
    expect(p.views[2].status, AssignmentStatus.today);
  });

  test('skipped days count as handled, not missed', () {
    final skipped = PlanScheduler.setSkipped(
      enrollment,
      enrollment.assignments[0].id,
      true,
      nowUtc: now,
    );
    final p = PlanScheduler.progress(skipped, const [], start.addDays(3));
    expect(p.views[0].status, AssignmentStatus.skipped);
    expect(p.missedCount, 1); // only day 3
  });

  test('a plan is finished after its last scheduled day', () {
    final p = PlanScheduler.progress(enrollment, const [], start.addDays(28));
    expect(p.isFinished, isTrue);
  });
}
