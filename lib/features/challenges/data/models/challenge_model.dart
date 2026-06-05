import 'package:hive/hive.dart';

part 'challenge_model.g.dart';

@HiveType(typeId: 3)
class ChallengeModel extends HiveObject {
  ChallengeModel({
    required this.id,
    required this.title,
    required this.description,
    required this.targetValue,
    required this.currentValue,
    required this.unit,
    required this.type,
    this.isCompleted = false,
    this.completedAt,
    this.periodStart,
  });

  @HiveField(0)
  String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  String description;

  @HiveField(3)
  int targetValue;

  @HiveField(4)
  int currentValue;

  @HiveField(5)
  String unit;

  @HiveField(6)
  String type;

  @HiveField(7)
  bool isCompleted;

  @HiveField(8)
  DateTime? completedAt;

  @HiveField(9)
  DateTime? periodStart;

  double get progress =>
      targetValue > 0 ? (currentValue / targetValue).clamp(0.0, 1.0) : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'targetValue': targetValue,
        'currentValue': currentValue,
        'unit': unit,
        'type': type,
        'isCompleted': isCompleted,
        'completedAt': completedAt?.toIso8601String(),
        'periodStart': periodStart?.toIso8601String(),
      };

  factory ChallengeModel.fromJson(Map<String, dynamic> json) =>
      ChallengeModel(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        targetValue: json['targetValue'] as int,
        currentValue: json['currentValue'] as int? ?? 0,
        unit: json['unit'] as String,
        type: json['type'] as String,
        isCompleted: json['isCompleted'] as bool? ?? false,
        completedAt: json['completedAt'] != null
            ? DateTime.parse(json['completedAt'] as String)
            : null,
        periodStart: json['periodStart'] != null
            ? DateTime.parse(json['periodStart'] as String)
            : null,
      );
}
