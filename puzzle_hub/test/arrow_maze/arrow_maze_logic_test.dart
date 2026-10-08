import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/arrow_maze/logic/arrow_maze_logic.dart';

void main() {
  const minDensity = {
    MazeTier.easy: 0.84,
    MazeTier.medium: 0.8,
    MazeTier.hard: 0.9,
    MazeTier.extreme: 0.9,
  };
  // Minimum number of arrows on any level of the tier.
  const minArrows = {
    MazeTier.easy: 12,
    MazeTier.medium: 16,
    MazeTier.hard: 45,
    MazeTier.extreme: 50,
  };

  test('every tier has 100 levels; extreme is huge with one life and hint', () {
    for (final t in MazeTier.values) {
      expect(t.count, 100);
    }
    expect(MazeTier.extreme.lives, 1);
    expect(MazeTier.extreme.hints, 1);
    final sp = ArrowMazeLevels.spec(MazeTier.extreme, 100);
    expect(sp.rows, 30);
    expect(sp.cols, 20);
  });

  for (final tier in MazeTier.values) {
    test('${tier.key}: all levels solvable, deterministic, dense, packed', () {
      var lo = 1.0, sum = 0.0, minBlocked = 1.0, minDepth = 999, minN = 999;
      for (var l = 1; l <= tier.count; l++) {
        final b = ArrowMazeLevels.generate(tier, l);
        final sp = ArrowMazeLevels.spec(tier, l);
        expect((b.rows, b.cols), (sp.rows, sp.cols));
        expect(b.solve(), isNotNull, reason: '${tier.key} level $l');
        expect(b.snakes.every((s) => s.length >= 2), isTrue);
        // Cells are distinct, in bounds and form connected paths.
        final seen = <int>{};
        for (final s in b.snakes) {
          for (var i = 0; i < s.cells.length; i++) {
            final c = s.cells[i];
            expect(c >= 0 && c < b.rows * b.cols, isTrue);
            expect(seen.add(c), isTrue, reason: 'overlap ${tier.key} $l');
            if (i > 0) {
              final p = s.cells[i - 1];
              final d = (c - p).abs();
              expect(d == 1 && c ~/ b.cols == p ~/ b.cols || d == b.cols,
                  isTrue);
            }
          }
        }
        final st = b.stats();
        lo = b.density < lo ? b.density : lo;
        sum += b.density;
        if (st.blockedFraction < minBlocked) minBlocked = st.blockedFraction;
        if (st.depth < minDepth) minDepth = st.depth;
        if (b.snakes.length < minN) minN = b.snakes.length;
        expect(b.density, greaterThanOrEqualTo(minDensity[tier]!),
            reason: '${tier.key} level $l');
        expect(b.snakes.length, greaterThanOrEqualTo(minArrows[tier]!),
            reason: '${tier.key} level $l arrows');
        if (tier.tangled) {
          // Heavy interlocking: most arrows start blocked, long chains.
          expect(st.blockedFraction, greaterThan(0.75),
              reason: '${tier.key} level $l');
          expect(st.depth, greaterThanOrEqualTo(10),
              reason: '${tier.key} level $l');
        }
      }
      // ignore: avoid_print
      print('${tier.key}: density min=${lo.toStringAsFixed(3)} '
          'avg=${(sum / tier.count).toStringAsFixed(3)} '
          'blocked>=${minBlocked.toStringAsFixed(2)} depth>=$minDepth '
          'arrows>=$minN');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

  test('generation is deterministic and fast', () {
    for (final tier in MazeTier.values) {
      final a = ArrowMazeLevels.generate(tier, 37);
      final b = ArrowMazeLevels.generate(tier, 37);
      expect(identical(a, b), isFalse); // fresh mutable boards
      expect(b.snakes.length, a.snakes.length);
      for (var i = 0; i < a.snakes.length; i++) {
        expect(b.snakes[i].cells, a.snakes[i].cells);
        expect(b.snakes[i].dir, a.snakes[i].dir);
      }
    }
    final sw = Stopwatch()..start();
    ArrowMazeLevels.generateTangle(30, 20, 4, 22, math.Random(7));
    expect(sw.elapsedMilliseconds, lessThan(400));
  });

  test('levels differ per tier and per level', () {
    String sig(ArrowMazeBoard b) =>
        b.snakes.map((s) => '${s.cells.join(',')}${s.dir}').join(';');
    expect(sig(ArrowMazeLevels.generate(MazeTier.hard, 3)),
        isNot(sig(ArrowMazeLevels.generate(MazeTier.hard, 4))));
    expect(sig(ArrowMazeLevels.generate(MazeTier.easy, 3)),
        isNot(sig(ArrowMazeLevels.generate(MazeTier.medium, 3))));
  });

  test('tap rules, undo, hint', () {
    final a = Snake(0, [0, 1], Dir.right);
    final b = Snake(1, [3, 4], Dir.down);
    final bd = ArrowMazeBoard(2, 5, [a, b]);
    expect(bd.canEscape(0), isFalse);
    expect(bd.tap(0), isFalse);
    expect(bd.canEscape(1), isTrue);
    expect(bd.hint()!.id, 1);
    expect(bd.tap(1), isTrue);
    expect(bd.tap(1), isNull);
    expect(bd.tap(0), isTrue);
    expect(bd.isCleared, isTrue);
    expect(bd.undo(), 0);
    expect(bd.remaining, 1);
    expect(bd.canEscape(0), isTrue);
  });

  test('stats: blocked fraction and dependency depth', () {
    // 0 -> blocked by 1 -> blocked by 2 (chain of three).
    final bd = ArrowMazeBoard(1, 6, [
      Snake(0, [0, 1], Dir.right),
      Snake(1, [2, 3], Dir.right),
      Snake(2, [4, 5], Dir.right),
    ]);
    final st = bd.stats();
    expect(st.depth, 3);
    expect(st.blockedFraction, closeTo(2 / 3, 1e-9));
  });
}
