import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/block_puzzle/block_puzzle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  testWidgets('menu shows tiers, picking one starts the game and remembers it', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: BlockPuzzleScreen()));
    await tester.pump(const Duration(seconds: 1));
    for (final t in ['Easy', 'Medium', 'Hard', 'Extreme']) {
      expect(find.text(t), findsOneWidget);
    }
    await tester.tap(find.text('Hard'));
    await tester.pump(const Duration(seconds: 1));
    expect(Storage.getInt('block.tier'), 2);
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.byKey(const ValueKey('slot-0')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('dragging a piece onto the board places it and scores', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: BlockPuzzleScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Easy'));
    await tester.pump(const Duration(seconds: 1));

    Text score() => tester.widget<Text>(find.byKey(const ValueKey('score')));
    expect(score().data, '0');

    final start = tester.getCenter(find.byKey(const ValueKey('slot-0')));
    final g = await tester.startGesture(start);
    await g.moveTo(start + const Offset(0, -300));
    await tester.pump();
    await g.moveTo(const Offset(200, 380));
    await tester.pump();
    await g.up();
    await tester.pump(const Duration(seconds: 2));
    expect(int.parse(score().data!), greaterThan(0));
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('dropping off the board does not place', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: BlockPuzzleScreen()));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Medium'));
    await tester.pump(const Duration(seconds: 1));
    final start = tester.getCenter(find.byKey(const ValueKey('slot-1')));
    final g = await tester.startGesture(start);
    await g.moveTo(start + const Offset(0, 10));
    await g.up();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<Text>(find.byKey(const ValueKey('score'))).data, '0');
    await tester.pump(const Duration(seconds: 3));
  });
}
