import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/dominoes/logic/dominoes_logic.dart';

/// Plays a whole round with bots for every seat.
void _playRound(DominoGame g, int level) {
  var guard = 0;
  while (!g.roundOver) {
    final seat = g.turn;
    final a = g.botAction(level);
    switch (a.kind) {
      case 'play':
        expect(g.play(seat, a.move!.index, a.move!.end), isTrue);
      case 'draw':
        g.noteCannotFollow(seat);
        expect(g.draw(seat), isNotNull);
      default:
        g.noteCannotFollow(seat);
        expect(g.pass(seat), isTrue);
    }
    expect(++guard, lessThan(500));
  }
}

void main() {
  test('a double-six set has 28 different tiles', () {
    final s = Domino.fullSet();
    expect(s.length, 28);
    expect(s.toSet().length, 28);
    expect(s.fold<int>(0, (a, d) => a + d.pips), 168);
  });

  test('deal: 7 tiles for 2 players, 5 for 3-4; highest double opens', () {
    for (final n in [2, 3, 4]) {
      final g = DominoGame(players: n, random: math.Random(n));
      final inHands = g.hands.fold<int>(0, (a, h) => a + h.length);
      expect(inHands + g.boneyard.length + g.line.length, 28);
      expect(g.line.length, 1, reason: 'opening tile is played');
      expect(g.hands.where((h) => h.length == g.handSize - 1).length, 1);
    }
  });

  test('tiles join only on matching ends and stay oriented', () {
    final g = DominoGame(players: 2, random: math.Random(1));
    for (var i = 0; i < 300 && !g.roundOver; i++) {
      final seat = g.turn;
      final ms = g.moves(seat);
      if (ms.isEmpty) {
        g.draw(seat) ?? g.pass(seat);
        continue;
      }
      final m = ms.first;
      expect(g.play(seat, m.index, m.end), isTrue);
      for (var k = 0; k + 1 < g.line.length; k++) {
        expect(g.line[k].right, g.line[k + 1].left);
      }
    }
  });

  test('illegal moves are refused', () {
    final g = DominoGame(players: 2, random: math.Random(3));
    final other = (g.turn + 1) % 2;
    expect(g.play(other, 0, End.left), isFalse, reason: 'not your turn');
    final bad = g.hands[g.turn].indexWhere((d) => !d.has(g.leftEnd) && !d.has(g.rightEnd));
    if (bad >= 0) expect(g.play(g.turn, bad, End.right), isFalse);
  });

  test('bots finish rounds and matches; scores only go up', () {
    for (var seed = 0; seed < 20; seed++) {
      for (final n in [2, 3, 4]) {
        final g = DominoGame(players: n, target: 50, random: math.Random(seed));
        var rounds = 0;
        while (g.matchWinner == null && rounds < 30) {
          final before = [...g.scores];
          _playRound(g, seed % 3);
          for (var p = 0; p < n; p++) {
            expect(g.scores[p], greaterThanOrEqualTo(before[p]));
          }
          rounds++;
          if (g.matchWinner == null) g.newRound();
        }
        expect(g.matchWinner, isNotNull, reason: 'seed $seed, $n players');
      }
    }
  });
}
