import '../../../../core/services/hive_service.dart';
import '../datasources/achievement_definitions.dart';
import '../models/achievement_model.dart';
import '../../../profile/data/models/user_profile_model.dart';

class AchievementRepository {
  Future<List<AchievementModel>> getAchievements() async {
    final box = HiveService.instance.achievementsBox;
    if (box.isEmpty) {
      final defaults = AchievementDefinitions.defaults();
      for (final a in defaults) {
        await box.put(a.id, a);
      }
      return defaults;
    }
    return box.values.toList();
  }

  Future<void> unlockAchievement(String id) async {
    final box = HiveService.instance.achievementsBox;
    final achievement = box.get(id);
    if (achievement != null && !achievement.isUnlocked) {
      achievement.isUnlocked = true;
      achievement.unlockedAt = DateTime.now();
      await achievement.save();
    }
  }

  Future<void> checkAndUnlock(UserProfileModel profile) async {
    if (profile.totalWorkouts >= 1) {
      await unlockAchievement('first_workout');
    }
    if (profile.currentStreak >= 3) await unlockAchievement('streak_3');
    if (profile.currentStreak >= 7) await unlockAchievement('streak_7');
    if (profile.currentStreak >= 30) await unlockAchievement('streak_30');
    if (profile.totalCalories >= 1000) await unlockAchievement('calories_1000');
    if (profile.totalWorkouts >= 50) await unlockAchievement('workouts_50');
  }

  Future<void> resetAchievements() async {
    final box = HiveService.instance.achievementsBox;
    await box.clear();
    final defaults = AchievementDefinitions.defaults();
    for (final a in defaults) {
      await box.put(a.id, a);
    }
  }
}
