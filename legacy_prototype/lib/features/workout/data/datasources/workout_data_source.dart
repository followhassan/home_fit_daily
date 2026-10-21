import '../../domain/entities/exercise_entity.dart';
import '../../domain/entities/workout_plan_entity.dart';

/// Static offline exercise and workout plan data.
abstract final class WorkoutDataSource {
  static const List<String> categories = [
    'Full Body',
    'Chest',
    'Arms',
    'Core',
    'Legs',
    'Cardio',
  ];

  static final List<ExerciseEntity> exercises = [
    const ExerciseEntity(
      id: 'jumping_jacks',
      name: 'Jumping Jacks',
      description: 'A full-body cardio exercise that warms up your muscles.',
      instructions: [
        'Stand upright with legs together and arms at sides.',
        'Jump while spreading legs shoulder-width apart.',
        'Raise arms overhead simultaneously.',
        'Jump back to starting position and repeat.',
      ],
      caloriesPerMinute: 8,
      durationSeconds: 45,
      category: 'Cardio',
      bodyPart: 'Full Body',
      iconName: 'fitness_center',
    ),
    const ExerciseEntity(
      id: 'high_knees',
      name: 'High Knees',
      description: 'Elevate your heart rate with rapid knee drives.',
      instructions: [
        'Stand tall with feet hip-width apart.',
        'Drive one knee up toward your chest.',
        'Quickly switch legs in a running motion.',
        'Pump your arms for momentum.',
      ],
      caloriesPerMinute: 9,
      durationSeconds: 45,
      category: 'Cardio',
      bodyPart: 'Legs',
      iconName: 'directions_run',
    ),
    const ExerciseEntity(
      id: 'arm_circles',
      name: 'Arm Circles',
      description: 'Warm up shoulders and improve mobility.',
      instructions: [
        'Extend arms out to the sides at shoulder height.',
        'Make small circles forward for 20 seconds.',
        'Reverse direction for another 20 seconds.',
        'Gradually increase circle size.',
      ],
      caloriesPerMinute: 4,
      durationSeconds: 40,
      category: 'Arms',
      bodyPart: 'Arms',
      iconName: 'accessibility_new',
    ),
    const ExerciseEntity(
      id: 'squats',
      name: 'Squats',
      description: 'Build lower body strength with bodyweight squats.',
      instructions: [
        'Stand with feet shoulder-width apart.',
        'Lower hips back and down as if sitting in a chair.',
        'Keep chest up and knees behind toes.',
        'Push through heels to return to standing.',
      ],
      caloriesPerMinute: 6,
      durationSeconds: 50,
      category: 'Legs',
      bodyPart: 'Legs',
      iconName: 'sports_gymnastics',
    ),
    const ExerciseEntity(
      id: 'standing_crunches',
      name: 'Standing Crunches',
      description: 'Engage your core without lying on the floor.',
      instructions: [
        'Stand with hands behind your head.',
        'Lift right knee while bringing left elbow down.',
        'Return and alternate sides.',
        'Keep core tight throughout.',
      ],
      caloriesPerMinute: 5,
      durationSeconds: 45,
      category: 'Core',
      bodyPart: 'Core',
      iconName: 'self_improvement',
    ),
    const ExerciseEntity(
      id: 'push_ups',
      name: 'Push Ups',
      description: 'Classic upper body exercise for chest and arms.',
      instructions: [
        'Start in a plank position, hands shoulder-width apart.',
        'Lower chest toward the floor.',
        'Keep body in a straight line.',
        'Push back up to starting position.',
      ],
      caloriesPerMinute: 7,
      durationSeconds: 45,
      category: 'Chest',
      bodyPart: 'Chest',
      iconName: 'sports_martial_arts',
    ),
    const ExerciseEntity(
      id: 'lunges',
      name: 'Lunges',
      description: 'Strengthen legs and improve balance.',
      instructions: [
        'Step forward with one leg.',
        'Lower hips until both knees are at 90 degrees.',
        'Push back to starting position.',
        'Alternate legs each rep.',
      ],
      caloriesPerMinute: 6,
      durationSeconds: 50,
      category: 'Legs',
      bodyPart: 'Legs',
      iconName: 'hiking',
    ),
    const ExerciseEntity(
      id: 'mountain_climbers',
      name: 'Mountain Climbers',
      description: 'High-intensity core and cardio movement.',
      instructions: [
        'Start in a plank position.',
        'Drive one knee toward your chest.',
        'Quickly switch legs in a running motion.',
        'Keep hips level and core engaged.',
      ],
      caloriesPerMinute: 10,
      durationSeconds: 40,
      category: 'Core',
      bodyPart: 'Full Body',
      iconName: 'landscape',
    ),
    const ExerciseEntity(
      id: 'plank',
      name: 'Plank',
      description: 'Isometric core exercise for stability.',
      instructions: [
        'Forearms on floor, elbows under shoulders.',
        'Extend legs behind you, body in straight line.',
        'Engage core and glutes.',
        'Hold position without sagging hips.',
      ],
      caloriesPerMinute: 4,
      durationSeconds: 45,
      category: 'Core',
      bodyPart: 'Core',
      iconName: 'horizontal_rule',
    ),
    const ExerciseEntity(
      id: 'burpees',
      name: 'Burpees',
      description: 'Full-body explosive exercise for maximum burn.',
      instructions: [
        'Start standing, drop into a squat.',
        'Kick feet back into plank position.',
        'Perform a push-up (optional).',
        'Jump feet forward and explode upward.',
      ],
      caloriesPerMinute: 12,
      durationSeconds: 40,
      category: 'Full Body',
      bodyPart: 'Full Body',
      iconName: 'bolt',
    ),
    const ExerciseEntity(
      id: 'jump_squats',
      name: 'Jump Squats',
      description: 'Explosive squat variation for power and cardio.',
      instructions: [
        'Perform a standard squat.',
        'Explode upward into a jump.',
        'Land softly with bent knees.',
        'Immediately go into the next squat.',
      ],
      caloriesPerMinute: 10,
      durationSeconds: 40,
      category: 'Legs',
      bodyPart: 'Legs',
      iconName: 'rocket_launch',
    ),
    const ExerciseEntity(
      id: 'plank_up_down',
      name: 'Plank Up Down',
      description: 'Dynamic plank variation for core and arms.',
      instructions: [
        'Start in forearm plank position.',
        'Push up to high plank one arm at a time.',
        'Lower back to forearm plank.',
        'Alternate leading arm each rep.',
      ],
      caloriesPerMinute: 8,
      durationSeconds: 45,
      category: 'Core',
      bodyPart: 'Arms',
      iconName: 'swap_vert',
    ),
  ];

  static ExerciseEntity? getExerciseById(String id) {
    try {
      return exercises.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }

  static List<ExerciseEntity> searchExercises(String query) {
    if (query.isEmpty) return exercises;
    final q = query.toLowerCase();
    return exercises
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.category.toLowerCase().contains(q) ||
              e.bodyPart.toLowerCase().contains(q),
        )
        .toList();
  }

  static List<ExerciseEntity> filterByCategory(String category) {
    if (category == 'All') return exercises;
    return exercises
        .where(
          (e) =>
              e.category == category ||
              e.bodyPart == category,
        )
        .toList();
  }

  static final List<WorkoutPlanEntity> plans = [
    WorkoutPlanEntity(
      id: 'beginner',
      name: 'Beginner Plan',
      difficulty: Difficulty.beginner,
      durationMinutes: 15,
      estimatedCalories: 80,
      description:
          'Perfect for those starting their fitness journey. Low impact, easy to follow exercises.',
      gradientStart: 0xFFFF4FA3,
      gradientEnd: 0xFF1A1A1A,
      exercises: [
        exercises[0], // Jumping Jacks
        exercises[1], // High Knees
        exercises[2], // Arm Circles
        exercises[3], // Squats
        exercises[4], // Standing Crunches
      ],
    ),
    WorkoutPlanEntity(
      id: 'intermediate',
      name: 'Intermediate Plan',
      difficulty: Difficulty.intermediate,
      durationMinutes: 20,
      estimatedCalories: 150,
      description:
          'Step up your game with moderate intensity exercises for better results.',
      gradientStart: 0xFFFF1F8F,
      gradientEnd: 0xFF0D0D0D,
      exercises: [
        exercises[5], // Push Ups
        exercises[6], // Lunges
        exercises[7], // Mountain Climbers
        exercises[8], // Plank
        exercises[9], // Burpees
      ],
    ),
    WorkoutPlanEntity(
      id: 'advanced',
      name: 'Advanced Plan',
      difficulty: Difficulty.advanced,
      durationMinutes: 25,
      estimatedCalories: 220,
      description:
          'High-intensity workout for experienced athletes seeking maximum burn.',
      gradientStart: 0xFFFF4FA3,
      gradientEnd: 0xFF000000,
      exercises: [
        exercises[9],  // Burpees
        exercises[10], // Jump Squats
        exercises[11], // Plank Up Down
        exercises[5],  // Push Ups
        exercises[1],  // High Knees
      ],
    ),
  ];

  static WorkoutPlanEntity? getPlanById(String id) {
    try {
      return plans.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
