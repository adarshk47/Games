import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/block_puzzle/logic/block_logic.dart';

List<List<int>> empty(int n) => List.generate(n, (_) => List.filled(n, -1));

void main() {
  test('shape catalogue has up to 5 cells and many orientations', () {
    expect(Shapes.all.every((s) => s.isNotEmpty && s.length <= 5), isTrue);
    expect(Shapes.all.isNotEmpty && Shapes.all.length > 40, isTrue);
  });

  test('placement bounds and overlap', () {
    final g = BlockGame.custom(Tier.medium, empty(8));
    final p = Piece(const [(0, 0), (0, 1), (0, 2)], 1);
    expect(g.canPlace(p, 0, 5), isTrue);
    expect(g.canPlace(p, 0, 6), isFalse);
    expect(g.canPlace(p, -1, 0), isFalse);
    g.grid[0][1] = 3;
    expect(g.canPlace(p, 0, 0), isFalse);
  });

  test('clearing a row and column together, combo scoring', () {
    final grid = empty(8);
    for (var j = 1; j < 8; j++) {
      grid[0][j] = 0;
    }
    for (var i = 1; i < 8; i++) {
      grid[i][0] = 0;
    }
    final g = BlockGame.custom(Tier.medium, grid);
    g.tray = [Piece(const [(0, 0)], 2), Piece(const [(0, 0)], 2), Piece(const [(0, 0)], 2)];
    final r = g.place(0, 0, 0)!;
    expect(r.rows, [0]);
    expect(r.cols, [0]);
    expect(r.cleared.length, 15);
    expect(r.gained, 1 + 10 * 2 * 2);
    expect(g.grid.every((row) => row.every((v) => v == -1)), isTrue);
  });

  test('scoring grows with simultaneous lines and streak', () {
    expect(BlockGame.scoreFor(4, 0, 0), 4);
    expect(BlockGame.scoreFor(4, 1, 1), 14);
    expect(BlockGame.scoreFor(4, 2, 1), 44);
    expect(BlockGame.scoreFor(4, 1, 3), 4 + 10 + 10);
  });

  test('tray refills after all three used', () {
    final g = BlockGame(Tier.medium, rng: Random(1));
    for (var s = 0; s < 3; s++) {
      final p = g.tray[s]!;
      var done = false;
      for (var r = 0; r < 8 && !done; r++) {
        for (var c = 0; c < 8 && !done; c++) {
          if (g.canPlace(p, r, c)) done = g.place(s, r, c) != null;
        }
      }
    }
    expect(g.tray.every((e) => e != null) || g.over, isTrue);
  });

  test('game over detection', () {
    final grid = empty(8);
    for (var i = 0; i < 8; i++) {
      for (var j = 0; j < 8; j++) {
        if ((i + j) % 2 == 0) grid[i][j] = 0;
      }
    }
    final g = BlockGame.custom(Tier.medium, grid);
    g.tray = [Piece(const [(0, 0), (0, 1)], 0), null, Piece(const [(0, 0), (1, 0)], 0)];
    expect(g.isGameOver, isTrue);
    g.tray[1] = Piece(const [(0, 0)], 0);
    expect(g.isGameOver, isFalse);
  });

  test('board sizes and prefill per tier', () {
    expect(BlockGame(Tier.easy).n, 8);
    final h = BlockGame(Tier.hard);
    expect(h.grid.expand((e) => e).where((v) => v != -1).length, Tier.hard.prefill);
    final x = BlockGame(Tier.extreme);
    expect(x.n, Tier.extreme.boardSize);
    expect(x.grid.expand((e) => e).where((v) => v != -1).length, Tier.extreme.prefill);
  });

  test('Easy generator always offers a placeable piece', () {
    for (var seed = 0; seed < 150; seed++) {
      final rng = Random(seed);
      final grid = empty(8);
      for (var k = 0; k < 44; k++) {
        grid[rng.nextInt(8)][rng.nextInt(8)] = 0;
      }
      final g = BlockGame.custom(Tier.easy, grid, rng: rng);
      final anyRoom = grid.expand((e) => e).any((v) => v == -1);
      g.refill();
      if (anyRoom) expect(g.tray.whereType<Piece>().any(g.fitsAnywhere), isTrue, reason: 'seed $seed');
    }
  });
}
