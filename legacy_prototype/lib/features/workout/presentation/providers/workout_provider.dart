import 'package:flutter/foundation.dart';

import '../../data/models/workout_history_model.dart';
import '../../data/repositories/workout_repository.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';

class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider(this._repository);

  final WorkoutRepository _repository;

  List<WorkoutPlanEntity> _plans = [];
  List<WorkoutHistoryModel> _history = [];
  List<String> _favorites = [];
  List<ExerciseEntity> _filteredExercises = [];
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _loading = true;

  List<WorkoutPlanEntity> get plans => _plans;
  List<WorkoutHistoryModel> get history => _history;
  List<String> get favorites => _favorites;
  List<ExerciseEntity> get filteredExercises => _filteredExercises;
  String get searchQuery => _searchQuery;
  String get selectedCategory => _selectedCategory;
  bool get isLoading => _loading;
  List<String> get categories => _repository.getCategories();

  int get todayCalories => _repository.getTodayCalories(_history);
  int get todayWorkouts => _repository.getTodayWorkouts(_history);

  Future<void> loadData() async {
    _loading = true;

    _plans = _repository.getPlans();
    _history = await _repository.getHistory();
    _favorites = await _repository.getFavorites();
    _applyFilters();

    _loading = false;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  void setCategory(String category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var exercises = _repository.getAllExercises();
    if (_selectedCategory != 'All') {
      exercises = _repository.filterByCategory(_selectedCategory);
    }
    if (_searchQuery.isNotEmpty) {
      exercises = exercises
          .where(
            (e) =>
                e.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                e.category.toLowerCase().contains(_searchQuery.toLowerCase()),
          )
          .toList();
    }
    _filteredExercises = exercises;
  }

  WorkoutPlanEntity? getPlanById(String id) => _repository.getPlanById(id);

  ExerciseEntity? getExerciseById(String id) => _repository.getExerciseById(id);

  bool isFavorite(String id) => _favorites.contains(id);

  Future<void> toggleFavorite(String id) async {
    await _repository.toggleFavorite(id);
    _favorites = await _repository.getFavorites();
    notifyListeners();
  }

  Future<void> completeWorkout({
    required String planId,
    required String planName,
    required int durationSeconds,
    required int caloriesBurned,
    required int exerciseCount,
    String difficulty = '',
  }) async {
    await _repository.saveWorkoutHistory(
      planId: planId,
      planName: planName,
      durationSeconds: durationSeconds,
      caloriesBurned: caloriesBurned,
      exerciseCount: exerciseCount,
      difficulty: difficulty,
    );
    await loadData();
  }

  List<WorkoutHistoryModel> getRecentActivity({int limit = 5}) {
    return _history.take(limit).toList();
  }

  Map<DateTime, int> getWeeklyWorkoutCounts() {
    final days = List.generate(7, (i) {
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i));
    });

    return {
      for (final day in days)
        day: _history
            .where(
              (h) =>
                  h.completedAt.year == day.year &&
                  h.completedAt.month == day.month &&
                  h.completedAt.day == day.day,
            )
            .length,
    };
  }

  Map<DateTime, int> getWeeklyCalorieCounts() {
    final days = List.generate(7, (i) {
      final today = DateTime.now();
      return DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: 6 - i));
    });

    return {
      for (final day in days)
        day: _history
            .where(
              (h) =>
                  h.completedAt.year == day.year &&
                  h.completedAt.month == day.month &&
                  h.completedAt.day == day.day,
            )
            .fold(0, (sum, h) => sum + h.caloriesBurned),
    };
  }

  int getWeeklyWorkoutTotal() {
    final weekStart = DateTime.now().subtract(const Duration(days: 7));
    return _history
        .where((h) => h.completedAt.isAfter(weekStart))
        .length;
  }
}
