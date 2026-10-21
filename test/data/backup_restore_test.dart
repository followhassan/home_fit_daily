import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/models/app_settings.dart';
import 'package:home_fit_daily/data/models/personal_records.dart';
import 'package:home_fit_daily/data/models/user_profile.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';
import 'package:home_fit_daily/domain/backup/backup_codec.dart';
import 'package:home_fit_daily/domain/backup/restore_service.dart';

import '../helpers/catalog_fixture.dart';
import '../helpers/sessions.dart';

final _now = DateTime.utc(2026, 10, 21, 9);

Future<Repositories> _seed(InMemoryKeyValueStore store, {String name = 'Sam'}) async {
  final repos = Repositories(store);
  await repos.profile.save(
    UserProfile.initial(id: 'p1', now: _now).copyWith(displayName: name, onboardingCompleted: true),
  );
  await repos.settings.save(AppSettings.defaults.copyWith(soundEnabled: false));
  await repos.sessions.save(sessionOn(LocalDate.parse('2026-10-20'), id: 's1'));
  await repos.favorites.add(
    FavoriteEntry(kind: FavoriteKind.exercise, itemId: 'push_up', addedAtUtc: _now),
  );
  return repos;
}

void main() {
  final catalog = loadBundledCatalog();

  group('BackupCodec', () {
    test('export then import round-trips personal data', () async {
      final store = InMemoryKeyValueStore();
      final repos = await _seed(store);
      final json = BackupCodec.encode(
        BackupPayload.fromRepositories(repos),
        nowUtc: _now,
        appVersion: '1.0.0',
      );
      final result = BackupCodec.decode(json, catalog);
      expect(result.isValid, isTrue, reason: result.errors.join());
      final payload = result.document!.payload;
      expect(payload.profile!.displayName, 'Sam');
      expect(payload.settings.soundEnabled, isFalse);
      expect(payload.sessions.single.id, 's1');
      expect(payload.favorites.single.itemId, 'push_up');
      expect(result.summary!.sessions, 1);
    });

    test('rejects malformed and truncated JSON', () {
      expect(BackupCodec.decode('{not json', catalog).isValid, isFalse);
      final full = BackupCodec.encode(
        BackupPayload.fromRepositories(Repositories(InMemoryKeyValueStore())),
        nowUtc: _now,
        appVersion: '1',
      );
      final truncated = full.substring(0, full.length ~/ 2);
      final result = BackupCodec.decode(truncated, catalog);
      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('incomplete'));
    });

    test('rejects files that are not HomeFit backups', () {
      expect(BackupCodec.decode('[1,2,3]', catalog).isValid, isFalse);
      expect(BackupCodec.decode(jsonEncode({'format': 'other'}), catalog).isValid, isFalse);
    });

    test('rejects backups from a newer app version', () {
      final result = BackupCodec.decode(
        jsonEncode({
          'format': BackupCodec.format,
          'backupFormatVersion': 99,
          'schemaVersion': 2,
          'exportedAtUtc': _now.toIso8601String(),
          'payload': <String, dynamic>{},
        }),
        catalog,
      );
      expect(result.isValid, isFalse);
      expect(result.errors.single, contains('newer version'));
    });

    test('rejects duplicate IDs and impossible values', () async {
      final repos = await _seed(InMemoryKeyValueStore());
      final map =
          jsonDecode(
                BackupCodec.encode(
                  BackupPayload.fromRepositories(repos),
                  nowUtc: _now,
                  appVersion: '1',
                ),
              )
              as Map<String, dynamic>;
      final payload = map['payload'] as Map<String, dynamic>;
      final sessions = payload['sessions'] as List;
      sessions.add(sessions.first);
      payload['measurements'] = [
        {
          'id': 'm1',
          'type': 'weight',
          'value': 5000,
          'timestampUtc': _now.toIso8601String(),
          'localDate': '2026-10-21',
        },
      ];
      final result = BackupCodec.decode(jsonEncode(map), catalog);
      expect(result.isValid, isFalse);
      expect(result.errors.join(), contains('more than once'));
      expect(result.errors.join(), contains('impossible'));
    });

    test('tolerates missing optional fields and drops stale references', () {
      final result = BackupCodec.decode(
        jsonEncode({
          'format': BackupCodec.format,
          'backupFormatVersion': 1,
          'schemaVersion': 2,
          'exportedAtUtc': _now.toIso8601String(),
          'payload': {
            'profile': {'id': 'p1'},
            'favorites': [
              {
                'kind': 'exercise',
                'itemId': 'no_such_exercise',
                'addedAtUtc': _now.toIso8601String(),
              },
            ],
          },
        }),
        catalog,
      );
      expect(result.isValid, isTrue, reason: result.errors.join());
      expect(result.document!.payload.profile!.weeklyGoal, 3);
      expect(result.document!.payload.favorites, isEmpty);
      expect(result.warnings, isNotEmpty);
    });

    test('rejects oversized and empty files', () {
      expect(BackupCodec.decodeBytes(const [], catalog).isValid, isFalse);
      expect(
        BackupCodec.decodeBytes(List.filled(BackupCodec.maxBytes + 1, 32), catalog).isValid,
        isFalse,
      );
    });
  });

  group('RestoreService', () {
    test('a successful import replaces data and can be undone', () async {
      final store = InMemoryKeyValueStore();
      final repos = await _seed(store, name: 'Before');
      final incoming = BackupPayload.fromRepositories(
        await _seed(InMemoryKeyValueStore(), name: 'After'),
      );
      final restore = RestoreService(store);
      await restore.applyBackup(incoming, nowUtc: _now);
      expect(repos.profile.load()!.displayName, 'After');
      expect(store.read(StorageBoxes.meta, MetaKeys.restoreJournal), isNull);
      expect(restore.undoSnapshotDate, _now);

      await restore.undoLastImport(nowUtc: _now);
      expect(repos.profile.load()!.displayName, 'Before');
      expect(restore.undoSnapshotDate, isNull);
    });

    test('a failed import leaves existing data untouched', () async {
      final store = InMemoryKeyValueStore();
      final repos = await _seed(store, name: 'Original');
      final incoming = BackupPayload.fromRepositories(
        await _seed(InMemoryKeyValueStore(), name: 'Imported'),
      );
      // Allow the journal write, then fail part-way through replacing boxes.
      store.failWritesAfter = store.writeCount + 3;
      await expectLater(
        RestoreService(store).applyBackup(incoming, nowUtc: _now),
        throwsA(isA<RestoreFailedException>()),
      );
      store.failWritesAfter = null;
      // Rollback happens immediately, or at the next launch via the journal.
      await RestoreService(store).recoverInterruptedRestore();
      expect(repos.profile.load()!.displayName, 'Original');
      expect(repos.sessions.all().single.id, 's1');
    });

    test('an import interrupted by process death rolls back on next launch', () async {
      final store = InMemoryKeyValueStore();
      final repos = await _seed(store, name: 'Original');
      final previous = {for (final box in StorageBoxes.personal) box: store.readAll(box)};
      // Simulate: journal written, then boxes partially replaced, then death.
      await store.write(
        StorageBoxes.meta,
        MetaKeys.restoreJournal,
        jsonEncode({'state': 'applying', 'previous': previous}),
      );
      await store.replaceBox(StorageBoxes.profile, const {});
      await store.replaceBox(StorageBoxes.sessions, const {});

      final rolledBack = await RestoreService(store).recoverInterruptedRestore();
      expect(rolledBack, isTrue);
      expect(repos.profile.load()!.displayName, 'Original');
      expect(repos.sessions.all(), hasLength(1));
      expect(store.read(StorageBoxes.meta, MetaKeys.restoreJournal), isNull);
    });

    test('partial replacement only touches the listed boxes', () async {
      final store = InMemoryKeyValueStore();
      final repos = await _seed(store);
      await RestoreService(store).replaceBoxes({StorageBoxes.sessions: const {}}, nowUtc: _now);
      expect(repos.sessions.all(), isEmpty);
      expect(repos.profile.load(), isNotNull);
      expect(repos.favorites.all(), hasLength(1));
    });

    test('erasing removes all personal data', () async {
      final store = InMemoryKeyValueStore();
      final repos = await _seed(store);
      await RestoreService(store).eraseAll(nowUtc: _now);
      expect(repos.profile.load(), isNull);
      expect(repos.sessions.all(), isEmpty);
      expect(repos.favorites.all(), isEmpty);
    });
  });

  test('corrupted records are skipped instead of crashing', () async {
    final store = InMemoryKeyValueStore();
    final repos = await _seed(store);
    await store.write(StorageBoxes.sessions, 'broken', '{"id": 12');
    expect(repos.sessions.all(), hasLength(1));
    expect(repos.unreadableRecordCount, 1);
    expect(await repos.removeUnreadableRecords(), 1);
    expect(store.read(StorageBoxes.sessions, 'broken'), isNull);
  });
}
