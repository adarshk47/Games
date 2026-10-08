import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/ball_sort/ball_sort_game.dart';
import 'package:puzzle_hub/games/ball_sort/ball_sort_screen.dart';
import 'package:puzzle_hub/games/ball_sort/logic/ball_sort_logic.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _coins(int n) async {
  await Storage.setInt('coins', n);
  Rewards.reload();
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 400));
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  const d = BsDifficulty.easy;

  test('skip gate: free in sequence, plays decrement, clearing unlocks', () async {
    expect(bsFreeUpTo(d), 1);
    expect(bsCanPlay(d, 1), isTrue);
    expect(bsCanPlay(d, 2), isFalse);
    await Storage.setInt('${bsGatePrefix(d)}.skip.50', LevelGate.maxPlays);
    expect(bsCanPlay(d, 50), isTrue);
    expect(bsPlaysLeft(d, 50), 10);
    await bsOnStart(d, 50);
    expect(bsPlaysLeft(d, 50), 9);
    await bsOnStart(d, 1);
    expect(LevelGate.playsLeft(bsGatePrefix(d), 1), 0);
    for (var i = 0; i < 9; i++) {
      await bsOnStart(d, 50);
    }
    expect(bsCanPlay(d, 50), isFalse); // locked again
    // Clearing a level unlocks it and the next one.
    await Storage.setInt(bsKey(d, 'stars.50'), 2);
    expect(bsCanPlay(d, 50), isTrue);
    expect(bsCanPlay(d, 51), isTrue);
    expect(bsCanPlay(d, 52), isFalse);
    expect(bsFreeUpTo(d), 1);
    // Legacy "unlocked" key keeps working.
    await Storage.setInt(bsKey(d, 'unlocked'), 8);
    expect(bsCanPlay(d, 8), isTrue);
    expect(bsFreeUpTo(d), 8);
  });

  testWidgets('level grid: buy a far-ahead level, refuse without coins', (t) async {
    await t.binding.setSurfaceSize(const Size(500, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await _coins(600);
    await t.pumpWidget(const MaterialApp(home: BallSortScreen()));
    await t.pump(const Duration(milliseconds: 800));
    await t.tap(find.text('Easy').first);
    await _settle(t);
    expect(find.byKey(const ValueKey('bs-level-100')), findsNothing); // lazy grid

    await t.tap(find.byKey(const ValueKey('bs-level-6')));
    await _settle(t);
    expect(find.text('Unlock level 6?'), findsOneWidget);
    await t.tap(find.text('Unlock for 500 coins'));
    await _settle(t);
    expect(Rewards.balance, 100);
    expect(find.text('Level 6'), findsOneWidget); // in the game
    expect(bsPlaysLeft(d, 6), 9);

    Navigator.of(t.element(find.text('Level 6'))).pop();
    await _settle(t);
    expect(find.text('9 plays left'), findsOneWidget);
    expect(find.text('BOUGHT'), findsOneWidget);

    // Not enough coins.
    await t.tap(find.byKey(const ValueKey('bs-level-12')));
    await _settle(t);
    await t.tap(find.text('Unlock for 1100 coins'));
    await _settle(t);
    expect(find.text('Not enough coins'), findsOneWidget);
    await t.tap(find.text('OK'));
    await _settle(t);
    expect(Rewards.balance, 100);
    expect(bsCanPlay(d, 12), isFalse);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });

  testWidgets('clearing a bought level unlocks the next one', (t) async {
    await t.binding.setSurfaceSize(const Size(500, 1000));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await Storage.setInt('${bsGatePrefix(d)}.skip.5', LevelGate.maxPlays);
    await t.pumpWidget(const MaterialApp(home: BallSortGame(difficulty: d, level: 5)));
    await t.pump(const Duration(milliseconds: 500));
    expect(bsPlaysLeft(d, 5), 9);
    // Solve it with the generator's known solution by tapping tubes.
    final g = generateLevelWithSolution(d, 5);
    final tubes = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_TubeView');
    expect(tubes, findsNWidgets(g.state.tubes.length));
    for (final m in g.solution) {
      await t.tap(tubes.at(m[0]), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 30));
      await t.tap(tubes.at(m[1]), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 400));
    }
    await t.pump(const Duration(seconds: 1));
    await _settle(t);
    expect(bsStars(d, 5), greaterThan(0));
    expect(LevelGate.playsLeft(bsGatePrefix(d), 5), 0);
    expect(bsCanPlay(d, 5), isTrue);
    expect(bsCanPlay(d, 6), isTrue);
    expect(bsFreeUpTo(d), 1);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
  });
}
