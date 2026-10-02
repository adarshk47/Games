import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/ball_sort/logic/ball_sort_logic.dart';

void main() {
  test('pour rules', () {
    final s = BallSortState([
      [0, 1, 1],
      [2, 1],
      [],
      [0, 0, 0, 0],
    ]);
    expect(s.canPour(0, 1), isTrue);
    expect(s.pour(0, 1), 2);
    expect(s.tubes[1], [2, 1, 1, 1]);
    expect(s.canPour(0, 3), isFalse);
    expect(s.canPour(1, 0), isFalse);
    expect(s.moves, 1);
  });

  test('capacity limits pour count', () {
    final s = BallSortState([
      [1, 1, 1],
      [0, 1, 1],
    ]);
    expect(s.pourCount(0, 1), 1);
  });

  test('win detection and extra tube', () {
    final s = BallSortState([
      [0, 0, 0, 0],
      [],
      [1, 1, 1, 1],
    ]);
    expect(s.isSolved, isTrue);
    expect(
        BallSortState([
          [0, 0, 0],
          [0],
        ]).isSolved,
        isFalse);
    expect(s.addTube(), isTrue);
    expect(s.addTube(), isTrue);
    expect(s.addTube(), isFalse);
    expect(s.tubes.length, 5);
  });

  test('difficulty progression', () {
    expect(colorsForLevel(BsDifficulty.easy, 1), 3);
    expect(colorsForLevel(BsDifficulty.easy, 100), 5);
    expect(colorsForLevel(BsDifficulty.medium, 1), 6);
    expect(colorsForLevel(BsDifficulty.medium, 100), 9);
    expect(colorsForLevel(BsDifficulty.hard, 1), 10);
    expect(colorsForLevel(BsDifficulty.hard, 100), 14);
    expect(colorsForLevel(BsDifficulty.extreme, 1), 15);
    expect(colorsForLevel(BsDifficulty.extreme, 100), 20);
    expect(emptyTubesForLevel(BsDifficulty.extreme, 1), 2);
    expect(emptyTubesForLevel(BsDifficulty.extreme, 30), 1);
  });

  test('every level of every difficulty is valid and solvable by its solution', () {
    for (final d in BsDifficulty.values) {
      for (var level = 1; level <= 60; level++) {
        final g = generateLevelWithSolution(d, level);
        final s = g.state;
        final counts = <int, int>{};
        for (final t in s.tubes) {
          expect(t.length <= kTubeCapacity, isTrue);
          for (final c in t) {
            counts[c] = (counts[c] ?? 0) + 1;
          }
        }
        expect(counts.length, colorsForLevel(d, level));
        expect(counts.values.every((v) => v == kTubeCapacity), isTrue);
        expect(s.tubes.length, counts.length + emptyTubesForLevel(d, level));
        expect(s.isSolved, isFalse);
        final play = s.clone();
        for (final m in g.solution) {
          expect(play.pour(m[0], m[1]) > 0, isTrue, reason: '${d.id} L$level');
        }
        expect(play.isSolved, isTrue, reason: '${d.id} L$level');
      }
    }
  });

  test('solver agrees on early levels', () {
    for (final d in [BsDifficulty.easy, BsDifficulty.medium]) {
      for (final level in [1, 5, 9]) {
        final sol = solve(generateLevel(d, level), maxNodes: 300000);
        expect(sol, isNotNull, reason: '${d.id} L$level');
      }
    }
  });

  test('stars by par', () {
    final par = parMoves(BsDifficulty.easy, 1);
    expect(starsFor(BsDifficulty.easy, 1, par), 3);
    expect(starsFor(BsDifficulty.easy, 1, par * 2), 1);
  });

  test('generation is deterministic and differs per difficulty', () {
    expect(generateLevel(BsDifficulty.easy, 5).key, generateLevel(BsDifficulty.easy, 5).key);
    expect(generateLevel(BsDifficulty.easy, 5).key, isNot(generateLevel(BsDifficulty.hard, 5).key));
  });
}
