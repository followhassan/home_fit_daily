import '../../core/utils/json_utils.dart';
import 'enums.dart';
import 'workout_session.dart';

/// Outcome of a single exercise segment while a session is in progress.
class SegmentResult {
  const SegmentResult({required this.outcome, required this.activeMs});

  factory SegmentResult.fromJson(JsonMap json) => SegmentResult(
    outcome: parseEnum(StepOutcome.values, json['outcome'], 'outcome'),
    activeMs: readIntOr(json, 'activeMs', 0),
  );

  final StepOutcome outcome;
  final int activeMs;

  JsonMap toJson() => {'outcome': outcome.json, 'activeMs': activeMs};
}

/// Serializable engine state. Elapsed values exclude paused time and any
/// time the app spent in the background.
class EngineCheckpoint {
  const EngineCheckpoint({
    required this.state,
    required this.resumeState,
    required this.segmentIndex,
    required this.segmentCount,
    required this.segmentElapsedMs,
    required this.extensionMs,
    required this.activeMs,
    required this.restMs,
    required this.preparationMs,
    required this.results,
    required this.reachedEnd,
  });

  factory EngineCheckpoint.fromJson(JsonMap json) {
    final rawResults = asJsonMap(json['results'] ?? const {}, 'results');
    return EngineCheckpoint(
      state: parseEnum(PlayerState.values, json['state'], 'state'),
      resumeState: parseEnumOrNull(PlayerState.values, json['resumeState']),
      segmentIndex: readInt(json, 'segmentIndex'),
      segmentCount: readInt(json, 'segmentCount'),
      segmentElapsedMs: readIntOr(json, 'segmentElapsedMs', 0),
      extensionMs: readIntOr(json, 'extensionMs', 0),
      activeMs: readIntOr(json, 'activeMs', 0),
      restMs: readIntOr(json, 'restMs', 0),
      preparationMs: readIntOr(json, 'preparationMs', 0),
      results: {
        for (final entry in rawResults.entries)
          int.parse(entry.key): SegmentResult.fromJson(
            asJsonMap(entry.value, 'results.${entry.key}'),
          ),
      },
      reachedEnd: readBool(json, 'reachedEnd'),
    );
  }

  final PlayerState state;
  final PlayerState? resumeState;
  final int segmentIndex;
  final int segmentCount;
  final int segmentElapsedMs;
  final int extensionMs;
  final int activeMs;
  final int restMs;
  final int preparationMs;
  final Map<int, SegmentResult> results;
  final bool reachedEnd;

  JsonMap toJson() => {
    'state': state.json,
    if (resumeState != null) 'resumeState': resumeState!.json,
    'segmentIndex': segmentIndex,
    'segmentCount': segmentCount,
    'segmentElapsedMs': segmentElapsedMs,
    'extensionMs': extensionMs,
    'activeMs': activeMs,
    'restMs': restMs,
    'preparationMs': preparationMs,
    'results': {for (final entry in results.entries) '${entry.key}': entry.value.toJson()},
    'reachedEnd': reachedEnd,
  };
}

/// A recoverable snapshot of an in-progress workout, saved at important
/// transitions so a session survives backgrounding and process death.
class ActiveSessionCheckpoint {
  const ActiveSessionCheckpoint({
    required this.recoveryVersion,
    required this.sessionId,
    required this.source,
    required this.sourceWorkoutId,
    required this.snapshot,
    required this.startedAtUtc,
    required this.checkpointAtUtc,
    required this.engine,
    this.planAssignmentId,
    this.enrollmentId,
  });

  /// Bump when the timeline or engine format changes incompatibly.
  static const int currentRecoveryVersion = 1;

  factory ActiveSessionCheckpoint.fromJson(JsonMap json) => ActiveSessionCheckpoint(
    recoveryVersion: readInt(json, 'recoveryVersion'),
    sessionId: readString(json, 'sessionId'),
    source: parseEnumOr(WorkoutSource.values, json['source'], WorkoutSource.catalog),
    sourceWorkoutId: readString(json, 'sourceWorkoutId'),
    snapshot: WorkoutSnapshot.fromJson(asJsonMap(json['workoutSnapshot'], 'workoutSnapshot')),
    startedAtUtc: readDateTime(json, 'startedAtUtc').toUtc(),
    checkpointAtUtc: readDateTime(json, 'checkpointAtUtc').toUtc(),
    engine: EngineCheckpoint.fromJson(asJsonMap(json['engine'], 'engine')),
    planAssignmentId: readOptionalString(json, 'planAssignmentId'),
    enrollmentId: readOptionalString(json, 'enrollmentId'),
  );

  final int recoveryVersion;
  final String sessionId;
  final WorkoutSource source;
  final String sourceWorkoutId;
  final WorkoutSnapshot snapshot;
  final DateTime startedAtUtc;
  final DateTime checkpointAtUtc;
  final EngineCheckpoint engine;
  final String? planAssignmentId;
  final String? enrollmentId;

  bool get isCompatible => recoveryVersion == currentRecoveryVersion;

  JsonMap toJson() => {
    'recoveryVersion': recoveryVersion,
    'sessionId': sessionId,
    'source': source.json,
    'sourceWorkoutId': sourceWorkoutId,
    'workoutSnapshot': snapshot.toJson(),
    'startedAtUtc': startedAtUtc.toUtc().toIso8601String(),
    'checkpointAtUtc': checkpointAtUtc.toUtc().toIso8601String(),
    'engine': engine.toJson(),
    if (planAssignmentId != null) 'planAssignmentId': planAssignmentId,
    if (enrollmentId != null) 'enrollmentId': enrollmentId,
  };
}
