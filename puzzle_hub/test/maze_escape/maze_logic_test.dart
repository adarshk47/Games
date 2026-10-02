import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/maze_escape/logic/fork_path.dart';
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

  test('fork path has exactly one correct option per fork', () {
    for (var level = 1; level <= kLevelCount; level++) {
      final l = ForkLevel.of(level);
      final f = ForkPath.generate(l.seed, l.forks, l.options);
      expect(f.forkCount, l.forks);
      for (var i = 0; i < f.forkCount; i++) {
        expect([for (var o = 0; o < l.options; o++) if (f.isCorrect(i, o)) o].length, 1);
        expect(f.correct[i], inInclusiveRange(0, l.options - 1));
      }
    }
  });

  test('level scaling', () {
    expect(LabLevel.of(1).size, 7);
    expect(LabLevel.of(kLevelCount).size, 21);
    expect(ForkLevel.of(1).forks, 3);
    expect(ForkLevel.of(kLevelCount).forks, 8);
    expect(ForkLevel.of(1).options, 3);
    expect(ForkLevel.of(kLevelCount).options, 5);
  });

  test('stars', () {
    expect(labStars(10, 10), 3);
    expect(labStars(10, 10, torchesUsed: 1), 2);
    expect(labStars(30, 10), 2);
    expect(labStars(100, 10), 1);
    expect(forkStars(0, 5), 3);
    expect(forkStars(2, 5), 2);
    expect(forkStars(9, 5), 1);
  });
}
