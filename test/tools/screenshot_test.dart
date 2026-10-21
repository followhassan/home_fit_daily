// Renders key screens to PNG files for visual review, with the real Inter
// and Material Icons fonts. Skipped unless SCREENSHOT_OUT is set:
//
//   SCREENSHOT_OUT=/tmp/shots FLUTTER_ROOT=... flutter test test/tools/screenshot_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:home_fit_daily/core/utils/local_date.dart';
import 'package:home_fit_daily/data/local/key_value_store.dart';
import 'package:home_fit_daily/data/models/enums.dart';
import 'package:home_fit_daily/data/repositories/repositories.dart';

import '../helpers/sessions.dart';
import '../helpers/test_app.dart';

Future<void> _loadFonts() async {
  Future<ByteData> file(String path) async => ByteData.sublistView(await File(path).readAsBytes());
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(file('assets/fonts/inter/Inter-$w.ttf'));
  }
  await inter.load();
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final icons = FontLoader('MaterialIcons')
      ..addFont(file('$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf'));
    await icons.load();
  }
}

void main() {
  final out = Platform.environment['SCREENSHOT_OUT'];

  Future<void> shot(WidgetTester tester, String name) async {
    await tester.runAsync(() async {
      final view = tester.binding.renderViews.first;
      final layer = view.debugLayer! as OffsetLayer;
      // The root layer is in physical pixels.
      final image = await layer.toImage(Offset.zero & tester.view.physicalSize, pixelRatio: 0.5);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$out/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
    });
  }

  testWidgets('screenshots', (tester) async {
    await tester.runAsync(_loadFonts);
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await seedOnboarded(store, name: 'Sam');
    final today = LocalDate.today();
    for (var i = 0; i < 9; i++) {
      await Repositories(store).sessions.save(
        sessionOn(
          today.addDays(-i * 2 - 1),
          status: i == 3 ? SessionStatus.partial : SessionStatus.completed,
          activeSeconds: 420 + i * 45,
        ),
      );
    }
    await pumpApp(tester, testServices(store: store));
    await shot(tester, '01_home');
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await settle(tester);
    await shot(tester, '02_home_scrolled');

    await tester.tap(find.text('Workouts').last);
    await settle(tester);
    await shot(tester, '03_workouts');
    await tapText(tester, 'Low-Impact Cardio');
    await shot(tester, '04_workout_detail');
    await tapText(tester, 'Start workout');
    await tapText(tester, 'Start workout');
    await tapText(tester, 'Start now');
    await settle(tester);
    await shot(tester, '05_player');
    await tester.tap(find.byTooltip('Leave workout'));
    await settle(tester);
    await tapText(tester, 'Quit');
    await tester.pageBack();
    await settle(tester);

    await tapText(tester, 'Exercises');
    await shot(tester, '06_exercises');
    await tapText(tester, 'Glute Bridge');
    await shot(tester, '07_exercise_detail');
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text('Plans').last);
    await settle(tester);
    await shot(tester, '08_plans');
    await tester.tap(find.text('Progress').last);
    await settle(tester);
    await shot(tester, '09_progress');
    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await settle(tester);
    await shot(tester, '10_progress_chart');
    await tester.tap(find.text('Guide').last);
    await settle(tester);
    await shot(tester, '11_guide');
    await tapText(tester, 'Warming up');
    await shot(tester, '12_article');
    await tester.pageBack();
    await settle(tester);
    await tester.tap(find.byTooltip('Settings').first);
    await settle(tester);
    await shot(tester, '13_settings');
  }, skip: out == null);

  testWidgets('onboarding screenshots', (tester) async {
    await tester.runAsync(_loadFonts);
    useScreen(tester, const Size(390, 844));
    final store = InMemoryKeyValueStore();
    await pumpApp(tester, testServices(store: store));
    await shot(tester, '20_onboarding');
    await tapText(tester, 'Set up in about a minute');
    await tapText(tester, 'Continue');
    await shot(tester, '21_onboarding_level');
  }, skip: out == null);
}
