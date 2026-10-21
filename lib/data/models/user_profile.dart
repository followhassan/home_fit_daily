import '../../core/utils/json_utils.dart';
import '../../core/utils/units.dart';
import 'enums.dart';

/// The user's fitness preferences. Everything is optional and editable; no
/// medical or identifying information is collected.
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.experienceLevel,
    required this.primaryGoal,
    required this.preferredDurationMinutes,
    required this.preferredDays,
    required this.availableEquipment,
    required this.lowImpactPreference,
    required this.unitSystem,
    required this.weeklyGoal,
    required this.onboardingCompleted,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Conservative defaults used before (or instead of) onboarding.
  factory UserProfile.initial({required String id, required DateTime now}) => UserProfile(
    id: id,
    displayName: '',
    experienceLevel: Difficulty.beginner,
    primaryGoal: FitnessGoal.consistency,
    preferredDurationMinutes: 10,
    preferredDays: const {1, 3, 5},
    availableEquipment: const {},
    lowImpactPreference: false,
    unitSystem: UnitSystem.metric,
    weeklyGoal: 3,
    onboardingCompleted: false,
    createdAt: now,
    updatedAt: now,
  );

  /// Tolerates missing optional fields written by older app versions.
  factory UserProfile.fromJson(JsonMap json) {
    final now = DateTime.now().toUtc();
    final rawDays = json['preferredDays'];
    return UserProfile(
      id: readString(json, 'id'),
      displayName: (readOptionalString(json, 'displayName') ?? '').trim(),
      experienceLevel: parseEnumOr(Difficulty.values, json['experienceLevel'], Difficulty.beginner),
      primaryGoal: parseEnumOr(FitnessGoal.values, json['primaryGoal'], FitnessGoal.consistency),
      preferredDurationMinutes: _validDuration(readOptionalInt(json, 'preferredDurationMinutes')),
      preferredDays: rawDays is List
          ? rawDays.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
          : const {1, 3, 5},
      availableEquipment: json['availableEquipment'] is List
          ? (json['availableEquipment'] as List)
                .map((e) => parseEnumOrNull(Equipment.values, e))
                .whereType<Equipment>()
                .toSet()
          : const {},
      lowImpactPreference: readBool(json, 'lowImpactPreference'),
      unitSystem: parseEnumOr(UnitSystem.values, json['unitSystem'], UnitSystem.metric),
      weeklyGoal: (readOptionalInt(json, 'weeklyGoal') ?? 3).clamp(1, 7),
      onboardingCompleted: readBool(json, 'onboardingCompleted'),
      createdAt: readOptionalDateTime(json, 'createdAt') ?? now,
      updatedAt: readOptionalDateTime(json, 'updatedAt') ?? now,
    );
  }

  static const List<int> durationOptions = [5, 10, 15, 20, 30];

  static int _validDuration(int? minutes) => durationOptions.contains(minutes) ? minutes! : 10;

  final String id;

  /// Optional; empty when the user did not provide a name.
  final String displayName;
  final Difficulty experienceLevel;
  final FitnessGoal primaryGoal;
  final int preferredDurationMinutes;

  /// ISO weekdays (Monday = 1).
  final Set<int> preferredDays;
  final Set<Equipment> availableEquipment;
  final bool lowImpactPreference;
  final UnitSystem unitSystem;

  /// Target number of completed workouts per Monday–Sunday week.
  final int weeklyGoal;
  final bool onboardingCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasName => displayName.isNotEmpty;

  UserProfile copyWith({
    String? displayName,
    Difficulty? experienceLevel,
    FitnessGoal? primaryGoal,
    int? preferredDurationMinutes,
    Set<int>? preferredDays,
    Set<Equipment>? availableEquipment,
    bool? lowImpactPreference,
    UnitSystem? unitSystem,
    int? weeklyGoal,
    bool? onboardingCompleted,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id,
    displayName: (displayName ?? this.displayName).trim(),
    experienceLevel: experienceLevel ?? this.experienceLevel,
    primaryGoal: primaryGoal ?? this.primaryGoal,
    preferredDurationMinutes: preferredDurationMinutes ?? this.preferredDurationMinutes,
    preferredDays: preferredDays ?? this.preferredDays,
    availableEquipment: availableEquipment ?? this.availableEquipment,
    lowImpactPreference: lowImpactPreference ?? this.lowImpactPreference,
    unitSystem: unitSystem ?? this.unitSystem,
    weeklyGoal: (weeklyGoal ?? this.weeklyGoal).clamp(1, 7),
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  JsonMap toJson() => {
    'id': id,
    'displayName': displayName,
    'experienceLevel': experienceLevel.json,
    'primaryGoal': primaryGoal.json,
    'preferredDurationMinutes': preferredDurationMinutes,
    'preferredDays': (preferredDays.toList()..sort()),
    'availableEquipment': availableEquipment.map((e) => e.json).toList(),
    'lowImpactPreference': lowImpactPreference,
    'unitSystem': unitSystem.json,
    'weeklyGoal': weeklyGoal,
    'onboardingCompleted': onboardingCompleted,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
