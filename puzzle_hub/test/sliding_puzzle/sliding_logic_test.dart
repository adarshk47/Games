import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sliding_puzzle/logic/sliding_logic.dart';

void main() {
  test('every tier/level shuffles to a solvable, unsolved board', () {
    final rng = Random(7);
    for (final tier in SlideTier.values) {
      for (var l = 1; l <= SlideTier.levelCount; l++) {
        final b = SlidingLogic.shuffle(tier.size, tier.depthFor(l), rng);
        expect(b.length, tier.size * tier.size);
        expect(List.of(b)..sort(), [for (var i = 0; i < b.length; i++) i]);
        expect(SlidingLogic.isSolvable(b, tier.size), isTrue, reason: '${tier.key} L$l');
        expect(SlidingLogic.isSolved(b), isFalse);
        // Deterministic per tier/level seed.
        final a1 = SlidingLogic.shuffle(tier.size, tier.depthFor(l), Random(tier.seedFor(l)));
        final a2 = SlidingLogic.shuffle(tier.size, tier.depthFor(l), Random(tier.seedFor(l)));
        expect(a1, a2);
        expect(SlidingLogic.isSolvable(a1, tier.size), isTrue);
        expect(SlidingLogic.isSolved(a1), isFalse);
      }
    }
  });

  test('depth increases with level and tiers have the right sizes', () {
    expect(SlideTier.values.map((t) => t.size), [3, 4, 5, 6]);
    expect(SlideTier.levelCount, 100);
    for (final t in SlideTier.values) {
      expect(t.depthFor(20), greaterThan(t.depthFor(1)));
      for (var l = 2; l <= SlideTier.levelCount; l++) {
        expect(t.depthFor(l), greaterThan(t.depthFor(l - 1)), reason: '${t.key} L$l');
      }
      // Original first 20 levels unchanged.
      expect(t.depthFor(20), t.baseDepth + t.depthStep * 20);
    }
  });

  test('solvability detects an unsolvable swap', () {
    expect(SlidingLogic.isSolvable(SlidingLogic.solved(3), 3), isTrue);
    expect(SlidingLogic.isSolvable(SlidingLogic.solved(4), 4), isTrue);
    expect(SlidingLogic.isSolvable([2, 1, 3, 4, 5, 6, 7, 8, 0], 3), isFalse);
    final b = SlidingLogic.solved(4);
    final t = b[0];
    b[0] = b[1];
    b[1] = t;
    expect(SlidingLogic.isSolvable(b, 4), isFalse);
  });

  test('single and multi-tile slides', () {
    final s = SlidingLogic.solved(3); // gap at index 8
    expect(SlidingLogic.slide(s, 3, 8), isNull); // gap
    expect(SlidingLogic.slide(s, 3, 0), isNull); // not in line
    expect(SlidingLogic.slide(s, 3, 7), [1, 2, 3, 4, 5, 6, 7, 0, 8]);
    expect(SlidingLogic.slide(s, 3, 5), [1, 2, 3, 4, 5, 0, 7, 8, 6]);
    // multi: tap 6 (index 6) with gap at 8 -> row shifts right
    expect(SlidingLogic.slide(s, 3, 6), [1, 2, 3, 4, 5, 6, 0, 7, 8]);
    // column multi: tap index 2 with gap at 8
    expect(SlidingLogic.slide(s, 3, 2), [1, 2, 0, 4, 5, 3, 7, 8, 6]);
    expect(SlidingLogic.movers(s, 3, 6), [7, 6]);
  });

  test('slide preserves solvability and win check', () {
    final rng = Random(3);
    var b = SlidingLogic.shuffle(4, 30, rng);
    for (var i = 0; i < 200; i++) {
      final nb = SlidingLogic.slide(b, 4, rng.nextInt(16));
      if (nb != null) b = nb;
      expect(SlidingLogic.isSolvable(b, 4), isTrue);
    }
    expect(SlidingLogic.isSolved([1, 2, 3, 4, 5, 6, 7, 0, 8]), isFalse);
    expect(SlidingLogic.isSolved(SlidingLogic.slide([1, 2, 3, 4, 5, 6, 7, 0, 8], 3, 8)!), isTrue);
  });

  test('stars by moves vs par', () {
    expect(SlidingLogic.starsFor(10, 10), 3);
    expect(SlidingLogic.starsFor(20, 10), 2);
    expect(SlidingLogic.starsFor(100, 10), 1);
  });
}
