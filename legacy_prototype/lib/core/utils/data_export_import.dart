import 'dart:convert';

import '../../features/profile/data/models/user_profile_model.dart';
import '../../features/workout/data/models/workout_history_model.dart';
import '../../features/achievements/data/models/achievement_model.dart';
import '../../features/challenges/data/models/challenge_model.dart';

/// Export/import user data as JSON for backup.
abstract final class DataExportImport {
  static String export({
    required UserProfileModel? profile,
    required List<WorkoutHistoryModel> history,
    required List<AchievementModel> achievements,
    required List<ChallengeModel> challenges,
    required List<String> favorites,
  }) {
    final data = {
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'profile': profile?.toJson(),
      'history': history.map((e) => e.toJson()).toList(),
      'achievements': achievements.map((e) => e.toJson()).toList(),
      'challenges': challenges.map((e) => e.toJson()).toList(),
      'favorites': favorites,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  static Map<String, dynamic>? parse(String jsonString) {
    try {
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
