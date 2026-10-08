import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/sliding_puzzle/logic/sliding_logic.dart';
import 'package:puzzle_hub/games/sliding_puzzle/sliding_puzzle_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  Future<void> open(WidgetTester t, {List<int>? start, Size size = const Size(360, 780)}) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    t.view.physicalSize = size;
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
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    expect(find.byKey(const ValueKey('slide-level-100')), findsNothing); // lazy grid
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

  testWidgets('skip gate: buy a far-ahead level, plays, refusal, clearing', (t) async {
    await open(t, start: [1, 2, 3, 4, 5, 6, 7, 0, 8], size: const Size(420, 1100));
    await Storage.setInt('coins', 1000);
    Rewards.reload();
    await t.tap(find.text('Easy'));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('slide-level-8')));
    await settle(t);
    expect(find.text('Unlock level 8?'), findsOneWidget);
    await t.tap(find.text('Unlock for 700 coins'));
    await settle(t);
    expect(Rewards.balance, 300);
    expect(find.text('Easy - Level 8'), findsOneWidget);
    expect(slidePlaysLeft(SlideTier.easy, 8), 9);

    // Restart spends a play.
    await t.tap(find.text('Restart'));
    await t.pump(const Duration(milliseconds: 300));
    expect(slidePlaysLeft(SlideTier.easy, 8), 8);

    // Solve it (debug board): clearing unlocks it and the next level.
    await t.tap(find.byKey(const ValueKey('tile-8')));
    await t.pump(const Duration(milliseconds: 300));
    await t.pump(const Duration(milliseconds: 2000));
    expect(find.text('Solved!'), findsOneWidget);
    expect(LevelGate.playsLeft('sliding.easy', 8), 0);
    expect(slideCanPlay(SlideTier.easy, 8), isTrue);
    expect(slideCanPlay(SlideTier.easy, 9), isTrue);
    expect(slideFreeUpTo(SlideTier.easy), 1);
    await settle(t);
    await t.tap(find.text('Menu'));
    await settle(t);

    // Not enough coins for level 12 (1100): refused.
    final before = Rewards.balance;
    await t.tap(find.byKey(const ValueKey('slide-level-12')));
    await settle(t);
    await t.tap(find.text('Unlock for 1100 coins'));
    await settle(t);
    expect(find.text('Not enough coins'), findsOneWidget);
    await t.tap(find.text('OK'));
    await settle(t);
    expect(Rewards.balance, before);
    expect(slideCanPlay(SlideTier.easy, 12), isFalse);
    expect(find.text('Easy - Level 12'), findsNothing);

    await t.pump(const Duration(seconds: 4));
    await t.pumpWidget(const SizedBox());
  });

  test('plays run out -> level locks again', () async {
    SharedPreferences.setMockInitialValues({'sliding.hard.skip.30': 1});
    await Storage.init();
    expect(slideCanPlay(SlideTier.hard, 30), isTrue);
    await slideOnStart(SlideTier.hard, 30);
    expect(slideCanPlay(SlideTier.hard, 30), isFalse);
  });
}
