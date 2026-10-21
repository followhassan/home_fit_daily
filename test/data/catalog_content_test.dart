import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/data/catalog/catalog_validator.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/exercise.dart';
import 'package:home_fit_daily/features/exercise_media/figure_library.dart';

import '../helpers/catalog_fixture.dart';

bool _assetExists(String path) {
  if (path.startsWith(MediaAttribution.figureScheme)) {
    return FigureLibrary.has(path.substring(MediaAttribution.figureScheme.length));
  }
  return File(path).existsSync();
}

void main() {
  final catalog = loadBundledCatalog();

  test('bundled catalog passes validation without errors', () {
    final issues = CatalogValidator(catalog, assetExists: _assetExists).validate();
    final errors = issues.where((i) => i.isError).toList();
    if (errors.isNotEmpty) {
      // Print everything so content authors can fix all problems at once.
      fail(errors.join('\n'));
    }
  });

  test('required minimum content counts are met', () {
    expect(catalog.exercises.length, greaterThanOrEqualTo(60));
    expect(catalog.workouts.length, greaterThanOrEqualTo(24));
    expect(catalog.plans.where((p) => p.days.length == 28).length, greaterThanOrEqualTo(4));
    expect(catalog.articles.length, greaterThanOrEqualTo(20));
  });

  test('catalog covers every exercise category and optional equipment', () {
    for (final category in ExerciseCategory.values) {
      expect(
        catalog.exercises.where((e) => e.category == category),
        isNotEmpty,
        reason: 'no exercises in ${category.json}',
      );
    }
    for (final equipment in [Equipment.chair, Equipment.resistanceBand, Equipment.dumbbells]) {
      expect(catalog.exercises.where((e) => e.equipment.contains(equipment)), isNotEmpty);
    }
    final noEquipment = catalog.exercises.where((e) => e.equipment.isEmpty);
    expect(noEquipment.length, greaterThan(catalog.exercises.length ~/ 2));
  });

  test('workouts cover short and longer sessions', () {
    final minutes = catalog.workouts.map((w) => catalog.infoFor(w).estimate.minutes).toList();
    expect(minutes.where((m) => m <= 10), isNotEmpty);
    expect(minutes.where((m) => m >= 25), isNotEmpty);
  });

  test('every article is honestly marked as not professionally reviewed', () {
    for (final article in catalog.articles) {
      expect(article.reviewStatus, ReviewStatus.unreviewed);
    }
  });

  test('every exercise has a demonstration in the figure library', () {
    for (final e in catalog.exercises) {
      expect(e.mediaPath, isNotNull, reason: e.id);
      expect(_assetExists(e.mediaPath!), isTrue, reason: e.id);
    }
  });
}
