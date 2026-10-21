/// Domain entity for an exercise.
class ExerciseEntity {
  const ExerciseEntity({
    required this.id,
    required this.name,
    required this.description,
    required this.instructions,
    required this.caloriesPerMinute,
    required this.durationSeconds,
    required this.category,
    required this.bodyPart,
    required this.iconName,
  });

  final String id;
  final String name;
  final String description;
  final List<String> instructions;
  final int caloriesPerMinute;
  final int durationSeconds;
  final String category;
  final String bodyPart;
  final String iconName;

  int get estimatedCalories =>
      ((caloriesPerMinute * durationSeconds) / 60).round();
}
