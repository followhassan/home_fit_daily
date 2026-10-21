import 'package:uuid/uuid.dart';

import '../../../../core/services/hive_service.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';
import '../datasources/workout_data_source.dart';
import '../models/workout_history_model.dart';

class WorkoutRepository {
  final _uuid = const Uuid();

  List<WorkoutPlanEntity> getPlans() => WorkoutDataSource.plans;

  WorkoutPlanEntity? getPlanById(String id) => WorkoutDataSource.getPlanById(id);

  List<ExerciseEntity> getAllExercises() => WorkoutDataSource.exercises;

  ExerciseEntity? getExerciseById(String id) =>
      WorkoutDataSource.getExerciseById(id);

  List<ExerciseEntity> searchExercises(String query) =>
      WorkoutDataSource.searchExercises(query);

  List<ExerciseEntity> filterByCategory(String category) =>
      WorkoutDataSource.filterByCategory(category);

  List<String> getCategories() => ['All', ...WorkoutDataSource.categories];

  Future<List<WorkoutHistoryModel>> getHistory() async {
    final box = HiveService.instance.historyBox;
    return box.values.toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  Future<void> saveWorkoutHistory({
    required String planId,
    required String planName,
    required int durationSeconds,
    required int caloriesBurned,
    required int exerciseCount,
    String difficulty = '',
  }) async {
    final history = WorkoutHistoryModel(
      id: _uuid.v4(),
      planId: planId,
      planName: planName,
      completedAt: DateTime.now(),
      durationSeconds: durationSeconds,
      caloriesBurned: caloriesBurned,
      exerciseCount: exerciseCount,
      difficulty: difficulty,
    );
    await HiveService.instance.historyBox.put(history.id, history);
  }

  Future<List<String>> getFavorites() async {
    return HiveService.instance.favoritesBox.values.toList();
  }

  Future<bool> isFavorite(String exerciseId) async {
    return HiveService.instance.favoritesBox.containsKey(exerciseId);
  }

  Future<void> toggleFavorite(String exerciseId) async {
    final box = HiveService.instance.favoritesBox;
    if (box.containsKey(exerciseId)) {
      await box.delete(exerciseId);
    } else {
      await box.put(exerciseId, exerciseId);
    }
  }

  int getTodayCalories(List<WorkoutHistoryModel> history) {
    final today = DateTime.now();
    return history
        .where((h) =>
            h.completedAt.year == today.year &&
            h.completedAt.month == today.month &&
            h.completedAt.day == today.day)
        .fold(0, (sum, h) => sum + h.caloriesBurned);
  }

  int getTodayWorkouts(List<WorkoutHistoryModel> history) {
    final today = DateTime.now();
    return history
        .where((h) =>
            h.completedAt.year == today.year &&
            h.completedAt.month == today.month &&
            h.completedAt.day == today.day)
        .length;
  }
}
