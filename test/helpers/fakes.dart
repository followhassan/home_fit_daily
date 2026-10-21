import 'dart:async';

import 'package:home_fit_daily/core/services/reminder_service.dart';
import 'package:home_fit_daily/data/models/app_settings.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/workout.dart';
import 'package:home_fit_daily/domain/workout_engine.dart';

/// Monotonic clock controlled by tests.
class FakeMonotonicClock implements MonotonicClock {
  int ms = 0;

  @override
  int nowMs() => ms;

  void advance(int milliseconds) => ms += milliseconds;
  void advanceSeconds(num seconds) => ms += (seconds * 1000).round();
}

/// Reminder service that records calls and lets tests choose the
/// permission answer.
class FakeReminderService implements ReminderService {
  FakeReminderService({this.grant = true, this.alreadyGranted = false});

  bool grant;
  bool alreadyGranted;
  int requestCount = 0;
  int cancelCount = 0;
  ReminderPreferences? applied;
  // Lives for the whole test; nothing listens after the test ends.
  // ignore: close_sinks
  final StreamController<String> _taps = StreamController.broadcast();

  @override
  Future<void> init() async {}

  @override
  Future<bool> requestPermission() async {
    requestCount++;
    if (grant) alreadyGranted = true;
    return grant;
  }

  @override
  Future<bool> hasPermission() async => alreadyGranted;

  @override
  Future<void> apply(ReminderPreferences preferences) async {
    applied = preferences.enabled ? preferences : null;
  }

  @override
  Future<void> cancelAll() async {
    cancelCount++;
    applied = null;
  }

  @override
  Stream<String> get taps => _taps.stream;

  @override
  Future<String?> takeLaunchPayload() async => null;
}

WorkoutStep timedStep(
  String id,
  String exerciseId, {
  int seconds = 30,
  int rest = 0,
  int sets = 1,
  bool perSide = false,
  StepType type = StepType.main,
}) => WorkoutStep(
  id: id,
  exerciseId: exerciseId,
  type: type,
  execution: ExecutionType.timed,
  durationSeconds: seconds,
  sets: sets,
  restSeconds: rest,
  perSide: perSide,
);

WorkoutStep repStep(
  String id,
  String exerciseId, {
  int reps = 10,
  int rest = 0,
  int sets = 1,
  bool perSide = false,
  StepType type = StepType.main,
}) => WorkoutStep(
  id: id,
  exerciseId: exerciseId,
  type: type,
  execution: ExecutionType.reps,
  repetitions: reps,
  sets: sets,
  restSeconds: rest,
  perSide: perSide,
);

Workout testWorkout(
  List<WorkoutStep> steps, {
  int rounds = 1,
  int roundRest = 0,
  String id = 'test_workout',
}) => Workout(
  id: id,
  title: 'Test workout',
  description: 'A workout used in tests.',
  category: WorkoutCategory.fullBody,
  goal: FitnessGoal.consistency,
  difficulty: Difficulty.beginner,
  steps: steps,
  rounds: rounds,
  roundRestSeconds: roundRest,
);
