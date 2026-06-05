import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../achievements/presentation/providers/achievement_provider.dart';
import '../../../challenges/presentation/providers/challenge_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/workout_provider.dart';

class WorkoutCompleteScreen extends StatefulWidget {
  const WorkoutCompleteScreen({
    super.key,
    required this.planId,
    required this.planName,
    required this.durationSeconds,
    required this.caloriesBurned,
    required this.exerciseCount,
    this.difficulty = '',
  });

  final String planId;
  final String planName;
  final int durationSeconds;
  final int caloriesBurned;
  final int exerciseCount;
  final String difficulty;

  @override
  State<WorkoutCompleteScreen> createState() => _WorkoutCompleteScreenState();
}

class _WorkoutCompleteScreenState extends State<WorkoutCompleteScreen> {
  @override
  void initState() {
    super.initState();
    _saveResults();
  }

  Future<void> _saveResults() async {
    final workout = context.read<WorkoutProvider>();
    final profile = context.read<ProfileProvider>();
    final achievements = context.read<AchievementProvider>();
    final challenges = context.read<ChallengeProvider>();

    await workout.completeWorkout(
      planId: widget.planId,
      planName: widget.planName,
      durationSeconds: widget.durationSeconds,
      caloriesBurned: widget.caloriesBurned,
      exerciseCount: widget.exerciseCount,
      difficulty: widget.difficulty,
    );

    await profile.recordWorkout(widget.caloriesBurned);
    await achievements.checkAchievements(profile.profile!);

    final minutes = widget.durationSeconds ~/ 60;
    await challenges.updateProgress(
      todayWorkouts: workout.todayWorkouts,
      todayMinutes: minutes,
      todayCalories: workout.todayCalories,
      weeklyWorkouts: workout.getWeeklyWorkoutTotal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final minutes = widget.durationSeconds ~/ 60;
    final seconds = widget.durationSeconds % 60;

    return Scaffold(
      backgroundColor: AppColors.deepBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppColors.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.premiumPink.withValues(alpha: 0.5),
                      blurRadius: 40,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 60,
                  color: AppColors.white,
                ),
              )
                  .animate()
                  .scale(duration: 600.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 1500.ms),
              const SizedBox(height: 32),
              Text(
                'Workout Complete!',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'Great job! You crushed it 💪',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ).animate().fadeIn(delay: 500.ms),
              const SizedBox(height: 40),
              Row(
                children: [
                  Expanded(
                    child: _ResultCard(
                      icon: Icons.timer,
                      label: 'Duration',
                      value: '$minutes:${seconds.toString().padLeft(2, '0')}',
                      delay: 600.ms,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ResultCard(
                      icon: Icons.local_fire_department,
                      label: 'Calories',
                      value: '${widget.caloriesBurned}',
                      delay: 700.ms,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ResultCard(
                icon: Icons.fitness_center,
                label: 'Exercises',
                value: '${widget.exerciseCount}',
                delay: 800.ms,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.popUntil(
                    context,
                    (route) => route.isFirst,
                  ),
                  child: const Text('Back to Home'),
                ),
              ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.3),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.delay,
  });

  final IconData icon;
  final String label;
  final String value;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.lightGrey.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.premiumPink, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    )
        .animate(delay: delay)
        .fadeIn()
        .scale(begin: const Offset(0.9, 0.9));
  }
}
