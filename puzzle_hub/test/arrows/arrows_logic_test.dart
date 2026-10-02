import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/arrows/logic/arrows_logic.dart';

void main() {
  test('all levels are solvable and sized correctly', () {
    for (var l = 1; l <= ArrowsLevels.count; l++) {
      final b = ArrowsLevels.generate(l);
      expect(b.size, ArrowsLevels.sizeFor(l));
      expect(b.remaining, greaterThan(0));
      expect(b.isSolvable(), isTrue, reason: 'level $l');
    }
    expect(ArrowsLevels.sizeFor(1), 4);
    expect(ArrowsLevels.sizeFor(ArrowsLevels.count), 9);
  });

  test('generation is deterministic', () {
    String sig(ArrowsBoard b) =>
        b.pieces.map((p) => '${p.r},${p.c},${p.dir}').join(';');
    expect(sig(ArrowsLevels.generate(5)), sig(ArrowsLevels.generate(5)));
  });

  test('tap rules: blocked arrow stays, free arrow leaves', () {
    final b = ArrowsBoard(3, const [
      ArrowPiece(0, 1, 0, Dir.right),
      ArrowPiece(1, 1, 2, Dir.up),
    ]);
    expect(b.tap(0, 0), isNull);
    expect(b.tap(1, 0), isFalse);
    expect(b.remaining, 2);
    expect(b.tap(1, 2), isTrue);
    expect(b.tap(1, 0), isTrue);
    expect(b.isCleared, isTrue);
  });

  test('hint returns removable arrow; unsolvable detected', () {
    final blocked = ArrowsBoard(2, const [
      ArrowPiece(0, 0, 0, Dir.right),
      ArrowPiece(1, 0, 1, Dir.left),
      ArrowPiece(2, 1, 0, Dir.up),
      ArrowPiece(3, 1, 1, Dir.up),
    ]);
    expect(blocked.hint(), isNull);
    expect(blocked.isSolvable(), isFalse);
    final g = ArrowsLevels.generate(3);
    expect(g.canRemove(g.hint()!), isTrue);
  });
}
