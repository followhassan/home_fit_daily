import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../core/utils/ids.dart';
import '../core/utils/local_date.dart';
import '../data/models/enums.dart';
import '../data/models/plan_enrollment.dart';
import '../data/models/training_plan.dart';
import '../data/repositories/repositories.dart';
import '../domain/plan_scheduler.dart';
import 'history_controller.dart';

/// Training-plan enrollment and derived progress.
///
/// Progress is always derived from session history (via explicit assignment
/// links), so deleting a session or importing a backup can never leave a
/// stale "completed" flag behind.
class PlanController extends ChangeNotifier {
  PlanController(this._repo, this._history, {this._clock = const AppClock()}) {
    _load();
    _history.addListener(_onHistoryChanged);
  }

  final EnrollmentRepository _repo;
  final HistoryController _history;
  final AppClock _clock;
  List<PlanEnrollment> _enrollments = [];
  EnrollmentProgress? _progress;
  LocalDate? _progressDay;

  List<PlanEnrollment> get enrollments => List.unmodifiable(_enrollments);

  /// The active or paused enrollment, if any.
  PlanEnrollment? get current {
    for (final e in _enrollments) {
      if (e.status.isCurrent) return e;
    }
    return null;
  }

  EnrollmentProgress? get progress {
    final enrollment = current;
    if (enrollment == null) return null;
    final today = _clock.today();
    if (_progress?.enrollment != enrollment || _progressDay != today) {
      _progress = PlanScheduler.progress(enrollment, _history.sessions, today);
      _progressDay = today;
    }
    return _progress;
  }

  EnrollmentProgress progressOf(PlanEnrollment enrollment) =>
      PlanScheduler.progress(enrollment, _history.sessions, _clock.today());

  void _load() {
    _enrollments = _repo.all();
    _progress = null;
  }

  /// Repairs storage if more than one plan is marked current (e.g. after an
  /// interrupted write): the newest stays, older ones are marked as left.
  Future<void> normalize() async {
    final currents = _enrollments.where((e) => e.status.isCurrent).toList();
    if (currents.length <= 1) return;
    final now = _clock.nowUtc();
    for (final e in currents.skip(1)) {
      await _repo.save(PlanScheduler.close(e, EnrollmentStatus.left, nowUtc: now));
    }
    _load();
    notifyListeners();
  }

  void _onHistoryChanged() {
    _progress = null;
    notifyListeners();
  }

  void refreshDay() {
    if (_progressDay != _clock.today()) {
      _progress = null;
      notifyListeners();
    }
  }

  Future<void> _replace(PlanEnrollment updated) async {
    await _repo.save(updated);
    _enrollments = [
      for (final e in _enrollments) e.id == updated.id ? updated : e,
      if (!_enrollments.any((e) => e.id == updated.id)) updated,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _progress = null;
    notifyListeners();
  }

  /// Starts [plan] on [startDate]. Any current plan is closed first, so at
  /// most one plan is ever active.
  Future<PlanEnrollment> start(TrainingPlan plan, LocalDate startDate) async {
    final now = _clock.nowUtc();
    final existing = current;
    if (existing != null) {
      await _replace(PlanScheduler.close(existing, EnrollmentStatus.left, nowUtc: now));
    }
    final enrollment = PlanScheduler.enroll(
      plan,
      enrollmentId: Ids.enrollment(),
      startDate: startDate,
      nowUtc: now,
    );
    await _replace(enrollment);
    return enrollment;
  }

  Future<void> pause() async {
    final e = current;
    if (e == null) return;
    await _replace(PlanScheduler.pause(e, today: _clock.today(), nowUtc: _clock.nowUtc()));
  }

  Future<void> resume() async {
    final e = current;
    if (e == null) return;
    await _replace(
      PlanScheduler.resume(
        e,
        sessions: _history.sessions,
        today: _clock.today(),
        nowUtc: _clock.nowUtc(),
      ),
    );
  }

  Future<void> leave() async {
    final e = current;
    if (e == null) return;
    await _replace(PlanScheduler.close(e, EnrollmentStatus.left, nowUtc: _clock.nowUtc()));
  }

  /// Marks a finished plan as completed so it moves to the plan history.
  Future<void> finish() async {
    final e = current;
    if (e == null) return;
    await _replace(PlanScheduler.close(e, EnrollmentStatus.completed, nowUtc: _clock.nowUtc()));
  }

  /// Throws [ScheduleException] with a user-facing message when invalid.
  Future<void> reschedule(String assignmentId, LocalDate newDate) async {
    final e = current;
    if (e == null) throw const ScheduleException('No active plan.');
    await _replace(
      PlanScheduler.reschedule(
        e,
        assignmentId,
        newDate,
        sessions: _history.sessions,
        today: _clock.today(),
        nowUtc: _clock.nowUtc(),
      ),
    );
  }

  Future<void> setSkipped(String assignmentId, bool skipped) async {
    final e = current;
    if (e == null) return;
    await _replace(PlanScheduler.setSkipped(e, assignmentId, skipped, nowUtc: _clock.nowUtc()));
  }

  /// Looks up an assignment in any enrollment (used for session links).
  (PlanEnrollment, PlanAssignment)? assignment(String assignmentId) {
    for (final e in _enrollments) {
      final a = e.assignmentById(assignmentId);
      if (a != null) return (e, a);
    }
    return null;
  }

  void reload() {
    _load();
    notifyListeners();
  }

  @override
  void dispose() {
    _history.removeListener(_onHistoryChanged);
    super.dispose();
  }
}
