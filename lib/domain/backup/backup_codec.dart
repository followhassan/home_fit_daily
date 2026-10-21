import 'dart:convert';

import '../../core/utils/json_utils.dart';
import '../../data/catalog/catalog.dart';
import '../../data/local/key_value_store.dart';
import '../../data/local/schema_migrator.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/custom_workout.dart';
import '../../data/models/enums.dart';
import '../../data/models/personal_records.dart';
import '../../data/models/plan_enrollment.dart';
import '../../data/models/user_profile.dart';
import '../../data/models/workout_session.dart';
import '../../data/repositories/repositories.dart';

/// All personal data included in a backup. The bundled catalog, media,
/// permission grants and any in-progress session are never included.
class BackupPayload {
  const BackupPayload({
    required this.profile,
    required this.settings,
    required this.favorites,
    required this.customWorkouts,
    required this.sessions,
    required this.enrollments,
    required this.measurements,
    required this.guideStates,
  });

  factory BackupPayload.fromRepositories(Repositories r) => BackupPayload(
    profile: r.profile.load(),
    settings: r.settings.loadOrDefault(),
    favorites: r.favorites.all(),
    customWorkouts: r.customWorkouts.all(),
    sessions: r.sessions.all(),
    enrollments: r.enrollments.all(),
    measurements: r.measurements.all(),
    guideStates: r.guideState.all().values.toList(),
  );

  final UserProfile? profile;
  final AppSettings settings;
  final List<FavoriteEntry> favorites;
  final List<CustomWorkout> customWorkouts;
  final List<WorkoutSession> sessions;
  final List<PlanEnrollment> enrollments;
  final List<MeasurementEntry> measurements;
  final List<ArticleReadingState> guideStates;

  JsonMap toJson() => {
    'profile': profile?.toJson(),
    'settings': settings.toJson(),
    'favorites': favorites.map((e) => e.toJson()).toList(),
    'customWorkouts': customWorkouts.map((e) => e.toJson()).toList(),
    'sessions': sessions.map((e) => e.toJson()).toList(),
    'enrollments': enrollments.map((e) => e.toJson()).toList(),
    'measurements': measurements.map((e) => e.toJson()).toList(),
    'guideStates': guideStates.map((e) => e.toJson()).toList(),
  };

  /// Storage representation: box name → key → JSON document.
  Map<String, Map<String, String>> toBoxEntries() => {
    StorageBoxes.profile: {if (profile != null) 'current': jsonEncode(profile!.toJson())},
    StorageBoxes.settings: {'current': jsonEncode(settings.toJson())},
    StorageBoxes.favorites: {for (final f in favorites) f.key: jsonEncode(f.toJson())},
    StorageBoxes.customWorkouts: {for (final w in customWorkouts) w.id: jsonEncode(w.toJson())},
    StorageBoxes.sessions: {for (final s in sessions) s.id: jsonEncode(s.toJson())},
    StorageBoxes.enrollments: {for (final e in enrollments) e.id: jsonEncode(e.toJson())},
    StorageBoxes.measurements: {for (final m in measurements) m.id: jsonEncode(m.toJson())},
    StorageBoxes.guideState: {for (final g in guideStates) g.articleId: jsonEncode(g.toJson())},
  };
}

class BackupDocument {
  const BackupDocument({
    required this.backupFormatVersion,
    required this.schemaVersion,
    required this.exportedAtUtc,
    required this.appVersion,
    required this.payload,
  });

  final int backupFormatVersion;
  final int schemaVersion;
  final DateTime exportedAtUtc;
  final String appVersion;
  final BackupPayload payload;
}

/// What an import would contain, shown to the user before confirming.
class BackupSummary {
  const BackupSummary({
    required this.exportedAtUtc,
    required this.sessions,
    required this.completedSessions,
    required this.customWorkouts,
    required this.favorites,
    required this.measurements,
    required this.enrollments,
    required this.bookmarks,
    required this.hasProfile,
  });

  final DateTime exportedAtUtc;
  final int sessions;
  final int completedSessions;
  final int customWorkouts;
  final int favorites;
  final int measurements;
  final int enrollments;
  final int bookmarks;
  final bool hasProfile;
}

class BackupValidation {
  const BackupValidation({this.document, this.errors = const [], this.warnings = const []});

  final BackupDocument? document;
  final List<String> errors;
  final List<String> warnings;

  bool get isValid => document != null && errors.isEmpty;

  BackupSummary? get summary {
    final doc = document;
    if (doc == null) return null;
    final p = doc.payload;
    return BackupSummary(
      exportedAtUtc: doc.exportedAtUtc,
      sessions: p.sessions.length,
      completedSessions: p.sessions.where((s) => s.status == SessionStatus.completed).length,
      customWorkouts: p.customWorkouts.length,
      favorites: p.favorites.length,
      measurements: p.measurements.length,
      enrollments: p.enrollments.length,
      bookmarks: p.guideStates.where((g) => g.bookmarked).length,
      hasProfile: p.profile != null,
    );
  }
}

/// Encodes and strictly validates backup files.
///
/// Backups are plain, unencrypted JSON. A file is rejected as a whole when
/// its structure is invalid; only stale references to catalog content that
/// no longer exists are dropped with a warning.
abstract final class BackupCodec {
  static const format = 'homefit.backup';
  static const backupFormatVersion = 1;
  static const maxBytes = 10 * 1024 * 1024;

  static String encode(
    BackupPayload payload, {
    required DateTime nowUtc,
    required String appVersion,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'format': format,
      'backupFormatVersion': backupFormatVersion,
      'schemaVersion': SchemaMigrator.currentSchemaVersion,
      'appVersion': appVersion,
      'exportedAtUtc': nowUtc.toUtc().toIso8601String(),
      'payload': payload.toJson(),
    });
  }

  static String fileName(DateTime nowLocal) {
    String two(int v) => v.toString().padLeft(2, '0');
    return 'homefit-backup-${nowLocal.year}${two(nowLocal.month)}'
        '${two(nowLocal.day)}-${two(nowLocal.hour)}${two(nowLocal.minute)}.json';
  }

  static BackupValidation decodeBytes(List<int> bytes, Catalog catalog) {
    if (bytes.length > maxBytes) {
      return const BackupValidation(
        errors: ['This file is too large to be a HomeFit backup (over 10 MB).'],
      );
    }
    if (bytes.isEmpty) {
      return const BackupValidation(errors: ['The selected file is empty.']);
    }
    final String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      return const BackupValidation(errors: ['The selected file is not a text backup file.']);
    }
    return decode(text, catalog);
  }

  static BackupValidation decode(String text, Catalog catalog) {
    final Object? root;
    try {
      root = jsonDecode(text);
    } on FormatException {
      return const BackupValidation(
        errors: ['The file is not valid JSON. It may be incomplete or damaged.'],
      );
    }
    if (root is! Map) {
      return const BackupValidation(errors: ['This file is not a HomeFit backup.']);
    }
    final json = asJsonMap(root, 'backup');
    if (json['format'] != format) {
      return const BackupValidation(errors: ['This file is not a HomeFit backup.']);
    }

    final errors = <String>[];
    final warnings = <String>[];
    final formatVersion = json['backupFormatVersion'];
    final schemaVersion = json['schemaVersion'];
    if (formatVersion is! int || schemaVersion is! int) {
      return const BackupValidation(errors: ['The backup is missing its version information.']);
    }
    if (formatVersion > backupFormatVersion ||
        schemaVersion > SchemaMigrator.currentSchemaVersion) {
      return const BackupValidation(
        errors: [
          'This backup was made by a newer version of HomeFit. '
              'Update the app to import it.',
        ],
      );
    }
    if (formatVersion < 1 || schemaVersion < 2) {
      return const BackupValidation(errors: ['This backup version is not supported.']);
    }
    final exportedAt = DateTime.tryParse('${json['exportedAtUtc']}');
    if (exportedAt == null) {
      return const BackupValidation(errors: ['The backup is missing its export date.']);
    }
    if (json['payload'] is! Map) {
      return const BackupValidation(errors: ['The backup does not contain any data section.']);
    }
    final payload = asJsonMap(json['payload'], 'payload');

    List<T> list<T>(String key, String label, T Function(JsonMap) parse) {
      final raw = payload[key];
      if (raw == null) return [];
      if (raw is! List) {
        errors.add('The "$label" section is damaged.');
        return [];
      }
      final result = <T>[];
      for (var i = 0; i < raw.length; i++) {
        try {
          result.add(parse(asJsonMap(raw[i], '$key[$i]')));
        } on FormatException catch (e) {
          errors.add('$label #${i + 1} is invalid (${e.message}).');
        }
      }
      return result;
    }

    UserProfile? profile;
    if (payload['profile'] != null) {
      try {
        profile = UserProfile.fromJson(asJsonMap(payload['profile'], 'profile'));
      } on FormatException catch (e) {
        errors.add('The profile is invalid (${e.message}).');
      }
    }
    var settings = AppSettings.defaults;
    if (payload['settings'] != null) {
      try {
        settings = AppSettings.fromJson(asJsonMap(payload['settings'], 'settings'));
      } on FormatException catch (e) {
        errors.add('The settings are invalid (${e.message}).');
      }
    }

    var favorites = list('favorites', 'Favorite', FavoriteEntry.fromJson);
    final customWorkouts = list('customWorkouts', 'Custom workout', CustomWorkout.fromJson);
    final sessions = list('sessions', 'Session', WorkoutSession.fromJson);
    var enrollments = list('enrollments', 'Plan', PlanEnrollment.fromJson);
    final measurements = list('measurements', 'Measurement', MeasurementEntry.fromJson);
    var guideStates = list('guideStates', 'Reading progress entry', ArticleReadingState.fromJson);

    void unique<T>(List<T> items, String Function(T) key, String label) {
      final seen = <String>{};
      for (final item in items) {
        if (!seen.add(key(item))) {
          errors.add('$label "${key(item)}" appears more than once.');
        }
      }
    }

    unique(customWorkouts, (w) => w.id, 'Custom workout');
    unique(sessions, (s) => s.id, 'Session');
    unique(enrollments, (e) => e.id, 'Plan enrollment');
    unique(measurements, (m) => m.id, 'Measurement');
    unique(favorites, (f) => f.key, 'Favorite');
    unique(guideStates, (g) => g.articleId, 'Reading progress for');

    for (final m in measurements) {
      final (min, max) = m.type.canonicalRange;
      if (m.canonicalValue < min || m.canonicalValue > max) {
        errors.add(
          'A ${m.type.label.toLowerCase()} entry has an '
          'impossible value.',
        );
      }
    }

    if (errors.isNotEmpty) {
      return BackupValidation(errors: errors);
    }

    // Stale catalog references are dropped, not fatal.
    final staleFavorites = favorites.where((f) {
      return f.kind == FavoriteKind.exercise
          ? catalog.exercise(f.itemId) == null
          : catalog.workout(f.itemId) == null;
    }).toList();
    if (staleFavorites.isNotEmpty) {
      warnings.add(
        '${staleFavorites.length} favorite(s) refer to content '
        'that is no longer available and will be skipped.',
      );
      favorites = favorites.where((f) => !staleFavorites.contains(f)).toList();
    }
    final staleArticles = guideStates.where((g) => catalog.article(g.articleId) == null).length;
    if (staleArticles > 0) {
      warnings.add(
        '$staleArticles reading progress entr'
        '${staleArticles == 1 ? 'y refers' : 'ies refer'} to articles '
        'that are no longer available and will be skipped.',
      );
      guideStates = guideStates.where((g) => catalog.article(g.articleId) != null).toList();
    }
    final current = enrollments.where((e) => e.status.isCurrent).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (current.length > 1) {
      warnings.add(
        'The backup had more than one active plan. Only the most '
        'recent one stays active.',
      );
      final keep = current.first.id;
      enrollments = [
        for (final e in enrollments)
          if (e.status.isCurrent && e.id != keep) e.copyWith(status: EnrollmentStatus.left) else e,
      ];
    }
    final assignmentIds = {
      for (final e in enrollments)
        for (final a in e.assignments) a.id,
    };
    final orphanLinks = sessions
        .where((s) => s.planAssignmentId != null && !assignmentIds.contains(s.planAssignmentId))
        .length;
    if (orphanLinks > 0) {
      warnings.add(
        '$orphanLinks session(s) refer to plan days that are not '
        'in this backup; they will stay in history but not count toward '
        'a plan.',
      );
    }
    final missingExercises = customWorkouts
        .where((w) => w.steps.any((s) => catalog.exercise(s.exerciseId) == null))
        .length;
    if (missingExercises > 0) {
      warnings.add(
        '$missingExercises custom workout(s) use exercises that are '
        'no longer available. You can edit them after importing.',
      );
    }

    return BackupValidation(
      document: BackupDocument(
        backupFormatVersion: formatVersion,
        schemaVersion: schemaVersion,
        exportedAtUtc: exportedAt.toUtc(),
        appVersion: '${json['appVersion'] ?? ''}',
        payload: BackupPayload(
          profile: profile,
          settings: settings,
          favorites: favorites,
          customWorkouts: customWorkouts,
          sessions: sessions,
          enrollments: enrollments,
          measurements: measurements,
          guideStates: guideStates,
        ),
      ),
      warnings: warnings,
    );
  }
}
