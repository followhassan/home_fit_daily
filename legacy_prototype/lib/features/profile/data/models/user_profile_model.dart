import 'package:hive/hive.dart';

part 'user_profile_model.g.dart';

@HiveType(typeId: 1)
class UserProfileModel extends HiveObject {
  UserProfileModel({
    this.name = 'Fitness Enthusiast',
    this.age = 25,
    this.gender = 'Other',
    this.weight = 70.0,
    this.height = 170.0,
    this.goalWeight = 65.0,
    this.fitnessGoal = 'Stay Fit',
    this.totalWorkouts = 0,
    this.totalCalories = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastWorkoutDate,
  });

  @HiveField(0)
  String name;

  @HiveField(1)
  int age;

  @HiveField(2)
  String gender;

  @HiveField(3)
  double weight;

  @HiveField(4)
  double height;

  @HiveField(5)
  double goalWeight;

  @HiveField(6)
  String fitnessGoal;

  @HiveField(7)
  int totalWorkouts;

  @HiveField(8)
  int totalCalories;

  @HiveField(9)
  int currentStreak;

  @HiveField(10)
  int longestStreak;

  @HiveField(11)
  DateTime? lastWorkoutDate;

  Map<String, dynamic> toJson() => {
        'name': name,
        'age': age,
        'gender': gender,
        'weight': weight,
        'height': height,
        'goalWeight': goalWeight,
        'fitnessGoal': fitnessGoal,
        'totalWorkouts': totalWorkouts,
        'totalCalories': totalCalories,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'lastWorkoutDate': lastWorkoutDate?.toIso8601String(),
      };

  factory UserProfileModel.fromJson(Map<String, dynamic> json) =>
      UserProfileModel(
        name: json['name'] as String? ?? 'Fitness Enthusiast',
        age: json['age'] as int? ?? 25,
        gender: json['gender'] as String? ?? 'Other',
        weight: (json['weight'] as num?)?.toDouble() ?? 70.0,
        height: (json['height'] as num?)?.toDouble() ?? 170.0,
        goalWeight: (json['goalWeight'] as num?)?.toDouble() ?? 65.0,
        fitnessGoal: json['fitnessGoal'] as String? ?? 'Stay Fit',
        totalWorkouts: json['totalWorkouts'] as int? ?? 0,
        totalCalories: json['totalCalories'] as int? ?? 0,
        currentStreak: json['currentStreak'] as int? ?? 0,
        longestStreak: json['longestStreak'] as int? ?? 0,
        lastWorkoutDate: json['lastWorkoutDate'] != null
            ? DateTime.parse(json['lastWorkoutDate'] as String)
            : null,
      );

  UserProfileModel copyWith({
    String? name,
    int? age,
    String? gender,
    double? weight,
    double? height,
    double? goalWeight,
    String? fitnessGoal,
    int? totalWorkouts,
    int? totalCalories,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastWorkoutDate,
  }) {
    return UserProfileModel(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      height: height ?? this.height,
      goalWeight: goalWeight ?? this.goalWeight,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      totalWorkouts: totalWorkouts ?? this.totalWorkouts,
      totalCalories: totalCalories ?? this.totalCalories,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastWorkoutDate: lastWorkoutDate ?? this.lastWorkoutDate,
    );
  }
}
