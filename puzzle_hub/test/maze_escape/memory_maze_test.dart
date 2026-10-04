import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
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

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  test('every memory maze level of every tier has a unique route', () {
    for (final t in MazeTier.values) {
      for (var level = 1; level <= kLevelCount; level++) {
        final l = MemLevel.of(t, level);
        final m = Maze.generate(l.seed, l.size, l.size);
        expect(m.reachableCount(), m.cellCount, reason: '${t.name} L$level');
        expect(m.edgeCount, m.cellCount - 1, reason: '${t.name} L$level');
        final p = m.solve();
        expect(p.first, m.start);
        expect(p.last, m.exit);
        expect(p.length, greaterThan(1));
        // Deterministic.
        expect(MemLevel.of(t, level).seed, l.seed);
        expect(Maze.generate(l.seed, l.size, l.size).open, m.open);
      }
    }
  });

  test('memory tier params', () {
    const sizes = {
      MazeTier.easy: [5, 7],
      MazeTier.medium: [7, 9],
      MazeTier.hard: [9, 11],
      MazeTier.extreme: [11, 13],
    };
    const secs = {MazeTier.easy: 6, MazeTier.medium: 5, MazeTier.hard: 4, MazeTier.extreme: 3};
    const peeks = {MazeTier.easy: 3, MazeTier.medium: 2, MazeTier.hard: 1, MazeTier.extreme: 0};
    for (final t in MazeTier.values) {
      expect(MemLevel.of(t, 1).size, sizes[t]![0]);
      expect(MemLevel.of(t, kLevelCount).size, sizes[t]![1]);
      for (var l = 1; l <= kLevelCount; l++) {
        final c = MemLevel.of(t, l);
        expect(c.peeks, peeks[t]);
        expect(c.previewMs, greaterThanOrEqualTo(secs[t]! * 1000));
        expect(c.previewMs, lessThan((secs[t]! + 1) * 1000));
        expect(c.maxBumps, t == MazeTier.extreme ? 3 : 0);
      }
      // Bigger mazes get a little more preview time.
      expect(MemLevel.of(t, kLevelCount).previewMs, greaterThan(MemLevel.of(t, 1).previewMs));
    }
    expect(MemLevel.of(MazeTier.easy, 1).previewMs, 6000);
    expect(MemLevel.of(MazeTier.extreme, 1).previewMs, 3000);
    expect(MemLevel.of(MazeTier.easy, 1).seed, isNot(LabLevel.of(MazeTier.easy, 1).seed));
  });

  test('memory star rules', () {
    expect(memStars(0, 0), 3);
    expect(memStars(1, 0), 3);
    expect(memStars(2, 0), 2);
    expect(memStars(4, 0), 2);
    expect(memStars(5, 0), 1);
    expect(memStars(0, 1), 2); // any peek caps at 2
    expect(memStars(2, 1), 2);
    expect(memStars(3, 1), 1);
    expect(memStars(0, 3), 1);
  });

  test('memory progress keys are separate from labyrinth keys', () {
    expect(MazeProgress.key(MazeTier.hard, 4), 'maze.lab.hard.stars.4');
    expect(MazeProgress.key(MazeTier.hard, 4, mode: MazeMode.memory), 'maze.mem.hard.stars.4');
    MazeProgress.save(MazeTier.easy, 1, 2, mode: MazeMode.memory);
    expect(MazeProgress.stars(MazeTier.easy, 1, mode: MazeMode.memory), 2);
    expect(MazeProgress.stars(MazeTier.easy, 1), 0);
    expect(MazeProgress.unlocked(MazeTier.easy, 2, mode: MazeMode.memory), isTrue);
    expect(MazeProgress.unlocked(MazeTier.easy, 2), isFalse);
    expect(MazeProgress.modeStars(MazeMode.memory), 2);
    expect(MazeProgress.modeStars(MazeMode.labyrinth), 0);
  });

  testWidgets('mode menu leads to memory maze tiers and levels', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    await tester.pumpWidget(const MaterialApp(home: MazeEscapeScreen()));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Labyrinth'), findsOneWidget);
    expect(find.text('Memory Maze'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mode-memory')));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Extreme'), findsOneWidget);
    await tester.tap(find.text('Easy'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Memory Maze - Easy'), findsOneWidget);
    expect(find.text('5x5'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('play a memory maze level from memory', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final cfg = MemLevel.of(MazeTier.easy, 1);
    final maze = Maze.generate(cfg.seed, cfg.size, cfg.size);
    final path = maze.solve();
    int dirTo(int a, int b) => [0, 1, 2, 3].firstWhere((d) => maze.neighbour(a, d) == b);

    await tester.pumpWidget(const MaterialApp(home: MemoryMazeGame(tier: MazeTier.easy, level: 1)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Memorise!'), findsOneWidget);
    expect(find.text('Ready!'), findsOneWidget);

    // Input is ignored during the preview.
    await tester.tap(find.byIcon(_icons[dirTo(path[0], path[1])]));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Bumps 0'), findsOneWidget);
    expect(find.text('Memorise!'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('mem-ready')));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Moves 0'), findsOneWidget);
    expect(find.text('Ready!'), findsNothing);

    // Bump into a wall at the start.
    final wallDir = [0, 1, 2, 3].firstWhere((d) => !maze.canMove(maze.start, d));
    await tester.tap(find.byIcon(_icons[wallDir]));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('Bumps 1'), findsOneWidget);

    // Peek once.
    await tester.tap(find.byKey(const ValueKey('mem-peek')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Peek 2'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));

    for (var i = 0; i + 1 < path.length; i++) {
      await tester.tap(find.byIcon(_icons[dirTo(path[i], path[i + 1])]));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 150));
    }
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Yaad se nikal gaye!'), findsOneWidget);
    // 1 bump + 1 peek => 2 stars, saved under the memory key only.
    expect(MazeProgress.stars(MazeTier.easy, 1, mode: MazeMode.memory), 2);
    expect(MazeProgress.stars(MazeTier.easy, 1), 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('extreme fails after 3 bumps', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    final cfg = MemLevel.of(MazeTier.extreme, 1);
    final maze = Maze.generate(cfg.seed, cfg.size, cfg.size);
    final wallDir = [0, 1, 2, 3].firstWhere((d) => !maze.canMove(maze.start, d));
    await tester.pumpWidget(const MaterialApp(home: MemoryMazeGame(tier: MazeTier.extreme, level: 1)));
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Peek 0'), findsOneWidget);
    expect(find.text('Bumps 0 / 3'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(_icons[wallDir]));
      await tester.pump(const Duration(milliseconds: 600));
    }
    await tester.pump(const Duration(seconds: 1));
    // Continue offer first (no coins); decline it.
    expect(find.text('Keep going?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Deewar se takra gaye!'), findsOneWidget);
    expect(MazeProgress.stars(MazeTier.extreme, 1, mode: MazeMode.memory), 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
