import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/utils/app_clock.dart';
import '../data/catalog/catalog.dart';
import '../data/local/key_value_store.dart';
import '../data/repositories/repositories.dart';
import '../domain/backup/backup_codec.dart';
import '../domain/backup/restore_service.dart';
import 'custom_workout_controller.dart';
import 'favorites_controller.dart';
import 'guide_controller.dart';
import 'history_controller.dart';
import 'measurement_controller.dart';
import 'plan_controller.dart';
import 'profile_controller.dart';
import 'recovery_controller.dart';
import 'settings_controller.dart';

/// Backup, restore, reset and erase operations. After any of them every
/// controller reloads from storage, so derived values (statistics, plan
/// progress) are rebuilt from the new data rather than cached.
class DataController extends ChangeNotifier {
  DataController({
    required this.repositories,
    required this.restore,
    required this.catalog,
    required this.profile,
    required this.settings,
    required this.favorites,
    required this.history,
    required this.plans,
    required this.customWorkouts,
    required this.measurements,
    required this.guide,
    required this.recovery,
    required this.appVersion,
    this._clock = const AppClock(),
  });

  final Repositories repositories;
  final RestoreService restore;
  final Catalog catalog;
  final ProfileController profile;
  final SettingsController settings;
  final FavoritesController favorites;
  final HistoryController history;
  final PlanController plans;
  final CustomWorkoutController customWorkouts;
  final MeasurementController measurements;
  final GuideController guide;
  final RecoveryController recovery;
  final String appVersion;
  final AppClock _clock;

  bool _busy = false;
  bool get isBusy => _busy;

  int get unreadableRecordCount => repositories.unreadableRecordCount;
  DateTime? get undoImportDate => restore.undoSnapshotDate;

  Future<T> _run<T>(Future<T> Function() body) async {
    if (_busy) throw StateError('Another data operation is in progress');
    _busy = true;
    notifyListeners();
    try {
      return await body();
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// The backup file contents (UTF-8 JSON). The in-progress session, the
  /// bundled catalog and permission grants are not included.
  Uint8List exportBackup() {
    final json = BackupCodec.encode(
      BackupPayload.fromRepositories(repositories),
      nowUtc: _clock.nowUtc(),
      appVersion: appVersion,
    );
    return Uint8List.fromList(utf8.encode(json));
  }

  String exportFileName() => BackupCodec.fileName(_clock.now());

  BackupValidation validateBackup(List<int> bytes) => BackupCodec.decodeBytes(bytes, catalog);

  /// Replaces all personal data with a validated backup.
  Future<void> importBackup(BackupDocument document) => _run(() async {
    await repositories.activeSession.clear();
    await restore.applyBackup(document.payload, nowUtc: _clock.nowUtc());
    await _reloadAll();
  });

  Future<void> undoLastImport() => _run(() async {
    await restore.undoLastImport(nowUtc: _clock.nowUtc());
    await _reloadAll();
  });

  /// Deletes workout history, plan enrollments and any interrupted session.
  /// Profile, settings, favorites, custom workouts, measurements and guide
  /// progress are kept.
  Future<void> resetProgress() => _run(() async {
    await repositories.activeSession.clear();
    await restore.replaceBoxes({
      StorageBoxes.sessions: const {},
      StorageBoxes.enrollments: const {},
    }, nowUtc: _clock.nowUtc());
    await _reloadAll();
  });

  /// Erases every piece of personal data and cancels reminders. The app
  /// returns to onboarding.
  Future<void> deleteAllData() => _run(() async {
    await repositories.activeSession.clear();
    await settings.disableReminders();
    await restore.eraseAll(nowUtc: _clock.nowUtc());
    await _reloadAll();
  });

  Future<int> removeUnreadableRecords() => _run(repositories.removeUnreadableRecords);

  Future<void> _reloadAll() async {
    profile.reload();
    settings.reload();
    favorites.reload();
    history.reload();
    history.setWeeklyGoal(profile.profile.weeklyGoal);
    plans.reload();
    customWorkouts.reload();
    measurements.reload();
    guide.reload();
    recovery.refresh();
    await settings.reconcileReminders();
  }
}
