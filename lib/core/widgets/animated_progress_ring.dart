import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class AnimatedProgressRing extends StatelessWidget {
  const AnimatedProgressRing({
    super.key,
    required this.progress,
    this.size = 120,
    this.strokeWidth = 8,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeWidth,
                  backgroundColor: AppColors.lightGrey,
                  valueColor: const AlwaysStoppedAnimation(AppColors.premiumPink),
                  strokeCap: StrokeCap.round,
                ),
              ),
              if (child != null) child!,
            ],
          ),
        );
      },
    );
  }
}
