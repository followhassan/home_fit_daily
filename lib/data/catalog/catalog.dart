import '../../domain/duration_estimator.dart';
import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/guide_article.dart';
import '../models/training_plan.dart';
import '../models/workout.dart';

/// Facts derived from a workout's exercises.
class WorkoutInfo {
  const WorkoutInfo({
    required this.equipment,
    required this.isLowImpact,
    required this.matRecommended,
    required this.estimate,
    required this.primaryMuscles,
    required this.exerciseIds,
    required this.missingExerciseIds,
  });

  /// Union of required equipment. Empty means no equipment needed.
  final Set<Equipment> equipment;

  /// True only when *every* exercise is low impact.
  final bool isLowImpact;
  final bool matRecommended;
  final DurationEstimate estimate;
  final Set<MuscleGroup> primaryMuscles;

  /// Distinct exercises in order of first appearance.
  final List<String> exerciseIds;

  /// Referenced exercises that no longer exist in the catalog.
  final Set<String> missingExerciseIds;

  bool get needsEquipment => equipment.isNotEmpty;

  String get equipmentLabel =>
      equipment.isEmpty ? 'No equipment' : equipment.map((e) => e.label).join(' · ');
}

/// Summary of a plan derived from its workouts.
class PlanInfo {
  const PlanInfo({
    required this.equipment,
    required this.averageMinutesPerWeek,
    required this.sessionsPerWeek,
  });

  final Set<Equipment> equipment;
  final int averageMinutesPerWeek;
  final double sessionsPerWeek;
}

/// The immutable, bundled content catalog with lookup indexes.
class Catalog {
  Catalog({
    required this.contentVersion,
    required this.exercises,
    required this.workouts,
    required this.plans,
    required this.articles,
    required this.tips,
  }) : _exercises = {for (final e in exercises) e.id: e},
       _workouts = {for (final w in workouts) w.id: w},
       _plans = {for (final p in plans) p.id: p},
       _articles = {for (final a in articles) a.id: a};

  final int contentVersion;
  final List<Exercise> exercises;
  final List<Workout> workouts;
  final List<TrainingPlan> plans;
  final List<GuideArticle> articles;
  final List<FitnessTip> tips;

  final Map<String, Exercise> _exercises;
  final Map<String, Workout> _workouts;
  final Map<String, TrainingPlan> _plans;
  final Map<String, GuideArticle> _articles;
  final Map<String, WorkoutInfo> _infoCache = {};
  final Map<String, PlanInfo> _planInfoCache = {};

  Exercise? exercise(String id) => _exercises[id];
  Workout? workout(String id) => _workouts[id];
  TrainingPlan? plan(String id) => _plans[id];
  GuideArticle? article(String id) => _articles[id];

  int secondsPerRep(String exerciseId) =>
      _exercises[exerciseId]?.secondsPerRep ?? DurationEstimator.fallbackSecondsPerRep;

  /// Derived facts for [workout]. Cached for catalog workouts; computed on
  /// demand for custom workouts, which can change.
  WorkoutInfo infoFor(Workout workout) {
    if (!workout.isCustom) {
      final cached = _infoCache[workout.id];
      if (cached != null) return cached;
    }
    final info = _analyze(workout);
    if (!workout.isCustom) _infoCache[workout.id] = info;
    return info;
  }

  WorkoutInfo _analyze(Workout workout) {
    final equipment = <Equipment>{};
    final muscles = <MuscleGroup>{};
    final ids = <String>[];
    final missing = <String>{};
    var lowImpact = true;
    var mat = false;
    for (final step in workout.steps) {
      final exercise = _exercises[step.exerciseId];
      if (exercise == null) {
        missing.add(step.exerciseId);
        continue;
      }
      if (!ids.contains(exercise.id)) ids.add(exercise.id);
      equipment.addAll(exercise.equipment);
      if (step.type == StepType.main) muscles.addAll(exercise.primaryMuscles);
      lowImpact &= exercise.isLowImpact;
      mat |= exercise.matRecommended;
    }
    return WorkoutInfo(
      equipment: equipment,
      isLowImpact: lowImpact && ids.isNotEmpty,
      matRecommended: mat,
      estimate: DurationEstimator.estimate(workout, secondsPerRep: secondsPerRep),
      primaryMuscles: muscles,
      exerciseIds: ids,
      missingExerciseIds: missing,
    );
  }

  /// The hardest exercise level used by a list of steps.
  Difficulty difficultyOf(Iterable<WorkoutStep> steps) {
    var result = Difficulty.beginner;
    for (final step in steps) {
      final level = _exercises[step.exerciseId]?.difficulty;
      if (level != null && level.rank > result.rank) result = level;
    }
    return result;
  }

  PlanInfo infoForPlan(TrainingPlan plan) {
    return _planInfoCache.putIfAbsent(plan.id, () {
      final equipment = <Equipment>{};
      var seconds = 0;
      var sessions = 0;
      for (final day in plan.days) {
        final workout = day.workoutId == null ? null : _workouts[day.workoutId];
        if (workout == null) continue;
        final info = infoFor(workout);
        equipment.addAll(info.equipment);
        seconds += info.estimate.seconds;
        sessions++;
      }
      final weeks = plan.weekCount == 0 ? 1 : plan.weekCount;
      return PlanInfo(
        equipment: equipment,
        averageMinutesPerWeek: (seconds / 60 / weeks).round(),
        sessionsPerWeek: sessions / weeks,
      );
    });
  }

  List<GuideArticle> articlesByIds(Iterable<String> ids) =>
      ids.map(article).whereType<GuideArticle>().toList();

  List<Exercise> exercisesByIds(Iterable<String> ids) =>
      ids.map(exercise).whereType<Exercise>().toList();

  List<Workout> workoutsByIds(Iterable<String> ids) =>
      ids.map(workout).whereType<Workout>().toList();
}
