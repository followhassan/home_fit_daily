import '../local/document_collection.dart';
import '../local/key_value_store.dart';
import '../models/active_session.dart';
import '../models/app_settings.dart';
import '../models/custom_workout.dart';
import '../models/personal_records.dart';
import '../models/plan_enrollment.dart';
import '../models/user_profile.dart';
import '../models/workout_session.dart';

/// Single-document repository (profile, settings).
class _SingletonRepository<T> {
  _SingletonRepository(
    KeyValueStore store,
    String box, {
    required T Function(Map<String, dynamic>) fromJson,
    required Map<String, dynamic> Function(T) toJson,
  }) : docs = DocumentCollection<T>(
         store: store,
         box: box,
         fromJson: fromJson,
         toJson: toJson,
         keyOf: (_) => _key,
       );

  static const _key = 'current';
  final DocumentCollection<T> docs;

  T? load() => docs.read(_key);
  Future<void> save(T value) => docs.put(value);
}

class ProfileRepository extends _SingletonRepository<UserProfile> {
  ProfileRepository(KeyValueStore store)
    : super(store, StorageBoxes.profile, fromJson: UserProfile.fromJson, toJson: (p) => p.toJson());
}

class SettingsRepository extends _SingletonRepository<AppSettings> {
  SettingsRepository(KeyValueStore store)
    : super(
        store,
        StorageBoxes.settings,
        fromJson: AppSettings.fromJson,
        toJson: (s) => s.toJson(),
      );

  AppSettings loadOrDefault() => load() ?? AppSettings.defaults;
}

class FavoritesRepository {
  FavoritesRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.favorites,
        fromJson: FavoriteEntry.fromJson,
        toJson: (f) => f.toJson(),
        keyOf: (f) => f.key,
      );

  final DocumentCollection<FavoriteEntry> docs;

  List<FavoriteEntry> all() => docs.readAll();
  Future<void> add(FavoriteEntry entry) => docs.put(entry);
  Future<void> remove(FavoriteKind kind, String itemId) =>
      docs.delete(FavoriteEntry.keyFor(kind, itemId));
}

class SessionRepository {
  SessionRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.sessions,
        fromJson: WorkoutSession.fromJson,
        toJson: (s) => s.toJson(),
        keyOf: (s) => s.id,
      );

  final DocumentCollection<WorkoutSession> docs;

  /// Newest first.
  List<WorkoutSession> all() =>
      docs.readAll()..sort((a, b) => b.completedAtUtc.compareTo(a.completedAtUtc));

  WorkoutSession? get(String id) => docs.read(id);
  bool contains(String id) => docs.contains(id);

  /// Idempotent: the session id is the storage key, so saving the same
  /// session twice never creates a duplicate history entry.
  Future<void> save(WorkoutSession session) => docs.put(session);
  Future<void> delete(String id) => docs.delete(id);
}

class ActiveSessionRepository {
  ActiveSessionRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.activeSession,
        fromJson: ActiveSessionCheckpoint.fromJson,
        toJson: (c) => c.toJson(),
        keyOf: (_) => _key,
      );

  static const _key = 'current';
  final DocumentCollection<ActiveSessionCheckpoint> docs;

  ActiveSessionCheckpoint? load() => docs.read(_key);
  bool get hasUnreadableCheckpoint => docs.unreadableKeys.contains(_key);
  Future<void> save(ActiveSessionCheckpoint checkpoint) => docs.put(checkpoint);
  Future<void> clear() => docs.delete(_key);
}

class EnrollmentRepository {
  EnrollmentRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.enrollments,
        fromJson: PlanEnrollment.fromJson,
        toJson: (e) => e.toJson(),
        keyOf: (e) => e.id,
      );

  final DocumentCollection<PlanEnrollment> docs;

  /// Newest first.
  List<PlanEnrollment> all() => docs.readAll()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> save(PlanEnrollment enrollment) => docs.put(enrollment);
  Future<void> saveAll(Iterable<PlanEnrollment> enrollments) => docs.putAll(enrollments);
  Future<void> delete(String id) => docs.delete(id);
}

class CustomWorkoutRepository {
  CustomWorkoutRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.customWorkouts,
        fromJson: CustomWorkout.fromJson,
        toJson: (w) => w.toJson(),
        keyOf: (w) => w.id,
      );

  final DocumentCollection<CustomWorkout> docs;

  /// Most recently edited first.
  List<CustomWorkout> all() => docs.readAll()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Future<void> save(CustomWorkout workout) => docs.put(workout);
  Future<void> delete(String id) => docs.delete(id);
}

class MeasurementRepository {
  MeasurementRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.measurements,
        fromJson: MeasurementEntry.fromJson,
        toJson: (m) => m.toJson(),
        keyOf: (m) => m.id,
      );

  final DocumentCollection<MeasurementEntry> docs;

  /// Oldest first.
  List<MeasurementEntry> all() => docs.readAll()
    ..sort((a, b) {
      final byDate = a.localDate.compareTo(b.localDate);
      return byDate != 0 ? byDate : a.timestampUtc.compareTo(b.timestampUtc);
    });

  Future<void> save(MeasurementEntry entry) => docs.put(entry);
  Future<void> delete(String id) => docs.delete(id);
}

class GuideStateRepository {
  GuideStateRepository(KeyValueStore store)
    : docs = DocumentCollection(
        store: store,
        box: StorageBoxes.guideState,
        fromJson: ArticleReadingState.fromJson,
        toJson: (s) => s.toJson(),
        keyOf: (s) => s.articleId,
      );

  final DocumentCollection<ArticleReadingState> docs;

  Map<String, ArticleReadingState> all() => {for (final s in docs.readAll()) s.articleId: s};

  Future<void> save(ArticleReadingState state) => docs.put(state);
}

/// All repositories over one store.
class Repositories {
  Repositories(this.store)
    : profile = ProfileRepository(store),
      settings = SettingsRepository(store),
      favorites = FavoritesRepository(store),
      sessions = SessionRepository(store),
      activeSession = ActiveSessionRepository(store),
      enrollments = EnrollmentRepository(store),
      customWorkouts = CustomWorkoutRepository(store),
      measurements = MeasurementRepository(store),
      guideState = GuideStateRepository(store);

  final KeyValueStore store;
  final ProfileRepository profile;
  final SettingsRepository settings;
  final FavoritesRepository favorites;
  final SessionRepository sessions;
  final ActiveSessionRepository activeSession;
  final EnrollmentRepository enrollments;
  final CustomWorkoutRepository customWorkouts;
  final MeasurementRepository measurements;
  final GuideStateRepository guideState;

  List<DocumentCollection<Object?>> get _collections => [
    profile.docs,
    settings.docs,
    favorites.docs,
    sessions.docs,
    enrollments.docs,
    customWorkouts.docs,
    measurements.docs,
    guideState.docs,
  ];

  /// Number of personal records that could not be decoded.
  int get unreadableRecordCount => _collections.fold(0, (sum, c) => sum + c.unreadableKeys.length);

  Future<int> removeUnreadableRecords() async {
    var removed = 0;
    for (final c in _collections) {
      removed += await c.removeUnreadable();
    }
    return removed;
  }
}
