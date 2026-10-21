import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/workout_session.dart';

import 'fakes.dart';

int _counter = 0;

/// A minimal session completed on [date].
WorkoutSession sessionOn(
  LocalDate date, {
  SessionStatus status = SessionStatus.completed,
  int activeSeconds = 600,
  String workoutId = 'test_workout',
  String? assignmentId,
  String? enrollmentId,
  String? id,
}) {
  final at = DateTime.utc(date.year, date.month, date.day, 12);
  final workout = testWorkout([timedStep('a', 'x')], id: workoutId);
  return WorkoutSession(
    id: id ?? 'session_${_counter++}',
    sourceWorkoutId: workoutId,
    source: WorkoutSource.catalog,
    snapshot: WorkoutSnapshot(workout: workout, exerciseNames: const {'x': 'X'}),
    startedAtUtc: at.subtract(Duration(seconds: activeSeconds)),
    completedAtUtc: at,
    localCompletionDate: date,
    timezoneOffsetMinutes: 0,
    status: status,
    stepRecords: const [],
    activeSeconds: activeSeconds,
    restSeconds: 60,
    preparationSeconds: 10,
    elapsedSeconds: activeSeconds + 70,
    planAssignmentId: assignmentId,
    enrollmentId: enrollmentId,
  );
}
