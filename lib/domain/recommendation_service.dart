import '../core/utils/local_date.dart';
import '../data/catalog/catalog.dart';
import '../data/models/enums.dart';
import '../data/models/user_profile.dart';
import '../data/models/workout.dart';
import '../data/models/workout_session.dart';

class Recommendation {
  const Recommendation({
    required this.workout,
    required this.info,
    required this.explanation,
    required this.isExactMatch,
  });

  final Workout workout;
  final WorkoutInfo info;

  /// e.g. "Beginner · No equipment · About 15 min".
  final String explanation;

  /// False when the list had to fall back to a general starting point.
  final bool isExactMatch;
}

/// Deterministic, on-device workout suggestions based on the user's stated
/// preferences. This is simple preference matching, not medical advice or
/// personalised coaching.
///
/// Hard requirements: required equipment must be available, and a
/// low-impact preference is respected. Workouts above the user's level are
/// excluded. The remaining workouts are ranked by closeness to the preferred
/// duration, goal fit and level fit, with recently completed workouts
/// ranked lower for variety. Ties are broken by ID so results are stable.
abstract final class RecommendationService {
  static List<Recommendation> recommend({
    required Catalog catalog,
    required UserProfile profile,
    Iterable<WorkoutSession> history = const [],
    LocalDate? today,
    int limit = 6,
    bool Function(Workout)? where,
  }) {
    final day = today ?? LocalDate.today();
    final recent = <String>{
      for (final s in history)
        if (s.status != SessionStatus.abandoned && day.daysSince(s.localCompletionDate) <= 2)
          s.sourceWorkoutId,
    };

    final scored = <(Workout, WorkoutInfo, int)>[];
    for (final workout in catalog.workouts) {
      if (where != null && !where(workout)) continue;
      final info = catalog.infoFor(workout);
      if (!_fits(profile, workout, info)) continue;
      scored.add((workout, info, _score(profile, workout, info, recent)));
    }
    scored.sort((a, b) {
      final byScore = b.$3.compareTo(a.$3);
      return byScore != 0 ? byScore : a.$1.id.compareTo(b.$1.id);
    });

    final results = [
      for (final (w, info, _) in scored.take(limit))
        Recommendation(workout: w, info: info, explanation: explain(w, info), isExactMatch: true),
    ];

    if (results.length < limit) {
      // Graceful fallback: gentle beginner, no-equipment workouts.
      final fallback = catalog.workouts.where((w) {
        if (results.any((r) => r.workout.id == w.id)) return false;
        if (where != null && !where(w)) return false;
        final info = catalog.infoFor(w);
        return w.difficulty == Difficulty.beginner &&
            !info.needsEquipment &&
            (!profile.lowImpactPreference || info.isLowImpact);
      }).toList()..sort((a, b) => a.id.compareTo(b.id));
      for (final w in fallback.take(limit - results.length)) {
        final info = catalog.infoFor(w);
        results.add(
          Recommendation(
            workout: w,
            info: info,
            explanation: explain(w, info),
            isExactMatch: false,
          ),
        );
      }
    }
    return results;
  }

  static bool _fits(UserProfile profile, Workout workout, WorkoutInfo info) {
    if (!profile.availableEquipment.containsAll(info.equipment)) return false;
    if (profile.lowImpactPreference && !info.isLowImpact) return false;
    if (workout.difficulty.rank > profile.experienceLevel.rank) return false;
    return info.missingExerciseIds.isEmpty;
  }

  static int _score(UserProfile profile, Workout workout, WorkoutInfo info, Set<String> recent) {
    var score = 0;
    final diff = (info.estimate.minutes - profile.preferredDurationMinutes).abs();
    score += 30 - (diff * 2).clamp(0, 30);
    if (workout.goal == profile.primaryGoal) score += 12;
    if (_goalCategories(profile.primaryGoal).contains(workout.category)) {
      score += 6;
    }
    if (workout.difficulty == profile.experienceLevel) score += 8;
    if (recent.contains(workout.id)) score -= 15;
    return score;
  }

  static Set<WorkoutCategory> _goalCategories(FitnessGoal goal) => switch (goal) {
    FitnessGoal.consistency => {WorkoutCategory.fullBody, WorkoutCategory.quickBreak},
    FitnessGoal.strength => {
      WorkoutCategory.strength,
      WorkoutCategory.upperBody,
      WorkoutCategory.lowerBody,
      WorkoutCategory.core,
    },
    FitnessGoal.endurance => {WorkoutCategory.cardio, WorkoutCategory.fullBody},
    FitnessGoal.mobility => {WorkoutCategory.mobility, WorkoutCategory.stretching},
  };

  static String explain(Workout workout, WorkoutInfo info) => [
    workout.difficulty.label,
    info.equipmentLabel,
    if (info.isLowImpact) 'Low impact',
    info.estimate.label,
  ].join(' · ');
}
