import '../core/utils/local_date.dart';
import '../data/models/enums.dart';
import '../data/models/plan_enrollment.dart';
import '../data/models/training_plan.dart';
import '../data/models/workout_session.dart';

enum AssignmentStatus {
  completed('Completed'),
  today('Today'),
  upcoming('Upcoming'),
  missed('Missed'),
  skipped('Skipped'),
  rest('Rest day'),
  onHold('On hold');

  const AssignmentStatus(this.label);
  final String label;

  bool get isPending => this == AssignmentStatus.today || this == AssignmentStatus.upcoming;
}

class AssignmentView {
  const AssignmentView({required this.assignment, required this.status, this.completedBy});

  final PlanAssignment assignment;
  final AssignmentStatus status;

  /// The completed session linked to this assignment, if any.
  final WorkoutSession? completedBy;
}

/// Derived progress of one enrollment at a given date.
class EnrollmentProgress {
  EnrollmentProgress._({required this.enrollment, required this.views, required this.today});

  final PlanEnrollment enrollment;
  final List<AssignmentView> views;
  final LocalDate today;

  Iterable<AssignmentView> get _training => views.where((v) => v.assignment.isTraining);

  int get eligibleCount => _training.length;
  int get completedCount => _training.where((v) => v.status == AssignmentStatus.completed).length;
  int get missedCount => _training.where((v) => v.status == AssignmentStatus.missed).length;
  int get skippedCount => _training.where((v) => v.status == AssignmentStatus.skipped).length;

  /// Completed share of training (workout and recovery) assignments. Rest
  /// days are not counted.
  double get completionFraction => eligibleCount == 0 ? 0 : completedCount / eligibleCount;

  List<AssignmentView> get missed =>
      _training.where((v) => v.status == AssignmentStatus.missed).toList();

  /// The assignment scheduled for today (training or rest), if any.
  AssignmentView? get todayView {
    AssignmentView? rest;
    for (final v in views) {
      if (v.assignment.scheduledDate != today) continue;
      if (v.assignment.isTraining) return v;
      rest ??= v;
    }
    return rest;
  }

  /// Pending training assignments from today onwards, in date order.
  List<AssignmentView> get upcoming =>
      _training.where((v) => v.status.isPending).toList()
        ..sort((a, b) => a.assignment.scheduledDate.compareTo(b.assignment.scheduledDate));

  /// Plan day reached today (1–28) based on the schedule.
  int get currentDay {
    var day = 1;
    for (final v in views) {
      if (!v.assignment.scheduledDate.isAfter(today) && v.assignment.dayNumber > day) {
        day = v.assignment.dayNumber;
      }
    }
    return day;
  }

  int get currentWeek => (currentDay - 1) ~/ 7 + 1;

  LocalDate get lastScheduledDate =>
      views.map((v) => v.assignment.scheduledDate).reduce((a, b) => a.isAfter(b) ? a : b);

  /// Every training day is done or skipped, or the schedule has ended.
  bool get isFinished =>
      _training.every(
        (v) => v.status == AssignmentStatus.completed || v.status == AssignmentStatus.skipped,
      ) ||
      today.isAfter(lastScheduledDate);
}

class ScheduleException implements Exception {
  const ScheduleException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Pure scheduling rules for training plans.
abstract final class PlanScheduler {
  static const int maxStartDelayDays = 14;

  static PlanEnrollment enroll(
    TrainingPlan plan, {
    required String enrollmentId,
    required LocalDate startDate,
    required DateTime nowUtc,
  }) {
    return PlanEnrollment(
      id: enrollmentId,
      planId: plan.id,
      planTitle: plan.title,
      planContentVersion: plan.contentVersion,
      startDate: startDate,
      status: EnrollmentStatus.active,
      assignments: [
        for (final day in plan.days)
          PlanAssignment(
            id: '${enrollmentId}_d${day.dayNumber}',
            dayNumber: day.dayNumber,
            type: day.type,
            workoutId: day.type.isTraining ? day.workoutId : null,
            note: day.note,
            scheduledDate: startDate.addDays(day.dayNumber - 1),
          ),
      ],
      createdAt: nowUtc,
      updatedAt: nowUtc,
    );
  }

  /// Completed sessions linked to this enrollment, keyed by assignment ID.
  /// Only an explicit assignment link counts – never a matching workout ID.
  static Map<String, WorkoutSession> completedLinks(
    PlanEnrollment enrollment,
    Iterable<WorkoutSession> sessions,
  ) {
    final ids = {for (final a in enrollment.assignments) a.id};
    final result = <String, WorkoutSession>{};
    for (final s in sessions) {
      final link = s.planAssignmentId;
      if (link == null || s.status != SessionStatus.completed) continue;
      if (!ids.contains(link)) continue;
      final existing = result[link];
      if (existing == null || s.completedAtUtc.isBefore(existing.completedAtUtc)) {
        result[link] = s;
      }
    }
    return result;
  }

  static EnrollmentProgress progress(
    PlanEnrollment enrollment,
    Iterable<WorkoutSession> sessions,
    LocalDate today,
  ) {
    final links = completedLinks(enrollment, sessions);
    final paused = enrollment.status == EnrollmentStatus.paused ? enrollment.pausedOn : null;
    final views = [
      for (final a in enrollment.assignments)
        AssignmentView(
          assignment: a,
          status: _status(a, links.containsKey(a.id), paused, today),
          completedBy: links[a.id],
        ),
    ];
    return EnrollmentProgress._(enrollment: enrollment, views: views, today: today);
  }

  static AssignmentStatus _status(
    PlanAssignment a,
    bool completed,
    LocalDate? pausedOn,
    LocalDate today,
  ) {
    if (!a.isTraining) return AssignmentStatus.rest;
    if (completed) return AssignmentStatus.completed;
    if (a.skipped) return AssignmentStatus.skipped;
    if (pausedOn != null && !a.scheduledDate.isBefore(pausedOn)) {
      return AssignmentStatus.onHold;
    }
    if (a.scheduledDate.isBefore(today)) return AssignmentStatus.missed;
    if (a.scheduledDate == today) return AssignmentStatus.today;
    return AssignmentStatus.upcoming;
  }

  /// Moves a training assignment to [newDate] and shifts every later,
  /// unfinished assignment (including rest days) by the same number of days.
  ///
  /// The schedule keeps its order and rest spacing; workouts are never
  /// doubled up on one day. Only moving later is supported.
  static PlanEnrollment reschedule(
    PlanEnrollment enrollment,
    String assignmentId,
    LocalDate newDate, {
    required Iterable<WorkoutSession> sessions,
    required LocalDate today,
    required DateTime nowUtc,
  }) {
    if (!enrollment.status.isCurrent) {
      throw const ScheduleException('This plan is no longer active.');
    }
    final target = enrollment.assignmentById(assignmentId);
    if (target == null || !target.isTraining) {
      throw const ScheduleException('Only training days can be rescheduled.');
    }
    final completed = completedLinks(enrollment, sessions);
    if (completed.containsKey(target.id)) {
      throw const ScheduleException('This session is already completed.');
    }
    if (newDate.isBefore(today)) {
      throw const ScheduleException('Choose today or a later date.');
    }
    final delta = newDate.daysSince(target.scheduledDate);
    if (delta <= 0) {
      throw const ScheduleException('Sessions can only be moved to a later date.');
    }
    final updated = [
      for (final a in enrollment.assignments)
        if (a.dayNumber >= target.dayNumber && !completed.containsKey(a.id))
          a.copyWith(
            scheduledDate: a.scheduledDate.addDays(delta),
            originalDate: a.originalDate ?? a.scheduledDate,
            skipped: a.id == target.id ? false : a.skipped,
          )
        else
          a,
    ];
    return enrollment.copyWith(assignments: updated, updatedAt: nowUtc);
  }

  static PlanEnrollment setSkipped(
    PlanEnrollment enrollment,
    String assignmentId,
    bool skipped, {
    required DateTime nowUtc,
  }) {
    final updated = [
      for (final a in enrollment.assignments)
        a.id == assignmentId && a.isTraining ? a.copyWith(skipped: skipped) : a,
    ];
    return enrollment.copyWith(assignments: updated, updatedAt: nowUtc);
  }

  static PlanEnrollment pause(
    PlanEnrollment enrollment, {
    required LocalDate today,
    required DateTime nowUtc,
  }) {
    if (enrollment.status != EnrollmentStatus.active) return enrollment;
    return enrollment.copyWith(status: EnrollmentStatus.paused, pausedOn: today, updatedAt: nowUtc);
  }

  /// Resumes a paused plan, shifting unfinished assignments from the pause
  /// date forward by the length of the pause.
  static PlanEnrollment resume(
    PlanEnrollment enrollment, {
    required Iterable<WorkoutSession> sessions,
    required LocalDate today,
    required DateTime nowUtc,
  }) {
    if (enrollment.status != EnrollmentStatus.paused) return enrollment;
    final pausedOn = enrollment.pausedOn ?? today;
    final delta = today.daysSince(pausedOn);
    final completed = completedLinks(enrollment, sessions);
    final updated = delta <= 0
        ? enrollment.assignments
        : [
            for (final a in enrollment.assignments)
              if (!completed.containsKey(a.id) && !a.scheduledDate.isBefore(pausedOn))
                a.copyWith(
                  scheduledDate: a.scheduledDate.addDays(delta),
                  originalDate: a.originalDate ?? a.scheduledDate,
                )
              else
                a,
          ];
    return enrollment.copyWith(
      status: EnrollmentStatus.active,
      assignments: updated,
      clearPausedOn: true,
      updatedAt: nowUtc,
    );
  }

  static PlanEnrollment close(
    PlanEnrollment enrollment,
    EnrollmentStatus status, {
    required DateTime nowUtc,
  }) => enrollment.copyWith(status: status, clearPausedOn: true, updatedAt: nowUtc);
}
