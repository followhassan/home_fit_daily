import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// One calendar day of a training plan (day 1 … 28).
class PlanDay {
  const PlanDay({required this.dayNumber, required this.type, this.workoutId, this.note});

  factory PlanDay.fromJson(JsonMap json) => PlanDay(
    dayNumber: readInt(json, 'day'),
    type: parseEnum(PlanDayType.values, json['type'], 'type'),
    workoutId: readOptionalString(json, 'workoutId'),
    note: readOptionalString(json, 'note'),
  );

  final int dayNumber;
  final PlanDayType type;
  final String? workoutId;
  final String? note;

  int get weekNumber => (dayNumber - 1) ~/ 7 + 1;

  JsonMap toJson() => {
    'day': dayNumber,
    'type': type.json,
    if (workoutId != null) 'workoutId': workoutId,
    if (note != null) 'note': note,
  };
}

class PlanWeek {
  const PlanWeek({required this.number, required this.focus});

  factory PlanWeek.fromJson(JsonMap json) =>
      PlanWeek(number: readInt(json, 'week'), focus: readString(json, 'focus'));

  final int number;
  final String focus;

  JsonMap toJson() => {'week': number, 'focus': focus};
}

/// A structured multi-week plan from the bundled catalog.
class TrainingPlan {
  const TrainingPlan({
    required this.id,
    required this.title,
    required this.summary,
    required this.description,
    required this.difficulty,
    required this.goal,
    required this.weeklySchedule,
    required this.progressionNotes,
    required this.recoveryGuidance,
    required this.weeks,
    required this.days,
    required this.tags,
    required this.contentVersion,
  });

  factory TrainingPlan.fromJson(JsonMap json) {
    final id = readString(json, 'id');
    try {
      return TrainingPlan(
        id: id,
        title: readString(json, 'title'),
        summary: readString(json, 'summary'),
        description: readString(json, 'description'),
        difficulty: parseEnum(Difficulty.values, json['difficulty'], 'difficulty'),
        goal: parseEnum(FitnessGoal.values, json['goal'], 'goal'),
        weeklySchedule: readString(json, 'weeklySchedule'),
        progressionNotes: readString(json, 'progression'),
        recoveryGuidance: readString(json, 'recovery'),
        weeks: readObjectList(json, 'weeks', PlanWeek.fromJson),
        days: readObjectList(json, 'days', PlanDay.fromJson),
        tags: readStringList(json, 'tags'),
        contentVersion: readIntOr(json, 'contentVersion', 1),
      );
    } on FormatException catch (e) {
      throw FormatException('plan "$id": ${e.message}');
    }
  }

  static const int lengthInDays = 28;

  final String id;
  final String title;
  final String summary;
  final String description;
  final Difficulty difficulty;
  final FitnessGoal goal;
  final String weeklySchedule;
  final String progressionNotes;
  final String recoveryGuidance;
  final List<PlanWeek> weeks;
  final List<PlanDay> days;
  final List<String> tags;
  final int contentVersion;

  int get weekCount => (days.length / 7).ceil();

  Iterable<PlanDay> daysOfWeek(int week) => days.where((d) => d.weekNumber == week);

  int get trainingDayCount => days.where((d) => d.type.isTraining).length;

  String focusOfWeek(int week) => weeks.where((w) => w.number == week).firstOrNull?.focus ?? '';
}
