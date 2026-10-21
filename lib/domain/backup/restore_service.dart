import 'dart:convert';

import '../../core/utils/json_utils.dart';
import '../../data/local/key_value_store.dart';
import 'backup_codec.dart';

class RestoreFailedException implements Exception {
  const RestoreFailedException(this.cause);
  final Object cause;

  @override
  String toString() => 'RestoreFailedException: $cause';
}

/// Replaces groups of storage boxes with a recoverable, journaled write.
///
/// Hive has no cross-box transactions, so multi-box changes (restoring a
/// backup, resetting progress, erasing data) work like this:
/// 1. Copy the raw contents of every affected box (including records the
///    app could not decode) into a journal entry in the meta box, flushed to
///    disk before anything else changes.
/// 2. Replace each affected box.
/// 3. Delete the journal (optionally keeping the copy as an "undo import"
///    snapshot).
///
/// If step 2 fails, the boxes are rolled back immediately. If the app dies
/// during step 2, [recoverInterruptedRestore] rolls back on the next launch.
/// Either way the change is all-or-nothing.
class RestoreService {
  RestoreService(this.store);

  final KeyValueStore store;

  Map<String, Map<String, String>> _snapshot(Iterable<String> boxes) => {
    for (final box in boxes) box: store.readAll(box),
  };

  Future<void> _replace(Map<String, Map<String, String>> boxes) async {
    for (final entry in boxes.entries) {
      await store.replaceBox(entry.key, entry.value);
    }
  }

  /// Returns true when an interrupted change was rolled back.
  Future<bool> recoverInterruptedRestore() async {
    final raw = store.read(StorageBoxes.meta, MetaKeys.restoreJournal);
    if (raw == null) return false;
    final previous = _decodeBoxes(raw, 'previous');
    if (previous != null) await _replace(previous);
    await store.delete(StorageBoxes.meta, MetaKeys.restoreJournal);
    await store.flush();
    return previous != null;
  }

  /// Replaces all personal data with [payload] and keeps the previous data
  /// so the import can be undone.
  Future<void> applyBackup(BackupPayload payload, {required DateTime nowUtc}) =>
      replaceBoxes(payload.toBoxEntries(), nowUtc: nowUtc, keepUndo: true);

  /// Erases all personal data with the same all-or-nothing guarantee.
  Future<void> eraseAll({required DateTime nowUtc}) async {
    await replaceBoxes({for (final box in StorageBoxes.personal) box: const {}}, nowUtc: nowUtc);
    await store.delete(StorageBoxes.meta, MetaKeys.preImportSnapshot);
    await store.flush();
  }

  /// Atomically replaces the content of each box in [next]. Boxes not
  /// listed are left untouched.
  Future<void> replaceBoxes(
    Map<String, Map<String, String>> next, {
    required DateTime nowUtc,
    bool keepUndo = false,
  }) async {
    final previous = _snapshot(next.keys);
    try {
      await store.write(
        StorageBoxes.meta,
        MetaKeys.restoreJournal,
        jsonEncode({
          'state': 'applying',
          'startedAtUtc': nowUtc.toIso8601String(),
          'previous': previous,
        }),
      );
      await store.flush();
    } catch (e) {
      throw RestoreFailedException(e);
    }

    try {
      await _replace(next);
      await store.flush();
    } catch (e) {
      try {
        await _replace(previous);
        await store.delete(StorageBoxes.meta, MetaKeys.restoreJournal);
      } catch (_) {
        // The journal remains; recoverInterruptedRestore() finishes the
        // rollback on the next launch.
      }
      throw RestoreFailedException(e);
    }

    if (keepUndo) {
      await store.write(
        StorageBoxes.meta,
        MetaKeys.preImportSnapshot,
        jsonEncode({'createdAtUtc': nowUtc.toIso8601String(), 'boxes': previous}),
      );
    }
    await store.delete(StorageBoxes.meta, MetaKeys.restoreJournal);
    await store.flush();
  }

  /// When the data from before the last import was saved, if available.
  DateTime? get undoSnapshotDate {
    final raw = store.read(StorageBoxes.meta, MetaKeys.preImportSnapshot);
    if (raw == null) return null;
    try {
      final json = asJsonMap(jsonDecode(raw), 'snapshot');
      return DateTime.tryParse('${json['createdAtUtc']}');
    } catch (_) {
      return null;
    }
  }

  /// Restores the data that existed before the last import.
  Future<void> undoLastImport({required DateTime nowUtc}) async {
    final raw = store.read(StorageBoxes.meta, MetaKeys.preImportSnapshot);
    final boxes = raw == null ? null : _decodeBoxes(raw, 'boxes');
    if (boxes == null) {
      throw const RestoreFailedException('No earlier data is available.');
    }
    await replaceBoxes(boxes, nowUtc: nowUtc);
    await store.delete(StorageBoxes.meta, MetaKeys.preImportSnapshot);
    await store.flush();
  }

  Map<String, Map<String, String>>? _decodeBoxes(String raw, String field) {
    try {
      final json = asJsonMap(jsonDecode(raw), 'journal');
      final boxes = asJsonMap(json[field], field);
      return {
        for (final entry in boxes.entries)
          entry.key: asJsonMap(entry.value, entry.key).map((k, v) => MapEntry(k, v as String)),
      };
    } catch (_) {
      return null;
    }
  }
}
