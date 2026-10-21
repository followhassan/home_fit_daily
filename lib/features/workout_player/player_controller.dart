import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../core/services/screen_awake.dart';
import '../../core/services/workout_feedback.dart';
import '../../core/utils/app_clock.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/ids.dart';
import '../../core/utils/local_date.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/active_session.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/enums.dart';
import '../../data/models/workout.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/repositories.dart';
import '../../domain/workout_engine.dart';
import '../../domain/workout_timeline.dart';

/// Everything needed to start (or recover) a guided session.
class PlayerLaunch {
  const PlayerLaunch({
    required this.sessionId,
    required this.snapshot,
    required this.source,
    required this.sourceWorkoutId,
    required this.startedAtUtc,
    this.planAssignmentId,
    this.enrollmentId,
    this.recovered,
  });

  /// A new session. The session ID is assigned here, before it starts, so
  /// every checkpoint and the final record share one stable identity.
  factory PlayerLaunch.fresh(
    Workout workout,
    Catalog catalog, {
    required DateTime nowUtc,
    String? planAssignmentId,
    String? enrollmentId,
  }) => PlayerLaunch(
    sessionId: Ids.session(),
    snapshot: WorkoutSnapshot(
      workout: workout,
      exerciseNames: {
        for (final step in workout.steps)
          step.exerciseId: catalog.exercise(step.exerciseId)?.name ?? step.exerciseId,
      },
    ),
    source: workout.source,
    sourceWorkoutId: workout.id,
    startedAtUtc: nowUtc,
    planAssignmentId: planAssignmentId,
    enrollmentId: enrollmentId,
  );

  factory PlayerLaunch.recover(ActiveSessionCheckpoint checkpoint) => PlayerLaunch(
    sessionId: checkpoint.sessionId,
    snapshot: checkpoint.snapshot,
    source: checkpoint.source,
    sourceWorkoutId: checkpoint.sourceWorkoutId,
    startedAtUtc: checkpoint.startedAtUtc,
    planAssignmentId: checkpoint.planAssignmentId,
    enrollmentId: checkpoint.enrollmentId,
    recovered: checkpoint,
  );

  final String sessionId;
  final WorkoutSnapshot snapshot;
  final WorkoutSource source;
  final String sourceWorkoutId;
  final DateTime startedAtUtc;
  final String? planAssignmentId;
  final String? enrollmentId;
  final ActiveSessionCheckpoint? recovered;
}

/// The result shown on the summary screen.
class SessionOutcome {
  const SessionOutcome({
    required this.title,
    required this.status,
    required this.session,
    required this.activeSeconds,
    required this.restSeconds,
    required this.elapsedSeconds,
    required this.completedCount,
    required this.skippedCount,
    required this.totalCount,
    required this.planAssignmentId,
  });

  final String title;

  /// Null when no exercise was completed and nothing was saved.
  final SessionStatus? status;
  final WorkoutSession? session;
  final int activeSeconds;
  final int restSeconds;
  final int elapsedSeconds;
  final int completedCount;
  final int skippedCount;
  final int totalCount;
  final String? planAssignmentId;

  bool get saved => session != null;
}

/// Drives a guided workout: owns the [WorkoutEngine], a single periodic
/// ticker, checkpointing, lifecycle handling, cues and the final save.
///
/// The ticker only refreshes [timeTick]; full [notifyListeners] calls happen
/// on structural changes (segment or state changes), so the screen does not
/// rebuild every frame.
class WorkoutPlayerController extends ChangeNotifier with WidgetsBindingObserver {
  WorkoutPlayerController({
    required this.launch,
    required this._sessions,
    required this._activeSessions,
    required this._feedback,
    required this._screenAwake,
    required AppSettings settings,
    required this._onSessionSaved,
    MonotonicClock? monotonic,
    this._clock = const AppClock(),
    this._tickInterval = const Duration(milliseconds: 200),
    this._observeLifecycle = true,
  }) : _settings = settings,
       timeline = WorkoutTimeline.build(launch.snapshot.workout) {
    final mono = monotonic ?? StopwatchClock();
    final recovered = launch.recovered;
    if (recovered != null) {
      try {
        engine = WorkoutEngine.restore(timeline, mono, recovered.engine);
        _wasRecovered = true;
      } on IncompatibleCheckpointException {
        engine = WorkoutEngine(timeline, mono);
        _recoveryFailed = true;
      }
    } else {
      engine = WorkoutEngine(timeline, mono);
    }
    _lastSegmentEntries = engine.segmentEntries;
    _feedback.configure(sound: settings.soundEnabled, vibration: settings.vibrationEnabled);
    if (_observeLifecycle) WidgetsBinding.instance.addObserver(this);
  }

  final PlayerLaunch launch;
  final WorkoutTimeline timeline;
  late final WorkoutEngine engine;
  final SessionRepository _sessions;
  final ActiveSessionRepository _activeSessions;
  final WorkoutFeedback _feedback;
  final ScreenAwake _screenAwake;
  final AppSettings _settings;
  final void Function(WorkoutSession) _onSessionSaved;
  final AppClock _clock;
  final Duration _tickInterval;
  final bool _observeLifecycle;

  /// Increments on every tick so timer text can rebuild on its own.
  final ValueNotifier<int> timeTick = ValueNotifier(0);

  Timer? _timer;
  int _lastSegmentEntries = 0;
  int _lastCountdown = -1;
  bool _wasRecovered = false;
  bool _recoveryFailed = false;
  bool _disposed = false;
  Future<void> _checkpointChain = Future.value();
  Future<SessionOutcome>? _finalizing;
  SessionOutcome? _outcome;
  Object? _saveError;

  PlayerState get state => engine.state;
  bool get wasRecovered => _wasRecovered;

  /// The saved checkpoint did not match this app version's timeline.
  bool get recoveryFailed => _recoveryFailed;
  bool get isFinished => engine.state.isFinal;
  SessionOutcome? get outcome => _outcome;
  Object? get saveError => _saveError;
  String get title => launch.snapshot.workout.title;

  String exerciseName(String? exerciseId) =>
      exerciseId == null ? '' : launch.snapshot.nameOf(exerciseId);

  WorkoutStep? stepOf(TimelineSegment segment) {
    final steps = launch.snapshot.workout.steps;
    final i = segment.stepIndex;
    return i >= 0 && i < steps.length ? steps[i] : null;
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  void start() => _apply(engine.start);
  void pause() => _apply(engine.pause);
  void resume() => _apply(engine.resume);
  void completeRepetitions() => _apply(engine.completeRepetitions);
  void skipExercise() => _apply(engine.skipExercise);
  void skipRest() => _apply(engine.skipRest);
  void extendRest([int seconds = 15]) => _apply(() => engine.extendRest(seconds));

  /// Ends the session now and saves it (completed or partial).
  Future<SessionOutcome> finishEarly() {
    _apply(engine.finish);
    return finalize();
  }

  /// Quits. Saved as abandoned only when some exercise was completed;
  /// abandoned sessions never count as completed workouts.
  Future<SessionOutcome> quit() {
    // Quitting before any exercise is completed records nothing.
    _apply(engine.abandon);
    return finalize();
  }

  void _apply(bool Function() command) {
    if (_disposed) return;
    if (command()) _afterChange();
  }

  void _onTick(Timer _) {
    if (_disposed) return;
    if (engine.tick()) {
      _afterChange();
      return;
    }
    final remaining = engine.remainingMs;
    if (remaining != null && engine.state.isRunning) {
      final seconds = Formatters.ceilSeconds(remaining);
      if (seconds >= 1 && seconds <= 3 && seconds != _lastCountdown) {
        _lastCountdown = seconds;
        _feedback.cue(FeedbackCue.countdown);
      }
    }
    timeTick.value++;
  }

  void _afterChange() {
    final state = engine.state;
    if (engine.segmentEntries != _lastSegmentEntries) {
      _lastSegmentEntries = engine.segmentEntries;
      _lastCountdown = -1;
      if (state == PlayerState.exercise) {
        _feedback.cue(FeedbackCue.exerciseStart);
      } else if (state == PlayerState.rest) {
        _feedback.cue(FeedbackCue.restStart);
      }
    }
    if (state.isRunning) {
      _timer ??= Timer.periodic(_tickInterval, _onTick);
    } else {
      _timer?.cancel();
      _timer = null;
    }
    unawaited(_screenAwake.set(state.isRunning && _settings.keepScreenAwake));
    if (state.isFinal) {
      // Errors surface through [saveError]; the screen offers a retry.
      unawaited(finalize().then((_) {}, onError: (Object _) {}));
    } else if (state != PlayerState.ready) {
      _saveCheckpoint();
    }
    timeTick.value++;
    notifyListeners();
  }

  /// Saves a recoverable snapshot. Writes are chained so they land in order
  /// and never after the session has been finalized.
  void _saveCheckpoint() {
    if (_finalizing != null) return;
    final checkpoint = ActiveSessionCheckpoint(
      recoveryVersion: ActiveSessionCheckpoint.currentRecoveryVersion,
      sessionId: launch.sessionId,
      source: launch.source,
      sourceWorkoutId: launch.sourceWorkoutId,
      snapshot: launch.snapshot,
      startedAtUtc: launch.startedAtUtc,
      checkpointAtUtc: _clock.nowUtc(),
      engine: engine.checkpoint(),
      planAssignmentId: launch.planAssignmentId,
      enrollmentId: launch.enrollmentId,
    );
    _checkpointChain = _checkpointChain
        .then((_) => _activeSessions.save(checkpoint))
        .catchError((Object e) => debugPrint('Checkpoint failed: $e'));
  }

  /// Saves the finished session exactly once. Repeated calls return the
  /// same result; after a failed save, calling again retries.
  Future<SessionOutcome> finalize() {
    final pending = _finalizing;
    if (pending != null) return pending;
    final future = _finalize();
    _finalizing = future;
    return future;
  }

  Future<SessionOutcome> _finalize() async {
    _timer?.cancel();
    _timer = null;
    await _screenAwake.set(false);
    // Let earlier checkpoint writes finish before clearing them.
    await _checkpointChain;

    final status = engine.resolveStatus();
    WorkoutSession? session;
    if (status != null) {
      session = _buildSession(status);
      try {
        await _sessions.save(session);
        _saveError = null;
      } catch (e) {
        // Keep the checkpoint so nothing is lost; allow a retry.
        _saveError = e;
        _finalizing = null;
        notifyListeners();
        rethrow;
      }
      _onSessionSaved(session);
    }
    try {
      await _activeSessions.clear();
    } catch (e) {
      // Harmless: on next launch the checkpoint is recognised as already
      // saved and removed.
      debugPrint('Clearing checkpoint failed: $e');
    }
    if (status == SessionStatus.completed) {
      _feedback.cue(FeedbackCue.complete);
    }
    final outcome = SessionOutcome(
      title: title,
      status: status,
      session: session,
      activeSeconds: engine.activeMs ~/ 1000,
      restSeconds: engine.restMs ~/ 1000,
      elapsedSeconds: engine.elapsedMs ~/ 1000,
      completedCount: engine.completedExerciseCount,
      skippedCount: engine.skippedExerciseCount,
      totalCount: timeline.exerciseSegmentCount,
      planAssignmentId: launch.planAssignmentId,
    );
    _outcome = outcome;
    if (!_disposed) notifyListeners();
    return outcome;
  }

  WorkoutSession _buildSession(SessionStatus status) {
    final completedAt = _clock.now();
    final records = <SessionStepRecord>[];
    for (final segment in timeline.segments) {
      if (!segment.isExercise) continue;
      final result = engine.results[segment.index];
      records.add(
        SessionStepRecord(
          segmentIndex: segment.index,
          stepId: segment.stepId ?? '',
          exerciseId: segment.exerciseId ?? '',
          round: segment.round,
          set: segment.set,
          side: segment.side,
          execution: segment.execution ?? ExecutionType.timed,
          targetSeconds: segment.durationSeconds,
          targetReps: segment.repetitions,
          outcome: result?.outcome ?? StepOutcome.notReached,
          activeSeconds: (result?.activeMs ?? 0) ~/ 1000,
        ),
      );
    }
    final active = engine.activeMs ~/ 1000;
    final rest = engine.restMs ~/ 1000;
    final prep = engine.preparationMs ~/ 1000;
    return WorkoutSession(
      id: launch.sessionId,
      sourceWorkoutId: launch.sourceWorkoutId,
      source: launch.source,
      snapshot: launch.snapshot,
      startedAtUtc: launch.startedAtUtc,
      completedAtUtc: completedAt.toUtc(),
      localCompletionDate: LocalDate.fromDateTime(completedAt),
      timezoneOffsetMinutes: completedAt.timeZoneOffset.inMinutes,
      status: status,
      stepRecords: records,
      activeSeconds: active,
      restSeconds: rest,
      preparationSeconds: prep,
      elapsedSeconds: active + rest + prep,
      planAssignmentId: launch.planAssignmentId,
      enrollmentId: launch.enrollmentId,
    );
  }

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Pauses automatically when the app leaves the foreground, saves a
  /// checkpoint, and stays paused until the user resumes. Nothing advances
  /// while the app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _apply(engine.interrupt);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    if (_observeLifecycle) WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _timer = null;
    // If the screen is removed while a session is still open, keep it
    // recoverable instead of losing it.
    if (!engine.state.isFinal && engine.state != PlayerState.ready) {
      if (engine.interrupt() || engine.state == PlayerState.interrupted) {
        _saveCheckpoint();
      }
    }
    unawaited(_screenAwake.set(false));
    timeTick.dispose();
    super.dispose();
  }
}
