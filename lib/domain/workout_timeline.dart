import '../data/models/enums.dart';
import '../data/models/workout.dart';

enum SegmentKind { preparation, exercise, rest, transition }

/// One block of time in a guided session: a "get ready" countdown, one set
/// of an exercise (on one side), a rest, or a short switch-sides transition.
class TimelineSegment {
  const TimelineSegment({
    required this.index,
    required this.kind,
    this.stepIndex = -1,
    this.stepId,
    this.exerciseId,
    this.stepType,
    this.execution,
    this.durationSeconds,
    this.repetitions,
    this.round = 1,
    this.totalRounds = 1,
    this.set = 1,
    this.totalSets = 1,
    this.side = Side.none,
    this.exerciseNumber = 0,
    this.instructionOverride,
  });

  final int index;
  final SegmentKind kind;

  /// Index of the source step in `workout.steps`, or -1.
  final int stepIndex;
  final String? stepId;
  final String? exerciseId;
  final StepType? stepType;
  final ExecutionType? execution;

  /// Target duration of timed segments (exercise, rest, preparation,
  /// transition). Null for repetition-based exercise segments.
  final int? durationSeconds;
  final int? repetitions;
  final int round;
  final int totalRounds;
  final int set;
  final int totalSets;
  final Side side;

  /// 1-based position among exercise segments; 0 for other kinds.
  final int exerciseNumber;
  final String? instructionOverride;

  bool get isExercise => kind == SegmentKind.exercise;

  /// Repetition-based exercise segments wait for the user to confirm.
  bool get waitsForUser => kind == SegmentKind.exercise && execution == ExecutionType.reps;

  bool get isTimed => !waitsForUser;

  /// Rest, preparation and transitions can be skipped with "Skip rest".
  bool get isRestLike => !isExercise;
}

/// The flattened, ordered list of segments for a workout.
///
/// Order: one preparation countdown, warm-up steps once, main steps repeated
/// for each round (as a circuit), then cool-down steps once. Each step runs
/// `sets` times; per-side steps run left then right with a short transition.
/// A step's rest follows each of its sets except after the final segment of
/// the workout. Between circuit rounds the longer of the step rest and the
/// round rest is used.
class WorkoutTimeline {
  WorkoutTimeline._(this.segments)
    : exerciseSegmentCount = segments.where((s) => s.isExercise).length;

  static const int defaultPreparationSeconds = 10;
  static const int switchSidesSeconds = 5;

  factory WorkoutTimeline.build(
    Workout workout, {
    int preparationSeconds = defaultPreparationSeconds,
  }) {
    final blocks = <_Block>[];
    for (var i = 0; i < workout.steps.length; i++) {
      final step = workout.steps[i];
      if (step.type == StepType.warmup) blocks.add(_Block(step, i, 1, 1));
    }
    final rounds = workout.rounds < 1 ? 1 : workout.rounds;
    final mainIndexes = [
      for (var i = 0; i < workout.steps.length; i++)
        if (workout.steps[i].type == StepType.main) i,
    ];
    for (var r = 1; r <= rounds; r++) {
      for (final i in mainIndexes) {
        blocks.add(
          _Block(workout.steps[i], i, r, rounds, endsRound: i == mainIndexes.last && r < rounds),
        );
      }
    }
    for (var i = 0; i < workout.steps.length; i++) {
      final step = workout.steps[i];
      if (step.type == StepType.cooldown) blocks.add(_Block(step, i, 1, 1));
    }

    final segments = <TimelineSegment>[];
    var exerciseNumber = 0;
    void add(TimelineSegment Function(int index) create) => segments.add(create(segments.length));

    if (preparationSeconds > 0 && blocks.isNotEmpty) {
      add(
        (i) => TimelineSegment(
          index: i,
          kind: SegmentKind.preparation,
          durationSeconds: preparationSeconds,
        ),
      );
    }

    for (var b = 0; b < blocks.length; b++) {
      final block = blocks[b];
      final step = block.step;
      final sets = step.sets < 1 ? 1 : step.sets;
      for (var s = 1; s <= sets; s++) {
        final sides = step.perSide ? const [Side.left, Side.right] : const [Side.none];
        for (var k = 0; k < sides.length; k++) {
          exerciseNumber++;
          final number = exerciseNumber;
          add(
            (i) => TimelineSegment(
              index: i,
              kind: SegmentKind.exercise,
              stepIndex: block.stepIndex,
              stepId: step.id,
              exerciseId: step.exerciseId,
              stepType: step.type,
              execution: step.execution,
              durationSeconds: step.isTimed ? step.durationSeconds : null,
              repetitions: step.isTimed ? null : step.repetitions,
              round: block.round,
              totalRounds: block.totalRounds,
              set: s,
              totalSets: sets,
              side: sides[k],
              exerciseNumber: number,
              instructionOverride: step.instructionOverride,
            ),
          );
          if (k < sides.length - 1) {
            add(
              (i) => TimelineSegment(
                index: i,
                kind: SegmentKind.transition,
                stepIndex: block.stepIndex,
                stepId: step.id,
                exerciseId: step.exerciseId,
                durationSeconds: switchSidesSeconds,
                round: block.round,
                totalRounds: block.totalRounds,
                set: s,
                totalSets: sets,
              ),
            );
          }
        }
        final isLast = b == blocks.length - 1 && s == sets;
        if (isLast) continue;
        var rest = step.restSeconds;
        if (s == sets && block.endsRound && workout.roundRestSeconds > rest) {
          rest = workout.roundRestSeconds;
        }
        if (rest > 0) {
          add(
            (i) => TimelineSegment(
              index: i,
              kind: SegmentKind.rest,
              stepIndex: block.stepIndex,
              durationSeconds: rest,
              round: block.round,
              totalRounds: block.totalRounds,
              set: s,
              totalSets: sets,
            ),
          );
        }
      }
    }
    return WorkoutTimeline._(List.unmodifiable(segments));
  }

  final List<TimelineSegment> segments;
  final int exerciseSegmentCount;

  int get length => segments.length;
  bool get isEmpty => exerciseSegmentCount == 0;

  /// The next exercise segment strictly after [index], if any.
  TimelineSegment? nextExerciseAfter(int index) {
    for (var i = index + 1; i < segments.length; i++) {
      if (segments[i].isExercise) return segments[i];
    }
    return null;
  }

  /// Indexes of the exercise segments belonging to the same set as the
  /// exercise segment at [index] (both sides of a per-side set).
  List<int> siblingSides(int index) {
    final segment = segments[index];
    return [
      for (final s in segments)
        if (s.isExercise &&
            s.stepIndex == segment.stepIndex &&
            s.round == segment.round &&
            s.set == segment.set)
          s.index,
    ];
  }
}

class _Block {
  _Block(this.step, this.stepIndex, this.round, this.totalRounds, {this.endsRound = false});

  final WorkoutStep step;
  final int stepIndex;
  final int round;
  final int totalRounds;
  final bool endsRound;
}
