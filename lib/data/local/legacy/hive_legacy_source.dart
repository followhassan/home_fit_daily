import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'legacy_adapters.dart';
import 'legacy_migration.dart';

/// Access to the prototype's Hive boxes, used once during migration.
abstract interface class LegacySource {
  Future<bool> exists();
  Future<LegacyData> read();
  Future<void> delete();
}

class HiveLegacySource implements LegacySource {
  bool _adaptersRegistered = false;

  @override
  Future<bool> exists() async {
    for (final name in LegacyBoxes.all) {
      if (await Hive.boxExists(name)) return true;
    }
    return false;
  }

  void _registerAdapters() {
    if (_adaptersRegistered) return;
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(LegacyHistoryAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(LegacyProfileAdapter());
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(LegacySettingsAdapter());
    }
    _adaptersRegistered = true;
  }

  @override
  Future<LegacyData> read() async {
    _registerAdapters();
    String? name;
    String? goal;
    bool? darkMode;
    final history = <LegacyHistoryEntry>[];
    final favorites = <String>[];

    final profile = await _values(LegacyBoxes.profile);
    for (final value in profile.whereType<LegacyProfileRecord>()) {
      if (value.fields[0] case final String n) name = n;
      if (value.fields[6] case final String g) goal = g;
    }

    final settings = await _values(LegacyBoxes.settings);
    for (final value in settings.whereType<LegacySettingsRecord>()) {
      if (value.fields[0] case final bool dark) darkMode = dark;
    }

    final records = await _values(LegacyBoxes.history);
    for (final value in records.whereType<LegacyHistoryRecord>()) {
      final f = value.fields;
      if (f[0] is! String || f[3] is! DateTime) continue;
      history.add(
        LegacyHistoryEntry(
          id: f[0] as String,
          planId: f[1] is String ? f[1] as String : 'workout',
          planName: f[2] is String ? f[2] as String : 'Workout',
          completedAtLocal: (f[3] as DateTime).toLocal(),
          durationSeconds: f[4] is int ? f[4] as int : 0,
          difficulty: f[7] is String ? f[7] as String : '',
        ),
      );
    }

    final favs = await _values(LegacyBoxes.favorites);
    favorites.addAll(favs.whereType<String>());

    return LegacyData(
      profileName: name,
      fitnessGoal: goal,
      darkMode: darkMode,
      history: history,
      favoriteExerciseIds: favorites,
    );
  }

  /// Reads all values of a legacy box. A damaged box yields no values
  /// rather than blocking the app.
  Future<List<Object?>> _values(String boxName) async {
    if (!await Hive.boxExists(boxName)) return const [];
    try {
      final box = await Hive.openBox<dynamic>(boxName);
      final values = box.values.toList();
      await box.close();
      return values;
    } catch (e) {
      debugPrint('Could not read legacy box $boxName: $e');
      return const [];
    }
  }

  @override
  Future<void> delete() async {
    for (final name in LegacyBoxes.all) {
      try {
        await Hive.deleteBoxFromDisk(name);
      } catch (e) {
        debugPrint('Could not delete legacy box $name: $e');
      }
    }
  }
}
