import '../models/enums.dart';
import '../models/exercise.dart';
import '../models/training_plan.dart';
import '../models/workout.dart';
import 'catalog.dart';

enum IssueSeverity { error, warning }

class ValidationIssue {
  const ValidationIssue(this.severity, this.location, this.message);

  final IssueSeverity severity;
  final String location;
  final String message;

  bool get isError => severity == IssueSeverity.error;

  @override
  String toString() =>
      '${severity == IssueSeverity.error ? 'ERROR' : 'WARN'} '
      '$location: $message';
}

/// Validates the bundled catalog: references, value ranges, required
/// content quality and minimum counts. Used by unit tests and by a debug-mode
/// startup check.
class CatalogValidator {
  CatalogValidator(this.catalog, {this.assetExists});

  final Catalog catalog;

  /// Returns whether a bundled asset exists. When null, asset checks are
  /// skipped.
  final bool Function(String path)? assetExists;

  static const minExercises = 60;
  static const minWorkouts = 24;
  static const minPlans = 4;
  static const minArticles = 20;

  static final _idPattern = RegExp(r'^[a-z0-9]+(_[a-z0-9]+)*$');

  final List<ValidationIssue> _issues = [];

  List<ValidationIssue> validate() {
    _issues.clear();
    _checkCounts();
    _checkExercises();
    _checkWorkouts();
    _checkPlans();
    _checkArticles();
    _checkTips();
    return List.unmodifiable(_issues);
  }

  void _error(String location, String message) =>
      _issues.add(ValidationIssue(IssueSeverity.error, location, message));

  void _warn(String location, String message) =>
      _issues.add(ValidationIssue(IssueSeverity.warning, location, message));

  void _checkCounts() {
    if (catalog.exercises.length < minExercises) {
      _error('catalog', 'needs at least $minExercises exercises');
    }
    if (catalog.workouts.length < minWorkouts) {
      _error('catalog', 'needs at least $minWorkouts workouts');
    }
    final completePlans = catalog.plans
        .where((p) => p.days.length == TrainingPlan.lengthInDays)
        .length;
    if (completePlans < minPlans) {
      _error('catalog', 'needs at least $minPlans complete 28-day plans');
    }
    if (catalog.articles.length < minArticles) {
      _error('catalog', 'needs at least $minArticles guide articles');
    }
  }

  void _checkIds(String kind, Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!_idPattern.hasMatch(id)) _error('$kind "$id"', 'invalid id format');
      if (!seen.add(id)) _error('$kind "$id"', 'duplicate id');
    }
  }

  void _text(String location, String field, String? value, int minLength) {
    if (value == null || value.trim().length < minLength) {
      _error(location, '"$field" is missing or too short (min $minLength)');
    }
  }

  void _checkExercises() {
    _checkIds('exercise', catalog.exercises.map((e) => e.id));
    final names = <String>{};
    for (final e in catalog.exercises) {
      final at = 'exercise "${e.id}"';
      if (!names.add(e.name.toLowerCase())) _error(at, 'duplicate name');
      _text(at, 'name', e.name, 3);
      _text(at, 'description', e.description, 25);
      _text(at, 'setup', e.setupInstructions, 20);
      _text(at, 'breathing', e.breathingGuidance, 15);
      _text(at, 'easier', e.easierVariation, 15);
      if (e.harderVariation != null) _text(at, 'harder', e.harderVariation, 15);
      if (e.executionInstructions.length < 2) {
        _error(at, 'needs at least 2 movement steps');
      }
      for (final step in e.executionInstructions) {
        _text(at, 'steps[]', step, 12);
      }
      if (e.commonMistakes.isEmpty) _error(at, 'needs common mistakes');
      for (final m in e.commonMistakes) {
        _text(at, 'mistakes[]', m, 10);
      }
      if (e.cautions.isEmpty) _error(at, 'needs at least one caution');
      if (e.tags.isEmpty) _error(at, 'needs search tags');
      if (e.primaryMuscles.isEmpty) _error(at, 'needs primary muscles');
      if (e.primaryMuscles.toSet().intersection(e.secondaryMuscles.toSet()).isNotEmpty) {
        _warn(at, 'muscle listed as both primary and secondary');
      }
      if (e.equipment.contains(Equipment.mat)) {
        _error(at, 'a mat is never required; use "matRecommended"');
      }
      if (!e.supports(e.executionType)) {
        _error(at, 'missing default value for its execution type');
      }
      final d = e.defaultDurationSeconds;
      if (d != null && (d < 5 || d > 600)) _error(at, 'invalid default duration');
      final r = e.defaultRepetitions;
      if (r != null && (r < 1 || r > 100)) _error(at, 'invalid default reps');
      if (e.secondsPerRep < 1 || e.secondsPerRep > 10) {
        _error(at, 'invalid secondsPerRep');
      }
      final media = e.mediaPath;
      if (media == null) {
        _warn(at, 'no demonstration media');
      } else {
        if (assetExists != null && !assetExists!(media)) {
          _error(at, 'media file not found: $media');
        }
        if (e.attribution == null) _error(at, 'media without attribution');
      }
    }
  }

  void _checkWorkouts() {
    _checkIds('workout', catalog.workouts.map((w) => w.id));
    for (final w in catalog.workouts) {
      final at = 'workout "${w.id}"';
      _text(at, 'title', w.title, 3);
      _text(at, 'description', w.description, 25);
      if (w.tags.isEmpty) _error(at, 'needs search tags');
      if (w.mainSteps.isEmpty) _error(at, 'needs at least one main step');
      _checkStepOrder(at, w.steps);
      _checkSteps(at, w, w.steps);
      if (w.rounds < 1 || w.rounds > 10) _error(at, 'invalid rounds');
      if (w.roundRestSeconds < 0 || w.roundRestSeconds > 300) {
        _error(at, 'invalid round rest');
      }
      final thumb = w.thumbnailPath;
      if (thumb != null && assetExists != null && !assetExists!(thumb)) {
        _error(at, 'thumbnail not found: $thumb');
      }
      final info = catalog.infoFor(w);
      final minutes = info.estimate.seconds / 60;
      if (minutes < 2 || minutes > 90) {
        _error(at, 'unrealistic estimated duration (${minutes.round()} min)');
      }
      final hardest = catalog.difficultyOf(w.steps);
      if (hardest.rank > w.difficulty.rank + 1 ||
          (w.difficulty == Difficulty.beginner && hardest == Difficulty.advanced)) {
        _error(at, 'labelled ${w.difficulty.json} but uses ${hardest.json}');
      }
      final claimsLowImpact = w.tags.any((t) => t.toLowerCase().contains('low impact'));
      if (claimsLowImpact && !info.isLowImpact) {
        _error(at, 'tagged low impact but contains high-impact exercises');
      }
    }
  }

  void _checkStepOrder(String at, List<WorkoutStep> steps) {
    var phase = 0;
    for (final step in steps) {
      final p = switch (step.type) {
        StepType.warmup => 0,
        StepType.main => 1,
        StepType.cooldown => 2,
      };
      if (p < phase) _error(at, 'warm-up, main and cool-down steps out of order');
      if (p > phase) phase = p;
    }
  }

  void _checkSteps(String at, Workout w, List<WorkoutStep> steps) {
    final stepIds = <String>{};
    for (final step in steps) {
      final sat = '$at step "${step.id}"';
      if (!stepIds.add(step.id)) _error(sat, 'duplicate step id');
      final Exercise? exercise = catalog.exercise(step.exerciseId);
      if (exercise == null) {
        _error(sat, 'unknown exercise "${step.exerciseId}"');
        continue;
      }
      if (!exercise.supports(step.execution)) {
        _error(sat, '${exercise.id} cannot be done as ${step.execution.json}');
      }
      if (step.isTimed) {
        final d = step.durationSeconds ?? 0;
        if (d < 5 || d > 600) _error(sat, 'invalid duration $d');
      } else {
        final r = step.repetitions ?? 0;
        if (r < 1 || r > 100) _error(sat, 'invalid repetitions $r');
      }
      if (step.sets < 1 || step.sets > 10) _error(sat, 'invalid sets');
      if (step.restSeconds < 0 || step.restSeconds > 300) {
        _error(sat, 'invalid rest');
      }
      if (step.perSide && !exercise.isPerSide) {
        _error(sat, 'per-side step for a two-sided exercise');
      }
      if (!step.perSide && exercise.isPerSide) {
        _error(sat, 'one-sided exercise must be done per side');
      }
    }
  }

  void _checkPlans() {
    _checkIds('plan', catalog.plans.map((p) => p.id));
    for (final plan in catalog.plans) {
      final at = 'plan "${plan.id}"';
      _text(at, 'title', plan.title, 3);
      _text(at, 'summary', plan.summary, 20);
      _text(at, 'description', plan.description, 40);
      _text(at, 'weeklySchedule', plan.weeklySchedule, 15);
      _text(at, 'progression', plan.progressionNotes, 40);
      _text(at, 'recovery', plan.recoveryGuidance, 40);
      if (plan.days.length != TrainingPlan.lengthInDays) {
        _error(at, 'must define all ${TrainingPlan.lengthInDays} days');
      }
      for (var i = 0; i < plan.days.length; i++) {
        if (plan.days[i].dayNumber != i + 1) {
          _error(at, 'day ${i + 1} is missing or out of order');
          break;
        }
      }
      for (var week = 1; week <= 4; week++) {
        if (plan.focusOfWeek(week).trim().length < 10) {
          _error(at, 'week $week needs a focus description');
        }
        final days = plan.daysOfWeek(week).toList();
        if (!days.any((d) => d.type == PlanDayType.rest)) {
          _error(at, 'week $week has no rest day');
        }
      }
      for (final day in plan.days) {
        final dat = '$at day ${day.dayNumber}';
        if (day.type == PlanDayType.rest) {
          if (day.workoutId != null) _error(dat, 'rest day with a workout');
          continue;
        }
        final workout = day.workoutId == null ? null : catalog.workout(day.workoutId!);
        if (workout == null) {
          _error(dat, 'unknown workout "${day.workoutId}"');
          continue;
        }
        if (workout.difficulty.rank > plan.difficulty.rank + 1) {
          _error(dat, 'workout is too hard for a ${plan.difficulty.json} plan');
        }
      }
    }
  }

  void _checkArticles() {
    _checkIds('article', catalog.articles.map((a) => a.id));
    for (final a in catalog.articles) {
      final at = 'article "${a.id}"';
      _text(at, 'title', a.title, 5);
      _text(at, 'summary', a.summary, 40);
      if (a.sections.length < 3) _error(at, 'needs at least 3 sections');
      for (final s in a.sections) {
        if (s.heading.trim().isEmpty) _error(at, 'section without heading');
        if (s.paragraphs.isEmpty && s.bullets.isEmpty) {
          _error(at, 'empty section "${s.heading}"');
        }
      }
      if (a.wordCount < 250) _error(at, 'too short (${a.wordCount} words)');
      if (a.tags.isEmpty) _error(at, 'needs search tags');
      for (final id in a.relatedArticleIds) {
        if (id == a.id) _error(at, 'relates to itself');
        if (catalog.article(id) == null) _error(at, 'unknown related article "$id"');
      }
      for (final id in a.relatedExerciseIds) {
        if (catalog.exercise(id) == null) {
          _error(at, 'unknown related exercise "$id"');
        }
      }
      for (final id in a.relatedWorkoutIds) {
        if (catalog.workout(id) == null) {
          _error(at, 'unknown related workout "$id"');
        }
      }
      for (final ref in a.references) {
        final url = ref.url;
        if (url != null && !url.startsWith('https://')) {
          _error(at, 'reference URL must use https: $url');
        }
      }
    }
  }

  void _checkTips() {
    _checkIds('tip', catalog.tips.map((t) => t.id));
    if (catalog.tips.length < 10) _error('tips', 'needs at least 10 tips');
    for (final tip in catalog.tips) {
      _text('tip "${tip.id}"', 'text', tip.text, 20);
      final articleId = tip.articleId;
      if (articleId != null && catalog.article(articleId) == null) {
        _error('tip "${tip.id}"', 'unknown article "$articleId"');
      }
    }
  }
}
