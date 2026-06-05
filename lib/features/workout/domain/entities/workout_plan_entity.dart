import 'exercise_entity.dart';

enum Difficulty { beginner, intermediate, advanced }

/// Domain entity for a workout plan.
class WorkoutPlanEntity {
  const WorkoutPlanEntity({
    required this.id,
    required this.name,
    required this.difficulty,
    required this.durationMinutes,
    required this.estimatedCalories,
    required this.exercises,
    required this.description,
    required this.gradientStart,
    required this.gradientEnd,
  });

  final String id;
  final String name;
  final Difficulty difficulty;
  final int durationMinutes;
  final int estimatedCalories;
  final List<ExerciseEntity> exercises;
  final String description;
  final int gradientStart;
  final int gradientEnd;

  int get exerciseCount => exercises.length;

  String get difficultyLabel {
    switch (difficulty) {
      case Difficulty.beginner:
        return 'Beginner';
      case Difficulty.intermediate:
        return 'Intermediate';
      case Difficulty.advanced:
        return 'Advanced';
    }
  }
}
