import 'dart:math' as math;

import '../data/models/active_session.dart';
import '../data/models/enums.dart';
import 'workout_timeline.dart';

/// Source of monotonic time in milliseconds.
///
/// Elapsed time is always measured with a monotonic clock, never wall-clock
/// time, so changing the device clock or time zone cannot distort timers.
abstract interface class MonotonicClock {
  int nowMs();
}

class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  int nowMs() => _stopwatch.elapsedMilliseconds;
}

class IncompatibleCheckpointException implements Exception {
  const IncompatibleCheckpointException(this.message);
  final String message;

  @override
  String toString() => 'IncompatibleCheckpointException: $message';
}

/// Explicit state machine for a guided workout session.
///
/// Time is accounted per interval: when a running interval closes (pause,
/// background interruption, or segment change) its length is added to the
/// current segment and to exactly one bucket – active, rest or preparation.
/// Remaining time is always *computed* from the clock rather than by
/// decrementing a counter, so late or missed timer callbacks cannot drift.
///
/// Rules:
/// * Timed segments end when their elapsed time reaches the target. If a
///   timer callback arrives late, the segment is credited with exactly its
///   target and at most [maxCarryMs] of the overshoot carries into the next
///   segment; longer delays are discarded rather than silently finishing
///   further segments.
/// * Repetition-based exercise segments never finish on their own; the user
///   must confirm them with [completeRepetitions].
/// * Paused and interrupted time is never counted.
class WorkoutEngine {
  WorkoutEngine(this.timeline, this._clock);

  /// Rebuilds an engine from a saved checkpoint. A session that was running
  /// when the checkpoint was written comes back [PlayerState.interrupted] so
  /// nothing advances until the user explicitly resumes.
  factory WorkoutEngine.restore(
    WorkoutTimeline timeline,
    MonotonicClock clock,
    EngineCheckpoint checkpoint,
  ) {
    if (checkpoint.segmentCount != timeline.length ||
        checkpoint.segmentIndex < 0 ||
        checkpoint.segmentIndex >= timeline.length) {
      throw const IncompatibleCheckpointException(
        'Saved session does not match the workout structure',
      );
    }
    if (checkpoint.state.isFinal) {
      throw const IncompatibleCheckpointException('Saved session had already finished');
    }
    final engine = WorkoutEngine(timeline, clock)
      .._index = checkpoint.segmentIndex
      .._segmentAccumMs = math.max(0, checkpoint.segmentElapsedMs)
      .._extensionMs = math.max(0, checkpoint.extensionMs)
      .._activeMs = math.max(0, checkpoint.activeMs)
      .._restMs = math.max(0, checkpoint.restMs)
      .._prepMs = math.max(0, checkpoint.preparationMs)
      .._reachedEnd = checkpoint.reachedEnd;
    engine._results.addAll(checkpoint.results);
    if (checkpoint.state == PlayerState.ready) {
      engine._state = PlayerState.ready;
    } else {
      engine._state = PlayerState.interrupted;
      engine._resumeState = checkpoint.state.isRunning
          ? checkpoint.state
          : (checkpoint.resumeState ?? _stateFor(timeline.segments[checkpoint.segmentIndex]));
    }
    return engine;
  }

  static const int maxCarryMs = 1000;
  static const int maxRestExtensionMs = 120 * 1000;

  final WorkoutTimeline timeline;
  final MonotonicClock _clock;

  PlayerState _state = PlayerState.ready;
  PlayerState? _resumeState;
  int _index = 0;
  int _segmentAccumMs = 0;
  int? _runningSince;
  int _extensionMs = 0;
  int _activeMs = 0;
  int _restMs = 0;
  int _prepMs = 0;
  bool _reachedEnd = false;
  int _segmentEntries = 0;
  final Map<int, SegmentResult> _results = {};

  PlayerState get state => _state;

  /// The running state to return to after a pause or interruption.
  PlayerState? get resumeState => _resumeState;
  int get segmentIndex => _index;
  bool get isEmpty => timeline.isEmpty;
  TimelineSegment get currentSegment => timeline.segments[_index];

  /// True when the session ended by finishing its last segment.
  bool get reachedEnd => _reachedEnd;

  /// Increments every time a segment starts; lets listeners detect changes.
  int get segmentEntries => _segmentEntries;
  Map<int, SegmentResult> get results => Map.unmodifiable(_results);

  bool get isPausedLike => _state == PlayerState.paused || _state == PlayerState.interrupted;

  /// The segment kind the user is effectively in, even while paused.
  PlayerState get effectiveState =>
      isPausedLike ? (_resumeState ?? _stateFor(currentSegment)) : _state;

  int get _liveMs => _runningSince == null ? 0 : math.max(0, _clock.nowMs() - _runningSince!);

  int get segmentElapsedMs => _segmentAccumMs + _liveMs;

  int get extensionMs => _extensionMs;

  /// Target length of the current timed segment including rest extensions.
  int get segmentTargetMs =>
      (currentSegment.durationSeconds ?? 0) * 1000 + (currentSegment.isRestLike ? _extensionMs : 0);

  /// Remaining time of a timed segment, clamped at zero; null while waiting
  /// for the user to finish a repetition-based set.
  int? get remainingMs =>
      isEmpty || !currentSegment.isTimed ? null : math.max(0, segmentTargetMs - segmentElapsedMs);

  _Bucket? get _liveBucket => isEmpty ? null : _bucketOf(currentSegment);

  int get activeMs => _activeMs + (_liveBucket == _Bucket.active ? _liveMs : 0);
  int get restMs => _restMs + (_liveBucket == _Bucket.rest ? _liveMs : 0);
  int get preparationMs => _prepMs + (_liveBucket == _Bucket.preparation ? _liveMs : 0);

  /// Active + rest + preparation. Never includes paused time.
  int get elapsedMs => activeMs + restMs + preparationMs;

  int get completedExerciseCount => _countOutcome(StepOutcome.completed);
  int get skippedExerciseCount => _countOutcome(StepOutcome.skipped);

  int _countOutcome(StepOutcome outcome) =>
      _results.values.where((r) => r.outcome == outcome).length;

  /// Overall progress through the session, 0–1.
  double get progress {
    if (isEmpty) return 0;
    if (_state == PlayerState.completed && _reachedEnd) return 1;
    var fraction = 0.0;
    final target = segmentTargetMs;
    if (currentSegment.isTimed && target > 0) {
      fraction = (segmentElapsedMs / target).clamp(0.0, 1.0);
    }
    return ((_index + fraction) / timeline.length).clamp(0.0, 1.0);
  }

  // ---------------------------------------------------------------------------
  // Commands. Each returns true when it changed the state.
  // ---------------------------------------------------------------------------

  bool start() {
    if (_state != PlayerState.ready || isEmpty) return false;
    _index = 0;
    _enterSegment(_clock.nowMs());
    return true;
  }

  /// Advances a timed segment whose time is up. Call regularly while running.
  bool tick() {
    if (!_state.isRunning) return false;
    final segment = currentSegment;
    if (!segment.isTimed) return false;
    final now = _clock.nowMs();
    final live = math.max(0, now - _runningSince!);
    final target = segmentTargetMs;
    if (_segmentAccumMs + live < target) return false;

    final credit = math.max(0, target - _segmentAccumMs);
    final overshoot = math.max(0, live - credit);
    _segmentAccumMs += credit;
    _addToBucket(segment, credit);
    _runningSince = null;
    _advance(
      now,
      outcome: segment.isExercise ? StepOutcome.completed : null,
      carryMs: math.min(overshoot, maxCarryMs),
    );
    return true;
  }

  /// Confirms that the user finished a repetition-based set.
  bool completeRepetitions() {
    if (_state != PlayerState.exercise || !currentSegment.waitsForUser) {
      return false;
    }
    final now = _clock.nowMs();
    _closeInterval(now);
    _advance(now, outcome: StepOutcome.completed);
    return true;
  }

  /// Skips the current exercise set (both sides for per-side exercises).
  /// Allowed while running or paused on an exercise; the next segment starts
  /// running immediately.
  bool skipExercise() {
    if (effectiveState != PlayerState.exercise || _state.isFinal) return false;
    if (_state == PlayerState.ready) return false;
    final now = _clock.nowMs();
    _closeInterval(now);
    final siblings = timeline.siblingSides(_index).where((i) => i >= _index).toList();
    for (final i in siblings) {
      _results[i] = SegmentResult(
        outcome: StepOutcome.skipped,
        activeMs: i == _index ? _segmentAccumMs : 0,
      );
    }
    final next = (siblings.isEmpty ? _index : siblings.last) + 1;
    _resumeState = null;
    if (next >= timeline.length) {
      _finish(PlayerState.completed, reachedEnd: true);
    } else {
      _index = next;
      _enterSegment(now);
    }
    return true;
  }

  /// Skips a rest, preparation or switch-sides segment.
  bool skipRest() {
    if (_state.isFinal || _state == PlayerState.ready) return false;
    if (!currentSegment.isRestLike) return false;
    final now = _clock.nowMs();
    _closeInterval(now);
    _resumeState = null;
    _advance(now);
    return true;
  }

  /// Adds time to the current rest (capped at [maxRestExtensionMs]).
  bool extendRest(int seconds) {
    if (_state.isFinal || _state == PlayerState.ready) return false;
    final kind = currentSegment.kind;
    if (kind != SegmentKind.rest && kind != SegmentKind.transition) {
      return false;
    }
    final updated = math.min(_extensionMs + seconds * 1000, maxRestExtensionMs);
    if (updated == _extensionMs) return false;
    _extensionMs = updated;
    return true;
  }

  bool pause() {
    if (!_state.isRunning) return false;
    _closeInterval(_clock.nowMs());
    _resumeState = _state;
    _state = PlayerState.paused;
    return true;
  }

  /// Pauses because the app left the foreground. Works from paused too, so
  /// the UI can explain why the session stopped.
  bool interrupt() {
    if (_state.isRunning) {
      _closeInterval(_clock.nowMs());
      _resumeState = _state;
      _state = PlayerState.interrupted;
      return true;
    }
    if (_state == PlayerState.paused) {
      _state = PlayerState.interrupted;
      return true;
    }
    return false;
  }

  bool resume() {
    if (!isPausedLike) return false;
    _state = _resumeState ?? _stateFor(currentSegment);
    _resumeState = null;
    _runningSince = _clock.nowMs();
    return true;
  }

  /// Ends the session now ("Finish early" or finishing from the last screen).
  bool finish() {
    if (_state.isFinal || _state == PlayerState.ready) return false;
    _closeInterval(_clock.nowMs());
    _finish(PlayerState.completed, reachedEnd: false);
    return true;
  }

  /// Quits the session. Abandoned sessions never count as completed.
  bool abandon() {
    if (_state.isFinal) return false;
    _closeInterval(_clock.nowMs());
    _finish(PlayerState.abandoned, reachedEnd: false);
    return true;
  }

  /// How the finished session should be stored, or null when no exercise
  /// was completed (nothing worth saving).
  SessionStatus? resolveStatus() {
    if (!_state.isFinal) return null;
    if (completedExerciseCount == 0) return null;
    if (_state == PlayerState.abandoned) return SessionStatus.abandoned;
    if (_reachedEnd && skippedExerciseCount == 0) {
      return SessionStatus.completed;
    }
    return SessionStatus.partial;
  }

  EngineCheckpoint checkpoint() => EngineCheckpoint(
    state: _state,
    resumeState: _resumeState,
    segmentIndex: _index,
    segmentCount: timeline.length,
    segmentElapsedMs: segmentElapsedMs,
    extensionMs: _extensionMs,
    activeMs: activeMs,
    restMs: restMs,
    preparationMs: preparationMs,
    results: Map.of(_results),
    reachedEnd: _reachedEnd,
  );

  // ---------------------------------------------------------------------------

  void _enterSegment(int startedAt) {
    _state = _stateFor(currentSegment);
    _segmentAccumMs = 0;
    _extensionMs = 0;
    _runningSince = startedAt;
    _segmentEntries++;
  }

  void _advance(int now, {StepOutcome? outcome, int carryMs = 0}) {
    final segment = currentSegment;
    if (segment.isExercise && outcome != null) {
      _results[_index] = SegmentResult(outcome: outcome, activeMs: _segmentAccumMs);
    }
    if (_index >= timeline.length - 1) {
      _finish(PlayerState.completed, reachedEnd: true);
      return;
    }
    _index++;
    _enterSegment(now - carryMs);
  }

  void _closeInterval(int now) {
    final since = _runningSince;
    if (since == null) return;
    final elapsed = math.max(0, now - since);
    _segmentAccumMs += elapsed;
    _addToBucket(currentSegment, elapsed);
    _runningSince = null;
  }

  void _finish(PlayerState finalState, {required bool reachedEnd}) {
    _runningSince = null;
    _resumeState = null;
    _reachedEnd = reachedEnd;
    for (final segment in timeline.segments) {
      if (!segment.isExercise || _results.containsKey(segment.index)) continue;
      final isCurrent = !reachedEnd && segment.index == _index;
      _results[segment.index] = SegmentResult(
        outcome: isCurrent ? StepOutcome.stopped : StepOutcome.notReached,
        activeMs: isCurrent ? _segmentAccumMs : 0,
      );
    }
    _state = finalState;
  }

  void _addToBucket(TimelineSegment segment, int ms) {
    switch (_bucketOf(segment)) {
      case _Bucket.active:
        _activeMs += ms;
      case _Bucket.rest:
        _restMs += ms;
      case _Bucket.preparation:
        _prepMs += ms;
    }
  }

  _Bucket _bucketOf(TimelineSegment segment) => switch (segment.kind) {
    SegmentKind.exercise => _Bucket.active,
    SegmentKind.rest || SegmentKind.transition => _Bucket.rest,
    SegmentKind.preparation => _Bucket.preparation,
  };

  static PlayerState _stateFor(TimelineSegment segment) => switch (segment.kind) {
    SegmentKind.preparation => PlayerState.preparation,
    SegmentKind.exercise => PlayerState.exercise,
    SegmentKind.rest || SegmentKind.transition => PlayerState.rest,
  };
}

enum _Bucket { active, rest, preparation }
