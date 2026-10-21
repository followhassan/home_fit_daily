import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/domain/duration_estimator.dart';
import 'package:home_fit_daily/domain/workout_timeline.dart';

import '../helpers/fakes.dart';

void main() {
  group('WorkoutTimeline', () {
    test('starts with a preparation countdown', () {
      final t = WorkoutTimeline.build(testWorkout([timedStep('a', 'x')]));
      expect(t.segments.first.kind, SegmentKind.preparation);
      expect(t.segments.first.durationSeconds, 10);
      expect(t.exerciseSegmentCount, 1);
    });

    test('no rest after the final exercise', () {
      final t = WorkoutTimeline.build(
        testWorkout([timedStep('a', 'x', rest: 20), timedStep('b', 'y', rest: 20)]),
      );
      final kinds = t.segments.map((s) => s.kind).toList();
      expect(kinds, [
        SegmentKind.preparation,
        SegmentKind.exercise,
        SegmentKind.rest,
        SegmentKind.exercise,
      ]);
    });

    test('per-side steps run left, switch, right', () {
      final t = WorkoutTimeline.build(
        testWorkout([repStep('a', 'lunge', perSide: true, rest: 15), timedStep('b', 'y')]),
      );
      final segs = t.segments.skip(1).toList();
      expect(segs[0].side, Side.left);
      expect(segs[1].kind, SegmentKind.transition);
      expect(segs[1].durationSeconds, WorkoutTimeline.switchSidesSeconds);
      expect(segs[2].side, Side.right);
      expect(segs[3].kind, SegmentKind.rest);
      expect(t.exerciseSegmentCount, 3);
    });

    test('sets repeat a step with rest between sets', () {
      final t = WorkoutTimeline.build(testWorkout([repStep('a', 'squat', sets: 3, rest: 30)]));
      final exercises = t.segments.where((s) => s.isExercise).toList();
      expect(exercises.map((s) => s.set), [1, 2, 3]);
      expect(t.segments.where((s) => s.kind == SegmentKind.rest).length, 2);
    });

    test('warm-up once, main steps per round, cool-down once', () {
      final t = WorkoutTimeline.build(
        testWorkout(
          [
            timedStep('w', 'march', type: StepType.warmup),
            timedStep('m1', 'squat', rest: 10),
            timedStep('m2', 'plank', rest: 10),
            timedStep('c', 'stretch', type: StepType.cooldown),
          ],
          rounds: 3,
          roundRest: 60,
        ),
      );
      final ids = t.segments.where((s) => s.isExercise).map((s) => s.stepId).toList();
      expect(ids, ['w', 'm1', 'm2', 'm1', 'm2', 'm1', 'm2', 'c']);
      final rounds = t.segments
          .where((s) => s.isExercise && s.stepId == 'm1')
          .map((s) => s.round)
          .toList();
      expect(rounds, [1, 2, 3]);
      // The longer round rest replaces the step rest between rounds.
      final restAfterRound1 =
          t.segments[t.segments.indexWhere((s) => s.isExercise && s.stepId == 'm2') + 1];
      expect(restAfterRound1.durationSeconds, 60);
    });

    test('sibling sides are found for skipping a whole set', () {
      final t = WorkoutTimeline.build(testWorkout([repStep('a', 'lunge', perSide: true)]));
      final left = t.segments.firstWhere((s) => s.isExercise);
      expect(t.siblingSides(left.index).length, 2);
    });
  });

  group('DurationEstimator', () {
    test('timed workouts have an exact estimate', () {
      final e = DurationEstimator.estimate(
        testWorkout([timedStep('a', 'x', seconds: 60, rest: 30), timedStep('b', 'y', seconds: 60)]),
        secondsPerRep: (_) => 3,
      );
      expect(e.seconds, 10 + 60 + 30 + 60);
      expect(e.isApproximate, isFalse);
    });

    test('repetition-based sets use the assumed pace and are approximate', () {
      final e = DurationEstimator.estimate(
        testWorkout([repStep('a', 'x', reps: 10, perSide: true)]),
        secondsPerRep: (_) => 4,
      );
      // prep 10 + left 40 + switch 5 + right 40
      expect(e.seconds, 95);
      expect(e.isApproximate, isTrue);
      expect(e.label, startsWith('About'));
    });
  });
}
