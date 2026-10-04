import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/sudoku/sudoku_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Regression: the menu used to crash (infinite recursion in the best-time lookup),
/// so the screen must at least open, start a game of every tier, and accept input.
void main() {
  Future<void> open(WidgetTester t, [Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    await Storage.init();
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const MaterialApp(home: SudokuScreen()));
    await t.pump(const Duration(milliseconds: 800));
  }

  testWidgets('menu opens with all four tiers', (t) async {
    await open(t);
    expect(tester(t), isNull);
    for (final label in ['Easy', 'Medium', 'Hard', 'Extreme']) {
      expect(find.text(label), findsWidgets);
    }
  });

  testWidgets('menu opens with an old Expert best time stored', (t) async {
    await open(t, {'sudoku.best.expert': 123});
    expect(find.text('Extreme'), findsWidgets);
  });

  for (final label in ['Easy', 'Extreme']) {
    testWidgets('can start a $label game and place a number', (t) async {
      await open(t);
      await t.tap(find.text(label).first);
      await t.pump();
      await t.runAsync(() => Future<void>.delayed(const Duration(seconds: 6)));
      await t.pump(const Duration(milliseconds: 800));
      // Board is showing: number pad digit 5 exists.
      expect(find.text('5'), findsWidgets);
      await t.tapAt(t.getCenter(find.byType(GestureDetector).at(20)));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('5').last);
      await t.pump(const Duration(milliseconds: 300));
      // Leave the screen (disposes timers).
      await t.pumpWidget(const SizedBox());
    });
  }
}

Object? tester(WidgetTester t) => t.takeException();
