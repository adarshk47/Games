import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/flow_pairs/logic/flow_logic.dart';

/// Replays the stored solution through the real drawing rules.
FlowGame replay(FlowPuzzle p) {
  final g = FlowGame(p);
  for (var i = 0; i < p.pairs.length; i++) {
    final s = p.solution[i];
    expect(g.begin(s.first), i);
    for (var k = 1; k < s.length; k++) {
      final r = g.extend(s[k]);
      expect(r, k == s.length - 1 ? FlowStep.connected : FlowStep.extended);
    }
    expect(g.end(), isTrue);
  }
  return g;
}

void main() {
  group('generator', () {
    for (final tier in FlowTier.values) {
      test('${tier.id}: all ${FlowLevels.count} levels solvable via replay', () {
        for (var l = 1; l <= FlowLevels.count; l++) {
          final p = FlowLevels.generate(tier, l);
          expect(p.size, FlowLevels.sizeFor(tier, l));
          // solution tiles the grid
          final seen = <int>{};
          for (var i = 0; i < p.pairs.length; i++) {
            final s = p.solution[i];
            expect(s.length, greaterThanOrEqualTo(3));
            expect(s.first, p.pairs[i].a);
            expect(s.last, p.pairs[i].b);
            for (var k = 0; k < s.length; k++) {
              expect(seen.add(s[k]), isTrue, reason: '${tier.id} L$l overlap');
              if (k > 0) {
                final d = (s[k] ~/ p.size - s[k - 1] ~/ p.size).abs() + (s[k] % p.size - s[k - 1] % p.size).abs();
                expect(d, 1);
              }
            }
          }
          expect(seen.length, p.cells);
          final g = replay(p);
          expect(g.solved, isTrue, reason: '${tier.id} L$l');
          expect(g.moves, p.pairs.length);
          expect(flowStars(g.moves, p.pairs.length), 3);
        }
      });
    }

    test('deterministic, and tier shapes match spec', () {
      for (final tier in FlowTier.values) {
        final a = FlowLevels.generate(tier, 7);
        final b = FlowLevels.generate(tier, 7);
        expect(identical(a, b) || a.solution.toString() == b.solution.toString(), isTrue);
      }
      expect(FlowLevels.generate(FlowTier.easy, 1).size, 5);
      expect(FlowLevels.generate(FlowTier.easy, 30).pairs.length, inInclusiveRange(4, 5));
      expect(FlowLevels.generate(FlowTier.medium, 30).size, 7);
      expect(FlowLevels.generate(FlowTier.hard, 30).size, 9);
      expect(FlowLevels.generate(FlowTier.extreme, 30).size, 12);
      expect(FlowLevels.generate(FlowTier.easy, 1).requireFill, isFalse);
      expect(FlowLevels.generate(FlowTier.hard, 1).requireFill, isTrue);
      expect(FlowLevels.generate(FlowTier.extreme, 1).requireFill, isTrue);
    });
  });

  group('rules', () {
    final p = FlowLevels.generate(FlowTier.easy, 1);

    test('cannot draw non-adjacent, blocked by other endpoint', () {
      final g = FlowGame(p);
      final s = p.solution[0];
      g.begin(s.first);
      expect(g.extend(s.last == s[1] ? s[2] : s.last), FlowStep.none);
      g.end();
      final tiny = FlowPuzzle(
          size: 3,
          pairs: const [FlowPair(0, 2), FlowPair(3, 5)],
          solution: const [
            [0, 1, 2],
            [3, 4, 5]
          ],
          requireFill: false);
      final tb = FlowBoard(tiny);
      tb.begin(0);
      expect(tb.extend(3), FlowStep.blocked);
      expect(tb.extend(1), FlowStep.extended);
      expect(tb.extend(2), FlowStep.connected);
      expect(tb.isConnected(0), isTrue);
      // complete path cannot be extended further
      expect(tb.extend(5), FlowStep.none);
    });

    test('drawing over another path cuts it; backtracking works', () {
      final tiny = FlowPuzzle(
          size: 3,
          pairs: const [FlowPair(0, 2), FlowPair(3, 5)],
          solution: const [
            [0, 1, 2],
            [3, 4, 5]
          ],
          requireFill: false);
      final b = FlowBoard(tiny);
      b.begin(3);
      b.extend(4);
      b.extend(5);
      expect(b.isConnected(1), isTrue);
      b.end();
      b.begin(0);
      expect(b.extend(1), FlowStep.extended);
      expect(b.extend(4), FlowStep.cut);
      expect(b.lastCut, 1);
      expect(b.paths[1], [3]);
      expect(b.isConnected(1), isFalse);
      expect(b.owner[5], -1);
      expect(b.extend(1), FlowStep.backtracked);
      expect(b.paths[0], [0, 1]);
      expect(b.extend(0), FlowStep.backtracked);
      b.end();
      expect(b.paths[0], isEmpty);
    });

    test('fill requirement and completion check', () {
      final tiny = FlowPuzzle(
          size: 3,
          pairs: const [FlowPair(0, 2), FlowPair(3, 5)],
          solution: const [
            [0, 1, 2],
            [3, 4, 5]
          ],
          requireFill: true);
      // only 6 of 9 cells are in the solution so fill can never be reached here
      final g = FlowGame(tiny);
      g.begin(0);
      g.extend(1);
      g.extend(2);
      g.end();
      g.begin(3);
      g.extend(4);
      g.extend(5);
      g.end();
      expect(g.board.connectedCount, 2);
      expect(g.solved, isFalse);
      final loose = FlowPuzzle(size: 3, pairs: tiny.pairs, solution: tiny.solution, requireFill: false);
      final g2 = FlowGame(loose);
      g2.begin(0);
      g2.extend(1);
      g2.extend(2);
      g2.end();
      expect(g2.solved, isFalse);
      g2.begin(3);
      g2.extend(4);
      g2.extend(5);
      g2.end();
      expect(g2.solved, isTrue);
    });

    test('tap on endpoint is not a move; undo/restart/hint', () {
      final g = FlowGame(p);
      g.begin(p.pairs[0].a);
      expect(g.end(), isFalse);
      expect(g.moves, 0);
      expect(g.board.paths[0], isEmpty);

      final s = p.solution[1];
      g.begin(s.first);
      g.extend(s[1]);
      expect(g.end(), isTrue);
      expect(g.moves, 1);
      expect(g.undo(), isTrue);
      expect(g.moves, 0);
      expect(g.board.filledCount, 0);

      expect(g.hint(), 0);
      expect(g.hintsLeft, 2);
      expect(g.board.isConnected(0), isTrue);
      expect(g.moves, 0);
      expect(g.undo(), isTrue);
      expect(g.board.filledCount, 0);

      for (var i = 0; i < 2; i++) {
        expect(g.hint(), isNotNull);
      }
      expect(g.hint(), isNull);
      g.restart();
      expect(g.hintsLeft, g.maxHints);
      expect(g.board.filledCount, 0);
    });

    test('hints alone can solve a level', () {
      final big = FlowGame(FlowLevels.generate(FlowTier.easy, 3), maxHints: 99);
      while (!big.solved) {
        expect(big.hint(), isNotNull);
      }
      expect(big.moves, 0);
    });

    test('mid-path begin truncates; stars thresholds', () {
      final g = replay(p);
      expect(g.solved, isTrue);
      expect(flowStars(p.pairs.length * 2, p.pairs.length), 2);
      expect(flowStars(p.pairs.length * 3, p.pairs.length), 1);
      final g2 = FlowGame(p);
      final s = p.solution[0];
      g2.begin(s.first);
      for (var k = 1; k < s.length - 1; k++) {
        g2.extend(s[k]);
      }
      g2.end();
      g2.begin(s[1]);
      expect(g2.board.paths[0], [s[0], s[1]]);
    });
  });
}
