import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/app.dart';
import 'package:home_fit_daily/app/app_services.dart';
import 'package:home_fit_daily/app/navigation.dart';
import 'package:home_fit_daily/core/services/screen_awake.dart';
import 'package:home_fit_daily/core/services/workout_feedback.dart';
import 'package:home_fit_daily/core/utils/app_clock.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/models/user_profile.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';
import 'package:home_fit_daily/domain/backup/restore_service.dart';

import 'catalog_fixture.dart';
import 'fakes.dart';

/// App services backed by memory, for widget tests.
AppServices testServices({
  InMemoryKeyValueStore? store,
  FakeReminderService? reminders,
  AppClock clock = const AppClock(),
  FakeMonotonicClock? monotonic,
}) {
  final s = store ?? InMemoryKeyValueStore();
  return AppServices(
    store: s,
    repositories: Repositories(s),
    catalog: loadBundledCatalog(),
    restore: RestoreService(s),
    reminders: reminders ?? FakeReminderService(),
    feedback: SilentFeedback(),
    screenAwake: NoopScreenAwake(),
    clock: clock,
    appVersion: 'test',
    monotonicClock: monotonic == null ? null : () => monotonic,
  );
}

/// Pre-completes onboarding so tests start on the home screen.
Future<void> seedOnboarded(InMemoryKeyValueStore store, {String name = ''}) =>
    Repositories(store).profile.save(
      UserProfile.initial(
        id: 'p',
        now: DateTime.utc(2026, 10, 21),
      ).copyWith(displayName: name, onboardingCompleted: true),
    );

/// Pumps the whole app and lets bootstrap complete. Figure animations loop
/// forever, so this pumps fixed durations instead of settling.
Future<void> pumpApp(WidgetTester tester, AppServices services) async {
  Nav.resetForTesting();
  await tester.pumpWidget(HomeFitApp(bootstrap: () async => services));
  await settle(tester);
}

Future<void> settle(WidgetTester tester, {int frames = 6}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Sets the logical screen size for the current test.
void useScreen(WidgetTester tester, Size size, {double textScale = 1}) {
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text);
  await scrollTo(tester, finder);
  if (finder.hitTestable().evaluate().isEmpty && finder.evaluate().isNotEmpty) {
    // e.g. a chip in a horizontal list
    await tester.ensureVisible(finder.first);
    await settle(tester, frames: 2);
  }
  final onScreen = finder.hitTestable();
  await tester.tap(onScreen.evaluate().isNotEmpty ? onScreen.first : finder.first);
  await settle(tester);
}

/// Scrolls the front-most vertical list until [finder] is built.
Future<void> scrollTo(WidgetTester tester, Finder target) async {
  // Built is not enough: the widget must be on screen to be tapped.
  final finder = target.hitTestable();
  if (finder.evaluate().isNotEmpty) return;
  final vertical = find
      .byWidgetPredicate(
        (w) => w is Scrollable && axisDirectionToAxis(w.axisDirection) == Axis.vertical,
      )
      .hitTestable(at: Alignment.center);
  final candidates = vertical.evaluate().toList().reversed;
  for (final element in candidates) {
    for (var i = 0; i < 60 && finder.evaluate().isEmpty; i++) {
      await tester.drag(find.byElementPredicate((e) => e == element), const Offset(0, -250));
      await tester.pump(const Duration(milliseconds: 50));
    }
    if (finder.evaluate().isNotEmpty) break;
  }
  await settle(tester, frames: 2);
}
