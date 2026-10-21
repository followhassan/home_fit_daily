import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';

import '../helpers/fakes.dart';
import '../helpers/test_app.dart';

void main() {
  testWidgets('onboarding can be skipped and is not shown again', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, testServices(store: store));

    expect(find.text('Welcome to HomeFit'), findsOneWidget);
    await tapText(tester, 'Skip setup');
    expect(find.text('Quick actions'), findsOneWidget);
    expect(Repositories(store).profile.load()!.onboardingCompleted, isTrue);

    // Relaunch: straight to the home screen.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, testServices(store: store));
    expect(find.text('Welcome to HomeFit'), findsNothing);
    expect(find.text('Quick actions'), findsOneWidget);
  });

  testWidgets('completing onboarding saves preferences and starting weight', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, testServices(store: store));

    await tapText(tester, 'Set up in about a minute');
    await tester.enterText(find.byType(TextField), 'Sam');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Intermediate');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Improve strength');
    await tapText(tester, 'Continue');
    await tapText(tester, '20 min');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Dumbbells');
    await tapText(tester, 'Continue');
    await tester.enterText(find.byType(TextField), '70');
    await tapText(tester, 'Continue');
    await tapText(tester, 'Get started');

    final repos = Repositories(store);
    final profile = repos.profile.load()!;
    expect(profile.displayName, 'Sam');
    expect(profile.experienceLevel, Difficulty.intermediate);
    expect(profile.primaryGoal, FitnessGoal.strength);
    expect(profile.preferredDurationMinutes, 20);
    expect(profile.availableEquipment, contains(Equipment.dumbbells));
    expect(repos.measurements.all().single.canonicalValue, 70);
    expect(find.textContaining('Sam'), findsWidgets);
  });

  testWidgets('every main tab opens without layout errors', (tester) async {
    useScreen(tester, const Size(360, 740));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));

    for (final tab in ['Workouts', 'Plans', 'Progress', 'Guide', 'Home']) {
      await tester.tap(find.text(tab).last);
      await settle(tester);
    }
    await tester.tap(find.text('Progress').last);
    await settle(tester);
    expect(find.text('Your progress will appear here'), findsOneWidget);

    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    expect(find.text('Profile & preferences'), findsOneWidget);
  });

  testWidgets('exercise search, no-results state and clear filters', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await tapText(tester, 'Exercises');

    await tester.enterText(find.byType(TextField).first, 'plank');
    await settle(tester);
    expect(find.text('Forearm Plank'), findsOneWidget);
    expect(find.text('Bodyweight Squat'), findsNothing);

    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await settle(tester);
    expect(find.text('No exercises match'), findsOneWidget);
    await tapText(tester, 'Clear all filters');
    expect(find.text('No exercises match'), findsNothing);
  });

  testWidgets('workout detail starts a guided session with working controls', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'five-minute');
    await settle(tester);
    await tapText(tester, 'Five-Minute Starter');
    expect(find.text('Warm-up'), findsOneWidget);

    await tapText(tester, 'Start workout');
    expect(find.text('Ready when you are'), findsOneWidget);
    await tapText(tester, 'Start workout');
    expect(find.text('Get ready'), findsOneWidget);
    await tapText(tester, 'Start now');
    expect(find.text('March in Place'), findsWidgets);
    await tapText(tester, 'Pause');
    expect(find.text('Resume'), findsOneWidget);
    await tapText(tester, 'Resume');
    await tapText(tester, 'Skip');
    // Leaving asks for confirmation; nothing done yet so nothing is saved.
    await tester.tap(find.byTooltip('Leave workout'));
    await settle(tester);
    expect(find.text('Leave this workout?'), findsOneWidget);
    await tapText(tester, 'Quit');
    expect(Repositories(store).sessions.all(), isEmpty);
  });

  testWidgets('custom workout builder explains validation errors', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await tapText(tester, 'My workouts');
    await tapText(tester, 'Create a workout');
    await tapText(tester, 'Save workout');
    expect(find.text('Give your workout a name.'), findsWidgets);
    expect(find.text('Add at least one exercise.'), findsWidgets);
    expect(Repositories(store).customWorkouts.all(), isEmpty);
  });

  testWidgets('settings changes persist', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    await pumpApp(tester, testServices(store: store));

    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await tapText(tester, 'Sounds');
    expect(Repositories(store).settings.load()!.soundEnabled, isFalse);
  });

  testWidgets('denied notification permission keeps reminders off without blocking', (
    tester,
  ) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    final reminders = FakeReminderService(grant: false);
    await pumpApp(tester, testServices(store: store, reminders: reminders));

    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await tapText(tester, 'Workout reminders');
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(reminders.requestCount, 1);
    expect(find.text('Notifications are off'), findsOneWidget);
    await tapText(tester, 'OK');
    expect(Repositories(store).settings.load()!.reminders.enabled, isFalse);
    expect(reminders.applied, isNull);
  });

  testWidgets('granted permission schedules reminders', (tester) async {
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store);
    final reminders = FakeReminderService(grant: true);
    await pumpApp(tester, testServices(store: store, reminders: reminders));

    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await tapText(tester, 'Workout reminders');
    await tester.tap(find.byType(Switch).first);
    await settle(tester);
    expect(reminders.applied, isNotNull);
    expect(Repositories(store).settings.load()!.reminders.enabled, isTrue);
  });

  for (final (name, size, scale) in [
    ('small phone', const Size(320, 568), 1.0),
    ('large text', const Size(390, 844), 2.0),
    ('tablet', const Size(1024, 1366), 1.0),
  ]) {
    testWidgets('main screens lay out on $name', (tester) async {
      useScreen(tester, size, textScale: scale);
      final store = InMemoryKeyValueStore();
      await seedOnboarded(store, name: 'Alexandra');
      await pumpApp(tester, testServices(store: store));
      for (final tab in ['Workouts', 'Plans', 'Progress', 'Guide', 'Home']) {
        await tester.tap(find.text(tab).last);
        await settle(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
