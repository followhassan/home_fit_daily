import 'package:hive/hive.dart';

part 'workout_history_model.g.dart';

@HiveType(typeId: 0)
class WorkoutHistoryModel extends HiveObject {
  WorkoutHistoryModel({
    required this.id,
    required this.planId,
    required this.planName,
    required this.completedAt,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.exerciseCount,
    this.difficulty = '',
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String planId;

  @HiveField(2)
  String planName;

  @HiveField(3)
  DateTime completedAt;

  @HiveField(4)
  int durationSeconds;

  @HiveField(5)
  int caloriesBurned;

  @HiveField(6)
  int exerciseCount;

  @HiveField(7)
  String difficulty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'planId': planId,
        'planName': planName,
        'completedAt': completedAt.toIso8601String(),
        'durationSeconds': durationSeconds,
        'caloriesBurned': caloriesBurned,
        'exerciseCount': exerciseCount,
        'difficulty': difficulty,
      };

  factory WorkoutHistoryModel.fromJson(Map<String, dynamic> json) =>
      WorkoutHistoryModel(
        id: json['id'] as String,
        planId: json['planId'] as String,
        planName: json['planName'] as String,
        completedAt: DateTime.parse(json['completedAt'] as String),
        durationSeconds: json['durationSeconds'] as int,
        caloriesBurned: json['caloriesBurned'] as int,
        exerciseCount: json['exerciseCount'] as int,
        difficulty: json['difficulty'] as String? ?? '',
      );
}
