import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/user_profile.dart';
import 'package:home_fit_daily/domain/recommendation_service.dart';

import '../helpers/catalog_fixture.dart';
import '../helpers/sessions.dart';

void main() {
  final catalog = loadBundledCatalog();
  final now = DateTime.utc(2026, 10, 21);
  UserProfile profile() => UserProfile.initial(id: 'p', now: now);

  test('never suggests workouts needing equipment the user lacks', () {
    final recs = RecommendationService.recommend(catalog: catalog, profile: profile(), limit: 30);
    expect(recs, isNotEmpty);
    for (final r in recs) {
      expect(r.info.equipment, isEmpty, reason: r.workout.id);
    }
  });

  test('includes equipment workouts when the equipment is available', () {
    final recs = RecommendationService.recommend(
      catalog: catalog,
      profile: profile().copyWith(
        experienceLevel: Difficulty.intermediate,
        availableEquipment: {Equipment.dumbbells},
      ),
      limit: 30,
    );
    expect(recs.any((r) => r.info.equipment.contains(Equipment.dumbbells)), isTrue);
  });

  test('respects a low-impact preference', () {
    final recs = RecommendationService.recommend(
      catalog: catalog,
      profile: profile().copyWith(lowImpactPreference: true),
      limit: 30,
    );
    for (final r in recs) {
      expect(r.info.isLowImpact, isTrue, reason: r.workout.id);
    }
  });

  test('beginners are not offered harder workouts', () {
    final recs = RecommendationService.recommend(catalog: catalog, profile: profile(), limit: 30);
    for (final r in recs) {
      expect(r.workout.difficulty, Difficulty.beginner, reason: r.workout.id);
    }
  });

  test('ranks workouts close to the preferred duration first', () {
    final recs = RecommendationService.recommend(
      catalog: catalog,
      profile: profile().copyWith(preferredDurationMinutes: 5),
      limit: 3,
    );
    expect(recs.first.info.estimate.minutes, lessThanOrEqualTo(8));
  });

  test('results are deterministic and explained', () {
    final a = RecommendationService.recommend(catalog: catalog, profile: profile());
    final b = RecommendationService.recommend(catalog: catalog, profile: profile());
    expect(a.map((r) => r.workout.id), b.map((r) => r.workout.id));
    expect(a.first.explanation, contains('Beginner'));
    expect(a.first.explanation, contains('min'));
  });

  test('recently completed workouts are ranked lower for variety', () {
    final first = RecommendationService.recommend(
      catalog: catalog,
      profile: profile(),
      limit: 1,
    ).first;
    final after = RecommendationService.recommend(
      catalog: catalog,
      profile: profile(),
      history: [sessionOn(LocalDate.parse('2026-10-21'), workoutId: first.workout.id)],
      today: LocalDate.parse('2026-10-21'),
      limit: 1,
    ).first;
    expect(after.workout.id, isNot(first.workout.id));
  });

  test('falls back gracefully when filters exclude everything', () {
    final recs = RecommendationService.recommend(
      catalog: catalog,
      profile: profile(),
      limit: 3,
      where: (w) => w.category == WorkoutCategory.stretching,
    );
    expect(recs, isNotEmpty);
  });
}
