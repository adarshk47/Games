import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/sliding_puzzle/sliding_puzzle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> open(WidgetTester t, {List<int>? start}) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(home: SlidingPuzzleScreen(debugStart: start, debugRng: Random(1))));
    await t.pump(const Duration(milliseconds: 800));
  }

  testWidgets('menu shows four tiers and locked levels', (t) async {
    await open(t);
    for (final l in ['Easy', 'Medium', 'Hard', 'Extreme']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.byIcon(Icons.lock_rounded), findsNWidgets(19));
    await t.pumpWidget(const SizedBox());
  });

  testWidgets('every tier starts and renders its tiles', (t) async {
    for (final e in {'Easy': 3, 'Medium': 4, 'Hard': 5, 'Extreme': 6}.entries) {
      await open(t);
      await t.tap(find.text(e.key));
      await t.pump();
      await t.tap(find.text('1').first);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(ValueKey('tile-${e.value * e.value - 1}')), findsOneWidget);
      await t.pumpWidget(const SizedBox());
    }
  });

  testWidgets('invalid tap, move and winning', (t) async {
    await open(t, start: [1, 2, 3, 4, 5, 6, 7, 0, 8]);
    await t.tap(find.text('1').first);
    await t.pump(const Duration(milliseconds: 500));
    // tile 1 is not in the gap's row/column: nothing happens
    await t.tap(find.byKey(const ValueKey('tile-1')));
    await t.pump(const Duration(milliseconds: 300));
    expect(Storage.getInt('sliding.easy.stars.1'), 0);
    // slide 8 left -> solved
    await t.tap(find.byKey(const ValueKey('tile-8')));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 2000));
    expect(find.text('Solved!'), findsOneWidget);
    expect(Storage.getInt('sliding.easy.stars.1'), 3);
    expect(Storage.getInt('sliding.easy.bestMoves.1'), 1);
    await t.pump(const Duration(seconds: 4));
    await t.pumpWidget(const SizedBox());
  });
}
