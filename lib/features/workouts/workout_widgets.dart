import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common.dart';
import '../../data/catalog/catalog.dart';
import '../../data/models/enums.dart';
import '../../data/models/workout.dart';
import '../../state/favorites_controller.dart';

IconData workoutCategoryIcon(WorkoutCategory category) => switch (category) {
  WorkoutCategory.fullBody => Icons.accessibility_new_rounded,
  WorkoutCategory.strength => Icons.fitness_center_rounded,
  WorkoutCategory.upperBody => Icons.sports_martial_arts_rounded,
  WorkoutCategory.lowerBody => Icons.directions_walk_rounded,
  WorkoutCategory.core => Icons.center_focus_strong_rounded,
  WorkoutCategory.cardio => Icons.favorite_border_rounded,
  WorkoutCategory.quickBreak => Icons.timer_outlined,
  WorkoutCategory.mobility => Icons.sync_rounded,
  WorkoutCategory.stretching => Icons.self_improvement_rounded,
  WorkoutCategory.custom => Icons.edit_note_rounded,
};

/// Category illustration used as the workout thumbnail.
class WorkoutArt extends StatelessWidget {
  const WorkoutArt({super.key, required this.category, this.size = 64});

  final WorkoutCategory category;
  final double size;

  @override
  Widget build(BuildContext context) {
    final shade = WorkoutCategory.values.indexOf(category) / WorkoutCategory.values.length;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(AppColors.premiumPink, const Color(0xFFFF1F8F), shade)!,
              Color.lerp(AppColors.darkGrey, const Color(0xFF3A1027), shade)!,
            ],
          ),
        ),
        child: Icon(workoutCategoryIcon(category), color: AppColors.white, size: size * 0.48),
      ),
    );
  }
}

/// Level, duration, equipment and impact chips for a workout.
class WorkoutMeta extends StatelessWidget {
  const WorkoutMeta({super.key, required this.workout, required this.info});

  final Workout workout;
  final WorkoutInfo info;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      LevelBadge(level: workout.difficulty),
      InfoChip(icon: Icons.schedule_rounded, label: info.estimate.shortLabel),
      InfoChip(
        icon: info.needsEquipment ? Icons.handyman_outlined : Icons.do_not_disturb_alt_rounded,
        label: info.equipmentLabel,
      ),
      if (info.isLowImpact)
        const InfoChip(icon: Icons.directions_walk_rounded, label: 'Low impact'),
    ],
  );
}

/// List row for a workout.
class WorkoutCard extends StatelessWidget {
  const WorkoutCard({
    super.key,
    required this.workout,
    required this.onTap,
    this.subtitle,
    this.showFavorite = true,
  });

  final Workout workout;
  final VoidCallback onTap;
  final String? subtitle;
  final bool showFavorite;

  @override
  Widget build(BuildContext context) {
    final info = context.read<Catalog>().infoFor(workout);
    final favorite =
        showFavorite &&
        !workout.isCustom &&
        context.select<FavoritesController, bool>((f) => f.isWorkoutFavorite(workout.id));
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Space.md),
      semanticLabel:
          '${workout.title}. ${workout.difficulty.label}, '
          '${info.estimate.label}, ${info.equipmentLabel}'
          '${favorite ? ', favorite' : ''}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            WorkoutArt(category: workout.category, size: 56),
            const SizedBox(width: Space.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(workout.title, style: context.text.titleMedium)),
                      if (favorite)
                        Icon(Icons.favorite_rounded, size: 18, color: context.palette.accentInk),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle ?? workout.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: Space.sm),
                  WorkoutMeta(workout: workout, info: info),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
