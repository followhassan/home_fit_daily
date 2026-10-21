import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/services/screen_awake.dart';
import 'package:home_fit_daily/core/services/workout_feedback.dart';
import 'package:home_fit_daily/core/utils/app_clock.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/models/app_settings.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/models/workout_session.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';
import 'package:home_fit_daily/features/workout_player/player_controller.dart';

import '../helpers/catalog_fixture.dart';
import '../helpers/fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final catalog = loadBundledCatalog();

  late InMemoryKeyValueStore store;
  late Repositories repos;
  late FakeMonotonicClock mono;
  late List<WorkoutSession> saved;
  late NoopScreenAwake awake;

  WorkoutPlayerController controller(PlayerLaunch launch) => WorkoutPlayerController(
    launch: launch,
    sessions: repos.sessions,
    activeSessions: repos.activeSession,
    feedback: SilentFeedback(),
    screenAwake: awake,
    settings: AppSettings.defaults,
    onSessionSaved: saved.add,
    monotonic: mono,
    clock: FixedClock(DateTime(2026, 10, 21, 18)),
    observeLifecycle: false,
  );

  PlayerLaunch launchFor(List steps, {String? assignment}) => PlayerLaunch.fresh(
    testWorkout(steps.cast()),
    catalog,
    nowUtc: DateTime.utc(2026, 10, 21, 17),
    planAssignmentId: assignment,
    enrollmentId: assignment == null ? null : 'e1',
  );

  setUp(() {
    store = InMemoryKeyValueStore();
    repos = Repositories(store);
    mono = FakeMonotonicClock();
    saved = [];
    awake = NoopScreenAwake();
  });

  test('completing saves exactly one session even with repeated taps', () async {
    final c = controller(launchFor([repStep('a', 'bodyweight_squat')], assignment: 'e1_d1'));
    c.start();
    c.skipRest();
    c.completeRepetitions(); // reaches the end → automatic finalize
    final results = await Future.wait([c.finalize(), c.finalize(), c.finishEarly()]);
    expect(results.toSet().length, 1);
    expect(saved, hasLength(1));
    expect(repos.sessions.all(), hasLength(1));
    final session = repos.sessions.all().single;
    expect(session.status, SessionStatus.completed);
    expect(session.planAssignmentId, 'e1_d1');
    expect(session.snapshot.workout.title, 'Test workout');
    expect(session.localCompletionDate.toIso(), '2026-10-21');
    // The checkpoint is cleared once the session is saved.
    expect(repos.activeSession.load(), isNull);
    c.dispose();
  });

  test('checkpoints are written during the session for recovery', () async {
    final c = controller(launchFor([timedStep('a', 'march_in_place', seconds: 30)]));
    c.start();
    c.skipRest();
    mono.advanceSeconds(12);
    c.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(c.state, PlayerState.interrupted);
    await Future<void>.delayed(Duration.zero);
    final checkpoint = repos.activeSession.load();
    expect(checkpoint, isNotNull);
    expect(checkpoint!.engine.segmentElapsedMs, 12000);
    expect(awake.enabled, isFalse);
    c.dispose();

    // Relaunch: the session comes back paused with the same progress.
    final recovered = controller(PlayerLaunch.recover(checkpoint));
    expect(recovered.wasRecovered, isTrue);
    expect(recovered.state, PlayerState.interrupted);
    expect(recovered.engine.remainingMs, 18000);
    recovered.dispose();
  });

  test('quitting before any exercise records nothing', () async {
    final c = controller(launchFor([repStep('a', 'bodyweight_squat')]));
    c.start();
    final outcome = await c.quit();
    expect(outcome.saved, isFalse);
    expect(outcome.status, isNull);
    expect(repos.sessions.all(), isEmpty);
    c.dispose();
  });

  test('finishing early saves a partial session that is not a completion', () async {
    final c = controller(launchFor([repStep('a', 'bodyweight_squat'), repStep('b', 'push_up')]));
    c.start();
    c.skipRest();
    c.completeRepetitions();
    final outcome = await c.finishEarly();
    expect(outcome.status, SessionStatus.partial);
    expect(repos.sessions.all().single.countsAsCompleted, isFalse);
    c.dispose();
  });

  test('screen stays awake only while exercising', () {
    final c = controller(launchFor([timedStep('a', 'march_in_place')]));
    c.start();
    expect(awake.enabled, isTrue);
    c.pause();
    expect(awake.enabled, isFalse);
    c.resume();
    expect(awake.enabled, isTrue);
    c.dispose();
  });
}
