import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/widgets/common.dart';
import '../data/catalog/catalog.dart';
import '../data/models/active_session.dart';
import '../data/models/workout.dart';
import '../features/workout_player/player_controller.dart';
import '../features/workout_player/player_screen.dart';
import '../state/recovery_controller.dart';
import 'app_services.dart';

/// Navigation helpers that ignore accidental double taps.
abstract final class Nav {
  static ModalRoute<Object?>? _lastPushed;

  /// A second tap while the previously pushed screen is still sliding in is
  /// ignored, which prevents opening the same screen twice.
  static bool _debounced() {
    final last = _lastPushed;
    if (last == null || !last.isActive || !last.isCurrent) return false;
    return last.animation?.status != AnimationStatus.completed;
  }

  @visibleForTesting
  static void resetForTesting() => _lastPushed = null;

  static Future<T?> push<T>(BuildContext context, Widget page, {bool fullscreenDialog = false}) {
    if (_debounced()) return Future.value();
    final route = MaterialPageRoute<T>(builder: (_) => page, fullscreenDialog: fullscreenDialog);
    _lastPushed = route;
    return Navigator.of(context, rootNavigator: true).push<T>(route);
  }
}

/// Starts or resumes guided workouts.
abstract final class WorkoutLauncher {
  /// Starts [workout]. Pass [planAssignmentId] only when the user starts a
  /// specific plan day – that link is what completes the day.
  static Future<void> start(
    BuildContext context,
    Workout workout, {
    String? planAssignmentId,
    String? enrollmentId,
  }) async {
    final recovery = context.read<RecoveryController>();
    if (recovery.state != RecoveryState.none) {
      final title = recovery.pending?.snapshot.workout.title ?? 'a workout';
      final discard = await confirmAction(
        context,
        title: 'Unfinished workout',
        message:
            'You have an unfinished session of "$title". Starting a new '
            'workout will discard it.',
        confirmLabel: 'Discard and start',
        destructive: true,
      );
      if (!discard || !context.mounted) return;
      await recovery.discard();
      if (!context.mounted) return;
    }
    final services = context.read<AppServices>();
    final launch = PlayerLaunch.fresh(
      workout,
      context.read<Catalog>(),
      nowUtc: services.clock.nowUtc(),
      planAssignmentId: planAssignmentId,
      enrollmentId: enrollmentId,
    );
    await Nav.push(context, PlayerScreen(launch: launch), fullscreenDialog: true);
    // An app resume while the player was open may have picked up this
    // session's own checkpoint; re-check now that it has been finalized.
    recovery.refresh();
  }

  static Future<void> resume(BuildContext context, ActiveSessionCheckpoint checkpoint) async {
    context.read<RecoveryController>().markResumed();
    await Nav.push(
      context,
      PlayerScreen(launch: PlayerLaunch.recover(checkpoint)),
      fullscreenDialog: true,
    );
    if (context.mounted) context.read<RecoveryController>().refresh();
  }
}
