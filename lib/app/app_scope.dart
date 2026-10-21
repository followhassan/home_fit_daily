import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/catalog/catalog.dart';
import '../state/custom_workout_controller.dart';
import '../state/data_controller.dart';
import '../state/favorites_controller.dart';
import '../state/guide_controller.dart';
import '../state/history_controller.dart';
import '../state/measurement_controller.dart';
import '../state/plan_controller.dart';
import '../state/profile_controller.dart';
import '../state/recovery_controller.dart';
import '../state/settings_controller.dart';
import 'app_services.dart';

/// Creates the app's controllers once and provides them to the tree.
class AppScope extends StatefulWidget {
  const AppScope({super.key, required this.services, required this.child});

  final AppServices services;
  final Widget child;

  @override
  State<AppScope> createState() => _AppScopeState();
}

class _AppScopeState extends State<AppScope> {
  late final ProfileController profile;
  late final SettingsController settings;
  late final FavoritesController favorites;
  late final HistoryController history;
  late final PlanController plans;
  late final CustomWorkoutController customWorkouts;
  late final MeasurementController measurements;
  late final GuideController guide;
  late final RecoveryController recovery;
  late final DataController data;

  @override
  void initState() {
    super.initState();
    final s = widget.services;
    final r = s.repositories;
    profile = ProfileController(r.profile, clock: s.clock);
    settings = SettingsController(r.settings, s.reminders);
    favorites = FavoritesController(r.favorites, s.catalog, clock: s.clock);
    history = HistoryController(r.sessions, weeklyGoal: profile.profile.weeklyGoal, clock: s.clock);
    plans = PlanController(r.enrollments, history, clock: s.clock);
    customWorkouts = CustomWorkoutController(r.customWorkouts, s.catalog, clock: s.clock);
    measurements = MeasurementController(r.measurements, clock: s.clock);
    guide = GuideController(r.guideState, clock: s.clock);
    recovery = RecoveryController(r.activeSession, r.sessions);
    data = DataController(
      repositories: r,
      restore: s.restore,
      catalog: s.catalog,
      profile: profile,
      settings: settings,
      favorites: favorites,
      history: history,
      plans: plans,
      customWorkouts: customWorkouts,
      measurements: measurements,
      guide: guide,
      recovery: recovery,
      appVersion: s.appVersion,
      clock: s.clock,
    );
    profile.addListener(_syncWeeklyGoal);

    // Startup housekeeping that never blocks the first frame.
    favorites.pruneStale().ignore();
    plans.normalize().ignore();
    settings.reconcileReminders().ignore();
  }

  void _syncWeeklyGoal() => history.setWeeklyGoal(profile.profile.weeklyGoal);

  @override
  void dispose() {
    profile.removeListener(_syncWeeklyGoal);
    for (final c in [
      data,
      recovery,
      guide,
      measurements,
      customWorkouts,
      plans,
      history,
      favorites,
      settings,
      profile,
    ]) {
      c.dispose();
    }
    widget.services.feedback.dispose().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppServices>.value(value: widget.services),
        Provider<Catalog>.value(value: widget.services.catalog),
        ChangeNotifierProvider.value(value: profile),
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider.value(value: favorites),
        ChangeNotifierProvider.value(value: history),
        ChangeNotifierProvider.value(value: plans),
        ChangeNotifierProvider.value(value: customWorkouts),
        ChangeNotifierProvider.value(value: measurements),
        ChangeNotifierProvider.value(value: guide),
        ChangeNotifierProvider.value(value: recovery),
        ChangeNotifierProvider.value(value: data),
      ],
      child: widget.child,
    );
  }
}
