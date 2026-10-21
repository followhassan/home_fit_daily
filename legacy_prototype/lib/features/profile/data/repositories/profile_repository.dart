import '../../../../core/services/hive_service.dart';
import '../models/user_profile_model.dart';

class ProfileRepository {
  static const String _profileKey = 'user_profile';

  Future<UserProfileModel> getProfile() async {
    final box = HiveService.instance.profileBox;
    if (box.containsKey(_profileKey)) {
      return box.get(_profileKey)!;
    }
    final profile = UserProfileModel();
    await box.put(_profileKey, profile);
    return profile;
  }

  Future<void> saveProfile(UserProfileModel profile) async {
    await HiveService.instance.profileBox.put(_profileKey, profile);
  }

  Future<void> updateStreak(DateTime workoutDate) async {
    final profile = await getProfile();
    final today = DateTime(workoutDate.year, workoutDate.month, workoutDate.day);

    if (profile.lastWorkoutDate != null) {
      final last = DateTime(
        profile.lastWorkoutDate!.year,
        profile.lastWorkoutDate!.month,
        profile.lastWorkoutDate!.day,
      );
      final diff = today.difference(last).inDays;

      if (diff == 0) {
        // Same day, no streak change
      } else if (diff == 1) {
        profile.currentStreak += 1;
      } else {
        profile.currentStreak = 1;
      }
    } else {
      profile.currentStreak = 1;
    }

    if (profile.currentStreak > profile.longestStreak) {
      profile.longestStreak = profile.currentStreak;
    }

    profile.lastWorkoutDate = today;
    await saveProfile(profile);
  }

  Future<void> addWorkoutStats(int calories) async {
    final profile = await getProfile();
    profile.totalWorkouts += 1;
    profile.totalCalories += calories;
    await saveProfile(profile);
  }
}
