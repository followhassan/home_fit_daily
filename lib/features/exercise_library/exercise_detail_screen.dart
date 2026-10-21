import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/exercise.dart';
import '../../data/models/personal_records.dart';
import '../../state/custom_workout_controller.dart';
import '../../state/favorites_controller.dart';
import '../custom_workouts/workout_builder_screen.dart';
import '../exercise_media/exercise_media.dart';

/// Full exercise details: demonstration, technique, variations, cautions.
class ExerciseDetailScreen extends StatelessWidget {
  const ExerciseDetailScreen({super.key, required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<FavoritesController, bool>(
      (f) => f.isExerciseFavorite(exercise.id),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          IconButton(
            tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
            icon: Icon(favorite ? Icons.favorite_rounded : Icons.favorite_border_rounded),
            color: favorite ? context.palette.accentInk : null,
            onPressed: () async {
              try {
                final now = await context.read<FavoritesController>().toggle(
                  FavoriteKind.exercise,
                  exercise.id,
                );
                if (context.mounted) {
                  showMessage(context, now ? 'Added to favorites' : 'Removed from favorites');
                }
              } catch (_) {
                if (context.mounted) showMessage(context, 'Could not update favorites.');
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: ContentWidth(
          child: ExerciseInstructions(
            exercise: exercise,
            footer: Padding(
              padding: const EdgeInsets.only(top: Space.xl),
              child: OutlinedButton.icon(
                onPressed: () => addExerciseToWorkout(context, exercise),
                icon: const Icon(Icons.playlist_add_rounded),
                label: const Text('Add to a custom workout'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets the user add [exercise] to a new or existing custom workout.
Future<void> addExerciseToWorkout(BuildContext context, Exercise exercise) async {
  final controller = context.read<CustomWorkoutController>();
  final existing = controller.workouts;
  final choice = await showModalBottomSheet<String>(
    context: context,
    useSafeArea: true,
    builder: (context) => ListView(
      shrinkWrap: true,
      children: [
        ListTile(
          leading: const Icon(Icons.add_circle_outline_rounded),
          title: const Text('New workout'),
          onTap: () => Navigator.pop(context, ''),
        ),
        for (final w in existing)
          ListTile(
            leading: const Icon(Icons.edit_note_rounded),
            title: Text(w.title),
            subtitle: Text('${w.steps.length} exercises'),
            onTap: () => Navigator.pop(context, w.id),
          ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final base = choice.isEmpty ? controller.newDraft() : controller.byId(choice)!;
  final draft = base.copyWith(steps: [...base.steps, defaultStepFor(exercise)]);
  await Nav.push(context, WorkoutBuilderScreen(initial: draft, isNew: choice.isEmpty));
}

/// The instruction content, shared by the detail screen and the in-workout
/// technique sheet.
class ExerciseInstructions extends StatelessWidget {
  const ExerciseInstructions({
    super.key,
    required this.exercise,
    this.scrollController,
    this.compact = false,
    this.footer,
  });

  final Exercise exercise;
  final ScrollController? scrollController;
  final bool compact;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final text = context.text;
    Widget section(String title, Widget child) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: title),
        child,
      ],
    );
    Widget bullets(List<String> items, IconData icon, {Color? color}) => Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 18, color: color ?? context.palette.accentInk),
                ),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(item, style: text.bodyMedium)),
              ],
            ),
          ),
      ],
    );

    final defaults = [
      if (e.supportsReps) '${e.defaultRepetitions} reps',
      if (e.supportsTimed) Formatters.duration(e.defaultDurationSeconds!),
    ].join(' or ');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.lg, Space.xxl),
      children: [
        if (compact) ...[Text(e.name, style: text.headlineSmall), const SizedBox(height: Space.md)],
        ExerciseMedia(exercise: e, height: compact ? 180 : 240),
        const SizedBox(height: Space.md),
        Text(e.description, style: text.bodyLarge),
        const SizedBox(height: Space.md),
        Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [
            LevelBadge(level: e.difficulty),
            InfoChip(icon: Icons.category_outlined, label: e.category.label),
            InfoChip(
              icon: e.requiresEquipment
                  ? Icons.handyman_outlined
                  : Icons.do_not_disturb_alt_rounded,
              label: e.requiresEquipment
                  ? e.equipment.map((q) => q.label).join(' · ')
                  : 'No equipment',
            ),
            if (e.matRecommended)
              const InfoChip(icon: Icons.crop_landscape_rounded, label: 'Mat recommended'),
            InfoChip(
              icon: e.isLowImpact ? Icons.directions_walk_rounded : Icons.directions_run_rounded,
              label: e.isLowImpact ? 'Low impact' : 'Higher impact',
            ),
            InfoChip(
              icon: Icons.repeat_rounded,
              label: '$defaults${e.isPerSide ? ' per side' : ''}',
            ),
          ],
        ),
        section(
          'Muscles worked',
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: 'Main: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: e.primaryMuscles.map((m) => m.label).join(', ')),
                if (e.secondaryMuscles.isNotEmpty) ...[
                  const TextSpan(
                    text: '\nAlso: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: e.secondaryMuscles.map((m) => m.label).join(', ')),
                ],
              ],
            ),
            style: text.bodyMedium,
          ),
        ),
        section('Starting position', Text(e.setupInstructions, style: text.bodyMedium)),
        section(
          'How to do it',
          Column(
            children: [
              for (var i = 0; i < e.executionInstructions.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: context.palette.surfaceAlt,
                        child: Text('${i + 1}', style: text.labelMedium),
                      ),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(e.executionInstructions[i], style: text.bodyMedium)),
                    ],
                  ),
                ),
            ],
          ),
        ),
        section(
          'Breathing',
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.air_rounded, size: 18, color: context.palette.accentInk),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(e.breathingGuidance, style: text.bodyMedium)),
            ],
          ),
        ),
        section(
          'Mistakes to avoid',
          bullets(e.commonMistakes, Icons.close_rounded, color: context.palette.error),
        ),
        section(
          'Variations',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Variation(label: 'Easier', text: e.easierVariation, icon: Icons.south_rounded),
              if (e.harderVariation != null)
                _Variation(label: 'Harder', text: e.harderVariation!, icon: Icons.north_rounded),
            ],
          ),
        ),
        section(
          'Take care',
          bullets(
            [...e.cautions, 'Stop if you feel sharp pain, dizziness or chest discomfort.'],
            Icons.health_and_safety_outlined,
            color: context.palette.warning,
          ),
        ),
        ?footer,
        if (e.attribution != null) ...[
          const SizedBox(height: Space.xl),
          Text(
            'Illustration: ${e.attribution!.source}. ${e.attribution!.license}.',
            style: text.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Variation extends StatelessWidget {
  const _Variation({required this.label, required this.text, required this.icon});

  final String label;
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.sm),
    child: AppCard(
      padding: const EdgeInsets.all(Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.palette.accentInk),
          const SizedBox(width: Space.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: text),
                ],
              ),
              style: context.text.bodyMedium,
            ),
          ),
        ],
      ),
    ),
  );
}

/// List row for an exercise.
class ExerciseTile extends StatelessWidget {
  const ExerciseTile({super.key, required this.exercise, required this.onTap, this.trailing});

  final Exercise exercise;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final favorite = context.select<FavoritesController, bool>(
      (f) => f.isExerciseFavorite(exercise.id),
    );
    final e = exercise;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      semanticLabel:
          '${e.name}. ${e.difficulty.label}, ${e.category.label}'
          '${e.requiresEquipment ? ', needs ${e.equipment.map((q) => q.label).join(' and ')}' : ''}'
          '${favorite ? ', favorite' : ''}',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: context.palette.surfaceAlt,
                borderRadius: BorderRadius.circular(Space.radiusSm),
              ),
              child: Icon(categoryIcon(e.category), color: context.palette.accentInk),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(e.name, style: context.text.titleSmall)),
                      if (favorite)
                        Icon(Icons.favorite_rounded, size: 16, color: context.palette.accentInk),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      e.difficulty.label,
                      e.primaryMuscles.take(2).map((m) => m.label).join(', '),
                      if (e.requiresEquipment) e.equipment.map((q) => q.label).join(', '),
                      if (e.isLowImpact) 'Low impact',
                    ].join(' · '),
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
