import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../constants/app_colors.dart';

/// Animated exercise demonstration using icons with motion effects.
class ExerciseIconWidget extends StatelessWidget {
  const ExerciseIconWidget({
    super.key,
    required this.iconName,
    this.size = 120,
    this.animate = true,
  });

  final String iconName;
  final double size;
  final bool animate;

  IconData get _icon {
    const iconMap = {
      'fitness_center': Icons.fitness_center,
      'directions_run': Icons.directions_run,
      'accessibility_new': Icons.accessibility_new,
      'sports_gymnastics': Icons.sports_gymnastics,
      'self_improvement': Icons.self_improvement,
      'sports_martial_arts': Icons.sports_martial_arts,
      'hiking': Icons.hiking,
      'landscape': Icons.landscape,
      'horizontal_rule': Icons.horizontal_rule,
      'bolt': Icons.bolt,
      'rocket_launch': Icons.rocket_launch,
      'swap_vert': Icons.swap_vert,
      'emoji_events': Icons.emoji_events,
      'local_fire_department': Icons.local_fire_department,
      'whatshot': Icons.whatshot,
      'military_tech': Icons.military_tech,
      'stars': Icons.stars,
    };
    return iconMap[iconName] ?? Icons.fitness_center;
  }

  @override
  Widget build(BuildContext context) {
    Widget iconWidget = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppColors.primaryGradient,
        boxShadow: [
          BoxShadow(
            color: AppColors.premiumPink.withValues(alpha: 0.4),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(_icon, size: size * 0.45, color: AppColors.white),
    );

    if (animate) {
      iconWidget = iconWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(0.95, 0.95),
            end: const Offset(1.05, 1.05),
            duration: 1200.ms,
            curve: Curves.easeInOut,
          )
          .shimmer(
            duration: 2000.ms,
            color: AppColors.white.withValues(alpha: 0.3),
          );
    }

    return iconWidget;
  }
}
