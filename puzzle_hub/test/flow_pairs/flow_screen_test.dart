import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/flow_pairs/flow_pairs_screen.dart';
import 'package:puzzle_hub/games/flow_pairs/logic/flow_logic.dart';
import 'package:puzzle_hub/games/flow_pairs/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup(WidgetTester t, Size size) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(const MaterialApp(home: FlowPairsScreen()));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _drawSolution(WidgetTester t, FlowTier tier, int level) async {
  final p = FlowLevels.generate(tier, level);
  final finder = find.byKey(ValueKey('flow_board_${tier.id}_$level'));
  expect(finder, findsOneWidget);
  final rect = t.getRect(finder);
  final cs = rect.width / p.size;
  Offset at(int cell) => rect.topLeft + Offset((cell % p.size + .5) * cs, (cell ~/ p.size + .5) * cs);
  for (final s in p.solution) {
    final g = await t.startGesture(at(s.first));
    for (var k = 1; k < s.length; k++) {
      await g.moveTo(at(s[k]));
      await t.pump(const Duration(milliseconds: 16));
    }
    await g.up();
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final size in const [Size(360, 640), Size(800, 1280), Size(320, 480)]) {
    testWidgets('tiers, locks, play + win at $size', (t) async {
      await _setup(t, size);
      expect(find.text('Easy'), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, -600));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Extreme'), findsOneWidget);
      await t.drag(find.byType(ListView), const Offset(0, 600));
      await t.pump(const Duration(seconds: 1));
      await t.tap(find.text('Easy'));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(find.byIcon(Icons.lock_rounded), findsWidgets);
      await t.tap(find.text('1'));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));

      // undo / hint / restart controls
      await t.tap(find.byIcon(Icons.lightbulb_rounded));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.text('Undo'));
      await t.pump(const Duration(milliseconds: 200));
      await t.tap(find.byIcon(Icons.refresh_rounded));
      await t.pump(const Duration(milliseconds: 200));

      await _drawSolution(t, FlowTier.easy, 1);
      await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 1));
      expect(find.text('Flow complete!'), findsOneWidget);
      expect(FlowProgress.completed(FlowTier.easy), 1);
      expect(FlowProgress.stars(FlowTier.easy, 1), 3);

      await t.tap(find.text('Next level'));
      await t.pump(const Duration(seconds: 1));
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('flow_board_easy_2')), findsOneWidget);
    });
  }

  testWidgets('fill-required extreme level can be won by dragging', (t) async {
    await _setup(t, const Size(800, 1280));
    await Storage.setInt('flow.extreme.completed', 4);
    await Storage.setInt('flow.hard.completed', 9);
    await t.pump();
    await t.pumpWidget(MaterialApp(home: FlowLevelsPage(tier: FlowTier.hard)));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('flow_level_10')));
    await t.pump(const Duration(seconds: 1));
    await t.pump(const Duration(seconds: 1));
    await _drawSolution(t, FlowTier.hard, 10);
    await t.pump(const Duration(seconds: 2));
      await t.pump(const Duration(seconds: 1));
    expect(find.text('Flow complete!'), findsOneWidget);
    expect(FlowProgress.completed(FlowTier.hard), 10);
  });
}
