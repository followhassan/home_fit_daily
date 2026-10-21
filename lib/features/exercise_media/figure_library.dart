import 'dart:ui';

import 'figure_model.dart';
import 'figure_sequence.dart';

/// The built-in demonstration animations, keyed by exercise ID.
///
/// These are simplified, procedurally drawn stick figures created for this
/// app. They show the general shape of each movement; the written
/// instructions remain the primary technique reference.
abstract final class FigureLibrary {
  static final Map<String, FigureSequence> _cache = {};

  static bool has(String id) => _builders.containsKey(id);

  static Iterable<String> get ids => _builders.keys;

  static FigureSequence? get(String id) {
    final cached = _cache[id];
    if (cached != null) return cached;
    final builder = _builders[id];
    if (builder == null) return null;
    return _cache[id] = builder();
  }
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

KeyFrame _k(Pose pose, [double hold = 0.3, double move = 0.8]) =>
    KeyFrame(pose, hold: hold, move: move);

/// Sets the near (R) arm so the wrist lands at [target] relative to the
/// shoulder. [bend] picks which side the elbow points.
Pose _reachR(Pose p, Offset target, {double bend = -1}) {
  final (a, b) = solveTwoBone(target, Body.upperArm, Body.forearm, bend: bend);
  return p.set({P.armR: a, P.foreR: b});
}

Pose _reachL(Pose p, Offset target, {double bend = 1}) {
  final (a, b) = solveTwoBone(target, Body.upperArm, Body.forearm, bend: bend);
  return p.set({P.armL: a, P.foreL: b});
}

Pose _reachBoth(Pose p, Offset target, {double bend = -1}) =>
    _reachL(_reachR(p, target, bend: bend), target, bend: bend);

// Side-view base poses (facing right).
/// Standing, arms slightly offset so both stay visible in side view.
Pose _stand() => Pose(armL: 7, foreL: 12, armR: -6, foreR: -2);
Pose _standArmsUp() => Pose().arms(180);
Pose _squat({double arms = 90}) =>
    Pose(torso: 145, thighL: 80, shinL: -25, thighR: 80, shinR: -25).arms(arms);
Pose _halfSquat() => Pose(torso: 160, thighL: 45, shinL: -15, thighR: 45, shinR: -15).arms(60);
Pose _plank() => Pose(
  torso: 114,
  thighL: -66,
  shinL: -66,
  footL: 15,
  thighR: -66,
  shinR: -66,
  footR: 15,
).arms(0);
Pose _forearmPlank() => Pose(
  torso: 103,
  thighL: -77,
  shinL: -77,
  footL: 15,
  thighR: -77,
  shinR: -77,
  footR: 15,
).arms(0, 90);
Pose _quadruped() =>
    Pose(torso: 105, thighL: 0, shinL: -90, footL: -90, thighR: 0, shinR: -90, footR: -90).arms(0);
Pose _supine() => Pose(torso: -90, footL: 180, footR: 180).arms(90).legs(90);
Pose _supineKneesBent() =>
    Pose(torso: -90, thighL: 135, shinL: 16, thighR: 135, shinR: 16).arms(90);
Pose _prone() => Pose(torso: 90, footL: -90, footR: -90).arms(-90).legs(-90);
Pose _longSit() => Pose(torso: 180, footL: 180, footR: 180).legs(90).arms(-25, -20);
Pose _kneel() => Pose(thighL: 0, shinL: -90, footL: -90, thighR: 0, shinR: -90, footR: -90);
Pose _downDog() => Pose(
  torso: 48,
  thighL: -32,
  shinL: -32,
  footL: 90,
  thighR: -32,
  shinR: -32,
  footR: 90,
).arms(48);

// Front-view base poses.
Pose _frontStand() =>
    Pose(footL: -90, footR: 90).set({P.armL: -8, P.foreL: -8, P.armR: 8, P.foreR: 8});
Pose _frontHandsOnHips() => _frontStand().set({P.armL: -35, P.foreL: 55, P.armR: 35, P.foreR: -55});

/// Hands together in front of the chest (front view).
Pose _frontHandsAtChest(Pose p) =>
    _reachL(_reachR(p, const Offset(-6, 12), bend: 1), const Offset(6, 12), bend: -1);

FigureSequence _seq(
  List<KeyFrame> frames, {
  FigureView view = FigureView.side,
  Anchor anchor = Anchor.feet,
  List<FigureProp> props = const [],
  bool ground = true,
  String? caption,
}) => FigureSequence(
  frames: frames,
  view: view,
  anchor: anchor,
  props: props,
  showGround: ground,
  caption: caption,
);

// -----------------------------------------------------------------------------
// Sequences
// -----------------------------------------------------------------------------

final Map<String, FigureSequence Function()> _builders = {
  // --- Warm-up ---------------------------------------------------------------
  'march_in_place': () {
    final a = _stand().set({
      P.thighR: 72,
      P.shinR: 2,
      P.armL: 35,
      P.foreL: 75,
      P.armR: -25,
      P.foreR: -5,
    });
    final b = _stand().set({
      P.thighL: 72,
      P.shinL: 2,
      P.armR: 35,
      P.foreR: 75,
      P.armL: -25,
      P.foreL: -5,
    });
    return _seq([_k(a, 0.05, 0.5), _k(b, 0.05, 0.5)], anchor: Anchor.hip);
  },
  'arm_circles': () {
    final level = _frontStand().set({P.armL: -90, P.foreL: -90, P.armR: 90, P.foreR: 90});
    final up = level.set({P.armL: -103, P.foreL: -108, P.armR: 103, P.foreR: 108});
    final down = level.set({P.armL: -77, P.foreL: -72, P.armR: 77, P.foreR: 72});
    return _seq([
      _k(level, 0, 0.3),
      _k(up, 0, 0.3),
      _k(level, 0, 0.3),
      _k(down, 0, 0.3),
    ], view: FigureView.front);
  },
  'shoulder_rolls': () {
    final base = _stand();
    return _seq([
      _k(base.set({P.shrug: 3.5}), 0.1, 0.45),
      _k(base.set({P.shrug: 1.5, P.protract: -3, P.armL: -6, P.armR: -6}), 0.1, 0.45),
      _k(base, 0.1, 0.45),
      _k(base.set({P.shrug: 1, P.protract: 3, P.armL: 6, P.armR: 6}), 0.1, 0.45),
    ]);
  },
  'hip_circles': () {
    final base = _frontHandsOnHips();
    return _seq([
      _k(base.set({P.thighL: -7, P.shinL: -7, P.thighR: -7, P.shinR: -7, P.torso: 176}), 0.1, 0.6),
      _k(base.set({P.thighL: 4, P.shinL: -4, P.thighR: -4, P.shinR: 4}), 0.1, 0.6),
      _k(base.set({P.thighL: 7, P.shinL: 7, P.thighR: 7, P.shinR: 7, P.torso: 184}), 0.1, 0.6),
      _k(base, 0.1, 0.6),
    ], view: FigureView.front);
  },
  'torso_rotations': () {
    final center = _frontStand().set({P.armL: -60, P.foreL: 80, P.armR: 60, P.foreR: -80});
    final right = center.set({P.armL: 35, P.foreL: 90, P.armR: 92, P.foreR: 95, P.torso: 177});
    final left = right.mirrored();
    return _seq([
      _k(center, 0.1, 0.55),
      _k(right, 0.2, 0.55),
      _k(center, 0.1, 0.55),
      _k(left, 0.2, 0.55),
    ], view: FigureView.front);
  },
  'leg_swings': () {
    final base = _stand().set({P.armL: 60, P.foreL: 60});
    return _seq([
      _k(base.set({P.thighR: 55, P.shinR: 45, P.footR: 110}), 0.05, 0.6),
      _k(base.set({P.thighR: -32, P.shinR: -35}), 0.05, 0.6),
    ], anchor: Anchor.ankleL);
  },
  'inchworm': () {
    final fold = Pose(torso: 55, thighL: 18, shinL: -5, thighR: 18, shinR: -5).arms(0);
    return _seq([
      _k(_stand(), 0.4, 0.8),
      _k(fold, 0.2, 1.1),
      _k(_plank(), 0.6, 1.1),
      _k(fold, 0.2, 0.8),
    ]);
  },

  // --- Full body -------------------------------------------------------------
  'squat_to_reach': () =>
      _seq([_k(_stand(), 0.2, 0.8), _k(_squat(), 0.3, 0.8), _k(_standArmsUp(), 0.4, 0.7)]),
  'burpee': () {
    final crouch = Pose(torso: 125, thighL: 85, shinL: -40, thighR: 85, shinR: -40).arms(0);
    final pushBottom = Pose(
      torso: 105,
      thighL: -75,
      shinL: -75,
      footL: 15,
      thighR: -75,
      shinR: -75,
      footR: 15,
    ).arms(-70, 15);
    return _seq([
      _k(_stand(), 0.2, 0.45),
      _k(crouch, 0.05, 0.35),
      _k(_plank(), 0.05, 0.4),
      _k(pushBottom, 0.05, 0.4),
      _k(_plank(), 0.05, 0.35),
      _k(crouch, 0.05, 0.35),
      _k(_standArmsUp().set({P.lift: 9, P.footL: 40, P.footR: 40}), 0.05, 0.35),
    ], anchor: Anchor.hands);
  },
  'step_back_burpee': () {
    final crouch = Pose(torso: 125, thighL: 85, shinL: -40, thighR: 85, shinR: -40).arms(0);
    final oneBack = crouch.set({P.torso: 118, P.thighR: -60, P.shinR: -62, P.footR: 15});
    return _seq([
      _k(_stand(), 0.2, 0.6),
      _k(crouch, 0.1, 0.5),
      _k(oneBack, 0.1, 0.5),
      _k(_plank(), 0.5, 0.5),
      _k(oneBack, 0.1, 0.5),
      _k(crouch, 0.1, 0.6),
      _k(_standArmsUp(), 0.3, 0.6),
    ], anchor: Anchor.hands);
  },
  'bear_plank_hold': () {
    final hover = _quadruped().set({
      P.torso: 100,
      P.thighL: 8,
      P.shinL: -70,
      P.footL: 10,
      P.thighR: 8,
      P.shinR: -70,
      P.footR: 10,
    });
    return _seq(
      [
        _k(_quadruped().set({P.footL: 10, P.footR: 10}), 0.4, 0.7),
        _k(hover, 2.2, 0.7),
      ],
      anchor: Anchor.hands,
      props: const [MatProp()],
    );
  },
  'plank_to_down_dog': () => _seq(
    [_k(_plank(), 0.4, 0.9), _k(_downDog(), 0.5, 0.9)],
    anchor: Anchor.hands,
    props: const [MatProp()],
  ),
  'dumbbell_thruster': () {
    Pose rack(Pose p) => _reachBoth(p, const Offset(6, 4), bend: 1);
    final squatRack = rack(Pose(torso: 150, thighL: 80, shinL: -25, thighR: 80, shinR: -25));
    return _seq(
      [_k(rack(_stand()), 0.2, 0.8), _k(squatRack, 0.2, 0.7), _k(_standArmsUp(), 0.4, 0.7)],
      props: const [DumbbellProp()],
    );
  },

  // --- Upper body ------------------------------------------------------------
  'wall_push_up': () {
    final start = Pose(torso: 160).legs(-20).arms(90);
    final bottom = Pose(torso: 145).legs(-35).arms(70, 186);
    return _seq([_k(start, 0.3, 0.9), _k(bottom, 0.2, 0.9)], props: const [WallProp(59.5)]);
  },
  'incline_push_up': () {
    final top = Pose(torso: 136, footL: 30, footR: 30).legs(-44).arms(0);
    final bottom = Pose(torso: 124, footL: 30, footR: 30).legs(-56).arms(-70, 20);
    return _seq(
      [_k(top, 0.3, 0.9), _k(bottom, 0.2, 0.9)],
      anchor: Anchor.hands,
      props: const [ChairProp(-3, behind: false)],
    );
  },
  'knee_push_up': () {
    final top = Pose(
      torso: 128,
      thighL: -52,
      shinL: -100,
      footL: -100,
      thighR: -52,
      shinR: -100,
      footR: -100,
    ).arms(0);
    final bottom = Pose(
      torso: 110,
      thighL: -70,
      shinL: -92,
      footL: -100,
      thighR: -70,
      shinR: -92,
      footR: -100,
    ).arms(-70, 15);
    return _seq(
      [_k(top, 0.3, 0.9), _k(bottom, 0.2, 0.9)],
      anchor: Anchor.hands,
      props: const [MatProp()],
    );
  },
  'push_up': () {
    final bottom = Pose(
      torso: 105,
      thighL: -75,
      shinL: -75,
      footL: 15,
      thighR: -75,
      shinR: -75,
      footR: 15,
    ).arms(-70, 15);
    return _seq([_k(_plank(), 0.3, 0.9), _k(bottom, 0.2, 0.9)], anchor: Anchor.hands);
  },
  'pike_push_up': () {
    final top = _downDog()
        .set({P.torso: 42, P.thighL: -22, P.shinL: -22, P.thighR: -22, P.shinR: -22})
        .arms(42);
    final bottom = top.set({P.torso: 62, P.head: -10}).arms(-25, 45);
    return _seq([_k(top, 0.3, 0.9), _k(bottom, 0.2, 0.9)], anchor: Anchor.hands);
  },
  'chair_dip': () {
    final top = Pose(thighL: 80, shinL: 0, thighR: 80, shinR: 0).arms(-10);
    final bottom = Pose(thighL: 100, shinL: -10, thighR: 100, shinR: -10).arms(-60, 10);
    return _seq(
      [_k(top, 0.3, 0.9), _k(bottom, 0.2, 0.9)],
      anchor: Anchor.wristR,
      props: const [ChairProp(3)],
    );
  },
  'prone_y_raise': () {
    final down = _prone().arms(90).set({P.head: -5});
    return _seq(
      [
        _k(down, 0.4, 0.7),
        _k(down.arms(104).set({P.shrug: -1}), 0.9, 0.7),
      ],
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'reverse_snow_angel': () {
    final base = Pose(
      torso: 90,
      thighL: -96,
      shinL: -96,
      thighR: -84,
      shinR: -84,
      footL: -96,
      footR: -84,
    );
    final sides = base.set({P.armL: -100, P.foreL: -100, P.armR: -80, P.foreR: -80});
    final wide = base.set({P.armL: 175, P.foreL: 175, P.armR: 5, P.foreR: 5});
    final overhead = base.set({P.armL: 100, P.foreL: 100, P.armR: 80, P.foreR: 80});
    return _seq(
      [_k(sides, 0.3, 0.8), _k(wide, 0.1, 0.8), _k(overhead, 0.4, 0.8), _k(wide, 0.1, 0.8)],
      view: FigureView.front,
      anchor: Anchor.hip,
      ground: false,
      caption: 'Seen from above',
    );
  },
  'band_pull_apart': () {
    final start = _frontHandsAtChest(
      _frontStand(),
    ).set({P.armL: -70, P.foreL: 75, P.armR: 70, P.foreR: -75});
    final apart = _frontStand().set({P.armL: -92, P.foreL: -92, P.armR: 92, P.foreR: 92});
    return _seq(
      [_k(start, 0.3, 0.8), _k(apart, 0.4, 0.8)],
      view: FigureView.front,
      props: const [BandProp(Joint.wristL, Joint.wristR)],
    );
  },
  'band_row': () {
    final reach = _longSit().set({P.torso: 175}).arms(80, 85);
    final pull = _longSit().set({P.torso: 182}).arms(-45, 80);
    return _seq(
      [_k(reach, 0.3, 0.8), _k(pull, 0.4, 0.8)],
      anchor: Anchor.hip,
      props: const [MatProp(), BandProp(Joint.toeR, Joint.wristR)],
    );
  },
  'dumbbell_bent_over_row': () {
    final hinge = Pose(torso: 128, thighL: 15, shinL: -8, thighR: 15, shinR: -8).arms(0);
    return _seq(
      [_k(hinge, 0.3, 0.8), _k(hinge.arms(-70, 0), 0.4, 0.8)],
      props: const [DumbbellProp()],
    );
  },
  'dumbbell_shoulder_press': () {
    final rack = _frontStand().set({P.armL: -80, P.foreL: 178, P.armR: 80, P.foreR: -178});
    final press = _frontStand().set({P.armL: -168, P.foreL: -175, P.armR: 168, P.foreR: 175});
    return _seq(
      [_k(rack, 0.3, 0.8), _k(press, 0.3, 0.8)],
      view: FigureView.front,
      props: const [DumbbellProp()],
    );
  },
  'dumbbell_biceps_curl': () => _seq(
    [_k(_stand().arms(0), 0.3, 0.8), _k(_stand().arms(4, 160), 0.3, 0.8)],
    props: const [DumbbellProp()],
  ),

  // --- Lower body ------------------------------------------------------------
  'bodyweight_squat': () => _seq([_k(_stand().arms(30), 0.3, 0.9), _k(_squat(), 0.3, 0.9)]),
  'sit_to_stand': () {
    final seated = Pose(torso: 165, thighL: 90, shinL: 0, thighR: 90, shinR: 0).arms(85);
    return _seq(
      [_k(seated, 0.4, 0.9), _k(_stand().arms(85), 0.4, 0.9)],
      props: const [ChairProp(-21)],
    );
  },
  'reverse_lunge': () {
    final lunge = Pose(
      torso: 178,
      thighR: 80,
      shinR: 0,
      thighL: -10,
      shinL: -90,
      footL: 0,
    ).set({P.armL: -35, P.foreL: 60, P.armR: -35, P.foreR: 60});
    final standHands = _stand().set({P.armL: -35, P.foreL: 60, P.armR: -35, P.foreR: 60});
    return _seq([_k(standHands, 0.3, 0.9), _k(lunge, 0.3, 0.9)], anchor: Anchor.ankleR);
  },
  'split_squat': () {
    final top = Pose(
      thighR: 18,
      shinR: 0,
      thighL: -22,
      shinL: -22,
      footL: 10,
    ).set({P.armL: -35, P.foreL: 60, P.armR: -35, P.foreR: 60});
    final bottom = top.set({P.thighR: 80, P.shinR: 0, P.thighL: -10, P.shinL: -90, P.footL: 0});
    return _seq([_k(top, 0.3, 0.9), _k(bottom, 0.3, 0.9)], anchor: Anchor.ankleR);
  },
  'lateral_lunge': () {
    final standing = _frontHandsAtChest(
      _frontStand().set({P.thighL: -3, P.shinL: -3, P.thighR: 3, P.shinR: 3}),
    );
    final lunge = _frontHandsAtChest(
      _frontStand().set({P.thighR: 52, P.shinR: -8, P.thighL: -48, P.shinL: -48, P.torso: 186}),
    );
    return _seq(
      [_k(standing, 0.3, 0.9), _k(lunge, 0.4, 0.9)],
      view: FigureView.front,
      anchor: Anchor.ankleL,
    );
  },
  'glute_bridge': () {
    final top = Pose(torso: -64, thighL: 116, shinL: 6, thighR: 116, shinR: 6).arms(90);
    return _seq(
      [_k(_supineKneesBent(), 0.3, 0.9), _k(top, 0.6, 0.9)],
      anchor: Anchor.ankleR,
      props: const [MatProp()],
    );
  },
  'single_leg_glute_bridge': () {
    final bottom = _supineKneesBent().set({P.thighL: 125, P.shinL: 125, P.footL: 180});
    final top = Pose(
      torso: -64,
      thighR: 116,
      shinR: 6,
      thighL: 116,
      shinL: 116,
      footL: 200,
    ).arms(90);
    return _seq(
      [_k(bottom, 0.3, 0.9), _k(top, 0.6, 0.9)],
      anchor: Anchor.ankleR,
      props: const [MatProp()],
    );
  },
  'wall_sit': () {
    final standing = Pose().legs(30).set({P.footL: 90, P.footR: 90});
    final sit = Pose().set({P.thighL: 90, P.shinL: 0, P.thighR: 90, P.shinR: 0});
    return _seq([_k(standing, 0.4, 1.0), _k(sit, 2.5, 1.0)], props: const [WallProp(-26)]);
  },
  'calf_raise': () => _seq([
    _k(_stand().arms(20), 0.3, 0.6),
    _k(_stand().arms(20).set({P.footL: 35, P.footR: 35}), 0.5, 0.6),
  ]),
  'sumo_squat': () {
    final top = _frontHandsAtChest(
      _frontStand().set({
        P.thighL: -18,
        P.shinL: -18,
        P.thighR: 18,
        P.shinR: 18,
        P.footL: -130,
        P.footR: 130,
      }),
    );
    final bottom = _frontHandsAtChest(
      _frontStand().set({
        P.thighL: -70,
        P.shinL: 18,
        P.thighR: 70,
        P.shinR: -18,
        P.footL: -130,
        P.footR: 130,
      }),
    );
    return _seq([_k(top, 0.3, 0.9), _k(bottom, 0.3, 0.9)], view: FigureView.front);
  },
  'fire_hydrant': () {
    // Seen from behind: the torso points away from the viewer.
    final base = Pose(
      torsoScale: 0.3,
      thighL: 0,
      thighR: 0,
      shinScaleL: 0.12,
      shinScaleR: 0.12,
      footScale: 0.1,
      footL: 0,
      footR: 0,
    ).arms(0).set({P.armL: -3, P.foreL: -3, P.armR: 3, P.foreR: 3});
    return _seq(
      [
        _k(base, 0.3, 0.8),
        _k(base.set({P.thighR: 72}), 0.4, 0.8),
      ],
      view: FigureView.front,
      props: const [MatProp()],
      caption: 'Seen from behind',
    );
  },
  'side_lying_leg_raise': () {
    final base = Pose(
      torso: -90,
      thighL: 92,
      shinL: 92,
      thighR: 90,
      shinR: 90,
      footL: 180,
      footR: 0,
    ).set({P.armL: -92, P.foreL: -150, P.armR: 90, P.foreR: 90});
    return _seq(
      [
        _k(base, 0.3, 0.8),
        _k(base.set({P.thighR: 62, P.shinR: 62, P.footR: -30}), 0.4, 0.8),
      ],
      view: FigureView.front,
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'jump_squat': () => _seq([
    _k(_squat(arms: -40), 0.2, 0.35),
    _k(_standArmsUp().set({P.lift: 12, P.footL: 40, P.footR: 40}), 0.05, 0.35),
    _k(_halfSquat(), 0.05, 0.4),
  ]),
  'bulgarian_split_squat': () {
    final top = Pose(thighR: 15, shinR: 0, thighL: -25, shinL: -95, footL: -90);
    final bottom = Pose(torso: 172, thighR: 75, shinR: 5, thighL: -5, shinL: -151, footL: -100);
    return _seq(
      [
        _k(top.set({P.armL: -35, P.foreL: 60, P.armR: -35, P.foreR: 60}), 0.3, 0.9),
        _k(bottom.set({P.armL: -35, P.foreL: 60, P.armR: -35, P.foreR: 60}), 0.3, 0.9),
      ],
      anchor: Anchor.ankleR,
      props: const [ChairProp(-36)],
    );
  },
  'goblet_squat': () {
    Pose hold(Pose p) => _reachBoth(p, const Offset(8, 10), bend: 1);
    return _seq(
      [_k(hold(_stand()), 0.3, 0.9), _k(hold(_squat()), 0.3, 0.9)],
      props: const [
        DumbbellProp([Joint.wristR]),
      ],
    );
  },
  'dumbbell_romanian_deadlift': () => _seq(
    [
      _k(_stand().set({P.thighL: 4, P.thighR: 4}).arms(0), 0.3, 1.0),
      _k(Pose(torso: 105, thighL: 14, shinL: -6, thighR: 14, shinR: -6).arms(0), 0.3, 1.0),
    ],
    props: const [DumbbellProp()],
  ),
  'band_lateral_walk': () {
    final narrow = Pose(
      footL: -90,
      footR: 90,
      thighL: -8,
      shinL: 4,
      thighR: 8,
      shinR: -4,
    ).set({P.armL: -35, P.foreL: 55, P.armR: 35, P.foreR: -55});
    final wide = narrow.set({P.thighR: 26, P.shinR: 18, P.thighL: -14, P.shinL: -4});
    return _seq(
      [
        _k(narrow, 0.1, 0.5),
        _k(wide.set({P.dx: 4}), 0.1, 0.5),
        _k(narrow.set({P.dx: 9}), 0.1, 0.5),
        _k(wide.mirrored().set({P.dx: 4}), 0.1, 0.5),
      ],
      view: FigureView.front,
      anchor: Anchor.hip,
      props: const [BandProp(Joint.kneeL, Joint.kneeR)],
    );
  },

  // --- Core ------------------------------------------------------------------
  'forearm_plank': () => _seq(
    [
      _k(
        _forearmPlank().set({
          P.torso: 96,
          P.thighL: -85,
          P.shinL: -85,
          P.thighR: -85,
          P.shinR: -85,
        }),
        0.4,
        0.8,
      ),
      _k(_forearmPlank(), 2.6, 0.8),
    ],
    anchor: Anchor.hands,
    props: const [MatProp()],
  ),
  'high_plank': () {
    final knees = Pose(
      torso: 128,
      thighL: -52,
      shinL: -100,
      footL: -100,
      thighR: -52,
      shinR: -100,
      footR: -100,
    ).arms(0);
    return _seq([_k(knees, 0.4, 0.8), _k(_plank(), 2.6, 0.8)], anchor: Anchor.hands);
  },
  'side_plank': () {
    // Viewed from the front: the body forms a diagonal line.
    final down = Pose(
      torso: 96,
      thighL: -84,
      shinL: -84,
      thighR: -84,
      shinR: -84,
      footL: -60,
      footR: -60,
      foreScaleR: 0.25,
    ).set({P.armR: 0, P.foreR: 90, P.armL: 120, P.foreL: 150});
    final up = down.set({P.torso: 103, P.thighL: -77, P.shinL: -77, P.thighR: -77, P.shinR: -77});
    return _seq(
      [_k(down, 0.4, 0.8), _k(up, 2.2, 0.8)],
      view: FigureView.front,
      anchor: Anchor.ankleR,
      props: const [MatProp()],
    );
  },
  'dead_bug': () {
    final neutral = Pose(
      torso: -90,
      thighL: 180,
      shinL: 90,
      thighR: 180,
      shinR: 90,
      footL: 180,
      footR: 180,
    ).arms(180);
    final a = neutral.set({P.armR: -100, P.foreR: -100, P.thighL: 100, P.shinL: 100, P.footL: 160});
    final b = neutral.set({P.armL: -100, P.foreL: -100, P.thighR: 100, P.shinR: 100, P.footR: 160});
    return _seq(
      [_k(neutral, 0.1, 0.8), _k(a, 0.3, 0.8), _k(neutral, 0.1, 0.8), _k(b, 0.3, 0.8)],
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'bird_dog': () {
    final base = _quadruped();
    final a = base.set({P.armR: 95, P.foreR: 95, P.thighL: -92, P.shinL: -92, P.footL: -100});
    final b = base.set({P.armL: 95, P.foreL: 95, P.thighR: -92, P.shinR: -92, P.footR: -100});
    return _seq(
      [_k(base, 0.1, 0.8), _k(a, 0.5, 0.8), _k(base, 0.1, 0.8), _k(b, 0.5, 0.8)],
      anchor: Anchor.kneeR,
      props: const [MatProp()],
    );
  },
  'crunch': () {
    final down = _supineKneesBent().set({P.armL: -130, P.foreL: 60, P.armR: -130, P.foreR: 60});
    final up = down.set({
      P.torso: -118,
      P.spine: 3,
      P.head: 18,
      P.armL: -150,
      P.foreL: 40,
      P.armR: -150,
      P.foreR: 40,
    });
    return _seq(
      [_k(down, 0.3, 0.7), _k(up, 0.4, 0.7)],
      anchor: Anchor.ankleR,
      props: const [MatProp()],
    );
  },
  'bicycle_crunch': () {
    final base = Pose(
      torso: -108,
      spine: 3,
      head: 15,
    ).set({P.armL: -150, P.foreL: 40, P.armR: -150, P.foreR: 40});
    final a = base.set({
      P.thighR: 160,
      P.shinR: 70,
      P.thighL: 105,
      P.shinL: 105,
      P.footL: 180,
      P.footR: 150,
    });
    final b = base.set({
      P.thighL: 160,
      P.shinL: 70,
      P.thighR: 105,
      P.shinR: 105,
      P.footR: 180,
      P.footL: 150,
    });
    return _seq([_k(a, 0.15, 0.6), _k(b, 0.15, 0.6)], anchor: Anchor.hip, props: const [MatProp()]);
  },
  'reverse_crunch': () {
    final start = Pose(
      torso: -90,
      thighL: 180,
      shinL: 90,
      thighR: 180,
      shinR: 90,
      footL: 180,
      footR: 180,
    ).arms(90);
    final curl = start.set({
      P.torso: -78,
      P.spine: 3,
      P.thighL: 200,
      P.shinL: 110,
      P.thighR: 200,
      P.shinR: 110,
    });
    return _seq(
      [_k(start, 0.3, 0.8), _k(curl, 0.3, 0.8)],
      anchor: Anchor.head,
      props: const [MatProp()],
    );
  },
  'hollow_hold': () {
    final flat = _supine().arms(-90);
    final hollow = flat.set({P.torso: -104, P.spine: 2, P.head: 12}).arms(-98).legs(102, 102, 180);
    return _seq(
      [_k(flat, 0.4, 0.8), _k(hollow, 2.4, 0.8)],
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'russian_twist': () {
    // Seen from the front: knees toward the viewer.
    final base = Pose(
      thighScaleL: 0.45,
      thighScaleR: 0.45,
      thighL: -150,
      thighR: 150,
      shinL: -10,
      shinR: 10,
      footL: -90,
      footR: 90,
    );
    final left = _reachL(
      _reachR(base.set({P.torso: 190}), const Offset(-24, 18), bend: 1),
      const Offset(-8, 18),
      bend: 1,
    );
    final right = left.mirrored();
    return _seq(
      [_k(left, 0.15, 0.6), _k(right, 0.15, 0.6)],
      view: FigureView.front,
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'superman_hold': () {
    final lifted = _prone()
        .set({P.torso: 98, P.spine: -2, P.head: 0})
        .arms(102)
        .legs(-100, -100, -100);
    return _seq(
      [_k(_prone().arms(90), 0.4, 0.8), _k(lifted, 2.0, 0.8)],
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'plank_shoulder_tap': () {
    final tapR = _reachR(_plank(), const Offset(4, 6), bend: -1);
    final tapL = _reachL(_plank(), const Offset(4, 6), bend: -1);
    return _seq([
      _k(_plank(), 0.1, 0.4),
      _k(tapR, 0.25, 0.4),
      _k(_plank(), 0.1, 0.4),
      _k(tapL, 0.25, 0.4),
    ], anchor: Anchor.feet);
  },
  'standing_cross_crunch': () {
    // Elbows wide, fingertips by the ears.
    final base = _frontStand().set({P.armL: -130, P.foreL: 80, P.armR: 130, P.foreR: -80});
    final crunch = base.set({
      P.torso: 168,
      P.thighR: -150,
      P.shinR: -5,
      P.footR: 60,
      P.armL: 38,
      P.foreL: 165,
    });
    return _seq(
      [
        _k(base, 0.1, 0.5),
        _k(crunch, 0.2, 0.5),
        _k(base, 0.1, 0.5),
        _k(crunch.mirrored(), 0.2, 0.5),
      ],
      view: FigureView.front,
      anchor: Anchor.hip,
    );
  },

  // --- Cardio ----------------------------------------------------------------
  'jumping_jacks': () {
    final closed = _frontStand().set({P.thighL: -2, P.shinL: -2, P.thighR: 2, P.shinR: 2});
    final open = _frontStand().set({
      P.thighL: -20,
      P.shinL: -20,
      P.thighR: 20,
      P.shinR: 20,
      P.armL: -168,
      P.foreL: -172,
      P.armR: 168,
      P.foreR: 172,
    });
    final air = Pose.lerp(closed, open, 0.5).set({P.lift: 6});
    return _seq(
      [_k(closed, 0.05, 0.18), _k(air, 0, 0.18), _k(open, 0.05, 0.18), _k(air, 0, 0.18)],
      view: FigureView.front,
      anchor: Anchor.hip,
    );
  },
  'step_jacks': () {
    final closed = _frontStand().set({P.thighL: -2, P.shinL: -2, P.thighR: 2, P.shinR: 2});
    final right = closed.set({
      P.thighR: 24,
      P.shinR: 24,
      P.armL: -165,
      P.foreL: -170,
      P.armR: 165,
      P.foreR: 170,
    });
    return _seq(
      [
        _k(closed, 0.1, 0.35),
        _k(right, 0.1, 0.35),
        _k(closed, 0.1, 0.35),
        _k(right.mirrored(), 0.1, 0.35),
      ],
      view: FigureView.front,
      anchor: Anchor.hip,
    );
  },
  'high_knees': () {
    final a = _stand().set({
      P.thighR: 95,
      P.shinR: 5,
      P.footR: 120,
      P.armL: 40,
      P.foreL: 150,
      P.armR: -30,
      P.foreR: 60,
      P.lift: 3,
      P.footL: 40,
    });
    final b = _stand().set({
      P.thighL: 95,
      P.shinL: 5,
      P.footL: 120,
      P.armR: 40,
      P.foreR: 150,
      P.armL: -30,
      P.foreL: 60,
      P.lift: 3,
      P.footR: 40,
    });
    return _seq([_k(a, 0, 0.28), _k(b, 0, 0.28)], anchor: Anchor.hip);
  },
  'knee_drive_march': () {
    final a = _stand().set({
      P.thighR: 88,
      P.shinR: 5,
      P.armL: 40,
      P.foreL: 150,
      P.armR: -30,
      P.foreR: 60,
    });
    final b = _stand().set({
      P.thighL: 88,
      P.shinL: 5,
      P.armR: 40,
      P.foreR: 150,
      P.armL: -30,
      P.foreL: 60,
    });
    return _seq([_k(a, 0.05, 0.42), _k(b, 0.05, 0.42)], anchor: Anchor.hip);
  },
  'butt_kicks': () {
    final a = _stand().set({
      P.thighR: -8,
      P.shinR: -155,
      P.footR: -120,
      P.armL: 30,
      P.foreL: 120,
      P.armR: -25,
      P.foreR: 70,
      P.lift: 2,
      P.footL: 50,
    });
    final b = _stand().set({
      P.thighL: -8,
      P.shinL: -155,
      P.footL: -120,
      P.armR: 30,
      P.foreR: 120,
      P.armL: -25,
      P.foreL: 70,
      P.lift: 2,
      P.footR: 50,
    });
    return _seq([_k(a, 0, 0.3), _k(b, 0, 0.3)], anchor: Anchor.hip);
  },
  'skater_hops': () {
    final right = _frontStand().set({
      P.thighR: 8,
      P.shinR: -2,
      P.thighL: 30,
      P.shinL: 50,
      P.footL: 90,
      P.armL: 40,
      P.foreL: 60,
      P.armR: -40,
      P.foreR: -60,
      P.torso: 172,
      P.dx: 12,
    });
    final left = right.mirrored();
    final air = Pose.lerp(right, left, 0.5).set({P.lift: 8});
    return _seq(
      [_k(right, 0.15, 0.25), _k(air, 0, 0.25), _k(left, 0.15, 0.25), _k(air, 0, 0.25)],
      view: FigureView.front,
      anchor: Anchor.hip,
    );
  },
  'skater_steps': () {
    final right = _frontStand().set({
      P.thighR: 15,
      P.shinR: 0,
      P.thighL: 25,
      P.shinL: 45,
      P.footL: 90,
      P.armL: 35,
      P.foreL: 55,
      P.armR: -35,
      P.foreR: -55,
      P.torso: 174,
      P.dx: 8,
    });
    return _seq(
      [_k(right, 0.15, 0.45), _k(right.mirrored(), 0.15, 0.45)],
      view: FigureView.front,
      anchor: Anchor.hip,
    );
  },
  'mountain_climber': () {
    final a = _plank().set({P.thighR: 35, P.shinR: -55, P.footR: 0});
    final b = _plank().set({P.thighL: 35, P.shinL: -55, P.footL: 0});
    return _seq([_k(a, 0, 0.3), _k(b, 0, 0.3)], anchor: Anchor.hands);
  },
  'shadow_boxing': () {
    final guard = Pose(thighR: 14, shinR: 8, thighL: -14, shinL: -14).arms(30, 165);
    final jab = guard.set({P.armR: 90, P.foreR: 90, P.torso: 176});
    final cross = guard.set({P.armL: 88, P.foreL: 90, P.torso: 172, P.protract: 2});
    return _seq([
      _k(guard, 0.1, 0.22),
      _k(jab, 0.05, 0.22),
      _k(guard, 0.1, 0.22),
      _k(cross, 0.05, 0.22),
    ], anchor: Anchor.feet);
  },
  'side_step_touch': () {
    final closed = _frontStand().set({P.thighL: -2, P.shinL: -2, P.thighR: 2, P.shinR: 2});
    final open = closed.set({
      P.thighR: 20,
      P.shinR: 20,
      P.armL: -50,
      P.foreL: -40,
      P.armR: 50,
      P.foreR: 40,
    });
    return _seq(
      [
        _k(closed, 0.1, 0.4),
        _k(open.set({P.dx: 4}), 0.1, 0.4),
        _k(closed.set({P.dx: 8}), 0.1, 0.4),
        _k(open.mirrored().set({P.dx: 4}), 0.1, 0.4),
      ],
      view: FigureView.front,
      anchor: Anchor.hip,
    );
  },

  // --- Mobility --------------------------------------------------------------
  'cat_cow': () {
    final cow = _quadruped().set({P.spine: -4, P.head: 25});
    final cat = _quadruped().set({P.spine: 6, P.head: -45, P.protract: -1});
    return _seq(
      [_k(cow, 0.6, 1.1), _k(cat, 0.6, 1.1)],
      anchor: Anchor.hands,
      props: const [MatProp()],
    );
  },
  'worlds_greatest_stretch': () {
    final lunge = Pose(
      torso: 125,
      thighR: 82,
      shinR: 4,
      thighL: -55,
      shinL: -85,
      footL: -90,
    ).arms(0);
    final reach = lunge.set({P.armR: 180, P.foreR: 180, P.torso: 140, P.head: 20});
    return _seq(
      [_k(lunge, 0.3, 0.9), _k(reach, 0.8, 0.9)],
      anchor: Anchor.ankleR,
      props: const [MatProp()],
    );
  },
  'open_book': () {
    // Seen from above, lying on one side with knees bent.
    final closed = Pose(
      torso: -90,
      thighL: 180,
      shinL: 90,
      thighR: 180,
      shinR: 90,
      footL: 90,
      footR: 90,
    ).arms(180);
    final open = closed.set({P.armR: 0, P.foreR: 0, P.head: 25});
    return _seq(
      [_k(closed, 0.4, 1.1), _k(open, 0.8, 1.1)],
      anchor: Anchor.hip,
      ground: false,
      caption: 'Seen from above',
    );
  },
  'thread_the_needle': () {
    final base = _quadruped();
    final open = base.set({P.armR: 180, P.foreR: 180, P.head: 20});
    final thread = base.set({
      P.torso: 98,
      P.armR: 80,
      P.foreR: 85,
      P.armL: 15,
      P.foreL: 0,
      P.head: -40,
    });
    return _seq(
      [_k(base, 0.2, 0.8), _k(open, 0.3, 0.9), _k(thread, 0.7, 0.9)],
      anchor: Anchor.kneeR,
      props: const [MatProp()],
    );
  },
  'ninety_ninety_switch': () {
    final left = Pose(
      thighL: -95,
      shinL: 0,
      thighR: -40,
      shinR: -95,
      footL: -90,
      footR: -90,
    ).set({P.armL: -25, P.foreL: -20, P.armR: 25, P.foreR: 20});
    return _seq(
      [_k(left, 0.6, 1.0), _k(left.mirrored(), 0.6, 1.0)],
      view: FigureView.front,
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'ankle_rock': () {
    final base = Pose(thighR: 25, shinR: 12, thighL: -22, shinL: -22, footL: 60).arms(80);
    return _seq(
      [
        _k(base, 0.3, 0.7),
        _k(base.set({P.thighR: 52, P.shinR: 32, P.torso: 172}), 0.3, 0.7),
      ],
      anchor: Anchor.ankleR,
      props: const [WallProp(13)],
    );
  },
  'wall_angel': () {
    final goal = _frontStand().set({P.armL: -92, P.foreL: 180, P.armR: 92, P.foreR: -180});
    final up = _frontStand().set({P.armL: -150, P.foreL: -175, P.armR: 150, P.foreR: 175});
    return _seq([_k(goal, 0.3, 0.9), _k(up, 0.3, 0.9)], view: FigureView.front);
  },
  'deep_squat_hold': () {
    final deep = Pose(torso: 160, thighL: 105, shinL: -38, thighR: 105, shinR: -38).arms(70);
    return _seq(
      [_k(_stand().arms(70), 0.4, 1.2), _k(deep, 2.4, 1.2)],
      props: const [WallProp(36, height: 80)],
    );
  },

  // --- Stretching ------------------------------------------------------------
  'childs_pose': () {
    final kneel = _kneel().arms(0);
    final pose = Pose(
      torso: 88,
      spine: 4,
      head: -15,
      thighL: 65,
      shinL: -90,
      footL: -90,
      thighR: 65,
      shinR: -90,
      footR: -90,
    ).arms(75);
    return _seq(
      [_k(kneel, 0.4, 1.2), _k(pose, 2.6, 1.2)],
      anchor: Anchor.kneeR,
      props: const [MatProp()],
    );
  },
  'standing_quad_stretch': () {
    final base = _stand().set({P.armL: 70, P.foreL: 70});
    final stretch = _reachR(
      base.set({P.thighR: -6, P.shinR: -165, P.footR: -170}),
      const Offset(-4, 26),
      bend: 1,
    );
    return _seq([_k(base, 0.4, 1.0), _k(stretch, 2.4, 1.0)], anchor: Anchor.ankleL);
  },
  'seated_hamstring_stretch': () {
    final upright = _longSit().set({P.thighL: 140, P.shinL: 20, P.footL: 120}).arms(60);
    final fold = upright.set({P.torso: 130, P.spine: 1}).arms(80);
    return _seq(
      [_k(upright, 0.4, 1.2), _k(fold, 2.4, 1.2)],
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'figure_four_stretch': () {
    // The crossed leg points toward the viewer, so it is foreshortened.
    final start = _supineKneesBent().set({
      P.thighR: 140,
      P.thighScaleR: 0.7,
      P.shinR: 124,
      P.shinScaleR: 0.35,
      P.footR: 90,
    });
    final pulled = start.set({
      P.thighL: 172,
      P.shinL: 95,
      P.footL: 180,
      P.thighR: 172,
      P.shinR: 140,
      P.armL: 165,
      P.foreL: 150,
      P.armR: 165,
      P.foreR: 150,
    });
    return _seq(
      [_k(start, 0.4, 1.1), _k(pulled, 2.4, 1.1)],
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'cross_body_shoulder_stretch': () {
    final base = _frontStand();
    final stretch = _reachL(base.set({P.armR: -92, P.foreR: -92}), const Offset(14, 8), bend: -1);
    return _seq([_k(base, 0.3, 0.9), _k(stretch, 2.4, 0.9)], view: FigureView.front);
  },
  'overhead_triceps_stretch': () {
    final base = _frontStand();
    final stretch = _reachL(base.set({P.armR: 178, P.foreR: -12}), const Offset(10, -16), bend: -1);
    return _seq([_k(base, 0.3, 0.9), _k(stretch, 2.4, 0.9)], view: FigureView.front);
  },
  'chest_opener_stretch': () => _seq([
    _k(_stand(), 0.3, 1.0),
    _k(_stand().set({P.protract: -2.5, P.shrug: -0.5, P.head: 6}).arms(-22, -30), 2.4, 1.0),
  ]),
  'sphinx_stretch': () => _seq(
    [
      _k(
        _prone().arms(-80, 90).set({P.armL: 110, P.foreL: 90, P.armR: 110, P.foreR: 90}),
        0.4,
        1.1,
      ),
      _k(_prone().set({P.torso: 127, P.spine: -3}).arms(0, 90), 2.4, 1.1),
    ],
    anchor: Anchor.hip,
    props: const [MatProp()],
  ),
  'standing_calf_stretch': () => _seq(
    [
      _k(Pose(torso: 165, thighR: 15, shinR: 5, thighL: -18, shinL: -18).arms(80), 0.4, 1.0),
      _k(Pose(torso: 155, thighR: 35, shinR: 18, thighL: -26, shinL: -26).arms(70, 85), 2.4, 1.0),
    ],
    anchor: Anchor.ankleR,
    props: const [WallProp(36)],
  ),
  'butterfly_stretch': () {
    final sit = Pose(
      thighL: -100,
      shinL: 76,
      thighR: 100,
      shinR: -76,
      footL: 90,
      footR: -90,
    ).set({P.armL: 10, P.foreL: 20, P.armR: -10, P.foreR: -20});
    final fold = sit.set({P.torsoScale: 0.72, P.head: 0});
    return _seq(
      [_k(sit, 0.6, 1.2), _k(fold, 2.0, 1.2)],
      view: FigureView.front,
      anchor: Anchor.hip,
      props: const [MatProp()],
    );
  },
  'supine_spinal_twist': () {
    // Seen from above: arms out in a T, knees dropping to one side.
    final right = Pose(
      torso: -90,
      thighL: 20,
      shinL: 90,
      thighR: 30,
      shinR: 90,
      footL: 90,
      footR: 90,
    ).set({P.armL: 180, P.foreL: 180, P.armR: 0, P.foreR: 0, P.head: 25});
    final left = right.set({P.thighL: 150, P.thighR: 160, P.head: -25});
    return _seq(
      [_k(right, 2.2, 1.4), _k(left, 2.2, 1.4)],
      view: FigureView.front,
      anchor: Anchor.hip,
      ground: false,
      caption: 'Seen from above',
    );
  },
  'downward_dog': () => _seq(
    [_k(_quadruped(), 0.4, 1.0), _k(_downDog(), 2.6, 1.0)],
    anchor: Anchor.hands,
    props: const [MatProp()],
  ),
  'kneeling_hip_flexor_stretch': () {
    final base = Pose(
      thighR: 85,
      shinR: 0,
      thighL: -5,
      shinL: -90,
      footL: -90,
    ).set({P.armL: -35, P.foreL: 60, P.armR: -35, P.foreR: 60});
    final shift = base.set({P.thighR: 68, P.shinR: 12, P.thighL: -28});
    return _seq(
      [_k(base, 0.4, 1.0), _k(shift, 2.4, 1.0)],
      anchor: Anchor.ankleR,
      props: const [MatProp()],
    );
  },
  'standing_side_stretch': () {
    final base = _frontStand();
    final stretch = base.set({P.torso: 196, P.armR: -170, P.foreR: -150, P.armL: -35, P.foreL: 55});
    return _seq([
      _k(base, 0.3, 0.9),
      _k(stretch, 1.8, 0.9),
      _k(base, 0.3, 0.9),
      _k(stretch.mirrored(), 1.8, 0.9),
    ], view: FigureView.front);
  },
};
