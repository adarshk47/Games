import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/arrow_maze/logic/arrow_maze_logic.dart';

void main() {
  test('all levels are solvable, deterministic, dense', () {
    var minDensity = 1.0;
    for (var l = 1; l <= ArrowMazeLevels.count; l++) {
      final b = ArrowMazeLevels.generate(l);
      expect(b.solve(), isNotNull, reason: 'level $l');
      expect(b.snakes.every((s) => s.length >= 2), isTrue);
      final b2 = ArrowMazeLevels.generate(l);
      expect(b2.snakes.length, b.snakes.length);
      expect(b2.snakes.first.cells, b.snakes.first.cells);
      if (b.density < minDensity) minDensity = b.density;
      expect(b.density, greaterThan(0.55), reason: 'level $l');
    }
  });

  test('tap rules, undo, hint', () {
    // 1x? hand-made: snake A (row0, cols0-1 heading right) blocked by B at (0,3).
    final a = Snake(0, [0, 1], Dir.right);
    final b = Snake(1, [3, 4 + 0], Dir.down); // cells (0,3),(0,4)? cols=5 -> idx 3,4
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
