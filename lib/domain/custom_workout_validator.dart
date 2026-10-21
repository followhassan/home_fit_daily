import '../data/catalog/catalog.dart';
import '../data/models/custom_workout.dart';
import '../domain/duration_estimator.dart';

/// Limits for user-created workouts.
abstract final class CustomWorkoutLimits {
  static const titleMax = 60;
  static const descriptionMax = 300;
  static const maxSteps = 40;
  static const minDuration = 5;
  static const maxDuration = 600;
  static const minReps = 1;
  static const maxReps = 100;
  static const maxSets = 10;
  static const maxRest = 300;
  static const maxRounds = 10;
  static const maxTotalMinutes = 120;
}

class CustomWorkoutValidation {
  const CustomWorkoutValidation({
    this.titleError,
    this.descriptionError,
    this.stepsError,
    this.stepErrors = const {},
    this.roundsError,
  });

  final String? titleError;
  final String? descriptionError;
  final String? stepsError;

  /// Errors per step id.
  final Map<String, String> stepErrors;
  final String? roundsError;

  bool get isValid =>
      titleError == null &&
      descriptionError == null &&
      stepsError == null &&
      stepErrors.isEmpty &&
      roundsError == null;

  /// All messages, for a summary at the top of the form.
  List<String> get messages => [
    ?titleError,
    ?descriptionError,
    ?stepsError,
    ?roundsError,
    ...stepErrors.values,
  ];
}

abstract final class CustomWorkoutValidator {
  static CustomWorkoutValidation validate(CustomWorkout workout, Catalog catalog) {
    String? titleError;
    final title = workout.title.trim();
    if (title.isEmpty) {
      titleError = 'Give your workout a name.';
    } else if (title.length > CustomWorkoutLimits.titleMax) {
      titleError = 'Keep the name under ${CustomWorkoutLimits.titleMax} characters.';
    }

    String? descriptionError;
    if (workout.description.length > CustomWorkoutLimits.descriptionMax) {
      descriptionError =
          'Keep the description under ${CustomWorkoutLimits.descriptionMax} '
          'characters.';
    }

    String? stepsError;
    if (workout.steps.isEmpty) {
      stepsError = 'Add at least one exercise.';
    } else if (workout.steps.length > CustomWorkoutLimits.maxSteps) {
      stepsError = 'Use at most ${CustomWorkoutLimits.maxSteps} exercises.';
    }

    final stepErrors = <String, String>{};
    for (final step in workout.steps) {
      final exercise = catalog.exercise(step.exerciseId);
      String? error;
      if (exercise == null) {
        error =
            'An exercise in this workout is no longer available. '
            'Remove it to save.';
      } else if (!exercise.supports(step.execution)) {
        error =
            '${exercise.name} can only be done '
            '${exercise.supportsTimed ? 'for time' : 'for repetitions'}.';
      } else if (step.isTimed) {
        final d = step.durationSeconds;
        if (d == null ||
            d < CustomWorkoutLimits.minDuration ||
            d > CustomWorkoutLimits.maxDuration) {
          error =
              '${exercise.name}: time must be between '
              '${CustomWorkoutLimits.minDuration} and '
              '${CustomWorkoutLimits.maxDuration} seconds.';
        }
      } else {
        final r = step.repetitions;
        if (r == null || r < CustomWorkoutLimits.minReps || r > CustomWorkoutLimits.maxReps) {
          error =
              '${exercise.name}: repetitions must be between '
              '${CustomWorkoutLimits.minReps} and ${CustomWorkoutLimits.maxReps}.';
        }
      }
      if (error == null && exercise != null) {
        if (step.sets < 1 || step.sets > CustomWorkoutLimits.maxSets) {
          error =
              '${exercise.name}: sets must be between 1 and '
              '${CustomWorkoutLimits.maxSets}.';
        } else if (step.restSeconds < 0 || step.restSeconds > CustomWorkoutLimits.maxRest) {
          error =
              '${exercise.name}: rest must be between 0 and '
              '${CustomWorkoutLimits.maxRest} seconds.';
        } else if (step.perSide && !exercise.isPerSide) {
          error = '${exercise.name} works both sides at once.';
        }
      }
      if (error != null) stepErrors[step.id] = error;
    }

    String? roundsError;
    if (workout.rounds < 1 || workout.rounds > CustomWorkoutLimits.maxRounds) {
      roundsError = 'Rounds must be between 1 and ${CustomWorkoutLimits.maxRounds}.';
    } else if (workout.roundRestSeconds < 0 ||
        workout.roundRestSeconds > CustomWorkoutLimits.maxRest) {
      roundsError = 'Rest between rounds must be 0–${CustomWorkoutLimits.maxRest} seconds.';
    } else if (stepsError == null && stepErrors.isEmpty) {
      final estimate = DurationEstimator.estimate(
        workout.toWorkout(difficulty: catalog.difficultyOf(workout.steps)),
        secondsPerRep: catalog.secondsPerRep,
      );
      if (estimate.minutes > CustomWorkoutLimits.maxTotalMinutes) {
        roundsError =
            'This workout would take about ${estimate.minutes} '
            'minutes. Keep it under ${CustomWorkoutLimits.maxTotalMinutes}.';
      }
    }

    return CustomWorkoutValidation(
      titleError: titleError,
      descriptionError: descriptionError,
      stepsError: stepsError,
      stepErrors: stepErrors,
      roundsError: roundsError,
    );
  }
}
