import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/maze_escape/logic/levels.dart';
import 'package:puzzle_hub/games/maze_escape/logic/maze.dart';

void main() {
  test('maze is a perfect maze with exactly one route', () {
    for (final size in [7, 12, 21]) {
      for (var seed = 0; seed < 5; seed++) {
        final m = Maze.generate(seed, size, size);
        expect(m.reachableCount(), m.cellCount);
        expect(m.edgeCount, m.cellCount - 1); // connected tree => unique path
        final p = m.solve();
        expect(p.first, m.start);
        expect(p.last, m.exit);
        expect(m.optimalMoves, p.length - 1);
        expect(m.deadEndCount, greaterThan(0));
        for (var i = 0; i + 1 < p.length; i++) {
          final d = [0, 1, 2, 3].firstWhere((d) => m.neighbour(p[i], d) == p[i + 1]);
          expect(m.canMove(p[i], d), isTrue);
        }
      }
    }
  });

  test('maze walls are symmetric and deterministic', () {
    final a = Maze.generate(42, 9, 9), b = Maze.generate(42, 9, 9);
    expect(a.open, b.open);
    for (var c = 0; c < a.cellCount; c++) {
      for (var d = 0; d < 4; d++) {
        if (a.canMove(c, d)) expect(a.canMove(a.neighbour(c, d), opposite(d)), isTrue);
      }
    }
  });

  test('solve from arbitrary cell', () {
    final m = Maze.generate(3, 8, 8);
    final p = m.solve(from: 20);
    expect(p.first, 20);
    expect(p.last, m.exit);
  });

  test('every labyrinth level of every tier has a unique route', () {
    for (final t in MazeTier.values) {
      for (var level = 1; level <= kLevelCount; level++) {
        final l = LabLevel.of(t, level);
        final m = Maze.generate(l.seed, l.size, l.size);
        expect(m.reachableCount(), m.cellCount, reason: '${t.name} L$level');
        expect(m.edgeCount, m.cellCount - 1, reason: '${t.name} L$level');
        final p = m.solve();
        expect(p.first, m.start);
        expect(p.last, m.exit);
        expect(p.length, greaterThan(1));
        if (l.limited) expect(l.moveLimit(m.optimalMoves), greaterThan(m.optimalMoves));
      }
    }
  });

  test('tier scaling', () {
    expect(LabLevel.of(MazeTier.easy, 1).size, 7);
    expect(LabLevel.of(MazeTier.easy, kLevelCount).size, 11);
    expect(LabLevel.of(MazeTier.easy, kLevelCount).fogRadius, 0);
    expect(LabLevel.of(MazeTier.easy, 1).torches, 3);
    expect(LabLevel.of(MazeTier.medium, kLevelCount).size, 15);
    expect(LabLevel.of(MazeTier.hard, kLevelCount).size, 19);
    expect(LabLevel.of(MazeTier.hard, 5).fogRadius, 3);
    expect(LabLevel.of(MazeTier.hard, 5).torches, 2);
    expect(LabLevel.of(MazeTier.hard, 5).limited, isTrue);
    expect(LabLevel.of(MazeTier.extreme, kLevelCount).size, 25);
    expect(LabLevel.of(MazeTier.extreme, 5).fogRadius, 2);
    expect(LabLevel.of(MazeTier.extreme, 5).torches, 1);
    expect(LabLevel.of(MazeTier.extreme, 5).limitFactor, lessThan(LabLevel.of(MazeTier.hard, 5).limitFactor));
  });

  test('stars', () {
    expect(labStars(10, 10), 3);
    expect(labStars(10, 10, torchesUsed: 1), 2);
    expect(labStars(30, 10), 2);
    expect(labStars(100, 10), 1);
  });
}
