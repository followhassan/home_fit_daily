import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/animated_progress_ring.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../providers/challenge_provider.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChallengeProvider>().loadChallenges();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<ChallengeProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.premiumPink),
            );
          }

          return RefreshIndicator(
            onRefresh: provider.loadChallenges,
            color: AppColors.premiumPink,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                const SliverAppBar(
                  floating: true,
                  title: Text('Challenges'),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily Challenges',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...provider.dailyChallenges.asMap().entries.map(
                              (entry) => _ChallengeCard(
                                title: entry.value.title,
                                description: entry.value.description,
                                current: entry.value.currentValue,
                                target: entry.value.targetValue,
                                unit: entry.value.unit,
                                isCompleted: entry.value.isCompleted,
                                delay: Duration(milliseconds: entry.key * 100),
                              ),
                            ),
                        const SizedBox(height: 24),
                        Text(
                          'Weekly Challenges',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        ...provider.weeklyChallenges.asMap().entries.map(
                              (entry) => _ChallengeCard(
                                title: entry.value.title,
                                description: entry.value.description,
                                current: entry.value.currentValue,
                                target: entry.value.targetValue,
                                unit: entry.value.unit,
                                isCompleted: entry.value.isCompleted,
                                delay: Duration(
                                  milliseconds:
                                      (provider.dailyChallenges.length +
                                              entry.key) *
                                          100,
                                ),
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
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.title,
    required this.description,
    required this.current,
    required this.target,
    required this.unit,
    required this.isCompleted,
    required this.delay,
  });

  final String title;
  final String description;
  final int current;
  final int target;
  final String unit;
  final bool isCompleted;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? current / target : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GradientCard(
        delay: delay,
        child: Row(
          children: [
            AnimatedProgressRing(
              progress: progress.clamp(0.0, 1.0),
              size: 64,
              strokeWidth: 5,
              child: isCompleted
                  ? const Icon(
                      Icons.check,
                      color: AppColors.success,
                      size: 24,
                    )
                  : Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                        ),
                      ),
                      if (isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Done',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 4,
                      backgroundColor: AppColors.lightGrey,
                      valueColor: AlwaysStoppedAnimation(
                        isCompleted ? AppColors.success : AppColors.premiumPink,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$current / $target $unit',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.premiumPink,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate(delay: delay).fadeIn().slideX(begin: 0.1);
  }
}
