import '../../../../core/services/hive_service.dart';
import '../../../../core/utils/date_helper.dart';
import '../models/challenge_model.dart';

class ChallengeRepository {
  Future<List<ChallengeModel>> getChallenges() async {
    final box = HiveService.instance.challengesBox;
    final today = DateHelper.startOfDay(DateTime.now());

    if (box.isEmpty) {
      return _createDefaultChallenges(today);
    }

    // Reset daily challenges if period has changed
    final challenges = box.values.toList();
    bool needsReset = false;
    for (final c in challenges) {
      if (c.type == 'daily' &&
          (c.periodStart == null || !DateHelper.isSameDay(c.periodStart!, today))) {
        needsReset = true;
        break;
      }
    }

    if (needsReset) {
      await box.clear();
      return _createDefaultChallenges(today);
    }

    return challenges;
  }

  Future<List<ChallengeModel>> _createDefaultChallenges(DateTime today) async {
    final weekStart = DateHelper.startOfWeek(today);
    final challenges = [
      ChallengeModel(
        id: 'daily_workout',
        title: 'Complete 1 Workout',
        description: 'Finish at least one workout today',
        targetValue: 1,
        currentValue: 0,
        unit: 'workout',
        type: 'daily',
        periodStart: today,
      ),
      ChallengeModel(
        id: 'daily_minutes',
        title: 'Workout 15 Minutes',
        description: 'Exercise for at least 15 minutes today',
        targetValue: 15,
        currentValue: 0,
        unit: 'min',
        type: 'daily',
        periodStart: today,
      ),
      ChallengeModel(
        id: 'daily_calories',
        title: 'Burn 100 Calories',
        description: 'Burn at least 100 calories today',
        targetValue: 100,
        currentValue: 0,
        unit: 'kcal',
        type: 'daily',
        periodStart: today,
      ),
      ChallengeModel(
        id: 'weekly_workouts',
        title: 'Complete 3 Workouts This Week',
        description: 'Stay consistent with 3 workouts this week',
        targetValue: 3,
        currentValue: 0,
        unit: 'workouts',
        type: 'weekly',
        periodStart: weekStart,
      ),
    ];

    final box = HiveService.instance.challengesBox;
    for (final c in challenges) {
      await box.put(c.id, c);
    }
    return challenges;
  }

  Future<void> updateChallengeProgress({
    required int workouts,
    required int minutes,
    required int calories,
    required int weeklyWorkouts,
  }) async {
    final box = HiveService.instance.challengesBox;
    final challenges = box.values.toList();

    for (final c in challenges) {
      switch (c.id) {
        case 'daily_workout':
          c.currentValue = workouts;
        case 'daily_minutes':
          c.currentValue = minutes;
        case 'daily_calories':
          c.currentValue = calories;
        case 'weekly_workouts':
          c.currentValue = weeklyWorkouts;
      }

      if (!c.isCompleted && c.currentValue >= c.targetValue) {
        c.isCompleted = true;
        c.completedAt = DateTime.now();
      }
      await c.save();
    }
  }

  Future<void> resetChallenges() async {
    await HiveService.instance.challengesBox.clear();
    await getChallenges();
  }
}
