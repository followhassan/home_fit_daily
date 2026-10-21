import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/core/utils/units.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/models/custom_workout.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/workout.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';
import 'package:home_fit_daily/domain/workout_engine.dart';
import 'package:home_fit_daily/domain/workout_timeline.dart';
import 'package:home_fit_daily/data/models/active_session.dart';
import 'package:home_fit_daily/data/models/workout_session.dart';
import 'package:home_fit_daily/features/exercise_library/exercise_detail_screen.dart';
import 'package:home_fit_daily/features/guide/article_screen.dart';

import '../helpers/catalog_fixture.dart';
import '../helpers/fakes.dart';
import '../helpers/sessions.dart';
import '../helpers/test_app.dart';

Future<void> _seedHistory(InMemoryKeyValueStore store) async {
  final repos = Repositories(store);
  final today = LocalDate.today();
  for (var i = 0; i < 12; i++) {
    await repos.sessions.save(
      sessionOn(
        today.addDays(-i * 2),
        status: i % 4 == 3 ? SessionStatus.partial : SessionStatus.completed,
        activeSeconds: 300 + i * 60,
      ),
    );
  }
}

void main() {
  final catalog = loadBundledCatalog();

  testWidgets('every exercise detail renders', (tester) async {
    useScreen(tester, const Size(360, 740));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));
    final context = tester.element(find.byType(Scaffold).first);
    for (final exercise in catalog.exercises) {
      unawaited(
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => ExerciseDetailScreen(exercise: exercise))),
      );
      await settle(tester, frames: 3);
      expect(find.text(exercise.name), findsWidgets, reason: exercise.id);
      Navigator.of(context).pop();
      await settle(tester, frames: 3);
    }
  });

  testWidgets('every guide article renders and records reading progress', (tester) async {
    useScreen(tester, const Size(360, 740));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));
    final context = tester.element(find.byType(Scaffold).first);
    for (final article in catalog.articles) {
      unawaited(
        Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => ArticleScreen(article: article))),
      );
      await settle(tester, frames: 3);
      await tester.drag(find.byType(ListView).last, const Offset(0, -20000));
      await settle(tester, frames: 3);
      Navigator.of(context).pop();
      await settle(tester, frames: 2);
    }
    final states = Repositories(store).guideState.all();
    expect(states.values.where((s) => s.isFinished).length, catalog.articles.length);
  });

  testWidgets('a repetition workout runs to the summary and is saved once', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    final now = DateTime.now().toUtc();
    await Repositories(store).customWorkouts.save(
      CustomWorkout(
        id: 'custom_test',
        title: 'Two squats',
        description: '',
        steps: const [
          WorkoutStep(
            id: 's1',
            exerciseId: 'bodyweight_squat',
            type: StepType.main,
            execution: ExecutionType.reps,
            repetitions: 2,
            restSeconds: 10,
          ),
          WorkoutStep(
            id: 's2',
            exerciseId: 'glute_bridge',
            type: StepType.main,
            execution: ExecutionType.timed,
            durationSeconds: 20,
          ),
        ],
        rounds: 1,
        roundRestSeconds: 0,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final mono = FakeMonotonicClock();
    await pumpApp(tester, testServices(store: store, monotonic: mono));

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await tapText(tester, 'My workouts');
    await tapText(tester, 'Two squats');
    await tapText(tester, 'Start workout');
    await tapText(tester, 'Start workout');
    await tapText(tester, 'Start now');
    expect(find.text('Bodyweight Squat'), findsWidgets);
    await tapText(tester, 'Done');
    // Rest, then the timed bridge finishes on its own as time passes.
    await tapText(tester, 'Skip rest');
    mono.advanceSeconds(21);
    await settle(tester);
    expect(find.text('Workout complete'), findsOneWidget);
    await tapText(tester, 'Moderate');
    await tapText(tester, 'Done');

    final sessions = Repositories(store).sessions.all();
    expect(sessions, hasLength(1));
    expect(sessions.single.status, SessionStatus.completed);
    expect(sessions.single.effortRating, EffortRating.moderate);
    expect(sessions.single.activeSeconds, greaterThanOrEqualTo(20));
    expect(Repositories(store).activeSession.load(), isNull);
  });

  testWidgets('starting a plan shows the schedule; leaving needs confirmation', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));

    await tester.tap(find.text('Plans').last);
    await settle(tester);
    await tapText(tester, 'Beginner Home Fitness');
    await scrollTo(tester, find.text('Week by week'));
    expect(find.text('Week by week'), findsOneWidget);
    await tapText(tester, 'Start this plan');
    // Accept today's date in the date picker.
    await tapText(tester, 'OK');
    expect(find.text('Schedule'), findsOneWidget);
    expect(Repositories(store).enrollments.all().single.status, EnrollmentStatus.active);

    await tester.tap(find.byTooltip('Plan options'));
    await settle(tester);
    await tapText(tester, 'Pause plan');
    expect(Repositories(store).enrollments.all().single.status, EnrollmentStatus.paused);
    await tapText(tester, 'Resume plan');
    expect(Repositories(store).enrollments.all().single.status, EnrollmentStatus.active);

    await tester.tap(find.byTooltip('Plan options'));
    await settle(tester);
    await tapText(tester, 'Leave plan');
    expect(find.text('Leave this plan?'), findsOneWidget);
    await tapText(tester, 'Leave plan');
    expect(Repositories(store).enrollments.all().single.status, EnrollmentStatus.left);
  });

  testWidgets('progress shows real history with chart, calendar and details', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await _seedHistory(store);
    await pumpApp(tester, testServices(store: store));

    await tester.tap(find.text('Progress').last);
    await settle(tester);
    expect(find.text('Your progress will appear here'), findsNothing);
    for (final range in ['30 days', '12 weeks', '12 months', '7 days']) {
      await tapText(tester, range);
    }
    await tapText(tester, 'See all');
    expect(find.text('History'), findsOneWidget);
    await tapText(tester, 'Partially completed');
    await tapText(tester, 'Test workout');
    expect(find.text('Session'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete session'));
    await settle(tester);
    await tapText(tester, 'Delete');
    expect(Repositories(store).sessions.all(), hasLength(11));
  });

  testWidgets('measurements can be added in imperial units', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    final repos = Repositories(store);
    await repos.profile.save(repos.profile.load()!.copyWith(unitSystem: UnitSystem.imperial));
    await pumpApp(tester, testServices(store: store));
    await tester.tap(find.text('Progress').last);
    await settle(tester);
    await tapText(tester, 'Optional: track weight or measurements. Nothing is required.');
    await tapText(tester, 'Add entry');
    await tester.enterText(find.byType(TextField).first, '160');
    await tapText(tester, 'Save');
    final entry = repos.measurements.all().single;
    expect(entry.canonicalValue, closeTo(72.57, 0.01));
    expect(find.text('160 lb'), findsWidgets);
  });

  testWidgets('an interrupted session can be resumed from home', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    final workout = catalog.workout('five_minute_starter')!;
    final timeline = WorkoutTimeline.build(workout);
    final engine = WorkoutEngine(timeline, FakeMonotonicClock())
      ..start()
      ..skipRest();
    await Repositories(store).activeSession.save(
      ActiveSessionCheckpoint(
        recoveryVersion: ActiveSessionCheckpoint.currentRecoveryVersion,
        sessionId: 'session_recover',
        source: WorkoutSource.catalog,
        sourceWorkoutId: workout.id,
        snapshot: WorkoutSnapshot(workout: workout, exerciseNames: const {}),
        startedAtUtc: DateTime.now().toUtc(),
        checkpointAtUtc: DateTime.now().toUtc(),
        engine: engine.checkpoint(),
      ),
    );
    await pumpApp(tester, testServices(store: store));
    expect(find.text('Unfinished workout'), findsOneWidget);
    await tapText(tester, 'Resume');
    expect(find.textContaining('restored where you left off'), findsOneWidget);
    expect(find.text('Resume'), findsOneWidget);
  });

  testWidgets('settings sub-pages open', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    for (final page in [
      'Profile & preferences',
      'Backup & restore',
      'Privacy',
      'Fitness disclaimer',
      'About HomeFit',
      'Content credits & licenses',
    ]) {
      await tapText(tester, page);
      expect(tester.takeException(), isNull);
      expect(
        find.text('Delete all personal data'),
        findsNothing,
        reason: 'still on settings after $page',
      );
      await tester.pageBack();
      await settle(tester);
      expect(find.text('Settings'), findsOneWidget, reason: 'back from $page');
    }
  });

  testWidgets('reset progress keeps the profile but clears history', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store, name: 'Kim');
    await _seedHistory(store);
    await pumpApp(tester, testServices(store: store));
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await tapText(tester, 'Reset workout progress');
    await tapText(tester, 'Reset progress');
    final repos = Repositories(store);
    expect(repos.sessions.all(), isEmpty);
    expect(repos.profile.load()!.displayName, 'Kim');
  });

  testWidgets('deleting all data returns to onboarding', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await _seedHistory(store);
    final reminders = FakeReminderService();
    await pumpApp(tester, testServices(store: store, reminders: reminders));
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await tapText(tester, 'Delete all personal data');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Delete everything');
    expect(find.text('Welcome to HomeFit'), findsOneWidget);
    expect(Repositories(store).sessions.all(), isEmpty);
    expect(reminders.cancelCount, greaterThan(0));
  });

  testWidgets('home shows today and suggestions with seeded history', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await _seedHistory(store);
    await pumpApp(tester, testServices(store: store));
    expect(find.text('This week'), findsOneWidget);
    await scrollTo(tester, find.text('Suggested for you'));
    expect(find.text('Suggested for you'), findsOneWidget);
  });
}
