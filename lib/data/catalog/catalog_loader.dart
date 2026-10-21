import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../core/utils/json_utils.dart';
import '../models/exercise.dart';
import '../models/guide_article.dart';
import '../models/training_plan.dart';
import '../models/workout.dart';
import 'catalog.dart';

/// Asset locations of the bundled content catalog. Exercises and articles
/// are split into one file per category to keep each file reviewable.
abstract final class CatalogAssets {
  static const exerciseFiles = [
    'assets/data/exercises/warm_up.json',
    'assets/data/exercises/full_body.json',
    'assets/data/exercises/upper_body.json',
    'assets/data/exercises/lower_body.json',
    'assets/data/exercises/core.json',
    'assets/data/exercises/cardio.json',
    'assets/data/exercises/mobility.json',
    'assets/data/exercises/stretching.json',
  ];
  static const workouts = 'assets/data/workouts.json';
  static const plans = 'assets/data/plans.json';
  static const articleFiles = [
    'assets/data/articles/getting_started.json',
    'assets/data/articles/technique.json',
    'assets/data/articles/training.json',
    'assets/data/articles/recovery.json',
    'assets/data/articles/nutrition.json',
    'assets/data/articles/mindset.json',
    'assets/data/articles/safety.json',
  ];
  static const tips = 'assets/data/tips.json';

  static const all = [...exerciseFiles, workouts, plans, ...articleFiles, tips];
}

class CatalogLoadException implements Exception {
  const CatalogLoadException(this.message);
  final String message;

  @override
  String toString() => 'CatalogLoadException: $message';
}

/// Loads the bundled JSON catalog. Parsing runs on a background isolate so
/// the first frame is never blocked by JSON decoding.
class CatalogLoader {
  const CatalogLoader({this.bundle});

  /// Defaults to [rootBundle].
  final AssetBundle? bundle;

  Future<Catalog> load() async {
    final assets = bundle ?? rootBundle;
    final sources = <String>[];
    for (final path in CatalogAssets.all) {
      try {
        sources.add(await assets.loadString(path, cache: false));
      } catch (e) {
        throw CatalogLoadException('Missing content file $path');
      }
    }
    try {
      return await Isolate.run(() => parseCatalog(sources));
    } on FormatException catch (e) {
      throw CatalogLoadException(e.message);
    }
  }
}

/// Parses the catalog files, given in [CatalogAssets.all] order.
///
/// Throws [FormatException] for malformed content or mismatched content
/// versions.
Catalog parseCatalog(List<String> sources) {
  if (sources.length != CatalogAssets.all.length) {
    throw const FormatException('Unexpected number of catalog files');
  }
  final files = <String, JsonMap>{};
  for (var i = 0; i < sources.length; i++) {
    final path = CatalogAssets.all[i];
    try {
      files[path] = asJsonMap(jsonDecode(sources[i]), path);
    } on FormatException catch (e) {
      throw FormatException('$path: ${e.message}');
    }
  }
  final versions = files.values.map((f) => readInt(f, 'contentVersion')).toSet();
  if (versions.length != 1) {
    throw FormatException('Catalog files disagree on contentVersion: $versions');
  }

  List<T> items<T>(String path, T Function(JsonMap) parse) {
    try {
      return readObjectList(files[path]!, 'items', parse);
    } on FormatException catch (e) {
      throw FormatException('$path: ${e.message}');
    }
  }

  return Catalog(
    contentVersion: versions.single,
    exercises: [for (final path in CatalogAssets.exerciseFiles) ...items(path, Exercise.fromJson)],
    workouts: items(CatalogAssets.workouts, Workout.fromJson),
    plans: items(CatalogAssets.plans, TrainingPlan.fromJson),
    articles: [
      for (final path in CatalogAssets.articleFiles) ...items(path, GuideArticle.fromJson),
    ],
    tips: items(CatalogAssets.tips, FitnessTip.fromJson),
  );
}
