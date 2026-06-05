/// App-wide constants.
abstract final class AppConstants {
  static const String appName = 'HomeFit';
  static const String appTagline = 'Home Workout Fitness';

  // Hive box names
  static const String profileBox = 'profile_box';
  static const String historyBox = 'history_box';
  static const String achievementsBox = 'achievements_box';
  static const String challengesBox = 'challenges_box';
  static const String favoritesBox = 'favorites_box';
  static const String settingsBox = 'settings_box';

  // SharedPreferences keys
  static const String onboardingKey = 'onboarding_complete';
  static const String darkModeKey = 'dark_mode';
  static const String notificationsKey = 'notifications_enabled';

  // Rest timer default (seconds)
  static const int defaultRestSeconds = 30;

  // Daily goal defaults
  static const int defaultDailyWorkoutGoal = 1;
  static const int defaultDailyMinutesGoal = 15;
  static const int defaultDailyCaloriesGoal = 100;
}
