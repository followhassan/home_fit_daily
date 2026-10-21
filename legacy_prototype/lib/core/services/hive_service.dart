import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';
import '../../features/workout/data/models/workout_history_model.dart';
import '../../features/profile/data/models/user_profile_model.dart';
import '../../features/achievements/data/models/achievement_model.dart';
import '../../features/challenges/data/models/challenge_model.dart';
import '../../features/settings/data/models/app_settings_model.dart';

/// Initializes and provides access to Hive boxes.
class HiveService {
  HiveService._();
  static final HiveService instance = HiveService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await Hive.initFlutter();

    Hive.registerAdapter(WorkoutHistoryModelAdapter());
    Hive.registerAdapter(UserProfileModelAdapter());
    Hive.registerAdapter(AchievementModelAdapter());
    Hive.registerAdapter(ChallengeModelAdapter());
    Hive.registerAdapter(AppSettingsModelAdapter());

    await Future.wait([
      Hive.openBox<WorkoutHistoryModel>(AppConstants.historyBox),
      Hive.openBox<UserProfileModel>(AppConstants.profileBox),
      Hive.openBox<AchievementModel>(AppConstants.achievementsBox),
      Hive.openBox<ChallengeModel>(AppConstants.challengesBox),
      Hive.openBox<String>(AppConstants.favoritesBox),
      Hive.openBox<AppSettingsModel>(AppConstants.settingsBox),
    ]);

    _initialized = true;
  }

  Box<WorkoutHistoryModel> get historyBox =>
      Hive.box<WorkoutHistoryModel>(AppConstants.historyBox);

  Box<UserProfileModel> get profileBox =>
      Hive.box<UserProfileModel>(AppConstants.profileBox);

  Box<AchievementModel> get achievementsBox =>
      Hive.box<AchievementModel>(AppConstants.achievementsBox);

  Box<ChallengeModel> get challengesBox =>
      Hive.box<ChallengeModel>(AppConstants.challengesBox);

  Box<String> get favoritesBox =>
      Hive.box<String>(AppConstants.favoritesBox);

  Box<AppSettingsModel> get settingsBox =>
      Hive.box<AppSettingsModel>(AppConstants.settingsBox);

  Future<void> clearAll() async {
    await historyBox.clear();
    await profileBox.clear();
    await achievementsBox.clear();
    await challengesBox.clear();
    await favoritesBox.clear();
    await settingsBox.clear();
  }
}
