import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// Source and license information for a bundled media asset.
class MediaAttribution {
  const MediaAttribution({required this.source, required this.license, this.author, this.notes});

  factory MediaAttribution.fromJson(JsonMap json) => MediaAttribution(
    source: readString(json, 'source'),
    license: readString(json, 'license'),
    author: readOptionalString(json, 'author'),
    notes: readOptionalString(json, 'notes'),
  );

  /// Media paths with this scheme refer to the app's own procedurally drawn
  /// figure animations (see `lib/features/exercise_media/`).
  static const figureScheme = 'figure://';

  static const generatedFigure = MediaAttribution(
    source: 'HomeFit built-in figure animation (drawn in code)',
    license: 'Original work created for this app; no third-party rights',
    author: 'HomeFit contributors',
    notes:
        'Simplified illustration. Not a professionally produced '
        'demonstration.',
  );

  final String source;
  final String license;
  final String? author;
  final String? notes;

  JsonMap toJson() => {
    'source': source,
    'license': license,
    if (author != null) 'author': author,
    if (notes != null) 'notes': notes,
  };
}

/// An exercise from the bundled, read-only catalog.
class Exercise {
  Exercise({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.matRecommended,
    required this.isLowImpact,
    required this.executionType,
    required this.defaultDurationSeconds,
    required this.defaultRepetitions,
    required this.secondsPerRep,
    required this.isPerSide,
    required this.setupInstructions,
    required this.executionInstructions,
    required this.breathingGuidance,
    required this.commonMistakes,
    required this.easierVariation,
    required this.harderVariation,
    required this.cautions,
    required this.mediaPath,
    required this.attribution,
    required this.tags,
  });

  factory Exercise.fromJson(JsonMap json) {
    final id = readString(json, 'id');
    try {
      return Exercise(
        id: id,
        name: readString(json, 'name'),
        description: readString(json, 'description'),
        category: parseEnum(ExerciseCategory.values, json['category'], 'category'),
        difficulty: parseEnum(Difficulty.values, json['difficulty'], 'difficulty'),
        primaryMuscles: _muscles(json, 'primaryMuscles'),
        secondaryMuscles: _muscles(json, 'secondaryMuscles'),
        equipment: readStringList(
          json,
          'equipment',
        ).map((e) => parseEnum(Equipment.values, e, 'equipment')).toSet(),
        matRecommended: readBool(json, 'matRecommended'),
        isLowImpact: readBool(json, 'lowImpact'),
        executionType: parseEnum(ExecutionType.values, json['execution'], 'execution'),
        defaultDurationSeconds: readOptionalInt(json, 'defaultDurationSeconds'),
        defaultRepetitions: readOptionalInt(json, 'defaultReps'),
        secondsPerRep: readIntOr(json, 'secondsPerRep', 3),
        isPerSide: readBool(json, 'perSide'),
        setupInstructions: readString(json, 'setup'),
        executionInstructions: readStringList(json, 'steps'),
        breathingGuidance: readString(json, 'breathing'),
        commonMistakes: readStringList(json, 'mistakes'),
        easierVariation: readString(json, 'easier'),
        harderVariation: readOptionalString(json, 'harder'),
        cautions: readStringList(json, 'cautions'),
        mediaPath: readOptionalString(json, 'mediaPath'),
        attribution: json['attribution'] != null
            ? MediaAttribution.fromJson(asJsonMap(json['attribution'], 'attribution'))
            : (readOptionalString(json, 'mediaPath')?.startsWith(MediaAttribution.figureScheme) ??
                  false)
            ? MediaAttribution.generatedFigure
            : null,
        tags: readStringList(json, 'tags'),
      );
    } on FormatException catch (e) {
      throw FormatException('exercise "$id": ${e.message}');
    }
  }

  static List<MuscleGroup> _muscles(JsonMap json, String key) => readStringList(
    json,
    key,
  ).map((m) => parseEnum(MuscleGroup.values, m, key)).toList(growable: false);

  final String id;
  final String name;
  final String description;
  final ExerciseCategory category;
  final Difficulty difficulty;
  final List<MuscleGroup> primaryMuscles;
  final List<MuscleGroup> secondaryMuscles;

  /// Equipment that is *required*. Empty means bodyweight only.
  final Set<Equipment> equipment;

  /// Floor exercises where a mat (or folded towel) makes things comfortable.
  final bool matRecommended;
  final bool isLowImpact;

  /// The default way to perform the exercise.
  final ExecutionType executionType;

  /// Default time per set (per side when [isPerSide]); null if the exercise
  /// cannot be done for time.
  final int? defaultDurationSeconds;

  /// Default repetitions per set (per side when [isPerSide]); null for holds
  /// and stretches that cannot be counted in repetitions.
  final int? defaultRepetitions;

  /// Assumed pace used only for duration estimates of rep-based sets.
  final int secondsPerRep;
  final bool isPerSide;
  final String setupInstructions;
  final List<String> executionInstructions;
  final String breathingGuidance;
  final List<String> commonMistakes;
  final String easierVariation;
  final String? harderVariation;
  final List<String> cautions;
  final String? mediaPath;
  final MediaAttribution? attribution;
  final List<String> tags;

  bool get supportsTimed => defaultDurationSeconds != null;
  bool get supportsReps => defaultRepetitions != null;
  bool get requiresEquipment => equipment.isNotEmpty;

  bool supports(ExecutionType type) => type == ExecutionType.timed ? supportsTimed : supportsReps;

  Set<MuscleGroup> get allMuscles => {...primaryMuscles, ...secondaryMuscles};

  /// Lower-cased text used for offline search.
  late final String searchText = [
    name,
    description,
    category.label,
    ...tags,
    ...primaryMuscles.map((m) => m.label),
  ].join(' ').toLowerCase();
}
