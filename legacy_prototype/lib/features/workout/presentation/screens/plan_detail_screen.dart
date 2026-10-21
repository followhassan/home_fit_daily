import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/difficulty_badge.dart';
import '../../../../core/widgets/exercise_icon_widget.dart';
import '../../../../core/widgets/premium_button.dart';
import '../providers/workout_provider.dart';
import 'exercise_detail_screen.dart';
import 'workout_session_screen.dart';

class PlanDetailScreen extends StatelessWidget {
  const PlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    final plan = context.read<WorkoutProvider>().getPlanById(planId);

    if (plan == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Plan Not Found')),
        body: const Center(child: Text('Workout plan not found')),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(plan.gradientStart),
                      Color(plan.gradientEnd),
                    ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.fitness_center,
                    size: 80,
                    color: AppColors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              title: Text(
                plan.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      DifficultyBadge(difficulty: plan.difficulty),
                      const SizedBox(width: 12),
                      _Meta(Icons.timer, '${plan.durationMinutes} min'),
                      const SizedBox(width: 12),
                      _Meta(Icons.local_fire_department,
                          '${plan.estimatedCalories} kcal'),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    plan.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Exercises (${plan.exerciseCount})',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final exercise = plan.exercises[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  leading: ExerciseIconWidget(
                    iconName: exercise.iconName,
                    size: 48,
                    animate: false,
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(
                    '${exercise.durationSeconds}s • ${exercise.estimatedCalories} kcal',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ExerciseDetailScreen(
                        exerciseId: exercise.id,
                      ),
                    ),
                  ),
                )
                    .animate(delay: Duration(milliseconds: index * 80))
                    .fadeIn()
                    .slideX(begin: 0.1);
              },
              childCount: plan.exercises.length,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: PremiumButton(
                label: 'Start Workout',
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => WorkoutSessionScreen(planId: plan.id),
                  ),
                ),
                width: double.infinity,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.label);

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.premiumPink),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
