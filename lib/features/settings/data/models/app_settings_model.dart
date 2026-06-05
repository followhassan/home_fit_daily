import 'package:hive/hive.dart';

part 'app_settings_model.g.dart';

@HiveType(typeId: 4)
class AppSettingsModel extends HiveObject {
  AppSettingsModel({
    this.darkMode = true,
    this.notificationsEnabled = true,
    this.dailyWorkoutGoal = 1,
    this.dailyMinutesGoal = 15,
    this.dailyCaloriesGoal = 100,
    this.restTimerSeconds = 30,
  });

  @HiveField(0)
  bool darkMode;

  @HiveField(1)
  bool notificationsEnabled;

  @HiveField(2)
  int dailyWorkoutGoal;

  @HiveField(3)
  int dailyMinutesGoal;

  @HiveField(4)
  int dailyCaloriesGoal;

  @HiveField(5)
  int restTimerSeconds;
}
