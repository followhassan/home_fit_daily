import '../../core/utils/json_utils.dart';

enum Difficulty implements JsonEnum {
  beginner('beginner', 'Beginner'),
  intermediate('intermediate', 'Intermediate'),
  advanced('advanced', 'Advanced');

  const Difficulty(this.json, this.label);

  @override
  final String json;
  @override
  final String label;

  int get rank => index;
}

enum FitnessGoal implements JsonEnum {
  consistency('consistency', 'Build consistency'),
  strength('strength', 'Improve strength'),
  endurance('endurance', 'Improve endurance'),
  mobility('mobility', 'Improve mobility');

  const FitnessGoal(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

/// Optional equipment. "No equipment" is represented by an empty set.
enum Equipment implements JsonEnum {
  mat('mat', 'Exercise mat'),
  chair('chair', 'Stable chair'),
  resistanceBand('resistance_band', 'Resistance band'),
  dumbbells('dumbbells', 'Dumbbells');

  const Equipment(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum ExerciseCategory implements JsonEnum {
  warmUp('warm_up', 'Warm-up'),
  fullBody('full_body', 'Full body'),
  upperBody('upper_body', 'Upper body'),
  lowerBody('lower_body', 'Lower body'),
  core('core', 'Core'),
  cardio('cardio', 'Cardio'),
  mobility('mobility', 'Mobility'),
  stretching('stretching', 'Stretching & cool-down');

  const ExerciseCategory(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum MuscleGroup implements JsonEnum {
  quadriceps('quadriceps', 'Quadriceps'),
  hamstrings('hamstrings', 'Hamstrings'),
  glutes('glutes', 'Glutes'),
  calves('calves', 'Calves'),
  hipFlexors('hip_flexors', 'Hip flexors'),
  adductors('adductors', 'Inner thighs'),
  abductors('abductors', 'Outer hips'),
  chest('chest', 'Chest'),
  shoulders('shoulders', 'Shoulders'),
  triceps('triceps', 'Triceps'),
  biceps('biceps', 'Biceps'),
  forearms('forearms', 'Forearms'),
  upperBack('upper_back', 'Upper back'),
  lats('lats', 'Lats'),
  lowerBack('lower_back', 'Lower back'),
  abs('abs', 'Abdominals'),
  obliques('obliques', 'Obliques');

  const MuscleGroup(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum ExecutionType implements JsonEnum {
  timed('timed', 'Timed'),
  reps('reps', 'Repetitions');

  const ExecutionType(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum StepType implements JsonEnum {
  warmup('warmup', 'Warm-up'),
  main('main', 'Main'),
  cooldown('cooldown', 'Cool-down');

  const StepType(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum WorkoutCategory implements JsonEnum {
  fullBody('full_body', 'Full body'),
  strength('strength', 'Strength'),
  upperBody('upper_body', 'Upper body'),
  lowerBody('lower_body', 'Lower body'),
  core('core', 'Core'),
  cardio('cardio', 'Cardio'),
  quickBreak('quick_break', 'Movement break'),
  mobility('mobility', 'Mobility'),
  stretching('stretching', 'Stretching'),
  custom('custom', 'Custom');

  const WorkoutCategory(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum WorkoutSource implements JsonEnum {
  catalog('catalog', 'Ready-made'),
  custom('custom', 'My workout');

  const WorkoutSource(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum PlanDayType implements JsonEnum {
  workout('workout', 'Workout'),
  recovery('recovery', 'Recovery'),
  rest('rest', 'Rest day');

  const PlanDayType(this.json, this.label);

  @override
  final String json;
  @override
  final String label;

  bool get isTraining => this != PlanDayType.rest;
}

enum SessionStatus implements JsonEnum {
  completed('completed', 'Completed'),
  partial('partial', 'Partially completed'),
  abandoned('abandoned', 'Abandoned');

  const SessionStatus(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum StepOutcome implements JsonEnum {
  completed('completed', 'Completed'),
  skipped('skipped', 'Skipped'),
  stopped('stopped', 'Stopped early'),
  notReached('not_reached', 'Not reached');

  const StepOutcome(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum EffortRating implements JsonEnum {
  easy('easy', 'Easy'),
  moderate('moderate', 'Moderate'),
  hard('hard', 'Hard');

  const EffortRating(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum MeasurementType implements JsonEnum {
  weight('weight', 'Body weight'),
  waist('waist', 'Waist'),
  hips('hips', 'Hips'),
  chest('chest', 'Chest'),
  upperArm('upper_arm', 'Upper arm'),
  thigh('thigh', 'Thigh');

  const MeasurementType(this.json, this.label);

  @override
  final String json;
  @override
  final String label;

  bool get isWeight => this == MeasurementType.weight;

  /// Accepted canonical range (kg for weight, cm for lengths).
  (double, double) get canonicalRange => isWeight ? (20.0, 400.0) : (10.0, 300.0);
}

enum ArticleCategory implements JsonEnum {
  gettingStarted('getting_started', 'Getting started'),
  technique('technique', 'Technique'),
  training('training', 'Training'),
  recovery('recovery', 'Recovery'),
  nutrition('nutrition', 'Nutrition & hydration'),
  mindset('mindset', 'Habits & mindset'),
  safety('safety', 'Safety');

  const ArticleCategory(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum ReviewStatus implements JsonEnum {
  unreviewed('unreviewed', 'Not professionally reviewed'),
  editorialReview('editorial_review', 'Editorially reviewed'),
  expertReviewed('expert_reviewed', 'Reviewed by a qualified professional');

  const ReviewStatus(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum ThemePreference implements JsonEnum {
  system('system', 'Match device'),
  light('light', 'Light'),
  dark('dark', 'Dark');

  const ThemePreference(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

enum EnrollmentStatus implements JsonEnum {
  active('active', 'Active'),
  paused('paused', 'Paused'),
  completed('completed', 'Finished'),
  left('left', 'Left');

  const EnrollmentStatus(this.json, this.label);

  @override
  final String json;
  @override
  final String label;

  bool get isCurrent => this == EnrollmentStatus.active || this == EnrollmentStatus.paused;
}

/// States of the guided workout player.
enum PlayerState implements JsonEnum {
  ready('ready', 'Ready'),
  preparation('preparation', 'Get ready'),
  exercise('exercise', 'Exercise'),
  rest('rest', 'Rest'),
  paused('paused', 'Paused'),
  interrupted('interrupted', 'Paused'),
  completed('completed', 'Finished'),
  abandoned('abandoned', 'Quit');

  const PlayerState(this.json, this.label);

  @override
  final String json;
  @override
  final String label;

  /// States in which the clock is running.
  bool get isRunning =>
      this == PlayerState.preparation || this == PlayerState.exercise || this == PlayerState.rest;

  bool get isFinal => this == PlayerState.completed || this == PlayerState.abandoned;
}

/// Which side of the body a unilateral exercise segment works.
enum Side implements JsonEnum {
  none('none', ''),
  left('left', 'Left side'),
  right('right', 'Right side');

  const Side(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}
