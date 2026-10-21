import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/data/motivation_quotes.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../../../../core/widgets/premium_button.dart';
import '../../../../core/widgets/skeleton_loader.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../profile/data/models/user_profile_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../workout/presentation/providers/workout_provider.dart';
import '../../../workout/presentation/screens/plan_detail_screen.dart';
import '../../../workout/presentation/screens/workout_session_screen.dart';
import '../../../workout/domain/entities/workout_plan_entity.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ProfileProvider>().loadProfile(),
      context.read<WorkoutProvider>().loadData(),
    ]);
  }

  WorkoutPlanEntity? _todayPlan(WorkoutProvider workout) {
    if (workout.plans.isEmpty) return null;
    final index = DateTime.now().weekday % workout.plans.length;
    return workout.plans[index];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileProvider, WorkoutProvider>(
      builder: (context, profile, workout, _) {
        if (profile.isLoading || workout.isLoading) {
          return const _HomeSkeleton();
        }

        final user = profile.profile ?? UserProfileModel();
        final todayPlan = _todayPlan(workout);
        final quote = MotivationQuotes.quoteForDay(DateTime.now());

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.premiumPink,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverAppBar(
                floating: true,
                pinned: false,
                expandedHeight: 0,
                backgroundColor: AppColors.deepBlack,
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.fitness_center,
                        color: AppColors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text('HomeFit'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _WelcomeSection(name: user.name),
                      const SizedBox(height: 20),
                      _QuoteCard(quote: quote),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: StatCard(
                              title: 'Streak',
                              value: '${user.currentStreak}',
                              icon: Icons.local_fire_department,
                              subtitle: 'days',
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFFF4FA3),
                                  Color(0xFF1A1A1A),
                                ],
                              ),
                              delay: 100.ms,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Today',
                              value: '${workout.todayCalories}',
                              icon: Icons.whatshot,
                              subtitle: 'kcal burned',
                              delay: 200.ms,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StatCard(
                        title: 'All Time Workouts',
                        value: '${user.totalWorkouts}',
                        icon: Icons.fitness_center,
                        subtitle: '${user.totalCalories} kcal total',
                        delay: 300.ms,
                      ),
                      const SizedBox(height: 24),
                      if (todayPlan != null) ...[
                        _TodayWorkoutCard(plan: todayPlan),
                        const SizedBox(height: 16),
                        PremiumButton(
                          label: AppStrings.quickStart,
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => _startWorkout(context, todayPlan),
                          width: double.infinity,
                        ),
                      ],
                      const SizedBox(height: 28),
                      _SectionTitle(
                        icon: Icons.star_rounded,
                        title: 'Featured Plans',
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: workout.plans.length,
                    itemBuilder: (context, i) {
                      final plan = workout.plans[i];
                      return _FeaturedPlanCard(
                        plan: plan,
                        onTap: () => _openPlan(context, plan),
                      );
                    },
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle(
                        icon: Icons.history_rounded,
                        title: 'Recent Activity',
                      ),
                      const SizedBox(height: 12),
                      if (workout.getRecentActivity().isEmpty)
                        GradientCard(
                          child: Column(
                            children: [
                              Icon(
                                Icons.self_improvement,
                                size: 48,
                                color: AppColors.premiumPink.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No workouts yet',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap Quick Start above to begin your first session!',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              if (todayPlan != null) ...[
                                const SizedBox(height: 16),
                                PremiumButton(
                                  label: 'Start First Workout',
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: () =>
                                      _startWorkout(context, todayPlan),
                                  width: double.infinity,
                                ),
                              ],
                            ],
                          ),
                        )
                      else
                        ...workout.getRecentActivity().map(
                              (h) => _ActivityItem(
                                name: h.planName,
                                calories: h.caloriesBurned,
                                date: h.completedAt,
                              ),
                            ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openPlan(BuildContext context, WorkoutPlanEntity plan) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlanDetailScreen(planId: plan.id)),
    );
  }

  void _startWorkout(BuildContext context, WorkoutPlanEntity plan) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => WorkoutSessionScreen(planId: plan.id)),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.premiumPink, size: 22),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 17
            ? 'Good Afternoon'
            : 'Good Evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          greeting,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ready for today\'s workout?',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final String quote;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: const LinearGradient(
        colors: [Color(0xFFFF4FA3), Color(0xFF1A1A1A)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.format_quote, color: AppColors.white, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Motivation',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.white.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  quote,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.white,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayWorkoutCard extends StatelessWidget {
  const _TodayWorkoutCard({required this.plan});

  final WorkoutPlanEntity plan;

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PlanDetailScreen(planId: plan.id),
          ),
        );
      },
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bolt, color: AppColors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Workout",
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.premiumPink,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.durationMinutes} min  •  ${plan.estimatedCalories} kcal  •  ${plan.exerciseCount} exercises',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: AppColors.premiumPink, size: 16),
        ],
      ),
    );
  }
}

class _FeaturedPlanCard extends StatelessWidget {
  const _FeaturedPlanCard({required this.plan, required this.onTap});

  final WorkoutPlanEntity plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(plan.gradientStart),
              Color(plan.gradientEnd),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.premiumPink.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              plan.difficultyLabel,
              style: TextStyle(
                color: AppColors.white.withValues(alpha: 0.8),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${plan.durationMinutes} min • ${plan.estimatedCalories} kcal',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.75),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  const _ActivityItem({
    required this.name,
    required this.calories,
    required this.date,
  });

  final String name;
  final int calories;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GradientCard(
        padding: const EdgeInsets.all(14),
        animate: false,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.premiumPink.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.premiumPink,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '$calories kcal • ${_formatDate(date)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return 'Today';
    }
    return '${d.day}/${d.month}/${d.year}';
  }
}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 56, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 150, height: 20),
                SizedBox(height: 8),
                SkeletonLoader(width: 200, height: 28),
                SizedBox(height: 20),
                SkeletonCard(),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: SkeletonCard()),
                    SizedBox(width: 12),
                    Expanded(child: SkeletonCard()),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
