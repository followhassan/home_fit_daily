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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
      context.read<WorkoutProvider>().loadData();
    });
  }

  Future<void> _refresh() async {
    await Future.wait([
      context.read<ProfileProvider>().loadProfile(),
      context.read<WorkoutProvider>().loadData(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileProvider, WorkoutProvider>(
      builder: (context, profile, workout, _) {
        if (profile.isLoading || workout.isLoading) {
          return const _HomeSkeleton();
        }

        final user = profile.profile!;
        final quote = MotivationQuotes.quoteForDay(DateTime.now());
        final todayPlan = workout.plans.first;

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.premiumPink,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
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
                              title: 'Current Streak',
                              value: '${user.currentStreak}',
                              icon: Icons.local_fire_department,
                              subtitle: 'days',
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF4FA3), Color(0xFF1A1A1A)],
                              ),
                              delay: 100.ms,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: StatCard(
                              title: 'Calories Today',
                              value: '${workout.todayCalories}',
                              icon: Icons.whatshot,
                              subtitle: 'kcal',
                              delay: 200.ms,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      StatCard(
                        title: 'Total Workouts',
                        value: '${user.totalWorkouts}',
                        icon: Icons.fitness_center,
                        subtitle: '${user.totalCalories} total kcal burned',
                        delay: 300.ms,
                      ),
                      const SizedBox(height: 24),
                      _TodayWorkoutCard(plan: todayPlan),
                      const SizedBox(height: 16),
                      PremiumButton(
                        label: AppStrings.quickStart,
                        icon: Icons.play_arrow_rounded,
                        onPressed: () => _startWorkout(context, todayPlan),
                        width: double.infinity,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Featured Plans',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 200,
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
                      Text(
                        'Recent Activity',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      if (workout.getRecentActivity().isEmpty)
                        GradientCard(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No workouts yet. Start your first one!',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
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
                      const SizedBox(height: 100),
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
        ).animate().fadeIn().slideX(begin: -0.1),
        Text(
          name,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
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
        children: [
          const Icon(Icons.format_quote, color: AppColors.white, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              quote,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.white,
                    fontStyle: FontStyle.italic,
                  ),
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.today, color: AppColors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's Workout",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.premiumPink,
                      ),
                ),
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  '${plan.durationMinutes} min • ${plan.estimatedCalories} kcal',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
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
        width: 160,
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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.premiumPink.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(
              Icons.fitness_center,
              color: AppColors.white.withValues(alpha: 0.8),
              size: 32,
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plan.name,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  '${plan.durationMinutes} min',
                  style: TextStyle(
                    color: AppColors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.2);
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          SkeletonLoader(width: 150, height: 24),
          SizedBox(height: 8),
          SkeletonLoader(width: 200, height: 32),
          SizedBox(height: 20),
          SkeletonCard(),
          SizedBox(height: 12),
          SkeletonCard(),
        ],
      ),
    );
  }
}
