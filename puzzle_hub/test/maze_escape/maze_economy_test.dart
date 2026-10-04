import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('bought levels are per mode and only the first locked one', () async {
    expect(MazeProgress.firstLocked(MazeTier.easy), 2);
    await MazeProgress.buyUnlock(MazeTier.easy, 2);
    expect(MazeProgress.unlocked(MazeTier.easy, 2), isTrue);
    expect(MazeProgress.unlocked(MazeTier.easy, 3), isFalse);
    expect(MazeProgress.unlocked(MazeTier.easy, 2, mode: MazeMode.memory), isFalse);
    expect(MazeProgress.firstLocked(MazeTier.easy), 3);
    expect(MazeProgress.completed(MazeTier.easy), 0);
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
    expect(find.text('Deewar se takra gaye!'), findsNothing);
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

  testWidgets('level grid: next locked level can be unlocked', (t) async {
    await t.binding.setSurfaceSize(const Size(800, 1200));
    await _coins(150);
    await t.pumpWidget(const MaterialApp(home: MazeEscapeScreen()));
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.byKey(const ValueKey('mode-labyrinth')));
    await _settle(t);
    await t.tap(find.text('Easy'));
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
    expect(MazeProgress.isBought(MazeTier.easy, 2), isTrue);
    expect(find.text('Labyrinth Easy 2'), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 4));
  });
}
