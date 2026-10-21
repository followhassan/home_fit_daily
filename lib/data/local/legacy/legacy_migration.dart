import '../../../core/utils/local_date.dart';
import '../../models/app_settings.dart';
import '../../models/enums.dart';
import '../../models/personal_records.dart';
import '../../models/user_profile.dart';
import '../../models/workout.dart';
import '../../models/workout_session.dart';

/// Plain data read from the prototype's storage.
class LegacyData {
  const LegacyData({
    this.profileName,
    this.fitnessGoal,
    this.darkMode,
    this.history = const [],
    this.favoriteExerciseIds = const [],
  });

  final String? profileName;
  final String? fitnessGoal;
  final bool? darkMode;
  final List<LegacyHistoryEntry> history;
  final List<String> favoriteExerciseIds;

  bool get isEmpty =>
      profileName == null &&
      fitnessGoal == null &&
      darkMode == null &&
      history.isEmpty &&
      favoriteExerciseIds.isEmpty;
}

class LegacyHistoryEntry {
  const LegacyHistoryEntry({
    required this.id,
    required this.planId,
    required this.planName,
    required this.completedAtLocal,
    required this.durationSeconds,
    required this.difficulty,
  });

  final String id;
  final String planId;
  final String planName;
  final DateTime completedAtLocal;
  final int durationSeconds;
  final String difficulty;
}

class LegacyConversion {
  const LegacyConversion({
    required this.profile,
    required this.settings,
    required this.sessions,
    required this.favorites,
  });

  final UserProfile? profile;
  final AppSettings? settings;
  final List<WorkoutSession> sessions;
  final List<FavoriteEntry> favorites;
}

/// Converts prototype (schema 1) data into the current format.
///
/// Only data the user actually produced is carried over. Values the
/// prototype filled with placeholders (default weight, height, age, gender,
/// estimated calories, cached streak totals) are intentionally dropped
/// rather than presented as real measurements.
abstract final class LegacyConverter {
  static const _placeholderName = 'Fitness Enthusiast';

  /// Prototype exercise IDs that have an equivalent in the new catalog.
  static const exerciseIdMap = {
    'jumping_jacks': 'jumping_jacks',
    'high_knees': 'high_knees',
    'arm_circles': 'arm_circles',
    'squats': 'bodyweight_squat',
    'standing_crunches': 'standing_cross_crunch',
    'push_ups': 'push_up',
    'lunges': 'reverse_lunge',
    'mountain_climbers': 'mountain_climber',
    'plank': 'forearm_plank',
    'burpees': 'burpee',
    'jump_squats': 'jump_squat',
  };

  static LegacyConversion convert(
    LegacyData data, {
    required String profileId,
    required DateTime nowUtc,
    required bool Function(String exerciseId) exerciseExists,
  }) {
    UserProfile? profile;
    final name = data.profileName?.trim();
    if (name != null || data.fitnessGoal != null) {
      profile = UserProfile.initial(id: profileId, now: nowUtc).copyWith(
        displayName: (name == null || name == _placeholderName) ? '' : name,
        primaryGoal: _goal(data.fitnessGoal),
      );
    }

    final settings = data.darkMode == null
        ? null
        : AppSettings.defaults.copyWith(
            theme: data.darkMode! ? ThemePreference.dark : ThemePreference.light,
          );

    final sessions = [
      for (final entry in data.history)
        if (entry.durationSeconds >= 0) _session(entry),
    ];

    final favorites = <FavoriteEntry>[];
    final seen = <String>{};
    for (final oldId in data.favoriteExerciseIds) {
      final newId = exerciseIdMap[oldId];
      if (newId == null || !exerciseExists(newId) || !seen.add(newId)) continue;
      favorites.add(FavoriteEntry(kind: FavoriteKind.exercise, itemId: newId, addedAtUtc: nowUtc));
    }

    return LegacyConversion(
      profile: profile,
      settings: settings,
      sessions: sessions,
      favorites: favorites,
    );
  }

  static FitnessGoal _goal(String? legacy) {
    final value = legacy?.toLowerCase() ?? '';
    if (value.contains('muscle') || value.contains('strength')) {
      return FitnessGoal.strength;
    }
    if (value.contains('endurance') || value.contains('cardio')) {
      return FitnessGoal.endurance;
    }
    if (value.contains('flex') || value.contains('mobility')) {
      return FitnessGoal.mobility;
    }
    return FitnessGoal.consistency;
  }

  static WorkoutSession _session(LegacyHistoryEntry entry) {
    final completedLocal = entry.completedAtLocal;
    final difficulty = Difficulty.values.firstWhere(
      (d) => d.label.toLowerCase() == entry.difficulty.toLowerCase(),
      orElse: () => Difficulty.beginner,
    );
    final workout = Workout(
      id: 'legacy_${entry.planId}',
      title: entry.planName.isEmpty ? 'Workout' : entry.planName,
      description: 'Imported from an earlier version of HomeFit.',
      category: WorkoutCategory.fullBody,
      goal: FitnessGoal.consistency,
      difficulty: difficulty,
      steps: const [],
    );
    return WorkoutSession(
      id: 'legacy_${entry.id}',
      sourceWorkoutId: workout.id,
      source: WorkoutSource.catalog,
      snapshot: WorkoutSnapshot(workout: workout, exerciseNames: const {}),
      startedAtUtc: completedLocal.subtract(Duration(seconds: entry.durationSeconds)).toUtc(),
      completedAtUtc: completedLocal.toUtc(),
      localCompletionDate: LocalDate.fromDateTime(completedLocal),
      timezoneOffsetMinutes: completedLocal.timeZoneOffset.inMinutes,
      status: SessionStatus.completed,
      stepRecords: const [],
      activeSeconds: entry.durationSeconds,
      restSeconds: 0,
      preparationSeconds: 0,
      elapsedSeconds: entry.durationSeconds,
      importedFromLegacy: true,
    );
  }
}
