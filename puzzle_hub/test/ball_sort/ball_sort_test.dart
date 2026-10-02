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
    expect(colorsForLevel(1), 3);
    expect(colorsForLevel(100), 12);
  });

  test('generated levels are valid and solvable', () {
    for (final level in [1, 2, 4, 7, 10, 20, 31, 60]) {
      final s = generateLevel(level);
      final counts = <int, int>{};
      for (final t in s.tubes) {
        expect(t.length <= kTubeCapacity, isTrue);
        for (final c in t) {
          counts[c] = (counts[c] ?? 0) + 1;
        }
      }
      expect(counts.length, colorsForLevel(level));
      expect(counts.values.every((v) => v == kTubeCapacity), isTrue);
      expect(s.isSolved, isFalse);
      if (level <= 10) {
        final sol = solve(s, maxNodes: 500000);
        expect(sol, isNotNull, reason: 'level $level');
        final play = s.clone();
        for (final m in sol!) {
          expect(play.pour(m[0], m[1]) > 0, isTrue);
        }
        expect(play.isSolved, isTrue);
      }
    }
  });

  test('generation is deterministic', () {
    expect(generateLevel(5).key, generateLevel(5).key);
  });
}
