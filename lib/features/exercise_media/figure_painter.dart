import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'figure_model.dart';
import 'figure_sequence.dart';

class FigureColors {
  const FigureColors({
    required this.body,
    required this.farLimb,
    required this.prop,
    required this.ground,
    required this.accent,
  });

  final Color body;
  final Color farLimb;
  final Color prop;
  final Color ground;
  final Color accent;

  @override
  bool operator ==(Object other) =>
      other is FigureColors &&
      other.body == body &&
      other.farLimb == farLimb &&
      other.prop == prop &&
      other.ground == ground &&
      other.accent == accent;

  @override
  int get hashCode => Object.hash(body, farLimb, prop, ground, accent);
}

/// Paints one pose of a [FigureSequence], scaled to fit the canvas.
class FigurePainter extends CustomPainter {
  FigurePainter({required this.sequence, required this.pose, required this.colors});

  final FigureSequence sequence;
  final Pose pose;
  final FigureColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    paintFigure(canvas, size, sequence, pose, colors);
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.pose != pose || old.colors != colors || old.sequence != sequence;
}

/// Height in model units of a standing figure including padding.
const _referenceHeight = 104.0;

/// Draws [pose] into a canvas of [size]. Shared by the widget and the
/// image-export test harness.
void paintFigure(
  Canvas canvas,
  Size size,
  FigureSequence sequence,
  Pose pose,
  FigureColors colors,
) {
  final bounds = sequence.bounds;
  final pad = math.max(6.0, size.shortestSide * 0.05);
  // Every figure is drawn at the same body size (a standing figure fills
  // the shorter side) unless the movement needs more room, so compact
  // poses do not look oversized.
  final scale = math.min(
    math.min((size.width - pad * 2) / bounds.width, (size.height - pad * 2) / bounds.height),
    (size.shortestSide - pad * 2) / _referenceHeight,
  );
  final origin = Offset(
    (size.width - bounds.width * scale) / 2 - bounds.left * scale,
    (size.height - bounds.height * scale) / 2 - bounds.top * scale,
  );
  Offset map(Offset p) => origin + p * scale;

  final frame = sequence.solve(pose);
  final joints = frame.joints;
  final stroke = math.max(2.0, 4.6 * scale);

  Paint line(Color color, [double? width]) => Paint()
    ..color = color
    ..strokeWidth = width ?? stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;

  final groundY = map(Offset.zero).dy;
  if (sequence.showGround) {
    canvas.drawLine(
      Offset(pad / 2, groundY),
      Offset(size.width - pad / 2, groundY),
      line(colors.ground, math.max(1.5, 1.6 * scale)),
    );
  }

  for (final prop in sequence.props) {
    switch (prop) {
      case MatProp():
        final xs = joints.values.map((o) => o.dx);
        final left = map(Offset(xs.reduce(math.min) - 6, 0)).dx;
        final right = map(Offset(xs.reduce(math.max) + 6, 0)).dx;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, groundY - 2 * scale, right, groundY + 0.8 * scale),
            Radius.circular(scale),
          ),
          Paint()..color = colors.accent.withValues(alpha: 0.3),
        );
      case WallProp(:final x, :final height):
        final p = map(Offset(x, 0));
        canvas.drawLine(p, map(Offset(x, -height)), line(colors.prop, math.max(2, 3 * scale)));
      case ChairProp(:final x, :final seatHeight, :final behind):
        final dir = behind ? -1.0 : 1.0;
        final paint = line(colors.prop, math.max(2, 2.8 * scale));
        final front = map(Offset(x, -seatHeight));
        final back = map(Offset(x + dir * 16, -seatHeight));
        canvas.drawLine(front, back, paint);
        canvas.drawLine(front, map(Offset(x, 0)), paint);
        canvas.drawLine(back, map(Offset(x + dir * 16, 0)), paint);
        canvas.drawLine(back, map(Offset(x + dir * 17, -seatHeight - 22)), paint);
      case BandProp() || DumbbellProp():
        break;
    }
  }

  void limb(List<Joint> chain, Paint paint) {
    final first = map(joints[chain.first]!);
    final path = Path()..moveTo(first.dx, first.dy);
    for (final j in chain.skip(1)) {
      final p = map(joints[j]!);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, paint);
  }

  final side = sequence.view == FigureView.side;
  final far = line(side ? colors.farLimb : colors.body);
  final near = line(colors.body);

  // Far side first so the near limbs are drawn on top.
  limb([Joint.hipL, Joint.kneeL, Joint.ankleL, Joint.toeL], far);
  limb([Joint.shoulderL, Joint.elbowL, Joint.wristL], far);

  final hip = map(joints[Joint.hip]!);
  final neck = map(joints[Joint.neck]!);
  final control = map(frame.spineControl);
  canvas.drawPath(
    Path()
      ..moveTo(hip.dx, hip.dy)
      ..quadraticBezierTo(control.dx, control.dy, neck.dx, neck.dy),
    near,
  );
  if (!side) {
    limb([Joint.hipL, Joint.hipR], near);
    limb([Joint.shoulderL, Joint.shoulderR], near);
  }
  canvas.drawCircle(
    map(joints[Joint.head]!),
    Body.headRadius * scale,
    Paint()..color = colors.body,
  );

  limb([Joint.hipR, Joint.kneeR, Joint.ankleR, Joint.toeR], near);
  limb([Joint.shoulderR, Joint.elbowR, Joint.wristR], near);

  for (final prop in sequence.props) {
    switch (prop) {
      case BandProp(:final from, :final to):
        canvas.drawLine(
          map(joints[from]!),
          map(joints[to]!),
          line(colors.accent, math.max(1.5, 2 * scale)),
        );
      case DumbbellProp(:final at):
        final paint = Paint()..color = colors.prop;
        for (final j in at) {
          final c = map(joints[j]!);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: c, width: 9 * scale, height: 3 * scale),
              Radius.circular(scale),
            ),
            paint,
          );
          for (final dx in [-4.5, 4.5]) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromCenter(
                  center: c + Offset(dx * scale, 0),
                  width: 2.6 * scale,
                  height: 6.5 * scale,
                ),
                Radius.circular(scale * 0.8),
              ),
              paint,
            );
          }
        }
      case MatProp() || WallProp() || ChairProp():
        break;
    }
  }
}
