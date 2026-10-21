import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../core/services/reminder_service.dart';
import '../core/services/screen_awake.dart';
import '../core/services/workout_feedback.dart';
import '../core/utils/app_clock.dart';
import '../data/catalog/catalog.dart';
import '../data/catalog/catalog_loader.dart';
import '../data/catalog/catalog_validator.dart';
import '../data/local/hive_key_value_store.dart';
import '../data/local/key_value_store.dart';
import '../data/local/legacy/hive_legacy_source.dart';
import '../data/local/schema_migrator.dart';
import '../data/models/exercise.dart';
import '../data/repositories/repositories.dart';
import '../domain/backup/restore_service.dart';
import '../domain/workout_engine.dart';
import '../features/exercise_media/figure_library.dart';

/// Everything the app needs, created once at startup.
class AppServices {
  AppServices({
    required this.store,
    required this.repositories,
    required this.catalog,
    required this.restore,
    required this.reminders,
    required this.feedback,
    required this.screenAwake,
    required this.clock,
    required this.appVersion,
    this.rolledBackInterruptedRestore = false,
    this.migration,
    MonotonicClock Function()? monotonicClock,
  }) : monotonicClock = monotonicClock ?? StopwatchClock.new;

  final KeyValueStore store;
  final Repositories repositories;
  final Catalog catalog;
  final RestoreService restore;
  final ReminderService reminders;
  final WorkoutFeedback feedback;
  final ScreenAwake screenAwake;
  final AppClock clock;
  final String appVersion;
  final bool rolledBackInterruptedRestore;
  final MigrationReport? migration;

  /// Creates the monotonic clock used to time workouts (replaceable in tests).
  final MonotonicClock Function() monotonicClock;
}

/// A startup failure the user can act on.
class StartupFailure implements Exception {
  const StartupFailure({required this.title, required this.message, this.boxToReset});

  final String title;
  final String message;

  /// When set, the user may delete this one damaged storage box.
  final String? boxToReset;
}

const appVersion = '1.0.0';

/// Opens storage, recovers interrupted writes, migrates data and loads the
/// catalog. Makes no network requests.
Future<AppServices> bootstrapServices() async {
  await Hive.initFlutter();

  final HiveKeyValueStore store;
  try {
    store = await HiveKeyValueStore.open(StorageBoxes.all);
  } on StorageOpenException catch (e) {
    throw StartupFailure(
      title: 'Your saved data could not be opened',
      message:
          'The file "${e.boxName}" appears to be damaged. You can try again, '
          'or reset only that part of your data. Other data is kept.',
      boxToReset: e.boxName,
    );
  }

  final restore = RestoreService(store);
  final rolledBack = await restore.recoverInterruptedRestore();

  final Catalog catalog;
  try {
    catalog = await const CatalogLoader().load();
  } on CatalogLoadException catch (e) {
    throw StartupFailure(
      title: 'App content is missing',
      message:
          'The built-in workouts could not be loaded (${e.message}). '
          'Reinstalling the app should fix this; your data is not affected.',
    );
  }
  if (kDebugMode) _debugValidate(catalog);

  final repositories = Repositories(store);
  final MigrationReport migration;
  try {
    migration = await SchemaMigrator(
      store: store,
      repositories: repositories,
      legacySource: HiveLegacySource(),
      exerciseExists: (id) => catalog.exercise(id) != null,
    ).run();
  } on StorageVersionException {
    throw const StartupFailure(
      title: 'Please update HomeFit',
      message:
          'Your data was saved by a newer version of the app. Update the app '
          'to continue; your data has not been changed.',
    );
  }
  await store.write(StorageBoxes.meta, MetaKeys.contentVersion, '${catalog.contentVersion}');

  final reminders = LocalReminderService();
  try {
    await reminders.init();
  } catch (e) {
    debugPrint('Reminders unavailable: $e');
  }
  final feedback = AudioHapticFeedback();
  // Sounds load in the background; the app never waits for them.
  feedback.init().ignore();

  return AppServices(
    store: store,
    repositories: repositories,
    catalog: catalog,
    restore: restore,
    reminders: reminders,
    feedback: feedback,
    screenAwake: WakelockScreenAwake(),
    clock: const AppClock(),
    appVersion: appVersion,
    rolledBackInterruptedRestore: rolledBack,
    migration: migration,
  );
}

void _debugValidate(Catalog catalog) {
  final issues = CatalogValidator(
    catalog,
    assetExists: (path) => path.startsWith(MediaAttribution.figureScheme)
        ? FigureLibrary.has(path.substring(MediaAttribution.figureScheme.length))
        : true,
  ).validate();
  for (final issue in issues.where((i) => i.isError)) {
    debugPrint('Catalog: $issue');
  }
}
