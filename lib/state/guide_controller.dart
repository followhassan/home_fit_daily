import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../data/models/personal_records.dart';
import '../data/repositories/repositories.dart';

/// Article bookmarks and reading progress.
class GuideController extends ChangeNotifier {
  GuideController(this._repo, {this._clock = const AppClock()}) {
    _states = _repo.all();
  }

  final GuideStateRepository _repo;
  final AppClock _clock;
  late Map<String, ArticleReadingState> _states;

  ArticleReadingState stateOf(String articleId) =>
      _states[articleId] ?? ArticleReadingState(articleId: articleId);

  bool isBookmarked(String articleId) => stateOf(articleId).bookmarked;

  double progressOf(String articleId) => stateOf(articleId).progress;

  /// Bookmarked article IDs, most recently bookmarked first.
  List<String> get bookmarkedIds {
    final list = _states.values.where((s) => s.bookmarked).toList()
      ..sort(
        (a, b) => (b.bookmarkedAtUtc ?? DateTime(0)).compareTo(a.bookmarkedAtUtc ?? DateTime(0)),
      );
    return [for (final s in list) s.articleId];
  }

  /// The most recently read, unfinished article, for "continue reading".
  String? get continueReadingId {
    final list =
        _states.values
            .where((s) => s.isStarted && !s.isFinished && s.lastReadAtUtc != null)
            .toList()
          ..sort((a, b) => b.lastReadAtUtc!.compareTo(a.lastReadAtUtc!));
    return list.isEmpty ? null : list.first.articleId;
  }

  Future<bool> toggleBookmark(String articleId) async {
    final current = stateOf(articleId);
    final updated = current.copyWith(
      bookmarked: !current.bookmarked,
      bookmarkedAtUtc: _clock.nowUtc(),
    );
    _states[articleId] = updated;
    notifyListeners();
    try {
      await _repo.save(updated);
    } catch (e) {
      _states[articleId] = current;
      notifyListeners();
      rethrow;
    }
    return updated.bookmarked;
  }

  /// Records the furthest point read. Progress never moves backwards, and
  /// writes happen only on meaningful changes to avoid excessive I/O.
  Future<void> recordProgress(String articleId, double fraction) async {
    final current = stateOf(articleId);
    final value = fraction.clamp(0.0, 1.0);
    final reachedEnd = value >= 0.95 && !current.isFinished;
    if (value < current.progress + 0.05 && !reachedEnd) return;
    final updated = current.copyWith(
      progress: value > current.progress ? value : current.progress,
      lastReadAtUtc: _clock.nowUtc(),
    );
    _states[articleId] = updated;
    notifyListeners();
    await _repo.save(updated);
  }

  /// Marks an article as opened (for "continue reading") without changing
  /// progress.
  Future<void> markOpened(String articleId) async {
    final updated = stateOf(articleId).copyWith(lastReadAtUtc: _clock.nowUtc());
    _states[articleId] = updated;
    await _repo.save(updated);
  }

  void reload() {
    _states = _repo.all();
    notifyListeners();
  }
}
