import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/enums.dart';
import '../../data/models/exercise.dart';
import 'figure_library.dart';
import 'figure_painter.dart';
import 'figure_sequence.dart';

/// Shows an exercise demonstration from its `mediaPath`.
///
/// Supported sources, loaded only when this widget is built:
/// * `figure://<id>` – built-in procedural figure animation;
/// * `assets/…json` – a bundled Lottie animation;
/// * `assets/…png|jpg|webp` – a bundled image.
///
/// Missing or failing media falls back to a category illustration so the
/// written instructions stay usable.
class ExerciseMedia extends StatelessWidget {
  const ExerciseMedia({
    super.key,
    required this.exercise,
    this.height = 220,
    this.animate = true,
    this.showCaption = true,
  });

  final Exercise exercise;
  final double height;

  /// Set false to show a still frame (e.g. in lists).
  final bool animate;
  final bool showCaption;

  @override
  Widget build(BuildContext context) {
    final path = exercise.mediaPath;
    Widget child;
    String? caption;
    if (path != null && path.startsWith(MediaAttribution.figureScheme)) {
      final sequence = FigureLibrary.get(path.substring(MediaAttribution.figureScheme.length));
      if (sequence != null) {
        child = FigureAnimation(
          sequence: sequence,
          animate: animate,
          semanticLabel: 'Animated illustration of ${exercise.name}',
        );
        caption = ['Simplified illustration', ?sequence.caption].join(' · ');
      } else {
        child = _Fallback(exercise: exercise);
      }
    } else if (path != null && path.endsWith('.json')) {
      child = Lottie.asset(
        path,
        animate: animate && !context.reduceMotion,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _Fallback(exercise: exercise),
      );
    } else if (path != null) {
      child = Image.asset(
        path,
        fit: BoxFit.contain,
        semanticLabel: 'Illustration of ${exercise.name}',
        errorBuilder: (_, _, _) => _Fallback(exercise: exercise),
      );
    } else {
      child = _Fallback(exercise: exercise);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: height, width: double.infinity, child: child),
        if (showCaption && caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption, style: context.text.bodySmall, textAlign: TextAlign.center),
          ),
      ],
    );
  }
}

/// Loops a [FigureSequence]. With reduced motion (or [animate] false) it
/// shows the key positions side by side instead of moving.
class FigureAnimation extends StatefulWidget {
  const FigureAnimation({
    super.key,
    required this.sequence,
    this.animate = true,
    this.semanticLabel,
  });

  final FigureSequence sequence;
  final bool animate;
  final String? semanticLabel;

  @override
  State<FigureAnimation> createState() => _FigureAnimationState();
}

class _FigureAnimationState extends State<FigureAnimation> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (widget.sequence.duration * 1000).round().clamp(500, 60000)),
  );
  bool _playing = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncPlayback();
  }

  @override
  void didUpdateWidget(FigureAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPlayback();
  }

  bool get _shouldAnimate =>
      widget.animate &&
      _playing &&
      !widget.sequence.isStatic &&
      !MediaQuery.of(context).disableAnimations;

  void _syncPlayback() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  FigureColors _colors(BuildContext context) {
    final palette = context.palette;
    final body = palette.accentInk;
    return FigureColors(
      body: body,
      farLimb: body.withValues(alpha: 0.45),
      prop: palette.textSecondary,
      ground: palette.border,
      accent: AppColors.success,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors(context);
    final sequence = widget.sequence;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget figure;
    if (!widget.animate || reduceMotion || sequence.isStatic) {
      // Still key positions, so the movement is understandable without
      // motion.
      final frames = sequence.frames.take(3).toList();
      figure = Row(
        children: [
          for (var i = 0; i < frames.length; i++) ...[
            if (i > 0)
              Icon(Icons.arrow_forward_rounded, size: 16, color: context.palette.textSecondary),
            Expanded(
              child: CustomPaint(
                painter: FigurePainter(sequence: sequence, pose: frames[i].pose, colors: colors),
              ),
            ),
          ],
        ],
      );
      if (!widget.animate || sequence.isStatic) {
        figure = CustomPaint(
          painter: FigurePainter(
            sequence: sequence,
            pose: sequence.frames.length > 1 ? sequence.frames[1].pose : sequence.frames.first.pose,
            colors: colors,
          ),
          size: Size.infinite,
        );
      }
    } else {
      figure = RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(
            painter: FigurePainter(
              sequence: sequence,
              pose: sequence.poseAt(_controller.value * sequence.duration),
              colors: colors,
            ),
            size: Size.infinite,
          ),
        ),
      );
    }

    final canToggle = widget.animate && !reduceMotion && !sequence.isStatic;
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: Stack(
        children: [
          Positioned.fill(child: ExcludeSemantics(child: figure)),
          if (canToggle)
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton(
                tooltip: _playing ? 'Pause animation' : 'Play animation',
                icon: Icon(
                  _playing ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                ),
                color: context.palette.textSecondary,
                onPressed: () {
                  setState(() => _playing = !_playing);
                  _syncPlayback();
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'No demonstration available for ${exercise.name}',
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(Space.radius),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(Space.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(categoryIcon(exercise.category), size: 48, color: context.palette.accentInk),
            const SizedBox(height: Space.sm),
            Text(
              'Demonstration unavailable – follow the written steps below.',
              textAlign: TextAlign.center,
              style: context.text.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

IconData categoryIcon(ExerciseCategory category) => switch (category) {
  ExerciseCategory.warmUp => Icons.wb_sunny_outlined,
  ExerciseCategory.fullBody => Icons.accessibility_new_rounded,
  ExerciseCategory.upperBody => Icons.fitness_center_rounded,
  ExerciseCategory.lowerBody => Icons.directions_walk_rounded,
  ExerciseCategory.core => Icons.center_focus_strong_rounded,
  ExerciseCategory.cardio => Icons.favorite_border_rounded,
  ExerciseCategory.mobility => Icons.sync_rounded,
  ExerciseCategory.stretching => Icons.self_improvement_rounded,
};
