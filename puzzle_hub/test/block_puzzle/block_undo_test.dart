import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/block_puzzle/logic/block_logic.dart';

void main() {
  test('undo takes back placements (max 3) and restores score and tray', () {
    final g = BlockGame(Tier.easy, rng: Random(7));
    final states = <(String, int)>[];
    for (var k = 0; k < 4; k++) {
      states.add((g.grid.toString() + g.tray.toString(), g.score));
      final slot = g.tray.indexWhere((p) => p != null);
      final p = g.tray[slot]!;
      var placed = false;
      for (var r = 0; r <= g.n - p.h && !placed; r++) {
        for (var c = 0; c <= g.n - p.w && !placed; c++) {
          placed = g.place(slot, r, c) != null;
        }
      }
      expect(placed, isTrue);
    }
    expect(g.undoDepth, 3);
    for (var k = 3; k >= 1; k--) {
      expect(g.undo(), isTrue);
      expect(g.grid.toString() + g.tray.toString(), states[k].$1);
      expect(g.score, states[k].$2);
    }
    expect(g.undo(), isFalse);
  });
}
