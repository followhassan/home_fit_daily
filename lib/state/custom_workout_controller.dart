import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../core/utils/ids.dart';
import '../data/catalog/catalog.dart';
import '../data/models/custom_workout.dart';
import '../data/models/workout.dart';
import '../data/repositories/repositories.dart';
import '../domain/custom_workout_validator.dart';

/// User-created workouts. Editing or deleting one never touches history,
/// because sessions keep their own snapshot of the workout.
class CustomWorkoutController extends ChangeNotifier {
  CustomWorkoutController(this._repo, this._catalog, {this._clock = const AppClock()}) {
    _workouts = _repo.all();
  }

  final CustomWorkoutRepository _repo;
  final Catalog _catalog;
  final AppClock _clock;
  late List<CustomWorkout> _workouts;

  /// Most recently edited first.
  List<CustomWorkout> get workouts => List.unmodifiable(_workouts);

  CustomWorkout? byId(String id) {
    for (final w in _workouts) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// A playable workout for a custom workout ID.
  Workout? playable(String id) {
    final custom = byId(id);
    if (custom == null) return null;
    return custom.toWorkout(difficulty: _catalog.difficultyOf(custom.steps));
  }

  /// Any workout by ID: catalog first, then custom.
  Workout? resolve(String id) => _catalog.workout(id) ?? playable(id);

  /// A new, empty draft (not saved).
  CustomWorkout newDraft() {
    final now = _clock.nowUtc();
    return CustomWorkout(
      id: Ids.customWorkout(),
      title: '',
      description: '',
      steps: const [],
      rounds: 1,
      roundRestSeconds: 30,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Validates and saves. Returns the validation; nothing is saved when it
  /// is invalid.
  Future<CustomWorkoutValidation> save(CustomWorkout draft) async {
    final cleaned = draft.copyWith(
      title: draft.title.trim(),
      description: draft.description.trim(),
    );
    final validation = CustomWorkoutValidator.validate(cleaned, _catalog);
    if (!validation.isValid) return validation;
    final existing = byId(cleaned.id);
    final saved = cleaned.copyWith(
      createdAt: existing?.createdAt ?? cleaned.createdAt,
      updatedAt: _clock.nowUtc(),
    );
    await _repo.save(saved);
    _workouts = [saved, ..._workouts.where((w) => w.id != saved.id)];
    notifyListeners();
    return validation;
  }

  /// Copies a custom workout under a new ID.
  Future<CustomWorkout> duplicate(String id) async {
    final source = byId(id);
    if (source == null) throw StateError('Workout not found');
    final now = _clock.nowUtc();
    final copy = source.copyWith(
      id: Ids.customWorkout(),
      title: _copyTitle(source.title),
      steps: [for (final s in source.steps) s.copyWith(id: Ids.customStep())],
      createdAt: now,
      updatedAt: now,
    );
    await _repo.save(copy);
    _workouts = [copy, ..._workouts];
    notifyListeners();
    return copy;
  }

  /// Creates an editable draft from any workout (e.g. a ready-made one).
  /// The draft is not saved until the user saves it in the builder.
  CustomWorkout draftFrom(Workout workout) {
    final now = _clock.nowUtc();
    return CustomWorkout(
      id: Ids.customWorkout(),
      title: _copyTitle(workout.title),
      description: workout.description,
      steps: [for (final s in workout.steps) s.copyWith(id: Ids.customStep())],
      rounds: workout.rounds,
      roundRestSeconds: workout.roundRestSeconds,
      createdAt: now,
      updatedAt: now,
    );
  }

  String _copyTitle(String title) {
    final base = title.length > 50 ? title.substring(0, 50) : title;
    return '$base (copy)';
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _workouts = _workouts.where((w) => w.id != id).toList();
    notifyListeners();
  }

  void reload() {
    _workouts = _repo.all();
    notifyListeners();
  }
}
