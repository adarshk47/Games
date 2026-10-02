import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sudoku/logic/sudoku_logic.dart';

void main() {
  test('full grid is valid', () {
    for (var s = 0; s < 5; s++) {
      expect(isValidSolvedGrid(generateFullGrid(Random(s))), isTrue);
    }
  });

  test('solver solves and counts', () {
    final p = generatePuzzle(Difficulty.easy, seed: 1);
    final s = solve(p.puzzle)!;
    expect(s, p.solution);
    expect(countSolutions(List.filled(81, 0), limit: 2), 2);
  });

  test('puzzles are unique with expected clues', () {
    for (final d in Difficulty.values) {
      final p = generatePuzzle(d, seed: 42 + d.index);
      expect(countSolutions(p.puzzle), 1, reason: d.name);
      expect(p.puzzle.where((e) => e != 0).length, lessThanOrEqualTo(d.clues + 3));
      for (var i = 0; i < 81; i++) {
        if (p.puzzle[i] != 0) expect(p.puzzle[i], p.solution[i]);
      }
    }
  });

  test('every tier generates a unique-solution puzzle', () {
    expect(Difficulty.values.map((d) => d.label), ['Easy', 'Medium', 'Hard', 'Extreme']);
    for (final d in Difficulty.values) {
      final p = generatePuzzle(d, seed: 7);
      expect(countSolutions(p.puzzle), 1, reason: d.name);
      expect(solve(p.puzzle), p.solution, reason: d.name);
    }
    expect(difficultyFromName('expert'), Difficulty.extreme);
  });

  test('seeded generation is deterministic', () {
    final a = generatePuzzle(Difficulty.medium, seed: dailySeed(DateTime(2026, 1, 2)));
    final b = generatePuzzle(Difficulty.medium, seed: dailySeed(DateTime(2026, 1, 2)));
    expect(a.puzzle, b.puzzle);
  });

  test('invalid grid has zero solutions', () {
    final g = List<int>.filled(81, 0)..[0] = 5..[1] = 5;
    expect(countSolutions(g), 0);
  });
}
