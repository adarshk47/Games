import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/minesweeper/minesweeper_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> open(WidgetTester t, [Map<String, Object> prefs = const {}]) async {
    SharedPreferences.setMockInitialValues(prefs);
    await Storage.init();
    t.view.physicalSize = const Size(360, 780);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(const MaterialApp(home: MinesweeperScreen()));
    await t.pump(const Duration(milliseconds: 800));
  }

  testWidgets('menu shows tiers and best time', (t) async {
    await open(t, {'mines.easy.best': 75, 'mines.easy.wins': 2});
    for (final l in ['Easy', 'Medium', 'Hard', 'Extreme']) {
      expect(find.text(l), findsWidgets);
    }
    expect(find.textContaining('Best 01:15'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
  });

  for (final label in ['Easy', 'Extreme']) {
    testWidgets('start $label, reveal, flag, hint, restart', (t) async {
      await open(t);
      await t.tap(find.text(label).first);
      await t.pump(const Duration(milliseconds: 500));
      expect(find.byKey(const ValueKey('minesLeft')), findsOneWidget);
      final cells = find.byType(GestureDetector);
      await t.tapAt(t.getCenter(cells.at(30)));
      await t.pump(const Duration(milliseconds: 800));
      await t.longPressAt(t.getCenter(cells.at(3)));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.byKey(const ValueKey('hintButton')));
      await t.pump(const Duration(milliseconds: 600));
      await t.tap(find.byKey(const ValueKey('modeToggle')));
      await t.pump();
      expect(find.text('Flag'), findsOneWidget);
      await t.tap(find.byIcon(Icons.refresh_rounded));
      await t.pump(const Duration(milliseconds: 300));
      await t.pumpWidget(const SizedBox());
    });
  }
}
