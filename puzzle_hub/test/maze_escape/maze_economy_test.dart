import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/maze_escape/labyrinth_game.dart';
import 'package:puzzle_hub/games/maze_escape/logic/levels.dart';
import 'package:puzzle_hub/games/maze_escape/logic/maze.dart';
import 'package:puzzle_hub/games/maze_escape/maze_escape_screen.dart';
import 'package:puzzle_hub/games/maze_escape/memory_maze_game.dart';
import 'package:puzzle_hub/games/maze_escape/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _icons = [
  Icons.keyboard_arrow_up_rounded,
  Icons.keyboard_arrow_right_rounded,
  Icons.keyboard_arrow_down_rounded,
  Icons.keyboard_arrow_left_rounded,
];

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

  test('skip gate: free in sequence, bought plays per mode, clearing unlocks', () async {
    const t = MazeTier.easy;
    expect(MazeProgress.freeUpTo(t), 1);
    expect(MazeProgress.canPlay(t, 1), isTrue);
    expect(MazeProgress.canPlay(t, 2), isFalse);
    expect(MazeProgress.gatePrefix(t), 'maze.lab.easy');
    await Storage.setInt('maze.lab.easy.skip.40', LevelGate.maxPlays);
    expect(MazeProgress.canPlay(t, 40), isTrue);
    expect(MazeProgress.playsLeft(t, 40), 10);
    expect(MazeProgress.canPlay(t, 40, mode: MazeMode.memory), isFalse);
    await MazeProgress.onStart(t, 40);
    expect(MazeProgress.playsLeft(t, 40), 9);
    await MazeProgress.onStart(t, 1); // free levels never use plays
    MazeProgress.save(t, 40, 3);
    await Future<void>.delayed(Duration.zero);
    expect(LevelGate.playsLeft('maze.lab.easy', 40), 0);
    expect(MazeProgress.unlocked(t, 40), isTrue);
    expect(MazeProgress.unlocked(t, 41), isTrue);
    expect(MazeProgress.unlocked(t, 39), isFalse);
    expect(MazeProgress.freeUpTo(t), 1);
    // Legacy one-time unlocks stay valid.
    await Storage.setBool('maze.lab.easy.unlockedBought.2', true);
    expect(MazeProgress.unlocked(t, 2), isTrue);
  });

  test('plays running out locks the level again', () async {
    await Storage.setInt('maze.mem.hard.skip.7', 1);
    expect(MazeProgress.canPlay(MazeTier.hard, 7, mode: MazeMode.memory), isTrue);
    await MazeProgress.onStart(MazeTier.hard, 7, mode: MazeMode.memory);
    expect(MazeProgress.canPlay(MazeTier.hard, 7, mode: MazeMode.memory), isFalse);
  });

  testWidgets('memory extreme: paid continue adds 3 bumps, paid peek', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    await _coins(100);
    final cfg = MemLevel.of(MazeTier.extreme, 1);
    final maze = Maze.generate(cfg.seed, cfg.size, cfg.size);
    final wallDir = [0, 1, 2, 3].firstWhere((d) => !maze.canMove(maze.start, d));
    await t.pumpWidget(const MaterialApp(home: MemoryMazeGame(tier: MazeTier.extreme, level: 1)));
    await t.pump(const Duration(seconds: 4));

    // Out of free peeks -> offer a paid one.
    expect(find.text('Peek 0'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('mem-peek')));
    await _settle(t);
    expect(find.text('Need a hint?'), findsOneWidget);
    await t.tap(find.text('Use 20 coins'));
    await _settle(t);
    expect(Rewards.balance, 80);
    await t.pump(const Duration(seconds: 3));

    for (var i = 0; i < 3; i++) {
      await t.tap(find.byIcon(_icons[wallDir]));
      await t.pump(const Duration(milliseconds: 600));
    }
    await _settle(t);
    expect(find.text('Keep going?'), findsOneWidget);
    await t.tap(find.text('Use 30 coins'));
    await _settle(t);
    expect(find.text('Bumps 3 / 6'), findsOneWidget);
    expect(find.text('Hit the walls!'), findsNothing);
    expect(Rewards.balance, 50);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('labyrinth: torch offered when out', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    await _coins(100);
    await t.pumpWidget(const MaterialApp(home: LabyrinthGame(tier: MazeTier.extreme, level: 1)));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byIcon(Icons.flashlight_on_rounded)); // the free one
    await t.pump(const Duration(milliseconds: 100));
    await t.pump(const Duration(seconds: 4));
    expect(find.text('🔦 0'), findsOneWidget);
    expect(find.text('Need a hint?'), findsNothing);
    await t.tap(find.byIcon(Icons.flashlight_on_rounded));
    await _settle(t);
    expect(find.text('Need a hint?'), findsOneWidget);
    await t.tap(find.text('Use 20 coins'));
    await _settle(t);
    expect(Rewards.balance, 80);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });

  Future<void> openGrid(WidgetTester t) async {
    await t.pumpWidget(const MaterialApp(home: MazeEscapeScreen()));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('mode-labyrinth')));
    await _settle(t);
    await t.tap(find.text('Easy'));
    await _settle(t);
  }

  testWidgets('level grid: far-ahead level bought with coins gets 10 plays', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    await _coins(1000);
    await openGrid(t);
    await t.tap(find.byKey(const ValueKey('maze-level-10')));
    await _settle(t);
    expect(find.text('Unlock level 10?'), findsOneWidget);
    await t.tap(find.text('Unlock for 900 coins'));
    await _settle(t);
    expect(Rewards.balance, 100);
    expect(find.text('Labyrinth Easy 10'), findsOneWidget);
    expect(MazeProgress.playsLeft(MazeTier.easy, 10), 9); // first play counted

    // Restart spends another play.
    await t.tap(find.byIcon(Icons.refresh_rounded));
    await _settle(t);
    expect(MazeProgress.playsLeft(MazeTier.easy, 10), 8);

    Navigator.of(t.element(find.text('Labyrinth Easy 10'))).pop();
    await _settle(t);
    expect(find.text('8 plays left'), findsOneWidget);
    expect(find.text('BOUGHT'), findsOneWidget);

    // Not enough coins: refused, nothing granted.
    await t.tap(find.byKey(const ValueKey('maze-level-20')));
    await _settle(t);
    await t.tap(find.text('Unlock for 1900 coins'));
    await _settle(t);
    expect(find.text('Not enough coins'), findsOneWidget);
    await t.tap(find.text('OK'));
    await _settle(t);
    expect(Rewards.balance, 100);
    expect(MazeProgress.canPlay(MazeTier.easy, 20), isFalse);
    expect(find.text('Labyrinth Easy 20'), findsNothing);

    // Clearing the bought level unlocks it and the next one for good.
    MazeProgress.save(MazeTier.easy, 10, 2);
    await _settle(t);
    expect(find.text('8 plays left'), findsNothing);
    expect(MazeProgress.unlocked(MazeTier.easy, 11), isTrue);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });

  testWidgets('level grid: the next level in sequence is free', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    MazeProgress.save(MazeTier.easy, 1, 3);
    await openGrid(t);
    await t.tap(find.byKey(const ValueKey('maze-level-2')));
    await _settle(t);
    expect(find.text('Labyrinth Easy 2'), findsOneWidget);
    expect(Rewards.balance, 0);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
