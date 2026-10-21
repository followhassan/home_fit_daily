import 'package:hive/hive.dart';

/// Read-only adapters for the boxes written by the earlier prototype
/// (schema version 1). They exist only so the migration can read old data.
///
/// Hive type IDs are permanent: 0 = workout history, 1 = user profile,
/// 2 = achievement, 3 = challenge, 4 = settings. These IDs must never be
/// reused for different types. Achievement (2) and challenge (3) boxes are
/// deleted without being read, so they need no adapter.
abstract class LegacyRecord {
  LegacyRecord(this.fields);

  /// Raw field values keyed by the prototype's `@HiveField` index.
  final Map<int, dynamic> fields;
}

class LegacyHistoryRecord extends LegacyRecord {
  LegacyHistoryRecord(super.fields);
}

class LegacyProfileRecord extends LegacyRecord {
  LegacyProfileRecord(super.fields);
}

class LegacySettingsRecord extends LegacyRecord {
  LegacySettingsRecord(super.fields);
}

abstract class _LegacyAdapter<T extends LegacyRecord> extends TypeAdapter<T> {
  T create(Map<int, dynamic> fields);

  @override
  T read(BinaryReader reader) {
    final count = reader.readByte();
    final fields = <int, dynamic>{for (var i = 0; i < count; i++) reader.readByte(): reader.read()};
    return create(fields);
  }

  @override
  void write(BinaryWriter writer, T obj) => throw UnsupportedError('Legacy records are read-only');
}

class LegacyHistoryAdapter extends _LegacyAdapter<LegacyHistoryRecord> {
  @override
  final int typeId = 0;

  @override
  LegacyHistoryRecord create(Map<int, dynamic> fields) => LegacyHistoryRecord(fields);
}

class LegacyProfileAdapter extends _LegacyAdapter<LegacyProfileRecord> {
  @override
  final int typeId = 1;

  @override
  LegacyProfileRecord create(Map<int, dynamic> fields) => LegacyProfileRecord(fields);
}

class LegacySettingsAdapter extends _LegacyAdapter<LegacySettingsRecord> {
  @override
  final int typeId = 4;

  @override
  LegacySettingsRecord create(Map<int, dynamic> fields) => LegacySettingsRecord(fields);
}

/// Box names used by the prototype.
abstract final class LegacyBoxes {
  static const history = 'history_box';
  static const profile = 'profile_box';
  static const settings = 'settings_box';
  static const favorites = 'favorites_box';
  static const achievements = 'achievements_box';
  static const challenges = 'challenges_box';

  static const all = [history, profile, settings, favorites, achievements, challenges];
}
