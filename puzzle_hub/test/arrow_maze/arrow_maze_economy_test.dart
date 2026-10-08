import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
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
  // InkRipple: no shader asset needed (ink_sparkle.frag may be unavailable).
  await t.pumpWidget(MaterialApp(
      theme: ThemeData(splashFactory: InkRipple.splashFactory), home: home));
  await t.pump(const Duration(seconds: 1));
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  test('skip gate: plays, relock at zero, clearing unlocks for good', () async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    const tier = MazeTier.easy;
    final prefix = ArrowMazeProgress.gatePrefix(tier);
    expect(prefix, 'arrow_maze.easy');
    expect(ArrowMazeProgress.freeUpTo(tier), 1);
    expect(ArrowMazeProgress.canPlay(tier, 1), isTrue);
    expect(ArrowMazeProgress.canPlay(tier, 2), isFalse);
    expect(LevelGate.skipPrice(ArrowMazeProgress.freeUpTo(tier), 6), 500);

    // Bought level with 2 plays: each start costs one, then it locks again.
    await Storage.setInt('$prefix.skip.6', 2);
    expect(ArrowMazeProgress.skipPlaysLeft(tier, 6), 2);
    await ArrowMazeProgress.onStart(tier, 6);
    expect(ArrowMazeProgress.skipPlaysLeft(tier, 6), 1);
    await ArrowMazeProgress.onStart(tier, 6);
    expect(ArrowMazeProgress.canPlay(tier, 6), isFalse);

    // Free levels never spend plays.
    await ArrowMazeProgress.onStart(tier, 1);
    expect(ArrowMazeProgress.canPlay(tier, 1), isTrue);

    // Clearing a bought level unlocks it and the next one for good.
    await Storage.setInt('$prefix.skip.9', 10);
    await ArrowMazeProgress.complete(tier, 9, 3);
    expect(LevelGate.playsLeft(prefix, 9), 0);
    expect(ArrowMazeProgress.canPlay(tier, 9), isTrue);
    expect(ArrowMazeProgress.isUnlocked(tier, 10), isTrue);
    expect(ArrowMazeProgress.isUnlocked(tier, 8), isFalse);
    expect(ArrowMazeProgress.freeUpTo(tier), 1);

    // Legacy one-off unlocks stay valid.
    await Storage.setBool('arrow_maze.easy.unlockedBought.30', true);
    expect(ArrowMazeProgress.isUnlocked(tier, 30), isTrue);
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

  testWidgets('skip gate in the level grid: buy far level, plays, refuse',
      (t) async {
    const tier = MazeTier.easy;
    final prefix = ArrowMazeProgress.gatePrefix(tier);
    await _setup(t, const ArrowMazeScreen(), coins: 1000);
    await t.tap(find.text('Easy'));
    await _settle(t);
    // Level 1 is free; level 5 (locks: 2,3,4,5,...) costs 4 x 100.
    final locks = find.byIcon(Icons.lock_rounded);
    await t.tap(locks.at(3));
    await _settle(t);
    expect(find.text('Unlock level 5?'), findsOneWidget);
    await t.tap(find.text('Unlock for 400 coins'));
    await _settle(t);
    expect(Rewards.balance, 600);
    expect(LevelGate.playsLeft(prefix, 5), 10);
    expect(find.text('10 plays left'), findsOneWidget);
    expect(find.byKey(const ValueKey('skip_badge_5')), findsOneWidget);

    // Playing it spends a play.
    await t.tap(find.text('5'));
    await _settle(t);
    expect(find.text('Easy - Level 5'), findsOneWidget);
    expect(LevelGate.playsLeft(prefix, 5), 9);
    // Restart spends another one.
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await _settle(t);
    expect(LevelGate.playsLeft(prefix, 5), 8);
    t.state<NavigatorState>(find.byType(Navigator)).pop();
    await _settle(t);
    expect(find.text('8 plays left'), findsOneWidget);

    // Not enough coins for a far jump: refused, nothing changes.
    await t.tap(find.byIcon(Icons.lock_rounded).at(17)); // level 20
    await _settle(t);
    expect(find.text('Unlock level 20?'), findsOneWidget);
    await t.tap(find.text('Unlock for 1900 coins'));
    await _settle(t);
    expect(find.text('Not enough coins'), findsOneWidget);
    await t.tap(find.text('OK'));
    await _settle(t);
    expect(Rewards.balance, 600);
    expect(LevelGate.playsLeft(prefix, 20), 0);
    expect(find.byKey(const ValueKey('skip_badge_20')), findsNothing);

    // Cancelling the price dialog spends nothing either.
    await t.tap(find.byIcon(Icons.lock_rounded).at(1)); // level 3
    await _settle(t);
    await t.tap(find.text('Cancel'));
    await _settle(t);
    expect(Rewards.balance, 600);

    // Clearing the bought level unlocks it (and the next) for good.
    await ArrowMazeProgress.complete(tier, 5, 3);
    expect(LevelGate.playsLeft(prefix, 5), 0);
    expect(ArrowMazeProgress.canPlay(tier, 5), isTrue);
    expect(ArrowMazeProgress.canPlay(tier, 6), isTrue);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('largest extreme board (30x20) renders, taps and zooms', (t) async {
    await _setup(t,
        const ArrowMazeGamePage(tier: MazeTier.extreme, level: 100));
    final board = ArrowMazeLevels.generate(MazeTier.extreme, 100);
    expect((board.rows, board.cols), (30, 20));
    expect(t.takeException(), isNull);
    expect(find.byType(InteractiveViewer), findsOneWidget);
    final free = board.snakes.firstWhere((s) => board.canEscape(s.id));
    final rect = t.getRect(find.byKey(const ValueKey('board_100_1')));
    final cell = rect.width / (board.cols + 1);
    await t.tapAt(rect.topLeft +
        Offset((free.head % board.cols + 1) * cell,
            (free.head ~/ board.cols + 1) * cell));
    await _settle(t);
    expect(find.textContaining('Left ${board.snakes.length - 1}'),
        findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 3));
  });
}
