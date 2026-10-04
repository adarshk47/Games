import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/game_2048/logic/game_2048_logic.dart';

Game2048 make(int size, List<List<int>> rows) {
  final g = Game2048(size, rng: Random(1));
  var id = 1;
  for (var r = 0; r < size; r++) {
    for (var c = 0; c < size; c++) {
      if (rows[r][c] != 0) g.tiles.add(Tile(id++, rows[r][c], r, c));
    }
  }
  g.nextId = id;
  return g;
}

List<List<int>> grid(Game2048 g) {
  final o = List.generate(g.size, (_) => List.filled(g.size, 0));
  for (final t in g.tiles) {
    o[t.r][t.c] = t.value;
  }
  return o;
}

void main() {
  test('slide left merges once per pair', () {
    final g = make(4, [
      [2, 2, 2, 2],
      [4, 0, 4, 8],
      [2, 2, 4, 0],
      [0, 0, 0, 2],
    ]);
    final res = g.move(Dir.left)!;
    final gr = grid(g);
    expect(gr[0].sublist(0, 2), [4, 4]);
    expect(gr[1].sublist(0, 2), [8, 8]);
    expect(gr[2].sublist(0, 2), [4, 4]);
    expect(gr[3][0], 2);
    expect(res.gained, 4 + 4 + 8 + 4);
    expect(g.score, 20);
  });

  test('right, up, down directions', () {
    var g = make(3, [
      [2, 0, 2],
      [0, 0, 0],
      [0, 0, 0],
    ]);
    g.move(Dir.right);
    expect(g.tiles.any((t) => t.r == 0 && t.c == 2 && t.value == 4), true);
    g = make(3, [
      [2, 0, 0],
      [0, 0, 0],
      [2, 0, 0],
    ]);
    g.move(Dir.up);
    expect(g.tiles.any((t) => t.r == 0 && t.c == 0 && t.value == 4), true);
    g = make(3, [
      [2, 0, 0],
      [2, 0, 0],
      [4, 0, 0],
    ]);
    g.move(Dir.down);
    expect(g.tiles.any((t) => t.r == 2 && t.c == 0 && t.value == 4), true);
    expect(g.tiles.any((t) => t.r == 1 && t.c == 0 && t.value == 4), true);
  });

  test('no-op move returns null and does not spawn', () {
    final g = make(4, [
      [2, 4, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ]);
    expect(g.move(Dir.left), isNull);
    expect(g.tiles.length, 2);
  });

  test('game over detection', () {
    final g = make(3, [
      [2, 4, 2],
      [4, 2, 4],
      [2, 4, 2],
    ]);
    expect(g.hasMoves, false);
    final h = make(3, [
      [2, 4, 2],
      [4, 2, 4],
      [2, 4, 4],
    ]);
    expect(h.hasMoves, true);
  });

  test('spawn distribution ~90/10 and only 2/4', () {
    final g = Game2048(4, rng: Random(42));
    var twos = 0;
    for (var i = 0; i < 2000; i++) {
      final v = g.nextSpawnValue();
      expect([2, 4], contains(v));
      if (v == 2) twos++;
    }
    expect(twos / 2000, closeTo(0.9, 0.03));
  });

  test('undo is limited to 3', () {
    final g = Game2048(4, rng: Random(3))..reset();
    var moves = 0;
    for (final d in [Dir.left, Dir.up, Dir.right, Dir.down, Dir.left, Dir.up]) {
      if (g.move(d) != null) moves++;
    }
    expect(moves, greaterThan(3));
    var undone = 0;
    while (g.undo()) {
      undone++;
    }
    expect(undone, 3);
    expect(g.undosLeft, 0);
  });

  test('undo single move gives exact previous board', () {
    final g = make(4, [
      [2, 2, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
      [0, 0, 0, 4],
    ]);
    final before = grid(g);
    g.move(Dir.left);
    expect(g.undo(), true);
    expect(grid(g), before);
    expect(g.score, 0);
  });

  test('save / load roundtrip', () {
    final g = Game2048.forTier(Tier2048.easy, rng: Random(9))..reset();
    g.move(Dir.left);
    final g2 = Game2048.fromJsonString(g.toJsonString())!;
    expect(g2.size, 5);
    expect(g2.score, g.score);
    expect(grid(g2), grid(g));
    expect(Game2048.fromJsonString('garbage'), isNull);
  });

  test('tier configs', () {
    expect(Game2048.forTier(Tier2048.easy).size, 5);
    expect(Game2048.forTier(Tier2048.easy).maxUndos, 5);
    expect(Game2048.forTier(Tier2048.medium).maxUndos, 3);
    expect(Game2048.forTier(Tier2048.hard).stoneCount, 2);
    expect(Game2048.forTier(Tier2048.extreme).maxUndos, 0);
    expect(Game2048(4).target, 2048);
  });

  test('stones are placed, never spawned on, and block movement', () {
    for (var seed = 0; seed < 20; seed++) {
      final g = Game2048.forTier(Tier2048.extreme, rng: Random(seed))..reset();
      expect(g.stones.length, 3);
      for (var i = 0; i < 100; i++) {
        g.move(Dir.values[i % 4]);
        for (final t in g.tiles) {
          expect(g.isStone(t.r, t.c), false);
        }
      }
    }
  });

  test('stone splits a line: no merge or slide across it', () {
    final g = Game2048(4, rng: Random(1), stoneCount: 1)..stones = {1};
    g.tiles.addAll([Tile(1, 2, 0, 0), Tile(2, 2, 0, 2), Tile(3, 4, 0, 3)]);
    g.nextId = 4;
    g.move(Dir.left);
    // tile 1 stays, tiles 2 and 3 pack against the stone: 2,4 at cols 2,3 (no merge)
    expect(g.tileAt(0, 0)!.value, 2);
    expect(g.tileAt(0, 2)!.value, 2);
    expect(g.tileAt(0, 3)!.value, 4);
    final h = Game2048(4, rng: Random(1), stoneCount: 1)..stones = {1};
    h.tiles.addAll([Tile(1, 2, 0, 2), Tile(2, 2, 0, 3)]);
    h.nextId = 3;
    h.move(Dir.left);
    expect(h.tileAt(0, 2)!.value, 4);
  });

  test('game over with stones', () {
    final g = Game2048(3, rng: Random(1), stoneCount: 1)..stones = {4};
    g.tiles.addAll([
      Tile(1, 2, 0, 0), Tile(2, 4, 0, 1), Tile(3, 2, 0, 2),
      Tile(4, 4, 1, 0), /* stone */ Tile(5, 4, 1, 2),
      Tile(6, 2, 2, 0), Tile(7, 4, 2, 1), Tile(8, 2, 2, 2),
    ]);
    expect(g.hasMoves, false);
    // 4 at (1,0) and 4 at (1,2) are separated by the stone; (1,2)-(0,2) differ
    g.tiles.firstWhere((t) => t.id == 5).value = 2; // now equals (0,2)=2 vertically
    expect(g.hasMoves, true);
  });

  test('save / load keeps tier and stones', () {
    final g = Game2048.forTier(Tier2048.hard, rng: Random(5))..reset();
    final g2 = Game2048.fromJsonString(g.toJsonString())!;
    expect(g2.tier, Tier2048.hard);
    expect(g2.stones, g.stones);
    expect(g2.target, Tier2048.hard.target);
    expect(g2.maxUndos, 1);
  });

  test('hard and extreme targets are reachable (Monte-Carlo bot)', () {
    Game2048 clone(Game2048 g, Random r) {
      final c = Game2048.forTier(g.tier, rng: r);
      c.stones = g.stones;
      c.tiles = [for (final t in g.tiles) t.copy()];
      c.score = g.score;
      c.nextId = g.nextId;
      return c;
    }

    Dir? pick(Game2048 g, Random r) {
      Dir? best;
      var bestV = -1e18;
      for (final d in Dir.values) {
        final probe = clone(g, r);
        if (probe.move(d) == null) continue;
        var tot = 0.0;
        for (var k = 0; k < 80; k++) {
          final c = clone(g, r)..move(d);
          var i = 0;
          for (; i < 120 && c.hasMoves; i++) {
            if (c.move(Dir.values[r.nextInt(4)]) == null) {
              c.move(Dir.values[r.nextInt(4)]);
            }
          }
          tot += c.score + (c.hasMoves ? c.maxTile * 2 : 0) + (c.hasMoves ? 0 : -500);
        }
        if (tot > bestV) {
          bestV = tot;
          best = d;
        }
      }
      return best;
    }

    for (final t in [Tier2048.hard, Tier2048.extreme]) {
      var reached = false;
      for (var seed = 0; seed < 4 && !reached; seed++) {
        final g = Game2048.forTier(t, rng: Random(seed))..reset();
        final r = Random(seed + 77);
        while (g.hasMoves && !g.reachedTarget) {
          final d = pick(g, r);
          if (d == null) break;
          g.move(d);
        }
        reached = g.reachedTarget;
      }
      expect(reached, true, reason: '${t.label} target ${t.target}');
    }
  }, timeout: const Timeout(Duration(minutes: 9)));

  group('Classic tier', () {
    test('config matches original rules', () {
      final g = Game2048.forTier(Tier2048.classic, rng: Random(1))..reset();
      expect(g.size, 4);
      expect(g.stoneCount, 0);
      expect(g.stones, isEmpty);
      expect(g.fourChance, 0.1);
      expect(g.target, 2048);
      expect(g.maxUndos, 3);
      expect(g.tiles.length, 2);
    });

    test('save/load round trip keeps tier', () {
      final g = Game2048.forTier(Tier2048.classic, rng: Random(4))..reset();
      for (var i = 0; i < 6; i++) {
        g.move(Dir.values[i % 4]);
      }
      final g2 = Game2048.fromJsonString(g.toJsonString())!;
      expect(g2.tier, Tier2048.classic);
      expect(g2.size, 4);
      expect(g2.score, g.score);
      expect(g2.target, 2048);
      expect(g2.tiles.length, g.tiles.length);
    });
  });

  group('coin economy helpers', () {
    test('paid undo works without free undos (extreme) and keeps undosLeft', () {
      final g = Game2048.forTier(Tier2048.extreme, rng: Random(4))..reset();
      final before = g.tiles.map((t) => [t.value, t.r, t.c]).toList();
      Dir? used;
      for (final d in Dir.values) {
        if (g.move(d) != null) {
          used = d;
          break;
        }
      }
      expect(used, isNotNull);
      expect(g.canUndo, isFalse);
      expect(g.hasHistory, isTrue);
      expect(g.paidUndo(), isTrue);
      expect(g.undosLeft, 0);
      expect(g.tiles.map((t) => [t.value, t.r, t.c]).toList(), before);
      expect(g.paidUndo(), isFalse);
    });

    test('removeSmallest frees the two smallest tiles and marks continued', () {
      final g = make(4, [
        [2, 4, 2, 4],
        [4, 2, 4, 2],
        [2, 4, 2, 4],
        [4, 2, 4, 8],
      ]);
      expect(g.hasMoves, isFalse);
      expect(g.removeSmallest(2), isTrue);
      expect(g.tiles.length, 14);
      expect(g.tiles.where((t) => t.value == 2).length, 5);
      expect(g.hasMoves, isTrue);
      expect(g.continued, isTrue);
      final g2 = Game2048.fromJsonString(g.toJsonString())!;
      expect(g2.continued, isTrue);
      g.reset();
      expect(g.continued, isFalse);
    });

    test('old saves without the continued flag still load', () {
      final g = Game2048.forTier(Tier2048.classic, rng: Random(2))..reset();
      final m = g.toJsonString().replaceAll(',"cont":false', '');
      expect(m.contains('cont'), isFalse);
      expect(Game2048.fromJsonString(m)!.continued, isFalse);
    });
  });
}
