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
    final g = Game2048(5, rng: Random(9))..reset();
    g.move(Dir.left);
    final g2 = Game2048.fromJsonString(g.toJsonString())!;
    expect(g2.size, 5);
    expect(g2.score, g.score);
    expect(grid(g2), grid(g));
    expect(Game2048.fromJsonString('garbage'), isNull);
  });

  test('target per size', () {
    expect(Game2048(4).target, 2048);
    expect(Game2048(3).target, 256);
  });
}
