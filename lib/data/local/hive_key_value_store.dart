import 'package:hive_flutter/hive_flutter.dart';

import 'key_value_store.dart';

/// Thrown when a storage box cannot be opened (for example because the file
/// is corrupted beyond Hive's automatic crash recovery).
class StorageOpenException implements Exception {
  const StorageOpenException(this.boxName, this.cause);

  final String boxName;
  final Object cause;

  @override
  String toString() => 'StorageOpenException($boxName): $cause';
}

/// [KeyValueStore] backed by Hive `Box<String>`s holding JSON documents.
///
/// No Hive type adapters are used for this schema, so no adapter type IDs
/// are consumed (IDs 0–4 remain reserved for the legacy prototype format,
/// see `docs/DATABASE.md`).
class HiveKeyValueStore implements KeyValueStore {
  HiveKeyValueStore._(this._boxes);

  final Map<String, Box<String>> _boxes;

  static Future<HiveKeyValueStore> open(List<String> boxNames) async {
    final boxes = <String, Box<String>>{};
    for (final name in boxNames) {
      try {
        boxes[name] = await Hive.openBox<String>(name);
      } catch (e) {
        throw StorageOpenException(name, e);
      }
    }
    return HiveKeyValueStore._(boxes);
  }

  /// Deletes one box from disk so the app can start with empty data for it.
  static Future<void> deleteBox(String name) => Hive.deleteBoxFromDisk(name);

  Box<String> _box(String name) {
    final box = _boxes[name];
    if (box == null) throw StateError('Box $name is not open');
    return box;
  }

  @override
  String? read(String box, String key) => _box(box).get(key);

  @override
  Map<String, String> readAll(String box) {
    final b = _box(box);
    return {
      for (final key in b.keys)
        if (b.get(key) case final String value) key.toString(): value,
    };
  }

  @override
  Future<void> write(String box, String key, String value) => _box(box).put(key, value);

  @override
  Future<void> writeAll(String box, Map<String, String> entries) => _box(box).putAll(entries);

  @override
  Future<void> delete(String box, String key) => _box(box).delete(key);

  @override
  Future<void> deleteAll(String box, Iterable<String> keys) => _box(box).deleteAll(keys);

  @override
  Future<void> replaceBox(String box, Map<String, String> entries) async {
    final b = _box(box);
    await b.clear();
    if (entries.isNotEmpty) await b.putAll(entries);
  }

  @override
  Future<void> flush() async {
    for (final box in _boxes.values) {
      await box.flush();
    }
  }
}
