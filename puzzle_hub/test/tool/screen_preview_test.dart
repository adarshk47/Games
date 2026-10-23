// Screenshots of a few screens for design review (skipped unless asked):
//   flutter test test/tool/screen_preview_test.dart --dart-define=ART_PREVIEW=true
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/bus_jam/bus_jam_game.dart';
import 'package:puzzle_hub/games/bus_jam/logic/bus_jam_logic.dart';
import 'package:puzzle_hub/home/games_tab.dart';
import 'package:puzzle_hub/games/snakes/snakes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _on = bool.fromEnvironment('ART_PREVIEW');

Future<void> _fonts() async {
  final dir = '${Platform.environment['FLUTTER_ROOT'] ?? r'D:\flutter'}/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  for (final f in ['Roboto-Regular.ttf', 'Roboto-Bold.ttf', 'Roboto-Black.ttf', 'roboto-black.ttf', 'roboto-regular.ttf', 'roboto-bold.ttf']) {
    final file = File('$dir/$f');
    if (file.existsSync()) loader.addFont(Future.value(ByteData.sublistView(file.readAsBytesSync())));
  }
  await loader.load();
}

Future<void> shot(WidgetTester t, Widget w, String name) async {
  final key = GlobalKey();
  await t.pumpWidget(MaterialApp(
    theme: ThemeData(fontFamily: 'Roboto'),
    home: RepaintBoundary(key: key, child: w),
  ));
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 200));
  }
  await t.runAsync(() async {
    final b = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final img = await b.toImage(pixelRatio: 1);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('build/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('bus jam', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    await t.runAsync(_fonts);
    t.view.physicalSize = const Size(400, 820);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await shot(t, BusJamGame(tier: BjTier.values[1], level: 5), 'bus_jam_preview');
    await shot(t, const Scaffold(backgroundColor: Color(0xFF1B1238), body: GamesTab()), 'home_preview');
    await shot(t, const SnakesPlayScreen(players: 4, cpu: true, seed: 42), 'snakes_preview');
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  }, skip: !_on);
}
