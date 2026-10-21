import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/widgets/exercise_icon_widget.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../../../../core/widgets/premium_button.dart';
import '../providers/workout_provider.dart';

class ExerciseDetailScreen extends StatefulWidget {
  const ExerciseDetailScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _isFavorite =
        context.read<WorkoutProvider>().isFavorite(widget.exerciseId);
  }

  @override
  Widget build(BuildContext context) {
    final exercise =
        context.read<WorkoutProvider>().getExerciseById(widget.exerciseId);

    if (exercise == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Exercise')),
        body: const Center(child: Text('Exercise not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(exercise.name),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.favorite : Icons.favorite_border,
              color: _isFavorite ? AppColors.premiumPink : null,
            ),
            onPressed: () async {
              await context
                  .read<WorkoutProvider>()
                  .toggleFavorite(widget.exerciseId);
              setState(() => _isFavorite = !_isFavorite);
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Hero(
              tag: 'exercise_${exercise.id}',
              child: ExerciseIconWidget(
                iconName: exercise.iconName,
                size: 160,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 24),
            Text(
              exercise.name,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              exercise.description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: Icons.timer,
                    label: 'Duration',
                    value: '${exercise.durationSeconds}s',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.local_fire_department,
                    label: 'Calories',
                    value: '${exercise.estimatedCalories} kcal',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoCard(
                    icon: Icons.category,
                    label: 'Category',
                    value: exercise.category,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _InfoCard(
                    icon: Icons.accessibility_new,
                    label: 'Body Part',
                    value: exercise.bodyPart,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Instructions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in exercise.instructions.asMap().entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GradientCard(
                  padding: const EdgeInsets.all(14),
                  animate: false,
                  delay: Duration(milliseconds: entry.key * 100),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: const TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            PremiumButton(
              label: AppStrings.startExercise,
              icon: Icons.play_arrow_rounded,
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Start a workout plan to begin exercising'),
                  ),
                );
              },
              width: double.infinity,
            ),
            const SizedBox(height: 12),
            PremiumButton(
              label: _isFavorite
                  ? AppStrings.removeFromFavorites
                  : AppStrings.addToFavorites,
              icon: _isFavorite ? Icons.favorite : Icons.favorite_border,
              isOutlined: true,
              onPressed: () async {
                await context
                    .read<WorkoutProvider>()
                    .toggleFavorite(widget.exerciseId);
                setState(() => _isFavorite = !_isFavorite);
              },
              width: double.infinity,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      padding: const EdgeInsets.all(14),
      animate: false,
      child: Column(
        children: [
          Icon(icon, color: AppColors.premiumPink, size: 22),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}
