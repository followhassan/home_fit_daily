/// Names of the storage boxes. Personal data and app metadata are kept apart
/// from the read-only catalog, which ships as bundled JSON.
abstract final class StorageBoxes {
  static const meta = 'hf_meta';
  static const profile = 'hf_profile';
  static const settings = 'hf_settings';
  static const favorites = 'hf_favorites';
  static const sessions = 'hf_sessions';
  static const activeSession = 'hf_active_session';
  static const enrollments = 'hf_enrollments';
  static const customWorkouts = 'hf_custom_workouts';
  static const measurements = 'hf_measurements';
  static const guideState = 'hf_guide_state';

  /// Boxes holding the user's personal data – exported in backups and
  /// replaced on restore.
  static const personal = [
    profile,
    settings,
    favorites,
    sessions,
    enrollments,
    customWorkouts,
    measurements,
    guideState,
  ];

  static const all = [meta, activeSession, ...personal];
}

/// Keys inside [StorageBoxes.meta].
abstract final class MetaKeys {
  static const schemaVersion = 'schemaVersion';
  static const contentVersion = 'contentVersion';
  static const restoreJournal = 'restoreJournal';
  static const preImportSnapshot = 'preImportSnapshot';
  static const legacyMigration = 'legacyMigration';
}

/// Minimal string key-value storage grouped into named boxes.
///
/// Reads are synchronous (boxes are loaded into memory when opened); writes
/// complete once persisted. Cross-box transactions do not exist, so callers
/// that touch several boxes must use a recoverable write strategy (see
/// `RestoreService`).
abstract interface class KeyValueStore {
  String? read(String box, String key);
  Map<String, String> readAll(String box);
  Future<void> write(String box, String key, String value);
  Future<void> writeAll(String box, Map<String, String> entries);
  Future<void> delete(String box, String key);
  Future<void> deleteAll(String box, Iterable<String> keys);

  /// Replaces the full content of [box].
  Future<void> replaceBox(String box, Map<String, String> entries);
  Future<void> flush();
}

/// In-memory implementation for tests. [failWritesAfter] simulates a crash
/// or disk error after a number of successful write operations.
class InMemoryKeyValueStore implements KeyValueStore {
  InMemoryKeyValueStore({this.failWritesAfter});

  final Map<String, Map<String, String>> _boxes = {};
  int? failWritesAfter;
  int writeCount = 0;

  Map<String, String> _box(String name) => _boxes.putIfAbsent(name, () => {});

  void _countWrite() {
    final limit = failWritesAfter;
    if (limit != null && writeCount >= limit) {
      throw const StorageWriteException('Simulated write failure');
    }
    writeCount++;
  }

  @override
  String? read(String box, String key) => _boxes[box]?[key];

  @override
  Map<String, String> readAll(String box) => Map.of(_box(box));

  @override
  Future<void> write(String box, String key, String value) async {
    _countWrite();
    _box(box)[key] = value;
  }

  @override
  Future<void> writeAll(String box, Map<String, String> entries) async {
    _countWrite();
    _box(box).addAll(entries);
  }

  @override
  Future<void> delete(String box, String key) async {
    _countWrite();
    _box(box).remove(key);
  }

  @override
  Future<void> deleteAll(String box, Iterable<String> keys) async {
    _countWrite();
    final b = _box(box);
    for (final key in keys) {
      b.remove(key);
    }
  }

  @override
  Future<void> replaceBox(String box, Map<String, String> entries) async {
    _countWrite();
    _boxes[box] = Map.of(entries);
  }

  @override
  Future<void> flush() async {}
}

class StorageWriteException implements Exception {
  const StorageWriteException(this.message);
  final String message;

  @override
  String toString() => 'StorageWriteException: $message';
}
