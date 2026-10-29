import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/ludo.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/ludo/logic/ludo_logic.dart';
import 'package:puzzle_hub/games/ludo/ludo_screen.dart';
import 'package:puzzle_hub/games/ludo/online/ludo_online_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<LudoSeat> _bots(int n) => [for (final c in ludoColours(n)) LudoSeat(c, SeatKind.bot)];

/// Plays a whole game with bots; returns it.
LudoGame _playOut(int players, int seed, {bool quick = false}) {
  final g = LudoGame(seats: _bots(players), seed: seed, quick: quick);
  final r = math.Random(seed);
  var guard = 0;
  while (!g.over && guard++ < 20000) {
    if (g.pending == null) {
      expect(g.apply(LudoAction.roll(g.turn)), isTrue);
    } else {
      expect(g.apply(LudoAction.move(g.turn, g.botChoice(1, r))), isTrue);
    }
  }
  return g;
}

void main() {
  test('track: 52 distinct cells on the cross, coloured starts in place', () {
    expect(Ludo.track.length, 52);
    expect(Ludo.track.toSet().length, 52);
    for (final (r, c) in Ludo.track) {
      expect((r >= 6 && r <= 8) || (c >= 6 && c <= 8), isTrue);
    }
    expect(Ludo.track[Ludo.startOf(0)], (6, 1));
    expect(Ludo.track[Ludo.startOf(1)], (1, 8));
    expect(Ludo.track[Ludo.startOf(2)], (8, 13));
    expect(Ludo.track[Ludo.startOf(3)], (13, 6));
    // Each colour's last track square is next to its home column.
    for (var c = 0; c < 4; c++) {
      final (r1, c1) = Ludo.cellOf(c, Ludo.lastTrack)!;
      final (r2, c2) = Ludo.homeCell(c, 51);
      expect((r1 - r2).abs() + (c1 - c2).abs(), 1, reason: 'colour $c');
    }
  });

  test('dice: deterministic, 1..6, roughly fair', () {
    final counts = List.filled(7, 0);
    for (var n = 0; n < 6000; n++) {
      final d = LudoGame.diceAt(12345, n);
      expect(d, inInclusiveRange(1, 6));
      expect(LudoGame.diceAt(12345, n), d);
      counts[d]++;
    }
    for (var v = 1; v <= 6; v++) {
      expect(counts[v], inInclusiveRange(800, 1200), reason: 'value $v');
    }
  });

  test('a token needs a 6 to leave the yard and cannot overshoot home', () {
    final g = LudoGame(seats: _bots(2), seed: 1);
    expect(g.movable(0, 5), isEmpty);
    expect(g.movable(0, 6), [0, 1, 2, 3]);
    g.tokens[0][0] = 54;
    expect(g.movable(0, 2), [0]);
    expect(g.movable(0, 3), isEmpty);
  });

  test('capture sends the opponent home and gives another turn; stars are safe', () {
    // Find a seed whose first roll is 3.
    final seed = List.generate(500, (i) => i + 1).firstWhere((s) => LudoGame.diceAt(s, 0) == 3);
    final g = LudoGame(seats: _bots(2), seed: seed);
    g.tokens[0][0] = 10; // red at global 10
    g.tokens[1][0] = 13 + 39; // yellow progress 13+39 -> global (26+52-? )
    // Put yellow exactly 3 squares ahead of red (global 13): yellow start is 26, so progress 39.
    g.tokens[1][0] = 39;
    expect(Ludo.squareOf(2, 39), 13);
    // 13 is a start square (safe): no capture there.
    expect(g.apply(const LudoAction.roll(0)), isTrue);
    expect(g.apply(const LudoAction.move(0, 0)), isTrue);
    expect(g.tokens[1][0], 39);
    expect(g.last.captured, isEmpty);

    final seed2 = List.generate(500, (i) => i + 1).firstWhere((s) => LudoGame.diceAt(s, 0) == 2);
    final h = LudoGame(seats: _bots(2), seed: seed2);
    h.tokens[0][0] = 10;
    h.tokens[1][0] = 38; // global 12 – not safe
    expect(h.apply(const LudoAction.roll(0)), isTrue);
    expect(h.apply(const LudoAction.move(0, 0)), isTrue);
    expect(h.tokens[1][0], -1);
    expect(h.last.captured, [(1, 0)]);
    expect(h.turn, 0, reason: 'a capture gives another turn');
  });

  test('three sixes in a row lose the turn', () {
    final seed = List.generate(200000, (i) => i + 1).firstWhere((s) => List.generate(3, (n) => LudoGame.diceAt(s, n)).every((d) => d == 6));
    final g = LudoGame(seats: _bots(2), seed: seed);
    g.apply(const LudoAction.roll(0));
    g.apply(const LudoAction.move(0, 0));
    g.apply(const LudoAction.roll(0));
    g.apply(const LudoAction.move(0, 0));
    g.apply(const LudoAction.roll(0));
    expect(g.last.lostTurn, isTrue);
    expect(g.turn, 1);
  });

  test('bots finish whole games (2, 3, 4 players, classic and quick); replay matches', () {
    for (final n in [2, 3, 4]) {
      for (final quick in [false, true]) {
        final g = _playOut(n, 7 + n, quick: quick);
        expect(g.over, isTrue, reason: '$n players quick=$quick');
        expect(g.winner, isNotNull);
        final w = g.winner!;
        expect(quick ? g.tokens[w].contains(Ludo.home) : g.tokens[w].every((p) => p == Ludo.home), isTrue);
        final r = LudoGame.replay(seats: _bots(n), seed: 7 + n, quick: quick, actions: g.log);
        expect(r.tokens, g.tokens);
        expect(r.finished, g.finished);
        // Online encoding round-trips.
        expect([for (final a in g.log) encodeLudo(decodeLudo(encodeLudo(a)))], [for (final a in g.log) encodeLudo(a)]);
      }
    }
  });

  test('actions out of turn are ignored', () {
    final g = LudoGame(seats: _bots(4), seed: 3);
    expect(g.apply(const LudoAction.roll(2)), isFalse);
    expect(g.apply(const LudoAction.move(0, 0)), isFalse);
    expect(g.log, isEmpty);
  });

  test('ludo strings: all 9 languages, identical placeholders', () {
    final ph = RegExp(r'\{(\w+)\}');
    for (final e in ludoStrings.entries) {
      final want = ph.allMatches(e.value['en']!).map((m) => m[1]).toSet();
      for (final l in AppLang.tableLangs) {
        final s = e.value[l.code];
        expect(s, isNotNull, reason: '${e.key} ${l.code}');
        expect(ph.allMatches(s!).map((m) => m[1]).toSet(), want, reason: '${e.key} ${l.code}');
      }
    }
  });

  testWidgets('menu -> game vs computer: roll, bots play, saved to continue', (t) async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(const MaterialApp(home: LudoScreen()));
    await t.pump(const Duration(milliseconds: 300));
    final start = find.byKey(const ValueKey('ludo_start'));
    await t.scrollUntilVisible(start, 200, scrollable: find.byType(Scrollable).first);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(start);
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(LudoPlayScreen), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ludo_dice')));
    // Let bots and auto-moves run for a while.
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 400));
    }
    expect(t.takeException(), isNull);
    // Leaving saves the game.
    t.state<NavigatorState>(find.byType(Navigator).first).pop();
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(LudoSave.load(), isNotNull);
    // The menu is still scrolled down to the Start button: scroll back up.
    await t.scrollUntilVisible(find.byKey(const ValueKey('ludo_continue')), -200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('ludo_continue')), findsOneWidget);
  });

  test('home dice / riddle: given values are used, 0 skips the turn, save round-trips', () {
    final g = LudoGame(seats: _bots(2), seed: 5);
    expect(g.apply(const LudoAction.roll(0, dice: 6)), isTrue);
    expect(g.pending, 6);
    expect(g.apply(const LudoAction.move(0, 0)), isTrue);
    expect(g.tokens[0][0], 0);
    expect(g.apply(const LudoAction.roll(0, dice: 0)), isTrue, reason: 'wrong riddle answer');
    expect(g.turn, 1);
    expect(g.apply(const LudoAction.roll(1, dice: 9)), isFalse);
    final json = [for (final a in g.log) a.toJson()];
    final back = LudoGame.replay(seats: _bots(2), seed: 5, quick: false, actions: [for (final j in json) LudoAction.fromJson(j)!]);
    expect(back.tokens, g.tokens);
    expect(back.turn, g.turn);
  });
}
