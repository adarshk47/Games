import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/arrows/logic/arrows_logic.dart';

void main() {
  test('every level of every tier is solvable (play-solved) and sized', () {
    for (final t in ArrowsTier.values) {
      for (var l = 1; l <= ArrowsLevels.count; l++) {
        final b = ArrowsLevels.generate(t, l);
        expect(b.size, ArrowsLevels.sizeFor(t, l));
        expect(b.remaining, greaterThan(0));
        expect(b.isSolvable(), isTrue, reason: '${t.id} $l');
        // Play it out with taps only (never a blocked tap).
        var guard = 0;
        while (!b.isCleared) {
          final p = b.hint();
          expect(p, isNotNull, reason: '${t.id} $l stuck');
          expect(b.tap(p!.r, p.c), isTrue);
          expect(++guard, lessThan(1000));
        }
      }
      expect(ArrowsLevels.sizeFor(t, 1), t.minSize);
      expect(ArrowsLevels.sizeFor(t, ArrowsLevels.count), t.maxSize);
    }
  });

  test('tiers scale as specified', () {
    expect([for (final t in ArrowsTier.values) t.lives], [3, 3, 2, 1]);
    expect(ArrowsLevels.sizeFor(ArrowsTier.extreme, 30), 12);
    expect(ArrowsLevels.sizeFor(ArrowsTier.hard, 1), 7);
  });

  test('generation is deterministic and differs per tier', () {
    String sig(ArrowsBoard b) =>
        b.pieces.map((p) => '${p.r},${p.c},${p.dir}').join(';');
    expect(sig(ArrowsLevels.generate(ArrowsTier.easy, 5)),
        sig(ArrowsLevels.generate(ArrowsTier.easy, 5)));
    expect(sig(ArrowsLevels.generate(ArrowsTier.easy, 5)),
        isNot(sig(ArrowsLevels.generate(ArrowsTier.medium, 5))));
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
    final g = ArrowsLevels.generate(ArrowsTier.easy, 3);
    expect(g.canRemove(g.hint()!), isTrue);
  });
}
