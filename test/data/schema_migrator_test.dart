import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/local/legacy/hive_legacy_source.dart';
import 'package:home_fit_daily/data/local/legacy/legacy_migration.dart';
import 'package:home_fit_daily/data/local/schema_migrator.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';

class _FakeLegacy implements LegacySource {
  _FakeLegacy(this.data);

  LegacyData? data;
  int deletes = 0;

  @override
  Future<bool> exists() async => data != null;

  @override
  Future<LegacyData> read() async => data!;

  @override
  Future<void> delete() async {
    deletes++;
    data = null;
  }
}

LegacyData _legacy() => LegacyData(
  profileName: 'Alex',
  fitnessGoal: 'Build Muscle',
  darkMode: false,
  history: [
    LegacyHistoryEntry(
      id: 'h1',
      planId: 'beginner',
      planName: 'Beginner Burn',
      completedAtLocal: DateTime(2026, 6, 1, 18, 30),
      durationSeconds: 900,
      difficulty: 'Beginner',
    ),
  ],
  favoriteExerciseIds: const ['squats', 'plank_up_down', 'squats'],
);

void main() {
  SchemaMigrator migrator(KeyValueStore store, LegacySource legacy) => SchemaMigrator(
    store: store,
    repositories: Repositories(store),
    legacySource: legacy,
    exerciseExists: (id) => {'bodyweight_squat', 'push_up'}.contains(id),
    clock: () => DateTime.utc(2026, 10, 21),
  );

  test('a fresh install just records the schema version', () async {
    final store = InMemoryKeyValueStore();
    final report = await migrator(store, _FakeLegacy(null)).run();
    expect(report.fromVersion, isNull);
    expect(store.read(StorageBoxes.meta, MetaKeys.schemaVersion), '2');
  });

  test('prototype data is converted without inventing values', () async {
    final store = InMemoryKeyValueStore();
    final legacy = _FakeLegacy(_legacy());
    final report = await migrator(store, legacy).run();
    final repos = Repositories(store);

    expect(report.legacySessionsImported, 1);
    final profile = repos.profile.load()!;
    expect(profile.displayName, 'Alex');
    expect(profile.primaryGoal, FitnessGoal.strength);
    expect(repos.settings.load()!.theme, ThemePreference.light);

    final session = repos.sessions.all().single;
    expect(session.status, SessionStatus.completed);
    expect(session.importedFromLegacy, isTrue);
    expect(session.activeSeconds, 900);
    expect(session.localCompletionDate.toIso(), '2026-06-01');

    // Only mappable, existing exercises; no duplicates.
    expect(repos.favorites.all().map((f) => f.itemId), ['bodyweight_squat']);
    // No body measurements are invented from prototype defaults.
    expect(repos.measurements.all(), isEmpty);
    // Old files are removed only after the new data is safely written.
    expect(legacy.deletes, 1);
  });

  test('migration is idempotent', () async {
    final store = InMemoryKeyValueStore();
    await migrator(store, _FakeLegacy(_legacy())).run();
    // Simulate a crash before the version marker: run again.
    await store.delete(StorageBoxes.meta, MetaKeys.schemaVersion);
    await migrator(store, _FakeLegacy(_legacy())).run();
    expect(Repositories(store).sessions.all(), hasLength(1));
  });

  test('the placeholder prototype name is not treated as a real name', () {
    final conversion = LegacyConverter.convert(
      const LegacyData(profileName: 'Fitness Enthusiast'),
      profileId: 'p',
      nowUtc: DateTime.utc(2026),
      exerciseExists: (_) => true,
    );
    expect(conversion.profile!.displayName, isEmpty);
  });

  test('data from a newer schema is refused rather than damaged', () async {
    final store = InMemoryKeyValueStore();
    await store.write(StorageBoxes.meta, MetaKeys.schemaVersion, '99');
    expect(() => migrator(store, _FakeLegacy(null)).run(), throwsA(isA<StorageVersionException>()));
  });
}
