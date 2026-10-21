import '../../core/utils/json_utils.dart';
import 'enums.dart';
import 'workout.dart';

/// A workout created by the user with the workout builder.
class CustomWorkout {
  const CustomWorkout({
    required this.id,
    required this.title,
    required this.description,
    required this.steps,
    required this.rounds,
    required this.roundRestSeconds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CustomWorkout.fromJson(JsonMap json) {
    final id = readString(json, 'id');
    try {
      return CustomWorkout(
        id: id,
        title: readString(json, 'title'),
        description: readOptionalString(json, 'description') ?? '',
        steps: readObjectList(json, 'steps', WorkoutStep.fromJson),
        rounds: readIntOr(json, 'rounds', 1),
        roundRestSeconds: readIntOr(json, 'roundRestSeconds', 0),
        createdAt: readDateTime(json, 'createdAt').toUtc(),
        updatedAt: readDateTime(json, 'updatedAt').toUtc(),
      );
    } on FormatException catch (e) {
      throw FormatException('custom workout "$id": ${e.message}');
    }
  }

  final String id;
  final String title;
  final String description;
  final List<WorkoutStep> steps;
  final int rounds;
  final int roundRestSeconds;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Builds a playable [Workout]. [difficulty] is derived by the caller from
  /// the exercises used.
  Workout toWorkout({required Difficulty difficulty}) => Workout(
    id: id,
    title: title,
    description: description,
    category: WorkoutCategory.custom,
    goal: FitnessGoal.consistency,
    difficulty: difficulty,
    steps: steps,
    rounds: rounds,
    roundRestSeconds: roundRestSeconds,
    source: WorkoutSource.custom,
  );

  CustomWorkout copyWith({
    String? id,
    String? title,
    String? description,
    List<WorkoutStep>? steps,
    int? rounds,
    int? roundRestSeconds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => CustomWorkout(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    steps: steps ?? this.steps,
    rounds: rounds ?? this.rounds,
    roundRestSeconds: roundRestSeconds ?? this.roundRestSeconds,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'steps': steps.map((s) => s.toJson()).toList(),
    'rounds': rounds,
    'roundRestSeconds': roundRestSeconds,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
