import 'dart:math' as math;
import 'dart:ui';

/// Simplified stick-figure model used for the built-in exercise
/// demonstrations.
///
/// Angles are in degrees and describe the direction of each body segment in
/// screen space: 0 points straight down, 90 points forward (to the right in
/// side view), 180 points up and -90 points backward. Every angle is
/// absolute, not relative to the parent segment, which keeps keyframes easy
/// to author and to read.
///
/// In side view the figure faces right; "R" limbs are the near side (drawn
/// in front) and "L" limbs the far side. In front view "L" limbs are on the
/// left of the screen. Front view is also used for top-down and rear views
/// by rotating the torso; segment scales approximate foreshortening for
/// limbs pointing toward or away from the viewer.
enum FigureView { side, front }

enum Joint {
  hip,
  hipL,
  hipR,
  neck,
  head,
  shoulderL,
  shoulderR,
  elbowL,
  elbowR,
  wristL,
  wristR,
  kneeL,
  kneeR,
  ankleL,
  ankleR,
  toeL,
  toeR,
}

/// Segment lengths for a figure about 94 units tall.
abstract final class Body {
  static const torso = 30.0;
  static const neck = 4.0;
  static const headRadius = 6.0;
  static const upperArm = 17.0;
  static const forearm = 15.0;
  static const thigh = 24.0;
  static const shin = 24.0;
  static const foot = 6.0;

  /// Half-widths used in front view.
  static const hipHalfWidth = 5.0;
  static const shoulderHalfWidth = 8.0;
}

/// Index of each animatable value in [Pose.values].
enum P {
  torso,
  head,
  spine,
  shrug,
  protract,
  armL,
  foreL,
  armR,
  foreR,
  thighL,
  shinL,
  footL,
  thighR,
  shinR,
  footR,
  lift,
  dx,
  torsoScale,
  foreScaleL,
  foreScaleR,
  thighScaleL,
  thighScaleR,
  shinScaleL,
  shinScaleR,
  footScale,
}

class Pose {
  Pose({
    double torso = 180,
    double head = 0,
    double spine = 0,
    double shrug = 0,
    double protract = 0,
    double armL = 0,
    double foreL = 0,
    double armR = 0,
    double foreR = 0,
    double thighL = 0,
    double shinL = 0,
    double footL = 90,
    double thighR = 0,
    double shinR = 0,
    double footR = 90,
    double lift = 0,
    double dx = 0,
    double torsoScale = 1,
    double foreScaleL = 1,
    double foreScaleR = 1,
    double thighScaleL = 1,
    double thighScaleR = 1,
    double shinScaleL = 1,
    double shinScaleR = 1,
    double footScale = 1,
  }) : _list = List.unmodifiable([
         torso,
         head,
         spine,
         shrug,
         protract,
         armL,
         foreL,
         armR,
         foreR,
         thighL,
         shinL,
         footL,
         thighR,
         shinR,
         footR,
         lift,
         dx,
         torsoScale,
         foreScaleL,
         foreScaleR,
         thighScaleL,
         thighScaleR,
         shinScaleL,
         shinScaleR,
         footScale,
       ]);

  Pose._fromList(List<double> values) : _list = List.unmodifiable(values);

  final List<double> _list;

  double operator [](P key) => _list[key.index];

  /// Returns a copy with the given values replaced.
  Pose set(Map<P, double> changes) {
    final list = List<double>.of(_list);
    changes.forEach((key, value) => list[key.index] = value);
    return Pose._fromList(list);
  }

  /// Both arms set to the same angles (upper arm, forearm).
  Pose arms(double upper, [double? fore]) =>
      set({P.armL: upper, P.armR: upper, P.foreL: fore ?? upper, P.foreR: fore ?? upper});

  /// Both legs set to the same angles (thigh, shin, optional foot).
  Pose legs(double thigh, [double? shin, double? foot]) => set({
    P.thighL: thigh,
    P.thighR: thigh,
    P.shinL: shin ?? thigh,
    P.shinR: shin ?? thigh,
    P.footL: ?foot,
    P.footR: ?foot,
  });

  /// Left/right mirror for front-view poses.
  Pose mirrored() {
    final l = _list;
    double v(P p) => l[p.index];
    return set({
      P.torso: 360 - v(P.torso),
      P.armL: -v(P.armR),
      P.foreL: -v(P.foreR),
      P.armR: -v(P.armL),
      P.foreR: -v(P.foreL),
      P.thighL: -v(P.thighR),
      P.shinL: -v(P.shinR),
      P.footL: -v(P.footR),
      P.thighR: -v(P.thighL),
      P.shinR: -v(P.shinL),
      P.footR: -v(P.footL),
      P.foreScaleL: v(P.foreScaleR),
      P.foreScaleR: v(P.foreScaleL),
      P.thighScaleL: v(P.thighScaleR),
      P.thighScaleR: v(P.thighScaleL),
      P.shinScaleL: v(P.shinScaleR),
      P.shinScaleR: v(P.shinScaleL),
      P.dx: -v(P.dx),
    });
  }

  static Pose lerp(Pose a, Pose b, double t) {
    final la = a._list;
    final lb = b._list;
    return Pose._fromList([for (var i = 0; i < la.length; i++) la[i] + (lb[i] - la[i]) * t]);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Pose) return false;
    final a = _list;
    final b = other._list;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_list);
}

/// Which joint stays fixed horizontally across frames.
enum Anchor { hip, feet, ankleL, ankleR, hands, wristR, head, kneeR }

Offset dirOf(double degrees) {
  final r = degrees * math.pi / 180;
  return Offset(math.sin(r), math.cos(r));
}

/// Angle (in this model's convention) of a vector.
double angleOf(Offset v) => math.atan2(v.dx, v.dy) * 180 / math.pi;

/// Two-segment inverse kinematics: absolute angles (upper, lower) that reach
/// [target] (relative to the root joint). [bend] chooses the elbow/knee side.
(double, double) solveTwoBone(Offset target, double upper, double lower, {double bend = 1}) {
  final d = target.distance.clamp((upper - lower).abs() + 0.01, upper + lower - 0.01);
  final cosA = ((upper * upper + d * d - lower * lower) / (2 * upper * d)).clamp(-1.0, 1.0);
  final a = math.acos(cosA) * 180 / math.pi;
  final base = angleOf(target);
  final a1 = base + (bend >= 0 ? a : -a);
  final elbow = dirOf(a1) * upper;
  return (a1, angleOf(target - elbow));
}

/// Solved joint positions plus the spine bend for drawing.
class FigureFrame {
  const FigureFrame(this.joints, this.spineControl);

  final Map<Joint, Offset> joints;

  /// Control point for drawing the torso as a curve.
  final Offset spineControl;
}

/// Solves joint positions for a pose. The result has the ground at y = 0
/// (up is negative) and the anchor joint at x = 0.
FigureFrame solvePose(Pose p, FigureView view, Anchor anchor, {bool grounded = true}) {
  final j = <Joint, Offset>{};
  const hip = Offset.zero;
  j[Joint.hip] = hip;
  final up = dirOf(p[P.torso]);
  final torsoLength = Body.torso * p[P.torsoScale];
  final neck = hip + up * torsoLength;
  j[Joint.neck] = neck;
  j[Joint.head] = neck + dirOf(p[P.torso] + p[P.head]) * (Body.neck + Body.headRadius);

  final front = view == FigureView.front;
  // Perpendicular to the torso: screen-right when upright; in side view this
  // is the "front" of the body.
  final across = Offset(-up.dy, up.dx);
  final shoulderBase =
      hip + up * (torsoLength - 2 * p[P.torsoScale] + p[P.shrug]) + across * p[P.protract];
  final sL = front ? shoulderBase - across * Body.shoulderHalfWidth : shoulderBase;
  final sR = front ? shoulderBase + across * Body.shoulderHalfWidth : shoulderBase;
  final hL = front ? hip - across * Body.hipHalfWidth : hip;
  final hR = front ? hip + across * Body.hipHalfWidth : hip;
  j[Joint.shoulderL] = sL;
  j[Joint.shoulderR] = sR;
  j[Joint.hipL] = hL;
  j[Joint.hipR] = hR;

  j[Joint.elbowL] = sL + dirOf(p[P.armL]) * Body.upperArm;
  j[Joint.wristL] = j[Joint.elbowL]! + dirOf(p[P.foreL]) * Body.forearm * p[P.foreScaleL];
  j[Joint.elbowR] = sR + dirOf(p[P.armR]) * Body.upperArm;
  j[Joint.wristR] = j[Joint.elbowR]! + dirOf(p[P.foreR]) * Body.forearm * p[P.foreScaleR];

  j[Joint.kneeL] = hL + dirOf(p[P.thighL]) * Body.thigh * p[P.thighScaleL];
  j[Joint.ankleL] = j[Joint.kneeL]! + dirOf(p[P.shinL]) * Body.shin * p[P.shinScaleL];
  j[Joint.toeL] = j[Joint.ankleL]! + dirOf(p[P.footL]) * Body.foot * p[P.footScale];
  j[Joint.kneeR] = hR + dirOf(p[P.thighR]) * Body.thigh * p[P.thighScaleR];
  j[Joint.ankleR] = j[Joint.kneeR]! + dirOf(p[P.shinR]) * Body.shin * p[P.shinScaleR];
  j[Joint.toeR] = j[Joint.ankleR]! + dirOf(p[P.footR]) * Body.foot * p[P.footScale];

  final anchorX = switch (anchor) {
    Anchor.hip => hip.dx,
    Anchor.feet => (j[Joint.ankleL]!.dx + j[Joint.ankleR]!.dx) / 2,
    Anchor.ankleL => j[Joint.ankleL]!.dx,
    Anchor.ankleR => j[Joint.ankleR]!.dx,
    Anchor.hands => (j[Joint.wristL]!.dx + j[Joint.wristR]!.dx) / 2,
    Anchor.wristR => j[Joint.wristR]!.dx,
    Anchor.head => j[Joint.head]!.dx,
    Anchor.kneeR => j[Joint.kneeR]!.dx,
  };

  var dy = 0.0;
  if (grounded) {
    // Rest the lowest point of the body on the ground.
    var lowest = -double.infinity;
    for (final entry in j.entries) {
      final y = entry.key == Joint.head ? entry.value.dy + Body.headRadius : entry.value.dy;
      if (y > lowest) lowest = y;
    }
    dy = -lowest - p[P.lift];
  }
  final shift = Offset(-anchorX + p[P.dx], dy);
  // Positive spine values round the back (bulge away from the front).
  final control = (hip + neck) / 2 - across * p[P.spine] + shift;
  return FigureFrame(j.map((k, v) => MapEntry(k, v + shift)), control);
}
