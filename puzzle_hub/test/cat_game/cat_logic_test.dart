import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/cat_game/logic/cat_logic.dart';

void main() {
  test('slides until wall', () {
    final l = CatLevel.parse(['C..#F']);
    final r = l.slide(l.start, Dir.right);
    expect(r.outcome, SlideOutcome.moved);
    expect(r.end, 2);
  });

  test('blocked, edge, yarn', () {
    final l = CatLevel.parse(['CY.F']);
    expect(l.slide(0, Dir.right).outcome, SlideOutcome.blocked);
    expect(l.slide(0, Dir.up).outcome, SlideOutcome.blocked);
  });

  test('fish stops and dog fails', () {
    final l = CatLevel.parse(['C.F.', 'D...']);
    expect(l.slide(0, Dir.right).outcome, SlideOutcome.fish);
    expect(l.slide(0, Dir.right).end, 2);
    expect(l.slide(0, Dir.down).outcome, SlideOutcome.dog);
  });

  test('BFS finds optimal path', () {
    final l = CatLevel.parse([
      'C..#',
      '....',
      '#..F',
    ]);
    final sol = CatSolver.solve(l)!;
    expect(sol.length, l.optimal);
    expect(sol.length, lessThanOrEqualTo(3));
  });

  test('unsolvable returns null', () {
    final l = CatLevel.parse(['C#F']);
    expect(CatSolver.solve(l), isNull);
  });

  test('stars', () {
    expect(starsFor(3, 3), 3);
    expect(starsFor(5, 3), 2);
    expect(starsFor(6, 3), 1);
  });

  test('every level solvable and replay of solution wins', () {
    expect(CatLevels.count, greaterThanOrEqualTo(30));
    for (var i = 0; i < CatLevels.count; i++) {
      final l = CatLevels.level(i);
      final sol = CatSolver.solve(l);
      expect(sol, isNotNull, reason: 'level $i');
      var pos = l.start;
      SlideResult? r;
      for (final d in sol!) {
        r = l.slide(pos, d);
        pos = r.end;
      }
      expect(r!.outcome, SlideOutcome.fish);
    }
  });
}
