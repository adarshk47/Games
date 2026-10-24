import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/ludo/logic/ludo_logic.dart';
import 'package:puzzle_hub/games/snakes/logic/snakes_logic.dart';
import 'package:puzzle_hub/games/snakes/snakes_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<LudoSeat> _bots(int n) => [for (final c in ludoColours(n)) LudoSeat(c, SeatKind.bot, name: 'B$c')];

void main() {
  test('board numbering zig-zags from the bottom-left', () {
    expect(Snakes.cellOf(1), (9, 0));
    expect(Snakes.cellOf(10), (9, 9));
    expect(Snakes.cellOf(11), (8, 9));
    expect(Snakes.cellOf(20), (8, 0));
    expect(Snakes.cellOf(100), (0, 0));
    final all = {for (var n = 1; n <= 100; n++) Snakes.cellOf(n)};
    expect(all.length, 100);
    for (final e in Snakes.ladders.entries) {
      expect(e.value, greaterThan(e.key));
    }
    for (final e in Snakes.snakes.entries) {
      expect(e.value, lessThan(e.key));
      expect(Snakes.ladders.containsKey(e.key), isFalse);
    }
  });

  test('whole games finish with exactly 100; replay matches; out-of-turn ignored', () {
    for (final n in [2, 3, 4]) {
      for (var seed = 1; seed <= 20; seed++) {
        final g = SnakesGame(seats: _bots(n), seed: seed);
        expect(g.roll((g.turn + 1) % n), isFalse);
        var guard = 0;
        while (!g.over && guard++ < 5000) {
          expect(g.roll(g.turn), isTrue);
          for (final p in g.pos) {
            expect(p, inInclusiveRange(0, 100));
            expect(Snakes.snakes.containsKey(p) || Snakes.ladders.containsKey(p), isFalse);
          }
        }
        expect(g.over, isTrue);
        expect(g.pos[g.winner!], 100);
        final r = SnakesGame.replay(seats: _bots(n), seed: seed, rolls: g.log);
        expect(r.pos, g.pos);
        expect(r.winner, g.winner);
      }
    }
  });

  test('a ladder and a snake move the token', () {
    // Find seeds whose first roll lands on a ladder (4 -> 14) or snake-free square.
    final seed = List.generate(2000, (i) => i + 1).firstWhere((s) {
      final g = SnakesGame(seats: _bots(2), seed: s);
      g.roll(0);
      return g.last.rolled == 4;
    });
    final g = SnakesGame(seats: _bots(2), seed: seed);
    g.roll(0);
    expect(g.pos[0], 14);
    expect(g.last.ladder, isTrue);
    expect(g.last.via, 4);
    final h = SnakesGame(seats: _bots(2), seed: seed);
    h.pos[0] = 12; // 12 + 4 = 16 = snake head
    h.roll(0);
    expect(h.pos[0], 6);
    expect(h.last.snake, isTrue);
  });

  testWidgets('play vs computer: roll, bots play, saved to continue', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: SnakesPlayScreen(players: 3, cpu: true, seed: math.Random(1).nextInt(1000))));
    await t.pump(const Duration(milliseconds: 300));
    await t.tap(find.byKey(const ValueKey('snakes_dice')));
    for (var i = 0; i < 20; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await t.pump(const Duration(seconds: 1));
    expect(SnakesSave.load(), isNotNull);
  });

  test('home dice / riddle values and replay', () {
    final g = SnakesGame(seats: _bots(2), seed: 9);
    expect(g.roll(0, dice: 4), isTrue);
    expect(g.pos[0], 14, reason: 'ladder 4 -> 14');
    expect(g.roll(1, dice: 0), isTrue, reason: 'wrong riddle: no move');
    expect(g.pos[1], 0);
    expect(g.turn, 0);
    final r = SnakesGame.replay(seats: _bots(2), seed: 9, rolls: g.log);
    expect(r.pos, g.pos);
    expect(r.turn, g.turn);
  });
}
