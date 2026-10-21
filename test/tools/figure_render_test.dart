// Renders every figure animation's keyframes to PNG contact sheets for
// visual review. Skipped unless FIGURE_OUT points at an output directory:
//
//   FIGURE_OUT=/tmp/figures flutter test test/tools/figure_render_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/features/exercise_media/figure_library.dart';
import 'package:home_fit_daily/features/exercise_media/figure_painter.dart';

void main() {
  final out = Platform.environment['FIGURE_OUT'];
  final only = Platform.environment['FIGURE_ONLY']?.split(',');

  testWidgets('render figure contact sheets', (tester) async {
    final ids = FigureLibrary.ids.where((id) => only == null || only.contains(id)).toList();
    const cell = 150.0;
    const perSheet = 8;
    const colors = FigureColors(
      body: Color(0xFFD81B78),
      farLimb: Color(0x80D81B78),
      prop: Color(0xFF777777),
      ground: Color(0xFFBBBBBB),
      accent: Color(0xFF2E7D32),
    );
    await tester.runAsync(() async {
      for (var start = 0; start < ids.length; start += perSheet) {
        final batch = ids.skip(start).take(perSheet).toList();
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        const columns = 5;
        final size = Size(cell * columns, cell * batch.length);
        canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white);
        for (var row = 0; row < batch.length; row++) {
          final sequence = FigureLibrary.get(batch[row])!;
          final frames = sequence.frames;
          for (var c = 0; c < columns && c < frames.length + 1; c++) {
            // Last column shows the midpoint of the first transition.
            final pose = c < frames.length
                ? frames[c].pose
                : sequence.poseAt(frames.first.hold + frames.first.move / 2);
            canvas.save();
            canvas.translate(c * cell, row * cell);
            canvas.drawRect(
              const Rect.fromLTWH(0, 0, cell, cell),
              Paint()
                ..color = const Color(0xFFEEEEEE)
                ..style = PaintingStyle.stroke,
            );
            paintFigure(canvas, const Size(cell, cell), sequence, pose, colors);
            canvas.restore();
          }
        }
        final image = await recorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final name = 'sheet_${(start ~/ perSheet).toString().padLeft(2, '0')}.png';
        File('$out/$name').writeAsBytesSync(png!.buffer.asUint8List());
        // ignore: avoid_print
        print('$name: ${batch.join(', ')}');
      }
    });
  }, skip: out == null);
}
