import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// One exercise entry inside a workout.
///
/// A step is either timed ([durationSeconds]) or repetition-based
/// ([repetitions]) – never both. Values are per set and, for [perSide]
/// steps, per side.
class WorkoutStep {
  const WorkoutStep({
    required this.id,
    required this.exerciseId,
    required this.type,
    required this.execution,
    this.durationSeconds,
    this.repetitions,
    this.sets = 1,
    this.restSeconds = 0,
    this.perSide = false,
    this.instructionOverride,
  });

  factory WorkoutStep.fromJson(JsonMap json) {
    final duration = readOptionalInt(json, 'durationSeconds');
    final reps = readOptionalInt(json, 'reps');
    if ((duration == null) == (reps == null)) {
      throw const FormatException('a step needs exactly one of "durationSeconds" or "reps"');
    }
    return WorkoutStep(
      id: readString(json, 'id'),
      exerciseId: readString(json, 'exerciseId'),
      type: parseEnumOr(StepType.values, json['type'], StepType.main),
      execution: duration != null ? ExecutionType.timed : ExecutionType.reps,
      durationSeconds: duration,
      repetitions: reps,
      sets: readIntOr(json, 'sets', 1),
      restSeconds: readIntOr(json, 'restSeconds', 0),
      perSide: readBool(json, 'perSide'),
      instructionOverride: readOptionalString(json, 'note'),
    );
  }

  final String id;
  final String exerciseId;
  final StepType type;
  final ExecutionType execution;
  final int? durationSeconds;
  final int? repetitions;
  final int sets;
  final int restSeconds;
  final bool perSide;
  final String? instructionOverride;

  bool get isTimed => execution == ExecutionType.timed;

  /// "30 sec", "10 reps", "8 reps / side".
  String get targetLabel {
    final base = isTimed ? '${durationSeconds}s' : '$repetitions reps';
    return perSide ? '$base / side' : base;
  }

  WorkoutStep copyWith({
    String? id,
    String? exerciseId,
    StepType? type,
    ExecutionType? execution,
    int? durationSeconds,
    int? repetitions,
    int? sets,
    int? restSeconds,
    bool? perSide,
    String? instructionOverride,
    bool clearInstruction = false,
  }) {
    final newExecution = execution ?? this.execution;
    return WorkoutStep(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      type: type ?? this.type,
      execution: newExecution,
      durationSeconds: newExecution == ExecutionType.timed
          ? (durationSeconds ?? this.durationSeconds)
          : null,
      repetitions: newExecution == ExecutionType.reps ? (repetitions ?? this.repetitions) : null,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      perSide: perSide ?? this.perSide,
      instructionOverride: clearInstruction
          ? null
          : (instructionOverride ?? this.instructionOverride),
    );
  }

  JsonMap toJson() => {
    'id': id,
    'exerciseId': exerciseId,
    'type': type.json,
    if (durationSeconds != null && isTimed) 'durationSeconds': durationSeconds,
    if (repetitions != null && !isTimed) 'reps': repetitions,
    'sets': sets,
    'restSeconds': restSeconds,
    'perSide': perSide,
    if (instructionOverride != null) 'note': instructionOverride,
  };
}

/// A ready-made or user-created workout routine.
///
/// Warm-up steps run once, main steps repeat for [rounds] (as a circuit),
/// and cool-down steps run once at the end.
class Workout {
  const Workout({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.goal,
    required this.difficulty,
    required this.steps,
    this.rounds = 1,
    this.roundRestSeconds = 0,
    this.tags = const [],
    this.thumbnailPath,
    this.contentVersion = 1,
    this.source = WorkoutSource.catalog,
  });

  factory Workout.fromJson(JsonMap json, {WorkoutSource? source}) {
    final id = readString(json, 'id');
    try {
      return Workout(
        id: id,
        title: readString(json, 'title'),
        description: readString(json, 'description'),
        category: parseEnum(WorkoutCategory.values, json['category'], 'category'),
        goal: parseEnum(FitnessGoal.values, json['goal'], 'goal'),
        difficulty: parseEnum(Difficulty.values, json['difficulty'], 'difficulty'),
        steps: readObjectList(json, 'steps', WorkoutStep.fromJson),
        rounds: readIntOr(json, 'rounds', 1),
        roundRestSeconds: readIntOr(json, 'roundRestSeconds', 0),
        tags: readStringList(json, 'tags'),
        thumbnailPath: readOptionalString(json, 'thumbnailPath'),
        contentVersion: readIntOr(json, 'contentVersion', 1),
        source: source ?? parseEnumOr(WorkoutSource.values, json['source'], WorkoutSource.catalog),
      );
    } on FormatException catch (e) {
      throw FormatException('workout "$id": ${e.message}');
    }
  }

  final String id;
  final String title;
  final String description;
  final WorkoutCategory category;
  final FitnessGoal goal;
  final Difficulty difficulty;
  final List<WorkoutStep> steps;
  final int rounds;
  final int roundRestSeconds;
  final List<String> tags;
  final String? thumbnailPath;
  final int contentVersion;
  final WorkoutSource source;

  bool get isCustom => source == WorkoutSource.custom;

  Iterable<WorkoutStep> get warmupSteps => steps.where((s) => s.type == StepType.warmup);
  Iterable<WorkoutStep> get mainSteps => steps.where((s) => s.type == StepType.main);
  Iterable<WorkoutStep> get cooldownSteps => steps.where((s) => s.type == StepType.cooldown);

  JsonMap toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'category': category.json,
    'goal': goal.json,
    'difficulty': difficulty.json,
    'rounds': rounds,
    'roundRestSeconds': roundRestSeconds,
    'steps': steps.map((s) => s.toJson()).toList(),
    'tags': tags,
    if (thumbnailPath != null) 'thumbnailPath': thumbnailPath,
    'contentVersion': contentVersion,
    'source': source.json,
  };
}
