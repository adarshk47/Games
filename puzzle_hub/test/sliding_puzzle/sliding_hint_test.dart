import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/sliding_puzzle/logic/sliding_logic.dart';

void main() {
  test('following the hints solves a 3x3 board', () {
    var b = SlidingLogic.shuffle(3, 40, Random(5));
    for (var k = 0; k < 60 && !SlidingLogic.isSolved(b); k++) {
      final i = SlidingLogic.hintMove(b, 3)!;
      b = SlidingLogic.slide(b, 3, i)!;
    }
    expect(SlidingLogic.isSolved(b), isTrue);
  });

  test('big boards still get a legal move quickly', () {
    final b = SlidingLogic.shuffle(5, 200, Random(2));
    final sw = Stopwatch()..start();
    final i = SlidingLogic.hintMove(b, 5);
    expect(i, isNotNull);
    expect(SlidingLogic.slide(b, 5, i!), isNotNull);
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
