import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/domain/workout_engine.dart';
import 'package:home_fit_daily/domain/workout_timeline.dart';

import '../helpers/fakes.dart';

WorkoutEngine _engine(FakeMonotonicClock clock, List steps, {int rounds = 1}) =>
    WorkoutEngine(WorkoutTimeline.build(testWorkout(steps.cast(), rounds: rounds)), clock);

void main() {
  late FakeMonotonicClock clock;

  setUp(() => clock = FakeMonotonicClock());

  test('ready → preparation → exercise using elapsed time, not tick counts', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 30)]);
    expect(e.state, PlayerState.ready);
    expect(e.start(), isTrue);
    expect(e.state, PlayerState.preparation);

    clock.advanceSeconds(9.9);
    expect(e.tick(), isFalse);
    expect(e.remainingMs, 100);

    clock.advanceSeconds(0.1);
    expect(e.tick(), isTrue);
    expect(e.state, PlayerState.exercise);
    expect(e.remainingMs, 30000);
  });

  test('a timed exercise completes automatically when its time is up', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 20), timedStep('b', 'y')]);
    e.start();
    clock.advanceSeconds(10);
    e.tick();
    clock.advanceSeconds(20);
    e.tick();
    expect(e.results.values.single.outcome, StepOutcome.completed);
    expect(e.currentSegment.stepId, 'b');
  });

  test('repetition sets never complete on their own', () {
    final e = _engine(clock, [repStep('a', 'squat')]);
    e.start();
    clock.advanceSeconds(10);
    e.tick();
    expect(e.state, PlayerState.exercise);
    clock.advanceSeconds(3600);
    expect(e.tick(), isFalse);
    expect(e.state, PlayerState.exercise);
    expect(e.remainingMs, isNull);
    expect(e.completeRepetitions(), isTrue);
    expect(e.state, PlayerState.completed);
    expect(e.reachedEnd, isTrue);
    expect(e.resolveStatus(), SessionStatus.completed);
  });

  test('completing reps is ignored outside a repetition exercise', () {
    final e = _engine(clock, [timedStep('a', 'x')]);
    e.start();
    expect(e.completeRepetitions(), isFalse); // still in preparation
  });

  test('paused time is excluded from timers and totals', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 30)]);
    e.start();
    e.skipRest(); // skip preparation
    clock.advanceSeconds(10);
    expect(e.pause(), isTrue);
    expect(e.state, PlayerState.paused);
    clock.advanceSeconds(300);
    expect(e.tick(), isFalse);
    expect(e.remainingMs, 20000);
    expect(e.resume(), isTrue);
    expect(e.state, PlayerState.exercise);
    clock.advanceSeconds(5);
    expect(e.remainingMs, 15000);
    expect(e.activeMs, 15000);
  });

  test('a late timer callback advances one segment and carries at most 1 s', () {
    final e = _engine(clock, [
      timedStep('a', 'x', seconds: 10, rest: 10),
      timedStep('b', 'y', seconds: 10),
    ]);
    e.start();
    e.skipRest();
    clock.advanceSeconds(15); // callback 5 s late
    expect(e.tick(), isTrue);
    expect(e.state, PlayerState.rest);
    // Exercise credited with exactly its target; overshoot capped.
    expect(e.activeMs, 10000);
    expect(e.restMs, 1000);
    expect(e.remainingMs, 9000);
  });

  test('remaining time is clamped at zero', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 10)]);
    e.start();
    e.skipRest();
    clock.advanceSeconds(11);
    // Before the tick processes the transition, remaining never goes below 0.
    expect(e.remainingMs, 0);
  });

  test('per-side exercises guide both sides', () {
    final e = _engine(clock, [repStep('a', 'lunge', perSide: true)]);
    e.start();
    e.skipRest();
    expect(e.currentSegment.side, Side.left);
    e.completeRepetitions();
    expect(e.state, PlayerState.rest);
    expect(e.currentSegment.kind, SegmentKind.transition);
    clock.advanceSeconds(5);
    e.tick();
    expect(e.currentSegment.side, Side.right);
    e.completeRepetitions();
    expect(e.state, PlayerState.completed);
    expect(e.completedExerciseCount, 2);
  });

  test('skipping a per-side exercise skips both sides and is recorded', () {
    final e = _engine(clock, [
      repStep('a', 'lunge', perSide: true, rest: 20),
      repStep('b', 'squat'),
    ]);
    e.start();
    e.skipRest();
    expect(e.skipExercise(), isTrue);
    expect(e.skippedExerciseCount, 2);
    expect(e.state, PlayerState.rest);
    e.skipRest();
    expect(e.currentSegment.stepId, 'b');
    e.completeRepetitions();
    expect(e.resolveStatus(), SessionStatus.partial);
  });

  test('skip works while paused and resumes running', () {
    final e = _engine(clock, [repStep('a', 'x'), repStep('b', 'y')]);
    e.start();
    e.skipRest();
    e.pause();
    expect(e.skipExercise(), isTrue);
    expect(e.state, PlayerState.exercise);
    expect(e.currentSegment.stepId, 'b');
  });

  test('rest can be extended, with a cap', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 10, rest: 20), timedStep('b', 'y')]);
    e.start();
    e.skipRest();
    clock.advanceSeconds(10);
    e.tick();
    expect(e.extendRest(15), isTrue);
    expect(e.remainingMs, 35000);
    for (var i = 0; i < 20; i++) {
      e.extendRest(15);
    }
    expect(e.extensionMs, WorkoutEngine.maxRestExtensionMs);
  });

  test('extending is only possible during rest', () {
    final e = _engine(clock, [timedStep('a', 'x')]);
    e.start();
    e.skipRest();
    expect(e.extendRest(15), isFalse);
  });

  test('rest and preparation are tracked separately from active time', () {
    final e = _engine(clock, [
      timedStep('a', 'x', seconds: 30, rest: 20),
      timedStep('b', 'y', seconds: 30),
    ]);
    e.start();
    clock.advanceSeconds(10);
    e.tick();
    clock.advanceSeconds(30);
    e.tick();
    clock.advanceSeconds(20);
    e.tick();
    clock.advanceSeconds(30);
    e.tick();
    expect(e.state, PlayerState.completed);
    expect(e.preparationMs, 10000);
    expect(e.activeMs, 60000);
    expect(e.restMs, 20000);
    expect(e.elapsedMs, 90000);
  });

  test('finishing early saves a partial session with honest outcomes', () {
    final e = _engine(clock, [repStep('a', 'x'), repStep('b', 'y'), repStep('c', 'z')]);
    e.start();
    e.skipRest();
    e.completeRepetitions();
    clock.advanceSeconds(4);
    expect(e.finish(), isTrue);
    expect(e.state, PlayerState.completed);
    expect(e.reachedEnd, isFalse);
    final outcomes = e.results.values.map((r) => r.outcome).toList();
    expect(
      outcomes,
      containsAll([StepOutcome.completed, StepOutcome.stopped, StepOutcome.notReached]),
    );
    expect(e.resolveStatus(), SessionStatus.partial);
  });

  test('quitting is recorded as abandoned only when work was done', () {
    final idle = _engine(clock, [repStep('a', 'x')]);
    idle.start();
    idle.abandon();
    expect(idle.resolveStatus(), isNull);

    final worked = _engine(clock, [repStep('a', 'x'), repStep('b', 'y')]);
    worked.start();
    worked.skipRest();
    worked.completeRepetitions();
    worked.abandon();
    expect(worked.state, PlayerState.abandoned);
    expect(worked.resolveStatus(), SessionStatus.abandoned);
  });

  test('commands after the session ended are ignored', () {
    final e = _engine(clock, [repStep('a', 'x')]);
    e.start();
    e.skipRest();
    e.completeRepetitions();
    expect(e.state, PlayerState.completed);
    expect(e.finish(), isFalse);
    expect(e.abandon(), isFalse);
    expect(e.completeRepetitions(), isFalse);
    expect(e.resume(), isFalse);
  });

  test('background interruption pauses, even from the paused state', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 30)]);
    e.start();
    e.skipRest();
    clock.advanceSeconds(5);
    expect(e.interrupt(), isTrue);
    expect(e.state, PlayerState.interrupted);
    clock.advanceSeconds(600); // app in the background
    expect(e.tick(), isFalse);
    expect(e.remainingMs, 25000);
    e.resume();
    expect(e.state, PlayerState.exercise);

    e.pause();
    expect(e.interrupt(), isTrue);
    expect(e.state, PlayerState.interrupted);
  });

  test('checkpoint restore comes back interrupted with the same progress', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 30, rest: 10), repStep('b', 'y')]);
    e.start();
    e.skipRest();
    clock.advanceSeconds(12);
    final checkpoint = e.checkpoint();
    expect(checkpoint.segmentElapsedMs, 12000);

    final clock2 = FakeMonotonicClock()..ms = 999999;
    final restored = WorkoutEngine.restore(e.timeline, clock2, checkpoint);
    expect(restored.state, PlayerState.interrupted);
    expect(restored.resumeState, PlayerState.exercise);
    expect(restored.remainingMs, 18000);
    clock2.advanceSeconds(1000); // time while closed is not counted
    expect(restored.tick(), isFalse);
    restored.resume();
    clock2.advanceSeconds(18);
    expect(restored.tick(), isTrue);
    expect(restored.state, PlayerState.rest);
    expect(restored.activeMs, 30000);
  });

  test('an incompatible checkpoint is rejected', () {
    final e = _engine(clock, [timedStep('a', 'x')]);
    e.start();
    final checkpoint = e.checkpoint();
    final other = WorkoutTimeline.build(testWorkout([timedStep('a', 'x'), timedStep('b', 'y')]));
    expect(
      () => WorkoutEngine.restore(other, clock, checkpoint),
      throwsA(isA<IncompatibleCheckpointException>()),
    );
  });

  test('progress moves from 0 to 1', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 10)]);
    expect(e.progress, 0);
    e.start();
    clock.advanceSeconds(10);
    e.tick();
    expect(e.progress, greaterThan(0.4));
    clock.advanceSeconds(10);
    e.tick();
    expect(e.progress, 1);
  });

  test('a workout completed with no skips is "completed"', () {
    final e = _engine(clock, [timedStep('a', 'x', seconds: 10)], rounds: 2);
    e.start();
    for (var i = 0; i < 10 && !e.state.isFinal; i++) {
      clock.advanceSeconds(10);
      e.tick();
    }
    expect(e.state, PlayerState.completed);
    expect(e.completedExerciseCount, 2);
    expect(e.resolveStatus(), SessionStatus.completed);
  });
}
