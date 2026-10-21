import 'dart:convert';

import '../../core/utils/ids.dart';
import '../repositories/repositories.dart';
import 'key_value_store.dart';
import 'legacy/hive_legacy_source.dart';
import 'legacy/legacy_migration.dart';

class StorageVersionException implements Exception {
  const StorageVersionException(this.storedVersion);
  final int storedVersion;

  @override
  String toString() => 'Data was saved by a newer app version (schema $storedVersion).';
}

class MigrationReport {
  const MigrationReport({
    required this.fromVersion,
    required this.toVersion,
    this.legacySessionsImported = 0,
  });

  final int? fromVersion;
  final int toVersion;
  final int legacySessionsImported;
}

/// Brings stored personal data up to [currentSchemaVersion].
///
/// Schema history:
/// * 1 – prototype: typed Hive boxes (`history_box`, `profile_box`, …).
/// * 2 – JSON documents in `hf_*` boxes (this version).
///
/// Every step is idempotent: records keep stable IDs and the version marker
/// is written only after the data, so an interrupted migration simply runs
/// again on the next launch. Personal data is never cleared to "fix" a
/// migration.
class SchemaMigrator {
  SchemaMigrator({
    required this.store,
    required this.repositories,
    required this.legacySource,
    required this.exerciseExists,
    DateTime Function()? clock,
  }) : _now = clock ?? DateTime.now;

  static const int currentSchemaVersion = 2;

  final KeyValueStore store;
  final Repositories repositories;
  final LegacySource legacySource;
  final bool Function(String exerciseId) exerciseExists;
  final DateTime Function() _now;

  int? get storedVersion =>
      int.tryParse(store.read(StorageBoxes.meta, MetaKeys.schemaVersion) ?? '');

  Future<MigrationReport> run() async {
    final from = storedVersion;
    if (from != null && from > currentSchemaVersion) {
      throw StorageVersionException(from);
    }

    var imported = 0;
    if (from == null) {
      if (await legacySource.exists()) {
        imported = await _migrateLegacy();
      }
      await store.write(StorageBoxes.meta, MetaKeys.schemaVersion, '$currentSchemaVersion');
      await store.flush();
    }

    // Remove prototype files only after the new data and version marker are
    // safely written. Also covers a crash between those two steps.
    final migrated = store.read(StorageBoxes.meta, MetaKeys.legacyMigration) != null;
    if (migrated && await legacySource.exists()) {
      await legacySource.delete();
    }

    return MigrationReport(
      fromVersion: from,
      toVersion: currentSchemaVersion,
      legacySessionsImported: imported,
    );
  }

  Future<int> _migrateLegacy() async {
    final data = await legacySource.read();
    final now = _now().toUtc();
    final conversion = LegacyConverter.convert(
      data,
      profileId: Ids.profile(),
      nowUtc: now,
      exerciseExists: exerciseExists,
    );
    if (conversion.profile != null && repositories.profile.load() == null) {
      await repositories.profile.save(conversion.profile!);
    }
    if (conversion.settings != null && repositories.settings.load() == null) {
      await repositories.settings.save(conversion.settings!);
    }
    if (conversion.sessions.isNotEmpty) {
      await repositories.sessions.docs.putAll(conversion.sessions);
    }
    if (conversion.favorites.isNotEmpty) {
      await repositories.favorites.docs.putAll(conversion.favorites);
    }
    await store.write(
      StorageBoxes.meta,
      MetaKeys.legacyMigration,
      jsonEncode({
        'migratedAtUtc': now.toIso8601String(),
        'sessions': conversion.sessions.length,
        'favorites': conversion.favorites.length,
      }),
    );
    return conversion.sessions.length;
  }
}
