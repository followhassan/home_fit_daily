import '../data/catalog/catalog.dart';
import '../data/models/enums.dart';
import '../data/models/exercise.dart';
import '../data/models/workout.dart';

/// Equipment filter options. [none] matches bodyweight-only items.
enum EquipmentChoice {
  none('No equipment', null),
  chair('Chair', Equipment.chair),
  resistanceBand('Band', Equipment.resistanceBand),
  dumbbells('Dumbbells', Equipment.dumbbells);

  const EquipmentChoice(this.label, this.equipment);
  final String label;
  final Equipment? equipment;

  /// Matches items that need nothing, or that use the chosen equipment.
  static bool matches(Set<EquipmentChoice> choices, Set<Equipment> required) {
    if (choices.isEmpty) return true;
    for (final choice in choices) {
      if (choice == EquipmentChoice.none && required.isEmpty) return true;
      if (choice.equipment != null && required.contains(choice.equipment)) {
        return true;
      }
    }
    return false;
  }
}

bool _matchesQuery(String haystack, String query) {
  final terms = query.toLowerCase().split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
  return terms.every(haystack.contains);
}

class ExerciseFilter {
  const ExerciseFilter({
    this.query = '',
    this.categories = const {},
    this.difficulties = const {},
    this.equipment = const {},
    this.muscles = const {},
    this.lowImpactOnly = false,
  });

  final String query;
  final Set<ExerciseCategory> categories;
  final Set<Difficulty> difficulties;
  final Set<EquipmentChoice> equipment;
  final Set<MuscleGroup> muscles;
  final bool lowImpactOnly;

  /// Number of active filter groups, excluding the search text.
  int get activeCount =>
      (categories.isNotEmpty ? 1 : 0) +
      (difficulties.isNotEmpty ? 1 : 0) +
      (equipment.isNotEmpty ? 1 : 0) +
      (muscles.isNotEmpty ? 1 : 0) +
      (lowImpactOnly ? 1 : 0);

  bool get isEmpty => query.trim().isEmpty && activeCount == 0;

  bool matches(Exercise e) {
    if (categories.isNotEmpty && !categories.contains(e.category)) return false;
    if (difficulties.isNotEmpty && !difficulties.contains(e.difficulty)) {
      return false;
    }
    if (!EquipmentChoice.matches(equipment, e.equipment)) return false;
    if (muscles.isNotEmpty && !e.allMuscles.any(muscles.contains)) return false;
    if (lowImpactOnly && !e.isLowImpact) return false;
    if (query.trim().isNotEmpty && !_matchesQuery(e.searchText, query)) {
      return false;
    }
    return true;
  }

  ExerciseFilter copyWith({
    String? query,
    Set<ExerciseCategory>? categories,
    Set<Difficulty>? difficulties,
    Set<EquipmentChoice>? equipment,
    Set<MuscleGroup>? muscles,
    bool? lowImpactOnly,
  }) => ExerciseFilter(
    query: query ?? this.query,
    categories: categories ?? this.categories,
    difficulties: difficulties ?? this.difficulties,
    equipment: equipment ?? this.equipment,
    muscles: muscles ?? this.muscles,
    lowImpactOnly: lowImpactOnly ?? this.lowImpactOnly,
  );

  /// Clears filters but keeps the search text.
  ExerciseFilter clearFilters() => ExerciseFilter(query: query);
}

enum DurationBucket {
  short('Up to 10 min', 0, 10),
  medium('11–20 min', 11, 20),
  long('Over 20 min', 21, 1000);

  const DurationBucket(this.label, this.min, this.max);
  final String label;
  final int min;
  final int max;

  bool contains(int minutes) => minutes >= min && minutes <= max;
}

enum WorkoutSort {
  recommended('Suggested order'),
  shortest('Shortest first'),
  longest('Longest first'),
  easiest('Easiest first'),
  title('Title A–Z');

  const WorkoutSort(this.label);
  final String label;
}

class WorkoutFilter {
  const WorkoutFilter({
    this.query = '',
    this.categories = const {},
    this.difficulties = const {},
    this.durations = const {},
    this.equipment = const {},
    this.favoritesOnly = false,
    this.lowImpactOnly = false,
    this.sort = WorkoutSort.recommended,
  });

  final String query;
  final Set<WorkoutCategory> categories;
  final Set<Difficulty> difficulties;
  final Set<DurationBucket> durations;
  final Set<EquipmentChoice> equipment;
  final bool favoritesOnly;
  final bool lowImpactOnly;
  final WorkoutSort sort;

  int get activeCount =>
      (categories.isNotEmpty ? 1 : 0) +
      (difficulties.isNotEmpty ? 1 : 0) +
      (durations.isNotEmpty ? 1 : 0) +
      (equipment.isNotEmpty ? 1 : 0) +
      (favoritesOnly ? 1 : 0) +
      (lowImpactOnly ? 1 : 0);

  bool get isEmpty => query.trim().isEmpty && activeCount == 0;

  bool matches(
    Workout w,
    WorkoutInfo info, {
    required bool isFavorite,
    required String searchText,
  }) {
    if (categories.isNotEmpty && !categories.contains(w.category)) return false;
    if (difficulties.isNotEmpty && !difficulties.contains(w.difficulty)) {
      return false;
    }
    if (durations.isNotEmpty && !durations.any((d) => d.contains(info.estimate.minutes))) {
      return false;
    }
    if (!EquipmentChoice.matches(equipment, info.equipment)) return false;
    if (favoritesOnly && !isFavorite) return false;
    if (lowImpactOnly && !info.isLowImpact) return false;
    if (query.trim().isNotEmpty && !_matchesQuery(searchText, query)) {
      return false;
    }
    return true;
  }

  List<Workout> apply(
    Catalog catalog,
    List<Workout> workouts, {
    required bool Function(String id) isFavorite,
  }) {
    final result = workouts.where((w) {
      final info = catalog.infoFor(w);
      return matches(
        w,
        info,
        isFavorite: isFavorite(w.id),
        searchText: workoutSearchText(w, catalog),
      );
    }).toList();
    int minutes(Workout w) => catalog.infoFor(w).estimate.seconds;
    switch (sort) {
      case WorkoutSort.recommended:
        break;
      case WorkoutSort.shortest:
        result.sort((a, b) => minutes(a).compareTo(minutes(b)));
      case WorkoutSort.longest:
        result.sort((a, b) => minutes(b).compareTo(minutes(a)));
      case WorkoutSort.easiest:
        result.sort((a, b) {
          final byLevel = a.difficulty.rank.compareTo(b.difficulty.rank);
          return byLevel != 0 ? byLevel : minutes(a).compareTo(minutes(b));
        });
      case WorkoutSort.title:
        result.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
    }
    return result;
  }

  WorkoutFilter copyWith({
    String? query,
    Set<WorkoutCategory>? categories,
    Set<Difficulty>? difficulties,
    Set<DurationBucket>? durations,
    Set<EquipmentChoice>? equipment,
    bool? favoritesOnly,
    bool? lowImpactOnly,
    WorkoutSort? sort,
  }) => WorkoutFilter(
    query: query ?? this.query,
    categories: categories ?? this.categories,
    difficulties: difficulties ?? this.difficulties,
    durations: durations ?? this.durations,
    equipment: equipment ?? this.equipment,
    favoritesOnly: favoritesOnly ?? this.favoritesOnly,
    lowImpactOnly: lowImpactOnly ?? this.lowImpactOnly,
    sort: sort ?? this.sort,
  );

  WorkoutFilter clearFilters() => WorkoutFilter(query: query, sort: sort);
}

final Expando<String> _workoutSearchCache = Expando();

/// Title, description, tags, category and exercise names, lower-cased.
String workoutSearchText(Workout w, Catalog catalog) => _workoutSearchCache[w] ??= [
  w.title,
  w.description,
  w.category.label,
  w.difficulty.label,
  ...w.tags,
  for (final step in w.steps) catalog.exercise(step.exerciseId)?.name ?? '',
].join(' ').toLowerCase();
