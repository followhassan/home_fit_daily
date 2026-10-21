import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/premium_button.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/personal_records.dart';
import '../../data/models/workout.dart';
import '../../state/custom_workout_controller.dart';
import '../../state/favorites_controller.dart';
import '../../state/profile_controller.dart';
import '../custom_workouts/workout_builder_screen.dart';
import '../exercise_library/exercise_detail_screen.dart';
import 'workout_widgets.dart';

/// Overview of a workout before starting it.
///
/// When opened from a plan day, [planAssignmentId] and [enrollmentId] link
/// the session to that day; otherwise the session is independent and never
/// completes a plan day.
class WorkoutDetailScreen extends StatelessWidget {
  const WorkoutDetailScreen({
    super.key,
    required this.workout,
    this.planAssignmentId,
    this.enrollmentId,
    this.planLabel,
  });

  final Workout workout;
  final String? planAssignmentId;
  final String? enrollmentId;
  final String? planLabel;

  @override
  Widget build(BuildContext context) {
    // Custom workouts may have been edited since this screen was opened.
    final current = workout.isCustom
        ? context.watch<CustomWorkoutController>().playable(workout.id)
        : workout;
    if (current == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(
          icon: Icons.delete_outline_rounded,
          title: 'Workout not found',
          message:
              'This workout has been deleted. Your past sessions with it are still in your history.',
        ),
      );
    }
    final catalog = context.read<Catalog>();
    final info = catalog.infoFor(current);
    final profile = context.watch<ProfileController>().profile;
    final missingEquipment = info.equipment.difference(profile.availableEquipment);
    final favorite = context.select<FavoritesController, bool>(
      (f) => f.isWorkoutFavorite(current.id),
    );
    final canStart = info.missingExerciseIds.isEmpty && current.steps.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.isCustom ? 'My workout' : 'Workout'),
        actions: [
          if (!current.isCustom)
            IconButton(
              tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
              icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
              color: favorite ? context.palette.accentInk : null,
              onPressed: () async {
                try {
                  final now = await context.read<FavoritesController>().toggle(
                    FavoriteKind.workout,
                    current.id,
                  );
                  if (context.mounted) {
                    showMessage(context, now ? 'Added to favorites' : 'Removed from favorites');
                  }
                } catch (_) {
                  if (context.mounted) showMessage(context, 'Could not update favorites.');
                }
              },
            ),
          _MoreMenu(workout: current),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, 120),
            children: [
              Row(
                children: [
                  WorkoutArt(category: current.category, size: 72),
                  const SizedBox(width: Space.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (planLabel != null)
                          Text(
                            planLabel!,
                            style: context.text.labelLarge?.copyWith(
                              color: context.palette.accentInk,
                            ),
                          ),
                        Text(current.title, style: context.text.headlineSmall),
                        Text(current.category.label, style: context.text.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.lg),
              WorkoutMeta(workout: current, info: info),
              if (current.description.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                Text(current.description, style: context.text.bodyLarge),
              ],
              if (missingEquipment.isNotEmpty)
                _Hint(
                  icon: Icons.handyman_outlined,
                  text:
                      'This workout uses ${missingEquipment.map((e) => e.label.toLowerCase()).join(' and ')}, '
                      'which is not in your equipment list.',
                ),
              if (info.matRecommended && !profile.availableEquipment.contains(Equipment.mat))
                const _Hint(
                  icon: Icons.crop_landscape_rounded,
                  text:
                      'Includes floor exercises – a carpet or folded towel helps if you do not have a mat.',
                ),
              if (!info.isLowImpact && profile.lowImpactPreference)
                const _Hint(
                  icon: Icons.volume_up_rounded,
                  text:
                      'Includes jumping or higher-impact moves. Use the easier variations to keep it low impact.',
                ),
              if (info.missingExerciseIds.isNotEmpty)
                const _Hint(
                  icon: Icons.error_outline_rounded,
                  text:
                      'Some exercises in this workout are no longer available. Edit the workout to replace them.',
                ),
              _Structure(workout: current),
              if (info.estimate.isApproximate)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: Text(
                    'Duration is approximate: repetition-based sets are estimated at about 3 seconds per repetition.',
                    style: context.text.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: PremiumButton(
            label: 'Start workout',
            icon: Icons.play_arrow_rounded,
            width: double.infinity,
            onPressed: canStart
                ? () => WorkoutLauncher.start(
                    context,
                    current,
                    planAssignmentId: planAssignmentId,
                    enrollmentId: enrollmentId,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.md),
    child: AppCard(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: context.palette.warning),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    ),
  );
}

class _Structure extends StatelessWidget {
  const _Structure({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final w = workout;
    Widget group(String title, Iterable<WorkoutStep> steps, {String? subtitle}) {
      final list = steps.toList();
      if (list.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: title),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.sm),
              child: Text(subtitle, style: context.text.bodySmall),
            ),
          for (final step in list) _StepRow(step: step),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        group('Warm-up', w.warmupSteps),
        group(
          w.rounds > 1 ? 'Main · ${w.rounds} rounds' : 'Main',
          w.mainSteps,
          subtitle: w.rounds > 1
              ? 'Do every exercise below, then repeat. '
                    '${w.roundRestSeconds > 0 ? 'Rest ${Formatters.duration(w.roundRestSeconds)} between rounds.' : ''}'
              : null,
        ),
        group('Cool-down', w.cooldownSteps),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step});

  final WorkoutStep step;

  @override
  Widget build(BuildContext context) {
    final exercise = context.read<Catalog>().exercise(step.exerciseId);
    final details = [
      step.isTimed ? Formatters.duration(step.durationSeconds ?? 0) : '${step.repetitions} reps',
      if (step.perSide) 'each side',
      if (step.sets > 1) '× ${step.sets} sets',
      if (step.restSeconds > 0) 'rest ${step.restSeconds}s',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        onTap: exercise == null
            ? null
            : () => Nav.push(context, ExerciseDetailScreen(exercise: exercise)),
        child: Row(
          children: [
            Icon(
              exercise == null ? Icons.error_outline_rounded : Icons.play_circle_outline_rounded,
              color: context.palette.accentInk,
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(exercise?.name ?? 'Unavailable exercise', style: context.text.titleSmall),
                  Text(details, style: context.text.bodySmall),
                  if (step.instructionOverride != null)
                    Text(step.instructionOverride!, style: context.text.bodySmall),
                ],
              ),
            ),
            if (exercise != null) const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _MoreMenu extends StatelessWidget {
  const _MoreMenu({required this.workout});

  final Workout workout;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<CustomWorkoutController>();
    return PopupMenuButton<String>(
      tooltip: 'More options',
      onSelected: (action) async {
        switch (action) {
          case 'copy':
            await Nav.push(
              context,
              WorkoutBuilderScreen(initial: controller.draftFrom(workout), isNew: true),
            );
          case 'edit':
            final custom = controller.byId(workout.id);
            if (custom != null) {
              await Nav.push(context, WorkoutBuilderScreen(initial: custom, isNew: false));
            }
          case 'duplicate':
            try {
              await controller.duplicate(workout.id);
              if (context.mounted) showMessage(context, 'Copy saved to My workouts');
            } catch (_) {
              if (context.mounted) showMessage(context, 'Could not duplicate the workout.');
            }
          case 'delete':
            final ok = await confirmAction(
              context,
              title: 'Delete this workout?',
              message:
                  '"${workout.title}" will be removed from My workouts. Sessions '
                  'you already completed stay in your history.',
              confirmLabel: 'Delete',
              destructive: true,
            );
            if (!ok || !context.mounted) return;
            try {
              await controller.delete(workout.id);
              if (context.mounted) {
                Navigator.of(context).pop();
                showMessage(context, 'Workout deleted');
              }
            } catch (_) {
              if (context.mounted) showMessage(context, 'Could not delete the workout.');
            }
        }
      },
      itemBuilder: (_) => workout.isCustom
          ? const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'duplicate', child: Text('Duplicate')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ]
          : const [PopupMenuItem(value: 'copy', child: Text('Copy to My workouts'))],
    );
  }
}
