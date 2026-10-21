import '../../core/utils/json_utils.dart';
import 'enums.dart';

class ArticleSection {
  const ArticleSection({required this.heading, required this.paragraphs, required this.bullets});

  factory ArticleSection.fromJson(JsonMap json) => ArticleSection(
    heading: readString(json, 'heading'),
    paragraphs: readStringList(json, 'paragraphs'),
    bullets: readStringList(json, 'bullets'),
  );

  final String heading;
  final List<String> paragraphs;
  final List<String> bullets;

  int get wordCount =>
      [heading, ...paragraphs, ...bullets].fold(0, (sum, text) => sum + _words(text));
}

class ArticleReference {
  const ArticleReference({required this.title, required this.publisher, this.year, this.url});

  factory ArticleReference.fromJson(JsonMap json) => ArticleReference(
    title: readString(json, 'title'),
    publisher: readString(json, 'publisher'),
    year: readOptionalInt(json, 'year'),
    url: readOptionalString(json, 'url'),
  );

  final String title;
  final String publisher;
  final int? year;
  final String? url;

  String get citation => [publisher, title, if (year != null) '$year'].join('. ');
}

/// An offline fitness guide article.
class GuideArticle {
  GuideArticle({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.sections,
    required this.tags,
    required this.references,
    required this.reviewStatus,
    required this.relatedArticleIds,
    required this.relatedExerciseIds,
    required this.relatedWorkoutIds,
  });

  factory GuideArticle.fromJson(JsonMap json) {
    final id = readString(json, 'id');
    try {
      return GuideArticle(
        id: id,
        title: readString(json, 'title'),
        category: parseEnum(ArticleCategory.values, json['category'], 'category'),
        summary: readString(json, 'summary'),
        sections: readObjectList(json, 'sections', ArticleSection.fromJson),
        tags: readStringList(json, 'tags'),
        references: readObjectList(json, 'references', ArticleReference.fromJson),
        reviewStatus: parseEnum(ReviewStatus.values, json['reviewStatus'], 'reviewStatus'),
        relatedArticleIds: readStringList(json, 'relatedArticles'),
        relatedExerciseIds: readStringList(json, 'relatedExercises'),
        relatedWorkoutIds: readStringList(json, 'relatedWorkouts'),
      );
    } on FormatException catch (e) {
      throw FormatException('article "$id": ${e.message}');
    }
  }

  final String id;
  final String title;
  final ArticleCategory category;
  final String summary;
  final List<ArticleSection> sections;
  final List<String> tags;
  final List<ArticleReference> references;
  final ReviewStatus reviewStatus;
  final List<String> relatedArticleIds;
  final List<String> relatedExerciseIds;
  final List<String> relatedWorkoutIds;

  late final int wordCount = _words(summary) + sections.fold(0, (sum, s) => sum + s.wordCount);

  /// Estimated at 200 words per minute, rounded up.
  int get readingTimeMinutes => (wordCount / 200).ceil().clamp(1, 60);

  late final String searchText = [
    title,
    summary,
    category.label,
    ...tags,
    ...sections.map((s) => s.heading),
  ].join(' ').toLowerCase();
}

/// A short tip shown on the home screen.
class FitnessTip {
  const FitnessTip({required this.id, required this.text, this.articleId});

  factory FitnessTip.fromJson(JsonMap json) => FitnessTip(
    id: readString(json, 'id'),
    text: readString(json, 'text'),
    articleId: readOptionalString(json, 'articleId'),
  );

  final String id;
  final String text;
  final String? articleId;
}

int _words(String text) => text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
