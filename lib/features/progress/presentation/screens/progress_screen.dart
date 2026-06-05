import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../workout/presentation/providers/workout_provider.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileProvider>().loadProfile();
      context.read<WorkoutProvider>().loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileProvider, WorkoutProvider>(
      builder: (context, profile, workout, _) {
        final user = profile.profile;
        if (user == null || profile.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.premiumPink),
            ),
          );
        }

        final weeklyWorkouts = workout.getWeeklyWorkoutCounts();
        final weeklyCalories = workout.getWeeklyCalorieCounts();
        final days = weeklyWorkouts.keys.toList();

        return Scaffold(
          body: RefreshIndicator(
            onRefresh: () async {
              await profile.loadProfile();
              await workout.loadData();
            },
            color: AppColors.premiumPink,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverAppBar(
                  floating: true,
                  title: Text('Progress'),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Total Workouts',
                                value: '${user.totalWorkouts}',
                                icon: Icons.fitness_center,
                                delay: 100.ms,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Total Calories',
                                value: '${user.totalCalories}',
                                icon: Icons.local_fire_department,
                                subtitle: 'kcal',
                                delay: 200.ms,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Current Streak',
                                value: '${user.currentStreak}',
                                icon: Icons.local_fire_department,
                                subtitle: 'days',
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFF4FA3),
                                    Color(0xFF1A1A1A),
                                  ],
                                ),
                                delay: 300.ms,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: StatCard(
                                title: 'Longest Streak',
                                value: '${user.longestStreak}',
                                icon: Icons.emoji_events,
                                subtitle: 'days',
                                delay: 400.ms,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Weekly Workouts',
                          style: Theme.of(context).textTheme.titleLarge,
                        ).animate().fadeIn(),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: _WorkoutBarChart(
                            days: days,
                            values: weeklyWorkouts.values.toList(),
                          ),
                        ).animate().fadeIn(delay: 200.ms),
                        const SizedBox(height: 28),
                        Text(
                          'Weekly Calories',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 220,
                          child: _CalorieLineChart(
                            days: days,
                            values: weeklyCalories.values.toList(),
                          ),
                        ).animate().fadeIn(delay: 400.ms),
                        const SizedBox(height: 28),
                        Text(
                          'Monthly Overview',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _MonthlySummary(workout: workout),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _WorkoutBarChart extends StatelessWidget {
  const _WorkoutBarChart({required this.days, required this.values});

  final List<DateTime> days;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxY = values.isEmpty
        ? 5.0
        : (values.reduce((a, b) => a > b ? a : b) + 1).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          barTouchData: BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox();
                  }
                  final day = days[index];
                  const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  return Text(
                    weekdays[day.weekday - 1],
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.lightGrey.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(values.length, (i) {
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i].toDouble(),
                  gradient: AppColors.primaryGradient,
                  width: 20,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _CalorieLineChart extends StatelessWidget {
  const _CalorieLineChart({required this.days, required this.values});

  final List<DateTime> days;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final maxY = values.isEmpty
        ? 100.0
        : (values.reduce((a, b) => a > b ? a : b) + 50).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.cardGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(
              color: AppColors.lightGrey.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= days.length) {
                    return const SizedBox();
                  }
                  return Text(
                    '${days[index].day}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  );
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(
                values.length,
                (i) => FlSpot(i.toDouble(), values[i].toDouble()),
              ),
              isCurved: true,
              gradient: AppColors.primaryGradient,
              barWidth: 3,
              dotData: FlDotData(
                show: true,
                getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                  radius: 4,
                  color: AppColors.premiumPink,
                  strokeWidth: 2,
                  strokeColor: AppColors.white,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.premiumPink.withValues(alpha: 0.3),
                    AppColors.premiumPink.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  const _MonthlySummary({required this.workout});

  final WorkoutProvider workout;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthHistory = workout.history.where(
      (h) => h.completedAt.year == now.year && h.completedAt.month == now.month,
    );

    final totalWorkouts = monthHistory.length;
    final totalCalories =
        monthHistory.fold(0, (sum, h) => sum + h.caloriesBurned);
    final totalMinutes = monthHistory.fold(
      0,
      (sum, h) => sum + h.durationSeconds ~/ 60,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4FA3), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            DateHelper.formatDate(DateTime(now.year, now.month, 1))
                .replaceAll(RegExp(r'\d+,'), '')
                .trim(),
            style: const TextStyle(
              color: AppColors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _MonthStat('Workouts', '$totalWorkouts'),
              _MonthStat('Calories', '$totalCalories'),
              _MonthStat('Minutes', '$totalMinutes'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }
}

class _MonthStat extends StatelessWidget {
  const _MonthStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: AppColors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
