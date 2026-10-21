import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../core/utils/local_date.dart';
import '../data/models/workout_session.dart';
import '../data/repositories/repositories.dart';
import '../domain/stats_service.dart';

/// Session history and the statistics derived from it.
///
/// Statistics are recomputed only when history, the weekly goal or the
/// calendar day changes – never on every widget rebuild – and there are no
/// cached totals in storage that could go stale after a deletion or import.
class HistoryController extends ChangeNotifier {
  HistoryController(this._repo, {required this._weeklyGoal, this._clock = const AppClock()}) {
    _sessions = _repo.all();
    _recompute();
  }

  final SessionRepository _repo;
  final AppClock _clock;
  int _weeklyGoal;
  late List<WorkoutSession> _sessions;
  late StatsSnapshot _stats;
  late LocalDate _statsDay;

  /// Newest first.
  List<WorkoutSession> get sessions => List.unmodifiable(_sessions);
  StatsSnapshot get stats {
    if (_clock.today() != _statsDay) _recompute();
    return _stats;
  }

  LocalDate get today => _clock.today();

  void _recompute() {
    _statsDay = _clock.today();
    _stats = StatsSnapshot.compute(_sessions, today: _statsDay, weeklyGoal: _weeklyGoal);
  }

  void setWeeklyGoal(int goal) {
    if (goal == _weeklyGoal) return;
    _weeklyGoal = goal;
    _recompute();
    notifyListeners();
  }

  /// Call when the app resumes; refreshes date-based values after midnight.
  void refreshDay() {
    if (_clock.today() != _statsDay) {
      _recompute();
      notifyListeners();
    }
  }

  WorkoutSession? byId(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<WorkoutSession> sessionsOn(LocalDate day) =>
      _sessions.where((s) => s.localCompletionDate == day).toList();

  bool hasCompletedOn(LocalDate day) => _stats.activityOn(day)?.hasCompleted ?? false;

  /// Records a session saved by the workout player (idempotent by ID).
  void onSessionSaved(WorkoutSession session) {
    _sessions = [session, ..._sessions.where((s) => s.id != session.id)]
      ..sort((a, b) => b.completedAtUtc.compareTo(a.completedAtUtc));
    _recompute();
    notifyListeners();
  }

  /// Saves an edited effort rating or note.
  Future<void> updateSession(WorkoutSession session) async {
    await _repo.save(session);
    onSessionSaved(session);
  }

  /// Deletes a session. Stats and plan progress are derived from history,
  /// so they update automatically.
  Future<void> deleteSession(String id) async {
    await _repo.delete(id);
    _sessions = _sessions.where((s) => s.id != id).toList();
    _recompute();
    notifyListeners();
  }

  void reload() {
    _sessions = _repo.all();
    _recompute();
    notifyListeners();
  }
}
