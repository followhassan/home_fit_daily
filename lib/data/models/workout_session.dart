import '../../core/utils/json_utils.dart';
import '../../core/utils/local_date.dart';
import 'enums.dart';
import 'workout.dart';

/// An immutable copy of the workout as it was when a session started.
///
/// Sessions keep this snapshot so later edits to a custom workout, or catalog
/// updates, never rewrite history.
class WorkoutSnapshot {
  const WorkoutSnapshot({required this.workout, required this.exerciseNames});

  factory WorkoutSnapshot.fromJson(JsonMap json) => WorkoutSnapshot(
    workout: Workout.fromJson(asJsonMap(json['workout'], 'workout')),
    exerciseNames: asJsonMap(
      json['exerciseNames'] ?? const <String, dynamic>{},
      'exerciseNames',
    ).map((k, v) => MapEntry(k, v is String ? v : k)),
  );

  final Workout workout;
  final Map<String, String> exerciseNames;

  String nameOf(String exerciseId) => exerciseNames[exerciseId] ?? exerciseId;

  JsonMap toJson() => {'workout': workout.toJson(), 'exerciseNames': exerciseNames};
}

/// What happened to one exercise segment (one set, one side) in a session.
class SessionStepRecord {
  const SessionStepRecord({
    required this.segmentIndex,
    required this.stepId,
    required this.exerciseId,
    required this.round,
    required this.set,
    required this.side,
    required this.execution,
    required this.targetSeconds,
    required this.targetReps,
    required this.outcome,
    required this.activeSeconds,
  });

  factory SessionStepRecord.fromJson(JsonMap json) => SessionStepRecord(
    segmentIndex: readInt(json, 'segment'),
    stepId: readString(json, 'stepId'),
    exerciseId: readString(json, 'exerciseId'),
    round: readIntOr(json, 'round', 1),
    set: readIntOr(json, 'set', 1),
    side: parseEnumOr(Side.values, json['side'], Side.none),
    execution: parseEnumOr(ExecutionType.values, json['execution'], ExecutionType.timed),
    targetSeconds: readOptionalInt(json, 'targetSeconds'),
    targetReps: readOptionalInt(json, 'targetReps'),
    outcome: parseEnum(StepOutcome.values, json['outcome'], 'outcome'),
    activeSeconds: readIntOr(json, 'activeSeconds', 0),
  );

  final int segmentIndex;
  final String stepId;
  final String exerciseId;
  final int round;
  final int set;
  final Side side;
  final ExecutionType execution;
  final int? targetSeconds;
  final int? targetReps;
  final StepOutcome outcome;
  final int activeSeconds;

  JsonMap toJson() => {
    'segment': segmentIndex,
    'stepId': stepId,
    'exerciseId': exerciseId,
    'round': round,
    'set': set,
    'side': side.json,
    'execution': execution.json,
    if (targetSeconds != null) 'targetSeconds': targetSeconds,
    if (targetReps != null) 'targetReps': targetReps,
    'outcome': outcome.json,
    'activeSeconds': activeSeconds,
  };
}

/// A finished workout session stored in history.
///
/// Timestamps are stored in UTC together with the local calendar date and
/// time-zone offset at completion, so history and streaks stay stable when
/// the user travels or the device time zone changes.
class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.sourceWorkoutId,
    required this.source,
    required this.snapshot,
    required this.startedAtUtc,
    required this.completedAtUtc,
    required this.localCompletionDate,
    required this.timezoneOffsetMinutes,
    required this.status,
    required this.stepRecords,
    required this.activeSeconds,
    required this.restSeconds,
    required this.preparationSeconds,
    required this.elapsedSeconds,
    this.planAssignmentId,
    this.enrollmentId,
    this.effortRating,
    this.note,
    this.importedFromLegacy = false,
  });

  factory WorkoutSession.fromJson(JsonMap json) {
    final id = readString(json, 'id');
    try {
      final completedAt = readDateTime(json, 'completedAtUtc').toUtc();
      final localDate =
          LocalDate.tryParse(json['localCompletionDate']) ??
          LocalDate.fromDateTime(completedAt.toLocal());
      return WorkoutSession(
        id: id,
        sourceWorkoutId: readString(json, 'sourceWorkoutId'),
        source: parseEnumOr(WorkoutSource.values, json['source'], WorkoutSource.catalog),
        snapshot: WorkoutSnapshot.fromJson(asJsonMap(json['workoutSnapshot'], 'workoutSnapshot')),
        startedAtUtc: readDateTime(json, 'startedAtUtc').toUtc(),
        completedAtUtc: completedAt,
        localCompletionDate: localDate,
        timezoneOffsetMinutes: readIntOr(json, 'timezoneOffsetMinutes', 0),
        status: parseEnum(SessionStatus.values, json['status'], 'status'),
        stepRecords: readObjectList(json, 'steps', SessionStepRecord.fromJson),
        activeSeconds: readIntOr(json, 'activeSeconds', 0),
        restSeconds: readIntOr(json, 'restSeconds', 0),
        preparationSeconds: readIntOr(json, 'preparationSeconds', 0),
        elapsedSeconds: readIntOr(json, 'elapsedSeconds', 0),
        planAssignmentId: readOptionalString(json, 'planAssignmentId'),
        enrollmentId: readOptionalString(json, 'enrollmentId'),
        effortRating: parseEnumOrNull(EffortRating.values, json['effortRating']),
        note: readOptionalString(json, 'note'),
        importedFromLegacy: readBool(json, 'importedFromLegacy'),
      );
    } on FormatException catch (e) {
      throw FormatException('session "$id": ${e.message}');
    }
  }

  final String id;
  final String sourceWorkoutId;
  final WorkoutSource source;
  final WorkoutSnapshot snapshot;
  final DateTime startedAtUtc;
  final DateTime completedAtUtc;
  final LocalDate localCompletionDate;
  final int timezoneOffsetMinutes;
  final SessionStatus status;
  final List<SessionStepRecord> stepRecords;

  /// Time spent in exercise segments, excluding pauses.
  final int activeSeconds;

  /// Time spent resting and switching sides, excluding pauses.
  final int restSeconds;

  /// "Get ready" countdown time, excluding pauses.
  final int preparationSeconds;

  /// Active + rest + preparation. Paused time is never included.
  final int elapsedSeconds;
  final String? planAssignmentId;
  final String? enrollmentId;
  final EffortRating? effortRating;
  final String? note;

  /// True for history converted from the earlier prototype's data format.
  final bool importedFromLegacy;

  String get title => snapshot.workout.title;

  bool get countsAsCompleted => status == SessionStatus.completed;

  /// Completed and partial sessions count toward active minutes.
  bool get countsTowardActivity => status != SessionStatus.abandoned;

  int get completedSteps => stepRecords.where((r) => r.outcome == StepOutcome.completed).length;

  int get skippedSteps => stepRecords.where((r) => r.outcome == StepOutcome.skipped).length;

  int get totalSteps => stepRecords.length;

  WorkoutSession copyWith({
    EffortRating? effortRating,
    bool clearEffort = false,
    String? note,
    bool clearNote = false,
  }) => WorkoutSession(
    id: id,
    sourceWorkoutId: sourceWorkoutId,
    source: source,
    snapshot: snapshot,
    startedAtUtc: startedAtUtc,
    completedAtUtc: completedAtUtc,
    localCompletionDate: localCompletionDate,
    timezoneOffsetMinutes: timezoneOffsetMinutes,
    status: status,
    stepRecords: stepRecords,
    activeSeconds: activeSeconds,
    restSeconds: restSeconds,
    preparationSeconds: preparationSeconds,
    elapsedSeconds: elapsedSeconds,
    planAssignmentId: planAssignmentId,
    enrollmentId: enrollmentId,
    effortRating: clearEffort ? null : (effortRating ?? this.effortRating),
    note: clearNote ? null : (note ?? this.note),
    importedFromLegacy: importedFromLegacy,
  );

  JsonMap toJson() => {
    'v': 1,
    'id': id,
    'sourceWorkoutId': sourceWorkoutId,
    'source': source.json,
    'workoutSnapshot': snapshot.toJson(),
    'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
    'completedAtUtc': completedAtUtc.toUtc().toIso8601String(),
    'localCompletionDate': localCompletionDate.toIso(),
    'timezoneOffsetMinutes': timezoneOffsetMinutes,
    'status': status.json,
    'steps': stepRecords.map((r) => r.toJson()).toList(),
    'activeSeconds': activeSeconds,
    'restSeconds': restSeconds,
    'preparationSeconds': preparationSeconds,
    'elapsedSeconds': elapsedSeconds,
    if (planAssignmentId != null) 'planAssignmentId': planAssignmentId,
    if (enrollmentId != null) 'enrollmentId': enrollmentId,
    if (effortRating != null) 'effortRating': effortRating!.json,
    if (note != null) 'note': note,
    if (importedFromLegacy) 'importedFromLegacy': true,
  };
}
