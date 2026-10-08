import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/hexa_sort/hexa_sort_screen.dart';
import 'package:puzzle_hub/games/hexa_sort/logic/hexa_sort_logic.dart';
import 'package:puzzle_hub/games/hexa_sort/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup(WidgetTester t, Widget home, {int coins = 0, Size size = const Size(400, 800)}) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
  await Storage.setInt('coins', coins);
  Rewards.reload();
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(MaterialApp(home: home));
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

Future<void> _place(WidgetTester t, int offer, int cell) async {
  await t.tap(find.byKey(ValueKey('hs_offer_$offer')));
  await t.pump(const Duration(milliseconds: 100));
  await t.tap(find.byKey(ValueKey('hs_cell_$cell')));
  await _settle(t, 4);
}

/// Three cells in a row: 0 - 1 - 2.
HsLevel _row({Map<int, List<int>> initial = const {}, required List<List<int>> script, int goal = 100}) => HsLevel(
      tier: HsTier.easy,
      number: 1,
      board: HsBoard(rows: 1, cols: 3),
      colors: 3,
      goal: goal,
      seed: 11,
      initial: initial,
      script: script,
    );

void main() {
  testWidgets('tier select opens the level grid', (t) async {
    await _setup(t, const HexaSortScreen());
    expect(find.text('Hexa Sort'), findsOneWidget);
    expect(find.text('Choose difficulty'), findsOneWidget);
    for (final s in ['Easy', 'Medium', 'Hard']) {
      expect(find.text(s), findsWidgets, reason: s);
    }
    await t.ensureVisible(find.text('Hard'));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.text('Hard'));
    await _settle(t, 3);
    expect(find.text('Hexa Sort · Hard'), findsOneWidget);
    expect(find.text('Play level 1'), findsOneWidget);
    expect(find.byIcon(Icons.lock_rounded), findsWidgets);
    await t.tap(find.text('Play level 1'));
    await _settle(t, 3);
    expect(find.text('Hard · 1'), findsOneWidget);
    expect(find.text('0 moves'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('placing stacks merges matching neighbours', (t) async {
    final lv = _row(initial: {
      0: [1, 1]
    }, script: [
      [1],
      [2],
      [0, 0],
    ]);
    await _setup(t, HexaSortGame(tier: HsTier.easy, level: 1, custom: lv));
    // Occupied cell is refused.
    await t.tap(find.byKey(const ValueKey('hs_cell_0')));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.text('Pick an empty cell'), findsOneWidget);
    await _settle(t, 4);
    // The single 1 joins cell 0, so cell 1 is free again.
    await _place(t, 0, 1);
    expect(t.takeException(), isNull);
    expect(find.text('1 moves'), findsOneWidget);
    await _place(t, 1, 1);
    expect(find.text('Pick an empty cell'), findsNothing);
    expect(find.text('2 moves'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('clearing ten tiles wins a crafted level', (t) async {
    final lv = _row(initial: {
      0: [0, 0, 0, 0, 0],
      2: [0, 0, 0, 0],
    }, script: [
      [0],
      [1, 1],
      [2, 2],
    ], goal: 10);
    await _setup(t, HexaSortGame(tier: HsTier.easy, level: 1, custom: lv));
    expect(find.text('Goal 0/10'), findsOneWidget);
    await _place(t, 0, 1);
    await _settle(t, 6);
    expect(t.takeException(), isNull);
    expect(find.text('Goal 10/10'), findsOneWidget);
    expect(find.text('Level complete!'), findsOneWidget);
    expect(HsProgress.stars(HsTier.easy, 1), 3);
    expect(HsProgress.unlocked(HsTier.easy), 2);
    expect(Rewards.balance, greaterThan(0));
    await t.tap(find.text('Next level'));
    await _settle(t, 2);
    expect(find.text('Easy · 2'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('full board offers to clear space, declining loses', (t) async {
    final lv = _row(script: [
      [0],
      [1],
      [2],
    ], goal: 10);
    await _setup(t, HexaSortGame(tier: HsTier.easy, level: 1, custom: lv), coins: 100);
    await _place(t, 0, 0);
    await _place(t, 1, 1);
    await _place(t, 2, 2);
    await _settle(t, 3);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t, 2);
    expect(Rewards.balance, 70);
    expect(find.text('Board full!'), findsNothing);
    // Every cell was freed: placing again works.
    await _place(t, 0, 1);
    expect(find.text('Pick an empty cell'), findsNothing);
    await _finish(t);

    // Declining shows the loss dialog.
    await _setup(t, HexaSortGame(tier: HsTier.easy, level: 1, custom: lv));
    await _place(t, 0, 0);
    await _place(t, 1, 1);
    await _place(t, 2, 2);
    await _settle(t, 3);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tapAt(const Offset(4, 4)); // dismiss the offer
    await _settle(t, 3);
    expect(find.text('Board full!'), findsOneWidget);
    await t.tap(find.text('Try again'));
    await _settle(t, 2);
    expect(find.text('0 moves'), findsOneWidget);
    await _finish(t);
  });

  testWidgets('one free refresh, then a paid offer', (t) async {
    await _setup(t, const HexaSortGame(tier: HsTier.medium, level: 3));
    await t.tap(find.textContaining('1 free'));
    await _settle(t, 2);
    expect(find.textContaining('free'), findsNothing);
    await t.tap(find.text('New stacks'));
    await _settle(t, 2);
    expect(find.text('Need a hint?'), findsOneWidget);
    await t.tapAt(const Offset(4, 4)); // dismiss the offer
    await _settle(t, 2);
    await _finish(t);
  });

  testWidgets('a locked level can be skipped to with coins', (t) async {
    await _setup(t, const HexaSortLevels(tier: HsTier.medium), coins: 300);
    await _settle(t, 2);
    await t.tap(find.byKey(const ValueKey('hs_level_3')));
    await _settle(t, 2);
    expect(find.text('Unlock level 3?'), findsOneWidget);
    await t.tap(find.text('Unlock for 200 coins'));
    await _settle(t, 3);
    expect(find.text('Medium · 3'), findsOneWidget);
    expect(Rewards.balance, 100);
    expect(LevelGate.playsLeft(HsProgress.prefix(HsTier.medium), 3), LevelGate.maxPlays - 1);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(t, 2);
    expect(find.text('9 plays left'), findsOneWidget);
    // Not enough coins for a bigger jump.
    await t.tap(find.byKey(const ValueKey('hs_level_9')));
    await _settle(t, 2);
    await t.tap(find.text('Unlock for 800 coins'));
    await _settle(t, 2);
    expect(find.text('Medium · 9'), findsNothing);
    expect(Rewards.balance, 100);
    await _finish(t);
  });
}
