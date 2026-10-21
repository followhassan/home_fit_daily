import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../data/catalog/catalog.dart';
import '../data/models/personal_records.dart';
import '../data/repositories/repositories.dart';

/// Favorite exercises and ready-made workouts.
///
/// One storage record per item makes duplicates impossible. References to
/// catalog items that no longer exist are hidden (and pruned on load) so a
/// catalog update never breaks the favorites screen.
class FavoritesController extends ChangeNotifier {
  FavoritesController(this._repo, this._catalog, {this._clock = const AppClock()}) {
    _load();
  }

  final FavoritesRepository _repo;
  final Catalog _catalog;
  final AppClock _clock;
  final Map<String, FavoriteEntry> _entries = {};

  void _load() {
    _entries
      ..clear()
      ..addEntries(_repo.all().map((e) => MapEntry(e.key, e)));
  }

  bool _exists(FavoriteEntry e) => e.kind == FavoriteKind.exercise
      ? _catalog.exercise(e.itemId) != null
      : _catalog.workout(e.itemId) != null;

  /// Removes favorites whose catalog item no longer exists.
  Future<void> pruneStale() async {
    final stale = _entries.values.where((e) => !_exists(e)).toList();
    for (final e in stale) {
      await _repo.remove(e.kind, e.itemId);
      _entries.remove(e.key);
    }
    if (stale.isNotEmpty) notifyListeners();
  }

  bool isFavorite(FavoriteKind kind, String id) =>
      _entries.containsKey(FavoriteEntry.keyFor(kind, id));

  bool isExerciseFavorite(String id) => isFavorite(FavoriteKind.exercise, id);
  bool isWorkoutFavorite(String id) => isFavorite(FavoriteKind.workout, id);

  /// Most recently added first.
  List<String> ids(FavoriteKind kind) {
    final list = _entries.values.where((e) => e.kind == kind && _exists(e)).toList()
      ..sort((a, b) => b.addedAtUtc.compareTo(a.addedAtUtc));
    return [for (final e in list) e.itemId];
  }

  /// Toggles a favorite and persists immediately. Returns the new state.
  /// The UI updates optimistically and is reverted if saving fails.
  Future<bool> toggle(FavoriteKind kind, String id) async {
    final key = FavoriteEntry.keyFor(kind, id);
    final existing = _entries[key];
    if (existing != null) {
      _entries.remove(key);
      notifyListeners();
      try {
        await _repo.remove(kind, id);
      } catch (e) {
        _entries[key] = existing;
        notifyListeners();
        rethrow;
      }
      return false;
    }
    final entry = FavoriteEntry(kind: kind, itemId: id, addedAtUtc: _clock.nowUtc());
    _entries[key] = entry;
    notifyListeners();
    try {
      await _repo.add(entry);
    } catch (e) {
      _entries.remove(key);
      notifyListeners();
      rethrow;
    }
    return true;
  }

  void reload() {
    _load();
    notifyListeners();
  }
}
