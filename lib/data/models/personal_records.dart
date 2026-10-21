import '../../core/utils/json_utils.dart';
import '../../core/utils/local_date.dart';
import 'enums.dart';

/// A body measurement stored in canonical metric units (kg or cm).
class MeasurementEntry {
  const MeasurementEntry({
    required this.id,
    required this.type,
    required this.canonicalValue,
    required this.timestampUtc,
    required this.localDate,
    this.note,
  });

  factory MeasurementEntry.fromJson(JsonMap json) {
    final timestamp = readDateTime(json, 'timestampUtc').toUtc();
    return MeasurementEntry(
      id: readString(json, 'id'),
      type: parseEnum(MeasurementType.values, json['type'], 'type'),
      canonicalValue: readDouble(json, 'value'),
      timestampUtc: timestamp,
      localDate:
          LocalDate.tryParse(json['localDate']) ?? LocalDate.fromDateTime(timestamp.toLocal()),
      note: readOptionalString(json, 'note'),
    );
  }

  final String id;
  final MeasurementType type;
  final double canonicalValue;
  final DateTime timestampUtc;
  final LocalDate localDate;
  final String? note;

  MeasurementEntry copyWith({
    double? canonicalValue,
    LocalDate? localDate,
    String? note,
    bool clearNote = false,
  }) => MeasurementEntry(
    id: id,
    type: type,
    canonicalValue: canonicalValue ?? this.canonicalValue,
    timestampUtc: timestampUtc,
    localDate: localDate ?? this.localDate,
    note: clearNote ? null : (note ?? this.note),
  );

  JsonMap toJson() => {
    'id': id,
    'type': type.json,
    'value': canonicalValue,
    'timestampUtc': timestampUtc.toUtc().toIso8601String(),
    'localDate': localDate.toIso(),
    if (note != null) 'note': note,
  };
}

/// Bookmark and reading progress for one guide article.
class ArticleReadingState {
  const ArticleReadingState({
    required this.articleId,
    this.bookmarked = false,
    this.progress = 0,
    this.lastReadAtUtc,
    this.bookmarkedAtUtc,
  });

  factory ArticleReadingState.fromJson(JsonMap json) => ArticleReadingState(
    articleId: readString(json, 'articleId'),
    bookmarked: readBool(json, 'bookmarked'),
    progress: (readOptionalDouble(json, 'progress') ?? 0).clamp(0.0, 1.0),
    lastReadAtUtc: readOptionalDateTime(json, 'lastReadAtUtc')?.toUtc(),
    bookmarkedAtUtc: readOptionalDateTime(json, 'bookmarkedAtUtc')?.toUtc(),
  );

  final String articleId;
  final bool bookmarked;

  /// Furthest scroll position reached, 0–1.
  final double progress;
  final DateTime? lastReadAtUtc;
  final DateTime? bookmarkedAtUtc;

  bool get isFinished => progress >= 0.95;
  bool get isStarted => progress > 0.02;

  ArticleReadingState copyWith({
    bool? bookmarked,
    double? progress,
    DateTime? lastReadAtUtc,
    DateTime? bookmarkedAtUtc,
  }) => ArticleReadingState(
    articleId: articleId,
    bookmarked: bookmarked ?? this.bookmarked,
    progress: progress ?? this.progress,
    lastReadAtUtc: lastReadAtUtc ?? this.lastReadAtUtc,
    bookmarkedAtUtc: bookmarkedAtUtc ?? this.bookmarkedAtUtc,
  );

  JsonMap toJson() => {
    'articleId': articleId,
    'bookmarked': bookmarked,
    'progress': progress,
    if (lastReadAtUtc != null) 'lastReadAtUtc': lastReadAtUtc!.toUtc().toIso8601String(),
    if (bookmarkedAtUtc != null) 'bookmarkedAtUtc': bookmarkedAtUtc!.toUtc().toIso8601String(),
  };
}

enum FavoriteKind implements JsonEnum {
  exercise('exercise', 'Exercise'),
  workout('workout', 'Workout');

  const FavoriteKind(this.json, this.label);

  @override
  final String json;
  @override
  final String label;
}

/// A favorited exercise or ready-made workout.
class FavoriteEntry {
  const FavoriteEntry({required this.kind, required this.itemId, required this.addedAtUtc});

  factory FavoriteEntry.fromJson(JsonMap json) => FavoriteEntry(
    kind: parseEnum(FavoriteKind.values, json['kind'], 'kind'),
    itemId: readString(json, 'itemId'),
    addedAtUtc: readDateTime(json, 'addedAtUtc').toUtc(),
  );

  final FavoriteKind kind;
  final String itemId;
  final DateTime addedAtUtc;

  /// Storage key; one record per item makes duplicates impossible.
  String get key => keyFor(kind, itemId);

  static String keyFor(FavoriteKind kind, String itemId) => '${kind.json}:$itemId';

  JsonMap toJson() => {
    'kind': kind.json,
    'itemId': itemId,
    'addedAtUtc': addedAtUtc.toUtc().toIso8601String(),
  };
}
