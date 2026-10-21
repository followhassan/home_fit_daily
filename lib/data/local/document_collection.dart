import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/utils/json_utils.dart';
import 'key_value_store.dart';

/// Typed access to a box of JSON documents.
///
/// Unreadable records are skipped instead of crashing the app. They are left
/// in storage (a future version may be able to read them) and reported via
/// [unreadableKeys] so the user can be told and offered a clean-up.
class DocumentCollection<T> {
  DocumentCollection({
    required this.store,
    required this.box,
    required this.fromJson,
    required this.toJson,
    required this.keyOf,
  });

  final KeyValueStore store;
  final String box;
  final T Function(JsonMap json) fromJson;
  final JsonMap Function(T value) toJson;
  final String Function(T value) keyOf;

  final Set<String> _unreadable = {};

  Set<String> get unreadableKeys => Set.unmodifiable(_unreadable);

  T? read(String key) {
    final raw = store.read(box, key);
    if (raw == null) return null;
    return _decode(key, raw);
  }

  List<T> readAll() {
    final result = <T>[];
    for (final entry in store.readAll(box).entries) {
      final value = _decode(entry.key, entry.value);
      if (value != null) result.add(value);
    }
    return result;
  }

  T? _decode(String key, String raw) {
    try {
      final value = fromJson(asJsonMap(jsonDecode(raw), key));
      _unreadable.remove(key);
      return value;
    } catch (e) {
      _unreadable.add(key);
      debugPrint('Skipping unreadable record $box/$key: $e');
      return null;
    }
  }

  bool contains(String key) => store.read(box, key) != null;

  Future<void> put(T value) => store.write(box, keyOf(value), jsonEncode(toJson(value)));

  Future<void> putAll(Iterable<T> values) =>
      store.writeAll(box, {for (final v in values) keyOf(v): jsonEncode(toJson(v))});

  Future<void> delete(String key) async {
    await store.delete(box, key);
    _unreadable.remove(key);
  }

  Future<void> replaceAll(Iterable<T> values) async {
    await store.replaceBox(box, {for (final v in values) keyOf(v): jsonEncode(toJson(v))});
    _unreadable.clear();
  }

  /// Permanently removes records that could not be decoded.
  Future<int> removeUnreadable() async {
    final keys = _unreadable.toList();
    if (keys.isNotEmpty) await store.deleteAll(box, keys);
    _unreadable.clear();
    return keys.length;
  }
}
