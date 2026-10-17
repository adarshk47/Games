import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/block_puzzle/logic/block_logic.dart';

void main() {
  test('a saved game comes back exactly (board, tray, score)', () {
    final g = BlockGame(Tier.medium, rng: Random(3));
    final slot = g.tray.indexWhere((p) => p != null);
    final p = g.tray[slot]!;
    var placed = false;
    for (var r = 0; r <= g.n - p.h && !placed; r++) {
      for (var c = 0; c <= g.n - p.w && !placed; c++) {
        placed = g.place(slot, r, c) != null;
      }
    }
    expect(placed, isTrue);
    final json = jsonDecode(jsonEncode(g.toJson())) as Map<String, dynamic>;
    final back = BlockGame.fromJson(Tier.medium, json)!;
    expect(back.grid.toString(), g.grid.toString());
    expect([for (final t in back.tray) t?.cells.toString()], [for (final t in g.tray) t?.cells.toString()]);
    expect(back.score, g.score);
    expect(BlockGame.fromJson(Tier.hard, json), isNull, reason: 'other difficulty');
  });
}
