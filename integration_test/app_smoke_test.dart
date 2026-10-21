// On-device smoke test with the real storage, catalog loading and plugins.
// It has NOT been run in this repository's CI (no device or emulator was
// available); run it manually on a test device or emulator:
//
//   flutter test integration_test/app_smoke_test.dart -d <device-id>
//
// It writes to the app's real storage, so use a device without data you
// want to keep.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/app.dart';
import 'package:integration_test/integration_test.dart';

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  // Exercise figures animate forever, so pumpAndSettle would never return.
  final end = DateTime.now().add(total);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('starts, skips onboarding and opens every tab', (tester) async {
    await tester.pumpWidget(const HomeFitApp());
    await _pumpFor(tester, const Duration(seconds: 5));

    final skip = find.text('Skip setup');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await _pumpFor(tester, const Duration(seconds: 2));
    }

    for (final tab in ['Workouts', 'Plans', 'Progress', 'Guide', 'Home']) {
      await tester.tap(find.text(tab).last);
      await _pumpFor(tester, const Duration(seconds: 1));
      expect(tester.takeException(), isNull, reason: 'opening $tab');
    }

    await tester.tap(find.byTooltip('Settings').first);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Backup & restore'), findsOneWidget);
  });

  testWidgets('opens a workout and leaves the player without saving', (tester) async {
    await tester.pumpWidget(const HomeFitApp());
    await _pumpFor(tester, const Duration(seconds: 5));
    final skip = find.text('Skip setup');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await _pumpFor(tester, const Duration(seconds: 2));
    }

    await tester.tap(find.text('Workouts').last);
    await _pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Five-Minute Starter').first);
    await _pumpFor(tester, const Duration(seconds: 1));
    expect(find.text('Start workout'), findsWidgets);

    await tester.tap(find.text('Start workout').first);
    await _pumpFor(tester, const Duration(seconds: 1));
    // The pre-start sheet, when shown, also offers "Start workout".
    if (find.text('Start now').evaluate().isEmpty &&
        find.text('Start workout').evaluate().isNotEmpty) {
      await tester.tap(find.text('Start workout').last);
      await _pumpFor(tester, const Duration(seconds: 1));
    }
    if (find.text('Start now').evaluate().isNotEmpty) {
      await tester.tap(find.text('Start now'));
      await _pumpFor(tester, const Duration(seconds: 2));
    }

    await tester.tap(find.byTooltip('Leave workout'));
    await _pumpFor(tester, const Duration(seconds: 1));
    await tester.tap(find.text('Quit'));
    await _pumpFor(tester, const Duration(seconds: 2));
    expect(find.byType(Scaffold), findsWidgets);
  });
}
