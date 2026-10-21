import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/exercise_icon_widget.dart';
import '../../../../core/widgets/gradient_card.dart';
import '../providers/achievement_provider.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AchievementProvider>().loadAchievements();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Achievements')),
      body: Consumer<AchievementProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.premiumPink),
            );
          }

          final unlocked = provider.unlocked.length;
          final total = provider.achievements.length;

          return RefreshIndicator(
            onRefresh: provider.loadAchievements,
            color: AppColors.premiumPink,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                GradientCard(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF4FA3), Color(0xFF1A1A1A)],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: AppColors.white,
                        size: 40,
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$unlocked / $total Unlocked',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          Text(
                            'Keep pushing to unlock more!',
                            style: TextStyle(
                              color: AppColors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ...provider.achievements.asMap().entries.map(
                      (entry) => _AchievementBadge(
                        title: entry.value.title,
                        description: entry.value.description,
                        iconName: entry.value.iconName,
                        isUnlocked: entry.value.isUnlocked,
                        unlockedAt: entry.value.unlockedAt,
                        delay: Duration(milliseconds: entry.key * 100),
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

class _AchievementBadge extends StatelessWidget {
  const _AchievementBadge({
    required this.title,
    required this.description,
    required this.iconName,
    required this.isUnlocked,
    this.unlockedAt,
    required this.delay,
  });

  final String title;
  final String description;
  final String iconName;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GradientCard(
        delay: delay,
        child: Row(
          children: [
            Opacity(
              opacity: isUnlocked ? 1.0 : 0.3,
              child: ExerciseIconWidget(
                iconName: iconName,
                size: 64,
                animate: isUnlocked,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isUnlocked
                              ? AppColors.white
                              : AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (isUnlocked && unlockedAt != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Unlocked ${_formatDate(unlockedAt!)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.premiumPink,
                            fontSize: 10,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              isUnlocked ? Icons.lock_open : Icons.lock,
              color: isUnlocked ? AppColors.success : AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    )
        .animate(delay: delay)
        .fadeIn()
        .scale(
          begin: isUnlocked ? const Offset(0.95, 0.95) : const Offset(1, 1),
        );
  }

  String _formatDate(DateTime d) =>
      '${d.day}/${d.month}/${d.year}';
}
