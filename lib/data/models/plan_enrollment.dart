import '../../core/utils/json_utils.dart';
import '../../core/utils/local_date.dart';
import 'enums.dart';

/// One explicitly scheduled day of an enrolled plan.
///
/// Completion is never stored here: an assignment counts as completed only
/// when a *completed* session carries this assignment's [id]. Repeating the
/// same workout outside the plan therefore never completes plan days.
class PlanAssignment {
  const PlanAssignment({
    required this.id,
    required this.dayNumber,
    required this.type,
    required this.scheduledDate,
    this.workoutId,
    this.note,
    this.skipped = false,
    this.originalDate,
  });

  factory PlanAssignment.fromJson(JsonMap json) => PlanAssignment(
    id: readString(json, 'id'),
    dayNumber: readInt(json, 'day'),
    type: parseEnum(PlanDayType.values, json['type'], 'type'),
    scheduledDate: LocalDate.parse(readString(json, 'date')),
    workoutId: readOptionalString(json, 'workoutId'),
    note: readOptionalString(json, 'note'),
    skipped: readBool(json, 'skipped'),
    originalDate: LocalDate.tryParse(json['originalDate']),
  );

  final String id;
  final int dayNumber;
  final PlanDayType type;
  final LocalDate scheduledDate;
  final String? workoutId;
  final String? note;

  /// The user chose to skip this session.
  final bool skipped;

  /// First scheduled date when the assignment has been rescheduled.
  final LocalDate? originalDate;

  int get weekNumber => (dayNumber - 1) ~/ 7 + 1;
  bool get isTraining => type.isTraining && workoutId != null;
  bool get wasRescheduled => originalDate != null && originalDate != scheduledDate;

  PlanAssignment copyWith({LocalDate? scheduledDate, bool? skipped, LocalDate? originalDate}) =>
      PlanAssignment(
        id: id,
        dayNumber: dayNumber,
        type: type,
        scheduledDate: scheduledDate ?? this.scheduledDate,
        workoutId: workoutId,
        note: note,
        skipped: skipped ?? this.skipped,
        originalDate: originalDate ?? this.originalDate,
      );

  JsonMap toJson() => {
    'id': id,
    'day': dayNumber,
    'type': type.json,
    'date': scheduledDate.toIso(),
    if (workoutId != null) 'workoutId': workoutId,
    if (note != null) 'note': note,
    if (skipped) 'skipped': true,
    if (originalDate != null) 'originalDate': originalDate!.toIso(),
  };
}

/// The user's enrollment in a training plan.
///
/// Day definitions are copied into [assignments] at enrollment time so later
/// catalog updates never rewrite a plan that is already in progress.
class PlanEnrollment {
  const PlanEnrollment({
    required this.id,
    required this.planId,
    required this.planTitle,
    required this.planContentVersion,
    required this.startDate,
    required this.status,
    required this.assignments,
    required this.createdAt,
    required this.updatedAt,
    this.pausedOn,
  });

  factory PlanEnrollment.fromJson(JsonMap json) {
    final id = readString(json, 'id');
    try {
      return PlanEnrollment(
        id: id,
        planId: readString(json, 'planId'),
        planTitle: readString(json, 'planTitle'),
        planContentVersion: readIntOr(json, 'planContentVersion', 1),
        startDate: LocalDate.parse(readString(json, 'startDate')),
        status: parseEnum(EnrollmentStatus.values, json['status'], 'status'),
        assignments: readObjectList(json, 'assignments', PlanAssignment.fromJson),
        createdAt: readDateTime(json, 'createdAt').toUtc(),
        updatedAt: readDateTime(json, 'updatedAt').toUtc(),
        pausedOn: LocalDate.tryParse(json['pausedOn']),
      );
    } on FormatException catch (e) {
      throw FormatException('enrollment "$id": ${e.message}');
    }
  }

  final String id;
  final String planId;
  final String planTitle;
  final int planContentVersion;
  final LocalDate startDate;
  final EnrollmentStatus status;
  final List<PlanAssignment> assignments;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Date the plan was paused; assignments from this date are on hold.
  final LocalDate? pausedOn;

  PlanAssignment? assignmentById(String assignmentId) {
    for (final a in assignments) {
      if (a.id == assignmentId) return a;
    }
    return null;
  }

  PlanEnrollment copyWith({
    EnrollmentStatus? status,
    List<PlanAssignment>? assignments,
    DateTime? updatedAt,
    LocalDate? pausedOn,
    bool clearPausedOn = false,
  }) => PlanEnrollment(
    id: id,
    planId: planId,
    planTitle: planTitle,
    planContentVersion: planContentVersion,
    startDate: startDate,
    status: status ?? this.status,
    assignments: assignments ?? this.assignments,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    pausedOn: clearPausedOn ? null : (pausedOn ?? this.pausedOn),
  );

  JsonMap toJson() => {
    'id': id,
    'planId': planId,
    'planTitle': planTitle,
    'planContentVersion': planContentVersion,
    'startDate': startDate.toIso(),
    'status': status.json,
    'assignments': assignments.map((a) => a.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    if (pausedOn != null) 'pausedOn': pausedOn!.toIso(),
  };
}
