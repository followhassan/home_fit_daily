import 'dart:ui';

import 'figure_model.dart';

/// Scenery and equipment drawn with the figure.
sealed class FigureProp {
  const FigureProp();
}

/// A floor mat under the figure.
class MatProp extends FigureProp {
  const MatProp();
}

/// A vertical wall (or door frame) at [x] in anchored coordinates.
class WallProp extends FigureProp {
  const WallProp(this.x, {this.height = 75});
  final double x;
  final double height;
}

/// A side-view chair whose seat front edge is at [x]. With [behind] the
/// seat and backrest extend to the left of [x], otherwise to the right.
class ChairProp extends FigureProp {
  const ChairProp(this.x, {this.seatHeight = 24, this.behind = true});
  final double x;
  final double seatHeight;
  final bool behind;
}

/// A resistance band drawn between two joints.
class BandProp extends FigureProp {
  const BandProp(this.from, this.to);
  final Joint from;
  final Joint to;
}

/// A dumbbell held at each listed joint.
class DumbbellProp extends FigureProp {
  const DumbbellProp([this.at = const [Joint.wristL, Joint.wristR]]);
  final List<Joint> at;
}

class KeyFrame {
  const KeyFrame(this.pose, {this.hold = 0.35, this.move = 0.9});

  final Pose pose;

  /// Seconds to hold this pose.
  final double hold;

  /// Seconds to move from this pose to the next.
  final double move;
}

/// A looping keyframe animation for one exercise.
class FigureSequence {
  FigureSequence({
    required this.frames,
    this.view = FigureView.side,
    this.anchor = Anchor.feet,
    this.props = const [],
    this.showGround = true,
    this.caption,
  }) : assert(frames.isNotEmpty);

  final List<KeyFrame> frames;
  final FigureView view;
  final Anchor anchor;
  final List<FigureProp> props;

  /// False for top-down views, which have no floor line.
  final bool showGround;

  /// Short note about the viewpoint, e.g. "Seen from above".
  final String? caption;

  late final double duration = frames.length == 1
      ? frames.first.hold
      : frames.fold(0.0, (sum, f) => sum + f.hold + f.move);

  bool get isStatic => frames.length == 1;

  FigureFrame solve(Pose pose) => solvePose(pose, view, anchor, grounded: showGround);

  /// Pose at [seconds] into the loop, with eased transitions.
  Pose poseAt(double seconds) {
    if (frames.length == 1) return frames.first.pose;
    var t = seconds % duration;
    for (var i = 0; i < frames.length; i++) {
      final f = frames[i];
      if (t < f.hold) return f.pose;
      t -= f.hold;
      if (t < f.move) {
        final next = frames[(i + 1) % frames.length].pose;
        return Pose.lerp(f.pose, next, _ease(t / f.move));
      }
      t -= f.move;
    }
    return frames.first.pose;
  }

  static double _ease(double t) => t < 0.5 ? 2 * t * t : 1 - (-2 * t + 2) * (-2 * t + 2) / 2;

  /// Bounding box of every frame and the props, used to fit the drawing.
  late final Rect bounds = _computeBounds();

  Rect _computeBounds() {
    Rect? rect;
    void include(Offset p, [double pad = 3]) {
      final r = Rect.fromCenter(center: p, width: pad * 2, height: pad * 2);
      rect = rect == null ? r : rect!.expandToInclude(r);
    }

    // Sample transitions too, so motion never leaves the frame.
    const samples = 6;
    for (var i = 0; i < frames.length; i++) {
      final a = frames[i].pose;
      final b = frames[(i + 1) % frames.length].pose;
      for (var s = 0; s <= (frames.length == 1 ? 0 : samples); s++) {
        final frame = solve(Pose.lerp(a, b, s / samples));
        for (final entry in frame.joints.entries) {
          include(entry.value, entry.key == Joint.head ? Body.headRadius + 2.5 : 4);
        }
      }
    }
    for (final prop in props) {
      switch (prop) {
        case WallProp(:final x, :final height):
          include(Offset(x, 0));
          include(Offset(x, -height));
        case ChairProp(:final x, :final seatHeight, :final behind):
          final back = behind ? x - 16 : x + 16;
          include(Offset(x, -seatHeight));
          include(Offset(back, -seatHeight - 22));
          include(Offset(back, 0));
        case MatProp() || BandProp() || DumbbellProp():
          break;
      }
    }
    if (showGround) include(Offset(rect!.left, 0));
    return rect!;
  }
}
