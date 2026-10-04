import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/arrows/arrows_screen.dart';
import 'package:puzzle_hub/games/arrows/logic/arrows_logic.dart';
import 'package:puzzle_hub/games/arrows/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup(WidgetTester t, Widget home, {int coins = 0}) async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
  await Storage.setInt('coins', coins);
  Rewards.reload();
  t.view.physicalSize = const Size(800, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(MaterialApp(home: home));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  test('buying the next locked level does not mark the skipped one done', () async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    const tier = ArrowsTier.easy;
    await ArrowsProgress.complete(tier, 1, 3);
    expect(ArrowsProgress.firstLocked(tier), 3);
    await ArrowsProgress.buyUnlock(tier, 3);
    expect(ArrowsProgress.isUnlocked(tier, 3), isTrue);
    await ArrowsProgress.complete(tier, 3, 2);
    expect(ArrowsProgress.isDone(tier, 2), isFalse);
    expect(ArrowsProgress.isDone(tier, 3), isTrue);
    expect(ArrowsProgress.isUnlocked(tier, 4), isTrue);
    expect(ArrowsProgress.completed(tier), 1);
    // Clearing the skipped level closes the gap.
    await ArrowsProgress.complete(tier, 2, 1);
    expect(ArrowsProgress.completed(tier), 3);
    expect(ArrowsProgress.firstLocked(tier), 5);
  });

  testWidgets('extra life continues the level when paid', (t) async {
    await _setup(t, const ArrowsGamePage(tier: ArrowsTier.extreme, level: 30), coins: 100);
    final board = ArrowsLevels.generate(ArrowsTier.extreme, 30);
    final blocked = board.pieces.firstWhere((p) => !board.canRemove(p));
    final rect = t.getRect(find.byKey(const ValueKey('board_extreme_30_1')));
    final cell = rect.width / board.size;
    final at = rect.topLeft + Offset((blocked.c + .5) * cell, (blocked.r + .5) * cell);
    await t.tapAt(at);
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t);
    expect(find.text('Out of lives'), findsNothing);
    expect(Rewards.balance, 70);
    // Still playable: block again -> second offer, decline -> lose.
    await t.tapAt(at);
    await _settle(t);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.text('Out of lives'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('tapping the next locked level offers an unlock', (t) async {
    await _setup(t, const ArrowsLevelsPage(tier: ArrowsTier.easy), coins: 150);
    await _settle(t);
    final locks = find.byIcon(Icons.lock_rounded);
    await t.tap(locks.at(1));
    await _settle(t);
    expect(find.text('Unlock level?'), findsNothing);
    await t.tap(locks.first);
    await _settle(t);
    expect(find.text('Unlock level?'), findsOneWidget);
    await t.tap(find.text('Use 150 coins'));
    await _settle(t);
    expect(find.text('Easy - Level 2'), findsOneWidget);
    expect(ArrowsProgress.isBought(ArrowsTier.easy, 2), isTrue);
    expect(Rewards.balance, 0);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
