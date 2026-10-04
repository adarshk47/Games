import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/arrow_maze/arrow_maze_screen.dart';
import 'package:puzzle_hub/games/arrow_maze/logic/arrow_maze_logic.dart';
import 'package:puzzle_hub/games/arrow_maze/progress.dart';
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
  test('only the first locked level can be bought; bought levels unlock', () async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    const tier = MazeTier.easy;
    expect(ArrowMazeProgress.firstLocked(tier), 2);
    await ArrowMazeProgress.buyUnlock(tier, 2);
    expect(ArrowMazeProgress.isUnlocked(tier, 2), isTrue);
    expect(ArrowMazeProgress.isUnlocked(tier, 3), isFalse);
    expect(ArrowMazeProgress.firstLocked(tier), 3);
    ArrowMazeProgress.complete(tier, 2, 3);
    expect(ArrowMazeProgress.isUnlocked(tier, 3), isTrue);
    expect(ArrowMazeProgress.isDone(tier, 1), isFalse);
  });

  testWidgets('paid hint after free hints and extra life before losing', (t) async {
    const tier = MazeTier.extreme;
    await _setup(t, const ArrowMazeGamePage(tier: tier, level: 1), coins: 100);
    final board = ArrowMazeLevels.generate(tier, 1);

    // Free hint, then a paid one.
    await t.tap(find.byIcon(Icons.lightbulb_rounded));
    await t.pump(const Duration(milliseconds: 200));
    expect(find.textContaining('Hints 0'), findsOneWidget);
    await t.tap(find.byIcon(Icons.lightbulb_rounded));
    await _settle(t);
    expect(find.text('Need a hint?'), findsOneWidget);
    await t.tap(find.text('Use 20 coins'));
    await _settle(t);
    expect(find.text('Need a hint?'), findsNothing);
    expect(Rewards.balance, 80);

    // Tap a blocked arrow: one life -> continue offer.
    final blocked = board.snakes.firstWhere((s) => !board.canEscape(s.id));
    final rect = t.getRect(find.byKey(const ValueKey('board_1_1')));
    final cell = rect.width / (board.cols + 1);
    final at = rect.topLeft +
        Offset((blocked.head % board.cols + 1) * cell,
            (blocked.head ~/ board.cols + 1) * cell);
    await t.tapAt(at);
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t);
    expect(Rewards.balance, 50);
    expect(find.text('Out of lives'), findsNothing);

    // Second loss: decline -> normal lose dialog.
    await t.tapAt(at);
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(find.text('Out of lives'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('tapping the next locked level offers an unlock', (t) async {
    await _setup(t, const ArrowMazeScreen(), coins: 200);
    await t.tap(find.text('Easy'));
    await _settle(t);
    final locks = find.byIcon(Icons.lock_rounded);
    // Level 3 is not the next one: nothing happens.
    await t.tap(locks.at(1));
    await _settle(t);
    expect(find.text('Unlock level?'), findsNothing);
    // Level 2 is.
    await t.tap(locks.first);
    await _settle(t);
    expect(find.text('Unlock level?'), findsOneWidget);
    await t.tap(find.text('Use 150 coins'));
    await _settle(t);
    expect(find.text('Easy - Level 2'), findsOneWidget);
    expect(ArrowMazeProgress.isBought(MazeTier.easy, 2), isTrue);
    expect(Rewards.balance, 50);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
