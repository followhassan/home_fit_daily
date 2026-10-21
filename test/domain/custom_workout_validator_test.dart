import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/data/models/custom_workout.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/workout.dart';
import 'package:home_fit_daily/domain/custom_workout_validator.dart';

import '../helpers/catalog_fixture.dart';

CustomWorkout _draft({
  String title = 'My workout',
  List<WorkoutStep> steps = const [],
  int rounds = 1,
}) => CustomWorkout(
  id: 'custom_1',
  title: title,
  description: '',
  steps: steps,
  rounds: rounds,
  roundRestSeconds: 30,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

const _squat = WorkoutStep(
  id: 's1',
  exerciseId: 'bodyweight_squat',
  type: StepType.main,
  execution: ExecutionType.reps,
  repetitions: 10,
  restSeconds: 30,
);

void main() {
  final catalog = loadBundledCatalog();

  test('a valid workout passes', () {
    final v = CustomWorkoutValidator.validate(_draft(steps: [_squat]), catalog);
    expect(v.isValid, isTrue, reason: v.messages.join());
  });

  test('title cannot be blank and at least one exercise is required', () {
    final v = CustomWorkoutValidator.validate(_draft(title: '   '), catalog);
    expect(v.titleError, isNotNull);
    expect(v.stepsError, isNotNull);
  });

  test('unknown exercises are rejected', () {
    final v = CustomWorkoutValidator.validate(
      _draft(steps: [_squat.copyWith(exerciseId: 'gone')]),
      catalog,
    );
    expect(v.stepErrors, contains('s1'));
  });

  test('values must be positive and within limits', () {
    for (final bad in [
      _squat.copyWith(repetitions: 0),
      _squat.copyWith(repetitions: 500),
      _squat.copyWith(sets: 0),
      _squat.copyWith(restSeconds: 1000),
      _squat.copyWith(execution: ExecutionType.timed, durationSeconds: 2),
    ]) {
      final v = CustomWorkoutValidator.validate(_draft(steps: [bad]), catalog);
      expect(v.isValid, isFalse, reason: bad.toJson().toString());
    }
  });

  test('timed-only exercises cannot be done for repetitions', () {
    const plank = WorkoutStep(
      id: 's2',
      exerciseId: 'forearm_plank',
      type: StepType.main,
      execution: ExecutionType.reps,
      repetitions: 10,
    );
    final v = CustomWorkoutValidator.validate(_draft(steps: [plank]), catalog);
    expect(v.stepErrors['s2'], contains('for time'));
  });

  test('a step is either timed or counted, never both', () {
    final converted = _squat.copyWith(execution: ExecutionType.timed, durationSeconds: 30);
    expect(converted.durationSeconds, 30);
    expect(converted.repetitions, isNull);
  });

  test('per-side only for one-sided exercises', () {
    final v = CustomWorkoutValidator.validate(
      _draft(steps: [_squat.copyWith(perSide: true)]),
      catalog,
    );
    expect(v.isValid, isFalse);
  });

  test('rounds are limited and very long workouts are rejected', () {
    expect(
      CustomWorkoutValidator.validate(_draft(steps: [_squat], rounds: 0), catalog).roundsError,
      isNotNull,
    );
    final long = _squat.copyWith(execution: ExecutionType.timed, durationSeconds: 600, sets: 10);
    final v = CustomWorkoutValidator.validate(_draft(steps: [long], rounds: 3), catalog);
    expect(v.roundsError, contains('minutes'));
  });
}
