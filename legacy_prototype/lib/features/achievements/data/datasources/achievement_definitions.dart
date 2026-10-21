import '../models/achievement_model.dart';

/// Default achievement definitions.
abstract final class AchievementDefinitions {
  static List<AchievementModel> defaults() => [
        AchievementModel(
          id: 'first_workout',
          title: 'First Workout',
          description: 'Complete your first workout',
          iconName: 'emoji_events',
        ),
        AchievementModel(
          id: 'streak_3',
          title: '3 Day Streak',
          description: 'Work out 3 days in a row',
          iconName: 'local_fire_department',
        ),
        AchievementModel(
          id: 'streak_7',
          title: '7 Day Streak',
          description: 'Work out 7 days in a row',
          iconName: 'whatshot',
        ),
        AchievementModel(
          id: 'streak_30',
          title: '30 Day Streak',
          description: 'Work out 30 days in a row',
          iconName: 'military_tech',
        ),
        AchievementModel(
          id: 'calories_1000',
          title: 'Burn 1000 Calories',
          description: 'Burn a total of 1000 calories',
          iconName: 'local_fire_department',
        ),
        AchievementModel(
          id: 'workouts_50',
          title: 'Complete 50 Workouts',
          description: 'Complete 50 total workouts',
          iconName: 'stars',
        ),
      ];
}
