import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/tile_match/logic/tile_match_logic.dart';
import 'package:puzzle_hub/games/tile_match/progress.dart';
import 'package:puzzle_hub/games/tile_match/tile_match_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

Future<void> _setup(WidgetTester t, Widget home, {int coins = 0, Size size = const Size(400, 800)}) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
  await Storage.setInt('coins', coins);
  Rewards.reload();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  // InkSparkle needs a shader asset that widget tests do not bundle.
  await t.pumpWidget(MaterialApp(theme: ThemeData(splashFactory: InkRipple.splashFactory), home: home));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _settle(WidgetTester t, [int n = 6]) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

Future<void> _finish(WidgetTester t) async {
  await t.pumpWidget(const SizedBox());
  await t.pump(const Duration(seconds: 3));
}

Future<void> _tapTile(WidgetTester t, int id) async {
  await t.tap(find.byKey(ValueKey('tm_tile_$id')));
  await t.pump(const Duration(milliseconds: 350));
  await t.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('tier select opens the level grid', (t) async {
    await _setup(t, const TileMatchScreen());
    expect(find.text('Tile Match'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsOneWidget);
    for (final s in ['Easy', 'Medium', 'Hard']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.tap(find.text('Hard'));
    await _settle(t, 3);
    expect(find.text('Tile Match · Hard'), findsOneWidget);
    expect(find.text('Play level 1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    await t.tap(find.text('Play level 1'));
    await _settle(t, 3);
    expect(find.text('Hard · Level 1'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('playing the solution wins and saves progress', (t) async {
    await _setup(t, const TileMatchGame(tier: TmTier.easy, level: 1));
    final lv = tmGenerate(TmTier.easy, 1);
    for (final id in lv.solution) {
      await _tapTile(t, id);
    }
    await _settle(t);
    expect(t.takeException(), isNull);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(TmProgress.stars(TmTier.easy, 1), 3);
    expect(TmProgress.unlocked(TmTier.easy), 2);
    expect(Rewards.balance, greaterThan(0));
    await t.tap(find.text('Next level'));
    await _settle(t, 2);
    expect(find.text('Easy · Level 2'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('a covered tile is refused', (t) async {
    await _setup(t, const TileMatchGame(tier: TmTier.medium, level: 5));
    final g = TmGame(tmGenerate(TmTier.medium, 5));
    final covered = g.level.tiles.firstWhere((x) => !g.isFree(x.id) && g.level.above[x.id].length == 1);
    // Tap the visible part of the covered tile: its bottom-right corner area.
    final box = t.getRect(find.byKey(ValueKey('tm_tile_${covered.id}')));
    final top = g.level.tiles[g.level.above[covered.id].first];
    final dx = top.x > covered.x ? box.left + 3 : box.right - 3;
    final dy = top.y > covered.y ? box.top + 3 : box.bottom - 3;
    await t.tapAt(Offset(dx, dy));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.text('Covered! Clear the tiles on top first.'), findsOneWidget);
    expect(find.byKey(ValueKey('tm_tile_${covered.id}')), findsOneWidget);
    await _settle(t);
    await _finish(t);
  });

  testWidgets('full tray offers a continue that returns 3 tiles; declining loses', (t) async {
    const tier = TmTier.extreme;
    await _setup(t, const TileMatchGame(tier: tier, level: 1), coins: 100, size: const Size(400, 860));
    final g = TmGame(tmGenerate(tier, 1));
    final line = losingLine(g);
    expect(g.lost, isTrue);
    for (final id in line) {
      await _tapTile(t, id);
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t, 2);
    expect(find.text('Tray full!'), findsNothing);
    expect(find.text('3 tiles went back to the board'), findsOneWidget);
    expect(Rewards.balance, 70);
    // Fill it again, then decline.
    g.returnLast();
    final more = losingLine(g);
    expect(g.lost, isTrue);
    for (final id in more) {
      await _tapTile(t, id);
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.text('Tray full!'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await _settle(t, 2);
    expect(find.text('${tmGenerate(tier, 1).tiles.length} tiles left'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('undo and shuffle: one free each, then a paid offer', (t) async {
    await _setup(t, const TileMatchGame(tier: TmTier.easy, level: 3), coins: 0);
    final lv = tmGenerate(TmTier.easy, 3);
    await _tapTile(t, lv.solution.first);
    expect(find.text('${lv.tiles.length} tiles left'), findsOneWidget); // tray tiles still count
    final undo = find.byKey(const ValueKey('tm_undo'));
    final shuffle = find.byKey(const ValueKey('tm_shuffle'));
    expect(find.descendant(of: undo, matching: find.text('1')), findsOneWidget);
    await t.tap(undo);
    await _settle(t, 2);
    expect(find.descendant(of: undo, matching: find.text('1')), findsNothing);
    expect(find.text('Undo move?'), findsNothing);
    await t.tap(shuffle);
    await _settle(t, 2);
    expect(find.text('Tiles shuffled!'), findsOneWidget);
    await t.tap(shuffle);
    await _settle(t, 2);
    expect(find.text('Need a hint?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t, 2);
    // Undo is disabled with an empty history; after a move it asks for coins.
    final g = TmGame(lv);
    final free = g.freeTiles.first;
    await _tapTile(t, free);
    await t.tap(undo);
    await _settle(t, 2);
    expect(find.text('Undo move?'), findsOneWidget);
    expect(find.text('Use 10 coins'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t, 2);
    await _finish(t);
  });

  testWidgets('locked levels can be skipped with coins (LevelGate)', (t) async {
    await _setup(t, const TileMatchLevels(tier: TmTier.medium), coins: 250);
    await _settle(t, 2);
    await t.tap(find.byKey(const ValueKey('tm_level_3')));
    await _settle(t, 2);
    expect(find.text('Unlock level 3?'), findsOneWidget);
    await t.tap(find.text('Unlock for 200 coins'));
    await _settle(t, 3);
    expect(find.text('Medium · Level 3'), findsOneWidget);
    expect(Rewards.balance, 50);
    expect(LevelGate.playsLeft(TmProgress.prefix(TmTier.medium), 3), LevelGate.maxPlays - 1);
    expect(find.text('9 plays left'), findsWidgets);
    // Back to the grid: the bought level shows its plays.
    await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await _settle(t, 2);
    expect(find.text('9 plays left'), findsWidgets);
    // Too expensive: level 10 needs 900 coins.
    await t.tap(find.byKey(const ValueKey('tm_level_10')));
    await _settle(t, 2);
    await t.tap(find.text('Unlock for 900 coins'));
    await _settle(t, 2);
    expect(find.text('Not enough coins'), findsOneWidget);
    await _finish(t);
  });
}
