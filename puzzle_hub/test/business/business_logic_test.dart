import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/business/logic/business_logic.dart';

BusinessGame _botGame(int players, int seed, {int maxRounds = 30, int level = 1, int cap = 4000}) {
  final g = BusinessGame(players: players, seed: seed, maxRounds: maxRounds);
  var n = 0;
  while (g.phase != Phase.over && n++ < cap) {
    expect(g.apply(g.botAction(level)), isTrue);
  }
  return g;
}

void main() {
  test('board: 36 squares, 4 corners, 19 cities in 8 groups', () {
    expect(Biz.board.length, 36);
    expect(Biz.board[0].kind, Sq.start);
    expect(Biz.board[Biz.jail].kind, Sq.jail);
    expect(Biz.board[18].kind, Sq.club);
    expect(Biz.board[27].kind, Sq.goJail);
    expect(Biz.board.where((s) => s.kind == Sq.city).length, 19);
    for (var g = 0; g < 8; g++) {
      expect(Biz.groupSquares(g).length, inInclusiveRange(2, 3), reason: 'group $g');
    }
    expect(Biz.board.where((s) => s.kind == Sq.transport).length, 4);
  });

  test('dice depend only on seed and roll number', () {
    final a = BusinessGame(players: 2, seed: 42), b = BusinessGame(players: 2, seed: 42);
    for (var i = 0; i < 50; i++) {
      expect(a.diceAt(i), b.diceAt(i));
      final (d1, d2) = a.diceAt(i);
      expect(d1, inInclusiveRange(1, 6));
      expect(d2, inInclusiveRange(1, 6));
    }
  });

  test('replaying the log gives the same game', () {
    for (final n in [2, 3, 4]) {
      final g = _botGame(n, 7 + n, maxRounds: 12);
      final r = BusinessGame.replay(players: n, seed: 7 + n, maxRounds: 12, actions: g.log);
      expect(r.money, g.money);
      expect(r.pos, g.pos);
      expect(r.owner, g.owner);
      expect(r.houses, g.houses);
      expect(r.phase, g.phase);
      final ints = [for (final a in g.log) a.toInt()];
      final r2 = BusinessGame.replay(players: n, seed: 7 + n, maxRounds: 12, actions: ints.map(BizAction.fromInt));
      expect(r2.money, g.money);
    }
  });

  test('only the player to move may act, and only legal moves', () {
    final g = BusinessGame(players: 3, seed: 5);
    expect(g.apply(const BizAction.roll(1)), isFalse);
    expect(g.apply(const BizAction.buy(0)), isFalse, reason: 'nothing to buy before rolling');
    expect(g.apply(BizAction.build(0, 1)), isFalse, reason: 'owns no group');
    expect(g.apply(const BizAction.roll(0)), isTrue);
  });

  test('rent grows with a full group, houses and hotels', () {
    final g = BusinessGame(players: 2, seed: 1);
    final grp = Biz.groupSquares(2);
    g.owner[grp.first] = 1;
    final base = g.rent(grp.first, 7);
    expect(base, Biz.board[grp.first].price ~/ 10);
    for (final s in grp) {
      g.owner[s] = 1;
    }
    expect(g.rent(grp.first, 7), base * 2);
    g.houses[grp.first] = 1;
    final one = g.rent(grp.first, 7);
    g.houses[grp.first] = 4;
    expect(g.rent(grp.first, 7), greaterThan(one));
  });

  test('bot games end; money never negative; nobody owns a square twice', () {
    for (var seed = 0; seed < 12; seed++) {
      for (final n in [2, 3, 4]) {
        final g = _botGame(n, seed, level: seed % 3);
        expect(g.phase, Phase.over, reason: 'seed $seed $n players');
        expect(g.winner, isNotNull);
        for (var p = 0; p < n; p++) {
          expect(g.money[p], greaterThanOrEqualTo(0));
        }
        for (var s = 0; s < Biz.size; s++) {
          if (g.owner[s] >= 0) expect(g.out[g.owner[s]], isFalse);
        }
      }
    }
  });

  test('unlimited games finish by bankruptcy', () {
    final g = _botGame(2, 3, maxRounds: 0, level: 2, cap: 20000);
    expect(g.phase, Phase.over);
    expect(g.out.where((o) => o).length, 1);
  });
}
