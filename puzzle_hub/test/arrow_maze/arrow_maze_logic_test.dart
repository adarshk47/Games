import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/arrow_maze/logic/arrow_maze_logic.dart';

void main() {
  const minDensity = {
    MazeTier.easy: 0.85,
    MazeTier.medium: 0.7,
    MazeTier.hard: 0.7,
    MazeTier.extreme: 0.75,
  };

  for (final tier in MazeTier.values) {
    test('${tier.key}: all levels solvable, deterministic, dense', () {
      var lo = 1.0, hi = 0.0, sum = 0.0;
      for (var l = 1; l <= tier.count; l++) {
        final b = ArrowMazeLevels.generate(tier, l);
        expect(b.solve(), isNotNull, reason: '${tier.key} level $l');
        expect(b.snakes.every((s) => s.length >= 2), isTrue);
        final b2 = ArrowMazeLevels.generate(tier, l);
        expect(b2.snakes.length, b.snakes.length);
        expect(b2.snakes.first.cells, b.snakes.first.cells);
        lo = b.density < lo ? b.density : lo;
        hi = b.density > hi ? b.density : hi;
        sum += b.density;
        expect(b.density, greaterThan(minDensity[tier]!),
            reason: '${tier.key} level $l');
      }
      // ignore: avoid_print
      print('${tier.key}: density min=${lo.toStringAsFixed(3)} '
          'avg=${(sum / tier.count).toStringAsFixed(3)} '
          'max=${hi.toStringAsFixed(3)}');
    }, timeout: const Timeout(Duration(minutes: 5)));
  }

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
}
