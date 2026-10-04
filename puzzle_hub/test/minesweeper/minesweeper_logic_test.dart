import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/minesweeper/logic/minesweeper_logic.dart';

List<bool> layout(int n, List<int> mines) => [for (var i = 0; i < n; i++) mines.contains(i)];

void main() {
  test('tier configs', () {
    expect([for (final c in mineConfigs.values) '${c.cols}x${c.rows}:${c.mines}'],
        ['8x8:8', '10x10:18', '12x16:40', '14x20:70']);
  });

  test('first tap is always safe, with a zero opening, and mine counts are exact', () {
    for (final t in MineTier.values) {
      for (var seed = 0; seed < 30; seed++) {
        final g = MineGame.forTier(t, random: Random(seed));
        final tap = seed * 7 % g.size;
        g.reveal(tap);
        expect(g.status, isNot(MineStatus.lost));
        expect(g.mine.where((m) => m).length, mineConfigs[t]!.mines);
        expect(g.mine[tap], isFalse);
        for (final n in g.neighbors(tap)) {
          expect(g.mine[n], isFalse);
        }
        expect(g.adj[tap], 0);
        expect(g.revealedCount, greaterThan(1));
      }
    }
  });

  test('adjacency numbers', () {
    final g = MineGame(3, 3, 2, mines: layout(9, [0, 1]));
    expect(g.adj[4], 2);
    expect(g.adj[2], 1);
    expect(g.adj[8], 0);
  });

  test('flood fill stops at numbers and skips flags', () {
    final g = MineGame(4, 4, 1, mines: layout(16, [0]));
    g.flagged[15] = true;
    final r = g.reveal(10);
    expect(g.revealed[15], isFalse);
    expect(g.revealed[1] && g.revealed[4] && g.revealed[5], isTrue);
    expect(g.revealed[0], isFalse);
    expect(r.length, 14);
  });

  test('win when all safe cells revealed', () {
    final g = MineGame(4, 1, 2, mines: layout(4, [0, 3]));
    g.reveal(1);
    expect(g.status, MineStatus.playing);
    g.reveal(2);
    expect(g.status, MineStatus.won);
    expect(g.flagged[0], isTrue);
  });

  test('lose reveals all mines and records the explosion', () {
    final g = MineGame(4, 1, 2, mines: layout(4, [0, 3]));
    g.toggleFlag(3);
    g.reveal(0);
    expect(g.status, MineStatus.lost);
    expect(g.explodedAt, 0);
    expect(g.revealed[0], isTrue);
    expect(g.reveal(1), isEmpty);
  });

  test('flags block reveal and update minesLeft', () {
    final g = MineGame(3, 3, 1, mines: layout(9, [0]));
    expect(g.toggleFlag(8), isTrue);
    expect(g.minesLeft, 0);
    expect(g.reveal(8), isEmpty);
    g.toggleFlag(8);
    expect(g.minesLeft, 1);
  });

  test('chord needs matching flags; wrong flag explodes', () {
    final g = MineGame(3, 3, 1, mines: layout(9, [0]));
    g.reveal(4);
    expect(g.chord(4), isEmpty);
    g.toggleFlag(0);
    final r = g.chord(4);
    expect(r, isNotEmpty);
    expect(g.status, MineStatus.won);

    final h = MineGame(3, 3, 1, mines: layout(9, [0]));
    h.reveal(4);
    h.toggleFlag(1);
    h.chord(4);
    expect(h.status, MineStatus.lost);
  });

  test('hint reveals a safe cell', () {
    for (var seed = 0; seed < 20; seed++) {
      final g = MineGame.forTier(MineTier.hard, random: Random(seed));
      g.reveal(0);
      final r = g.hint();
      expect(r, isNotEmpty);
      expect(g.status, isNot(MineStatus.lost));
    }
  });

  test('stars', () {
    expect(starsForTime(50, 60), 3);
    expect(starsForTime(100, 60), 2);
    expect(starsForTime(500, 60), 1);
    expect(starsForTime(50, 60, usedHint: true), 2);
  });
}
