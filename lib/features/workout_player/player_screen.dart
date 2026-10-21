import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/app_services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../domain/workout_timeline.dart';
import '../../state/history_controller.dart';
import '../../state/settings_controller.dart';
import '../exercise_library/exercise_detail_screen.dart';
import '../exercise_media/exercise_media.dart';
import 'player_controller.dart';
import 'summary_screen.dart';

/// Full-screen guided workout.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key, required this.launch});

  final PlayerLaunch launch;

  @override
  Widget build(BuildContext context) {
    final services = context.read<AppServices>();
    return ChangeNotifierProvider(
      create: (context) => WorkoutPlayerController(
        launch: launch,
        sessions: services.repositories.sessions,
        activeSessions: services.repositories.activeSession,
        feedback: services.feedback,
        screenAwake: services.screenAwake,
        settings: context.read<SettingsController>().settings,
        onSessionSaved: context.read<HistoryController>().onSessionSaved,
        clock: services.clock,
        monotonic: services.monotonicClock(),
      ),
      child: const _PlayerView(),
    );
  }
}

class _PlayerView extends StatefulWidget {
  const _PlayerView();

  @override
  State<_PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<_PlayerView> {
  bool _navigatedToSummary = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = context.watch<WorkoutPlayerController>();
    final outcome = c.outcome;
    if (outcome != null && !_navigatedToSummary) {
      _navigatedToSummary = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!outcome.saved && outcome.completedCount == 0) {
          Navigator.of(context).pop();
          showMessage(context, 'Workout ended. Nothing was completed, so nothing was saved.');
          return;
        }
        Navigator.of(
          context,
        ).pushReplacement(MaterialPageRoute(builder: (_) => SummaryScreen(outcome: outcome)));
      });
    }
  }

  Future<void> _requestExit() async {
    final c = context.read<WorkoutPlayerController>();
    if (c.state == PlayerState.ready || c.isFinished) {
      Navigator.of(context).pop();
      return;
    }
    final wasRunning = c.state.isRunning;
    if (wasRunning) c.pause();
    final completed = c.engine.completedExerciseCount;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this workout?'),
        content: Text(
          completed == 0
              ? 'You have not completed an exercise yet, so nothing will be saved if you quit.'
              : 'Finish and save keeps your progress as a partial session. '
                    'Quitting records it as abandoned, which does not count '
                    'toward your stats or plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _ExitChoice.quit),
            child: const Text('Quit'),
          ),
          if (completed > 0)
            TextButton(
              onPressed: () => Navigator.pop(context, _ExitChoice.finish),
              child: const Text('Finish & save'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _ExitChoice.keepGoing),
            child: const Text('Keep going'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case _ExitChoice.quit:
        await _guardSave(c.quit);
      case _ExitChoice.finish:
        await _guardSave(c.finishEarly);
      case _ExitChoice.keepGoing || null:
        if (wasRunning) c.resume();
    }
  }

  Future<void> _guardSave(Future<SessionOutcome> Function() action) async {
    try {
      await action();
    } catch (_) {
      // The error banner offers a retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WorkoutPlayerController>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide =
                  constraints.maxWidth > 760 && constraints.maxWidth > constraints.maxHeight;
              return Column(
                children: [
                  _TopBar(onClose: _requestExit),
                  const _ProgressBar(),
                  if (c.saveError != null) _SaveErrorBanner(controller: c),
                  if (c.recoveryFailed)
                    const _Banner(
                      icon: Icons.info_outline_rounded,
                      text:
                          'The saved session could not be restored after an '
                          'app update, so it has started from the beginning.',
                    ),
                  if (c.state == PlayerState.interrupted)
                    _Banner(
                      icon: Icons.pause_circle_outline_rounded,
                      text: c.wasRecovered
                          ? 'Your workout was restored where you left off. '
                                'Resume when you are ready.'
                          : 'Paused while the app was in the background.',
                    ),
                  Expanded(
                    child: wide
                        ? const Row(
                            children: [
                              Expanded(child: _MediaArea()),
                              Expanded(child: _InfoAndControls()),
                            ],
                          )
                        : const _PortraitBody(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

enum _ExitChoice { quit, finish, keepGoing }

class _PortraitBody extends StatelessWidget {
  const _PortraitBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Expanded(flex: 4, child: _MediaArea()),
        Expanded(flex: 6, child: _InfoAndControls()),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WorkoutPlayerController>();
    final segment = c.engine.currentSegment;
    final exercise = context.read<Catalog>().exercise(
      segment.exerciseId ?? c.timeline.nextExerciseAfter(segment.index)?.exerciseId ?? '',
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xs, Space.xs, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Leave workout',
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              c.title,
              style: context.text.titleMedium,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Technique and instructions',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: exercise == null
                ? null
                : () async {
                    if (c.state.isRunning) c.pause();
                    await showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder: (_) => DraggableScrollableSheet(
                        expand: false,
                        initialChildSize: 0.85,
                        maxChildSize: 0.95,
                        builder: (context, controller) => ExerciseInstructions(
                          exercise: exercise,
                          scrollController: controller,
                          compact: true,
                        ),
                      ),
                    );
                  },
          ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar();

  @override
  Widget build(BuildContext context) {
    final c = context.read<WorkoutPlayerController>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
      child: ValueListenableBuilder<int>(
        valueListenable: c.timeTick,
        builder: (context, _, _) {
          final value = c.engine.progress;
          return Semantics(
            label: 'Workout progress',
            value: '${(value * 100).round()} percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(value: value, minHeight: 6),
            ),
          );
        },
      ),
    );
  }
}

class _MediaArea extends StatelessWidget {
  const _MediaArea();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WorkoutPlayerController>();
    final segment = c.engine.currentSegment;
    // During rests, preview the upcoming exercise.
    final exerciseId = segment.isExercise
        ? segment.exerciseId
        : (segment.kind == SegmentKind.transition
              ? segment.exerciseId
              : c.timeline.nextExerciseAfter(segment.index)?.exerciseId);
    final exercise = exerciseId == null ? null : context.read<Catalog>().exercise(exerciseId);
    if (exercise == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg),
      child: LayoutBuilder(
        builder: (context, constraints) => ExerciseMedia(
          key: ValueKey(exercise.id),
          exercise: exercise,
          height: (constraints.maxHeight - 24).clamp(80.0, 420.0),
          animate: c.state.isRunning || c.state == PlayerState.ready,
        ),
      ),
    );
  }
}

class _InfoAndControls extends StatelessWidget {
  const _InfoAndControls();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WorkoutPlayerController>();
    final engine = c.engine;
    final segment = engine.currentSegment;
    final effective = engine.effectiveState;
    final step = c.stepOf(segment);
    final next = c.timeline.nextExerciseAfter(segment.index);

    String heading;
    String label;
    if (c.state == PlayerState.ready) {
      final first = c.timeline.nextExerciseAfter(-1);
      label = 'Ready when you are';
      heading = c.exerciseName(first?.exerciseId);
    } else if (segment.kind == SegmentKind.preparation) {
      label = 'Get ready';
      heading = c.exerciseName(next?.exerciseId);
    } else if (segment.kind == SegmentKind.transition) {
      label = 'Switch sides';
      heading = c.exerciseName(segment.exerciseId);
    } else if (segment.kind == SegmentKind.rest) {
      label = 'Rest';
      heading = next == null ? 'Almost done' : 'Next: ${c.exerciseName(next.exerciseId)}';
    } else {
      label = _position(segment, c.timeline.exerciseSegmentCount);
      heading = c.exerciseName(segment.exerciseId);
    }
    if (engine.isPausedLike) label = 'Paused · $label';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.lg),
      child: Column(
        children: [
          Text(
            label,
            style: context.text.labelLarge?.copyWith(color: context.palette.accentInk),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Space.xs),
          Semantics(
            header: true,
            liveRegion: true,
            child: Text(heading, style: context.text.headlineMedium, textAlign: TextAlign.center),
          ),
          if (segment.isExercise && step?.instructionOverride != null) ...[
            const SizedBox(height: Space.xs),
            Text(
              step!.instructionOverride!,
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: Space.md),
          const _TimerDisplay(),
          const SizedBox(height: Space.md),
          _Controls(effective: effective),
          if (next != null && segment.isExercise) ...[
            const SizedBox(height: Space.md),
            Text(
              'Next: ${c.exerciseName(next.exerciseId)} · ${_target(next)}',
              style: context.text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  static String _position(TimelineSegment s, int total) => [
    'Exercise ${s.exerciseNumber} of $total',
    if (s.totalRounds > 1) 'Round ${s.round}/${s.totalRounds}',
    if (s.totalSets > 1) 'Set ${s.set}/${s.totalSets}',
    if (s.side != Side.none) s.side.label,
  ].join(' · ');

  static String _target(TimelineSegment s) => s.waitsForUser
      ? '${s.repetitions} reps${s.side != Side.none ? ' / side' : ''}'
      : Formatters.duration(s.durationSeconds ?? 0);
}

/// The large timer. Rebuilds on every tick independently of the rest of the
/// screen.
class _TimerDisplay extends StatelessWidget {
  const _TimerDisplay();

  @override
  Widget build(BuildContext context) {
    final c = context.read<WorkoutPlayerController>();
    return ValueListenableBuilder<int>(
      valueListenable: c.timeTick,
      builder: (context, _, _) {
        final engine = c.engine;
        final segment = engine.currentSegment;
        if (c.state == PlayerState.ready) {
          final first = c.timeline.nextExerciseAfter(-1);
          return _BigValue(
            value: first == null ? '' : _InfoAndControls._target(first),
            caption: c.timeline.exerciseSegmentCount == 1
                ? '1 exercise'
                : '${c.timeline.exerciseSegmentCount} exercise sets',
          );
        }
        if (segment.waitsForUser) {
          final elapsed = engine.segmentElapsedMs ~/ 1000;
          return _BigValue(
            value: '${segment.repetitions}',
            caption:
                'repetitions${segment.side != Side.none ? ' (${segment.side.label.toLowerCase()})' : ''}'
                ' · ${Formatters.clock(elapsed)} elapsed',
            semanticValue: '${segment.repetitions} repetitions',
          );
        }
        final remaining = Formatters.ceilSeconds(engine.remainingMs ?? 0);
        return _BigValue(
          value: Formatters.clock(remaining),
          caption: segment.isExercise ? 'remaining' : 'until next',
          semanticValue: '$remaining seconds remaining',
        );
      },
    );
  }
}

class _BigValue extends StatelessWidget {
  const _BigValue({required this.value, required this.caption, this.semanticValue});

  final String value;
  final String caption;
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticValue ?? value,
      excludeSemantics: true,
      child: Column(
        children: [
          SizedBox(
            height: 104,
            child: FittedBox(
              child: Text(
                value,
                style: context.text.displayLarge?.copyWith(
                  fontSize: 88,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  height: 1,
                ),
              ),
            ),
          ),
          Text(
            caption,
            style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.effective});

  final PlayerState effective;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WorkoutPlayerController>();
    final engine = c.engine;
    final segment = engine.currentSegment;
    final paused = engine.isPausedLike;

    if (c.state == PlayerState.ready) {
      return _PrimaryButton(
        icon: Icons.play_arrow_rounded,
        label: 'Start workout',
        onPressed: c.start,
      );
    }
    if (c.isFinished) {
      return const Padding(padding: EdgeInsets.all(Space.lg), child: CircularProgressIndicator());
    }

    final primary = paused
        ? _PrimaryButton(icon: Icons.play_arrow_rounded, label: 'Resume', onPressed: c.resume)
        : segment.waitsForUser
        ? _PrimaryButton(
            icon: Icons.check_rounded,
            label: segment.side == Side.none
                ? 'Done'
                : 'Done – ${segment.side.label.toLowerCase()}',
            onPressed: c.completeRepetitions,
          )
        : _PrimaryButton(icon: Icons.pause_rounded, label: 'Pause', onPressed: c.pause);

    final isRest = segment.isRestLike;
    final secondary = <Widget>[
      if (isRest && segment.kind != SegmentKind.preparation)
        _SecondaryButton(
          icon: Icons.more_time_rounded,
          label: '+15 s',
          onPressed: () => c.extendRest(),
        ),
      if (isRest)
        _SecondaryButton(
          icon: Icons.skip_next_rounded,
          label: segment.kind == SegmentKind.preparation ? 'Start now' : 'Skip rest',
          onPressed: c.skipRest,
        ),
      if (!isRest)
        _SecondaryButton(icon: Icons.skip_next_rounded, label: 'Skip', onPressed: c.skipExercise),
      if (segment.waitsForUser && !paused)
        _SecondaryButton(icon: Icons.pause_rounded, label: 'Pause', onPressed: c.pause),
      _SecondaryButton(
        icon: Icons.flag_outlined,
        label: 'Finish',
        onPressed: () => _confirmFinish(context, c),
      ),
    ];

    return Column(
      children: [
        primary,
        const SizedBox(height: Space.md),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: secondary,
        ),
      ],
    );
  }

  Future<void> _confirmFinish(BuildContext context, WorkoutPlayerController c) async {
    final wasRunning = c.state.isRunning;
    if (wasRunning) c.pause();
    final completed = c.engine.completedExerciseCount;
    final ok = await confirmAction(
      context,
      title: 'Finish early?',
      message: completed == 0
          ? 'No exercise has been completed yet, so nothing will be saved.'
          : 'Your session will be saved as partially completed. Partial '
                'sessions appear in your history but do not count as completed '
                'workouts.',
      confirmLabel: 'Finish',
    );
    if (ok) {
      try {
        await c.finishEarly();
      } catch (_) {
        // Error banner offers a retry.
      }
    } else if (wasRunning) {
      c.resume();
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 30),
      label: Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        backgroundColor: AppColors.premiumPink,
        foregroundColor: AppColors.deepBlack,
      ),
    ),
  );
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({required this.icon, required this.label, required this.onPressed});

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(minimumSize: const Size(96, 52)),
  );
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
    child: AppCard(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          Icon(icon, color: context.palette.accentInk),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    ),
  );
}

class _SaveErrorBanner extends StatelessWidget {
  const _SaveErrorBanner({required this.controller});

  final WorkoutPlayerController controller;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.xs),
    child: AppCard(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: context.palette.error),
          const SizedBox(width: Space.md),
          const Expanded(
            child: Text(
              'Your session could not be saved. It is kept on this device; try saving again.',
            ),
          ),
          TextButton(onPressed: () => controller.finalize().ignore(), child: const Text('Retry')),
        ],
      ),
    ),
  );
}
