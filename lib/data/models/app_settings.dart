import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// Local workout reminder schedule.
class ReminderPreferences {
  const ReminderPreferences({
    required this.enabled,
    required this.days,
    required this.hour,
    required this.minute,
  });

  static const disabled = ReminderPreferences(enabled: false, days: {1, 3, 5}, hour: 18, minute: 0);

  factory ReminderPreferences.fromJson(JsonMap json) {
    final rawDays = json['days'];
    final days = rawDays is List
        ? rawDays.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
        : const {1, 3, 5};
    return ReminderPreferences(
      enabled: readBool(json, 'enabled'),
      days: days,
      hour: (readOptionalInt(json, 'hour') ?? 18).clamp(0, 23),
      minute: (readOptionalInt(json, 'minute') ?? 0).clamp(0, 59),
    );
  }

  final bool enabled;

  /// ISO weekdays (Monday = 1).
  final Set<int> days;
  final int hour;
  final int minute;

  ReminderPreferences copyWith({bool? enabled, Set<int>? days, int? hour, int? minute}) =>
      ReminderPreferences(
        enabled: enabled ?? this.enabled,
        days: days ?? this.days,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );

  JsonMap toJson() => {
    'enabled': enabled,
    'days': (days.toList()..sort()),
    'hour': hour,
    'minute': minute,
  };
}

/// Device-local app preferences. Every field changes real behaviour.
class AppSettings {
  const AppSettings({
    required this.theme,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.keepScreenAwake,
    required this.reminders,
  });

  static const defaults = AppSettings(
    theme: ThemePreference.dark,
    soundEnabled: true,
    vibrationEnabled: true,
    keepScreenAwake: true,
    reminders: ReminderPreferences.disabled,
  );

  factory AppSettings.fromJson(JsonMap json) => AppSettings(
    theme: parseEnumOr(ThemePreference.values, json['theme'], defaults.theme),
    soundEnabled: readBool(json, 'soundEnabled', fallback: true),
    vibrationEnabled: readBool(json, 'vibrationEnabled', fallback: true),
    keepScreenAwake: readBool(json, 'keepScreenAwake', fallback: true),
    reminders: json['reminders'] is Map
        ? ReminderPreferences.fromJson(asJsonMap(json['reminders'], 'reminders'))
        : ReminderPreferences.disabled,
  );

  final ThemePreference theme;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool keepScreenAwake;
  final ReminderPreferences reminders;

  AppSettings copyWith({
    ThemePreference? theme,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? keepScreenAwake,
    ReminderPreferences? reminders,
  }) => AppSettings(
    theme: theme ?? this.theme,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    reminders: reminders ?? this.reminders,
  );

  JsonMap toJson() => {
    'theme': theme.json,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
    'keepScreenAwake': keepScreenAwake,
    'reminders': reminders.toJson(),
  };
}
