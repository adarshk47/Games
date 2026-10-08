import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/hexa_sort/logic/hexa_sort_logic.dart';

/// One-row board of [n] cells (no holes): cell i touches i-1 and i+1.
HsBoard _row(int n, {Set<int> blocked = const {}}) => HsBoard(rows: 1, cols: n, blocked: blocked);

HsLevel _lv(HsBoard b, {Map<int, List<int>> initial = const {}, List<List<int>> script = const [], int goal = 10}) =>
    HsLevel(
      tier: HsTier.easy,
      number: 1,
      board: b,
      colors: 3,
      goal: goal,
      seed: 7,
      initial: initial,
      script: script,
    );

void main() {
  group('board geometry', () {
    test('odd-r neighbours and holes', () {
      final b = HsBoard(rows: 3, cols: 3);
      // Odd row 1 loses its last cell (index 5).
      expect(b.holes, {5});
      expect(b.isCell(5), isFalse);
      // Cell 4 (row 1, col 1, shifted right) touches 1,2 above and 7,8 below.
      expect(b.neighbors[4].toSet(), {3, 1, 2, 7, 8});
      // Cell 0 (row 0) touches 1 and 3 only.
      expect(b.neighbors[0].toSet(), {1, 3});
      expect(b.openCells.length, 8);
    });

    test('blocked cells are not neighbours', () {
      final b = _row(3, blocked: {1});
      expect(b.neighbors[0], isEmpty);
      expect(b.isOpen(1), isFalse);
    });
  });

  group('placement', () {
    test('only on empty open cells, offers consumed and re-dealt', () {
      final b = _row(5, blocked: {4});
      final g = HsGame(_lv(b, initial: {
        0: [1, 1]
      }, script: [
        [0, 2],
        [1, 2],
        [2, 0],
      ], goal: 100));
      expect(g.canPlace(0, 0), isFalse, reason: 'occupied');
      expect(g.canPlace(0, 4), isFalse, reason: 'blocked');
      expect(g.place(0, 4), isNull);
      final m = g.place(0, 2)!;
      expect(m.steps, isEmpty);
      expect(g.stacks[2], [0, 2]);
      expect(g.offers[0], isNull);
      expect(g.canPlace(0, 3), isFalse, reason: 'offer used');
      expect(g.moves, 1);
      g.place(1, 3); // tops 2 and 2 -> transfer
      expect(g.place(2, 1)!.dealt, isTrue);
      expect(g.offers.every((o) => o != null), isTrue);
    });
  });

  group('transfer and merge', () {
    test('matching neighbour pours its top run into the placed stack', () {
      final g = HsGame(_lv(_row(3), initial: {
        0: [2, 1]
      }, script: [
        [0, 1, 1],
      ], goal: 100));
      final m = g.place(0, 1)!;
      expect(m.steps.single.toString(), 'T(0->1 c1 x1)');
      expect(g.stacks[0], [2]);
      expect(g.stacks[1], [0, 1, 1, 1]);
    });

    test('the longer top run collects when both sides are equal', () {
      final g = HsGame(_lv(_row(3), initial: {
        0: [2, 1, 1]
      }, script: [
        [0, 1],
      ], goal: 100));
      final m = g.place(0, 1)!;
      expect(m.steps.single.toString(), 'T(1->0 c1 x1)');
      expect(g.stacks[0], [2, 1, 1, 1]);
      expect(g.stacks[1], [0]);
    });

    test('different tops do not interact', () {
      final g = HsGame(_lv(_row(3), initial: {
        0: [1, 2]
      }, script: [
        [1],
      ], goal: 100));
      expect(g.place(0, 1)!.steps, isEmpty);
      expect(g.stacks[0], [1, 2]);
    });

    test('hub stack gathers from both sides', () {
      final g = HsGame(_lv(_row(3), initial: {
        0: [1, 1],
        2: [0, 1],
      }, script: [
        [2, 1],
      ], goal: 100));
      final m = g.place(0, 1)!;
      expect(m.steps.map((s) => s.toString()), ['T(0->1 c1 x2)', 'T(2->1 c1 x1)']);
      expect(g.stacks[1], [2, 1, 1, 1, 1]);
      expect(g.stacks[0], isEmpty);
      expect(g.stacks[2], [0]);
    });

    test('a neighbour with more matches becomes the target', () {
      // 0:[c1]  1:[c1]  2:[placed c1]  -> cell 1 has two matches.
      final g = HsGame(_lv(_row(3), initial: {
        0: [0, 1],
        1: [1],
      }, script: [
        [1],
      ], goal: 100));
      final m = g.place(0, 2)!;
      expect(m.steps.every((s) => s.to == 1), isTrue);
      expect(g.stacks[1], [1, 1, 1]);
      expect(g.stacks[0], [0]);
      expect(g.stacks[2], isEmpty);
    });

    test('revealed colours chain into further transfers', () {
      // Placing [2,0] next to cell 1 ([1,0]) pulls the 0 away from cell 1,
      // revealing 1 which then matches cell 0.
      final g = HsGame(_lv(_row(4), initial: {
        0: [1, 1],
        1: [1, 0],
      }, script: [
        [2, 0],
      ], goal: 100));
      final m = g.place(0, 2)!;
      expect(m.steps.length, 2);
      expect(m.steps[0].kind, HsStepKind.transfer);
      expect(m.steps[0].color, 0);
      expect(m.steps[1].color, 1);
      final ones = g.stacks.where((s) => s.isNotEmpty && s.last == 1).toList();
      expect(ones.single, [1, 1, 1]);
    });
  });

  group('clearing', () {
    test('top run of 10 clears and counts toward the goal', () {
      final g = HsGame(_lv(_row(3), initial: {
        0: [2, 0, 0, 0, 0, 0],
        2: [0, 0, 0, 0],
      }, script: [
        [1, 0],
      ], goal: 10));
      final m = g.place(0, 1)!;
      expect(m.cleared, 10);
      expect(m.clears, 1);
      expect(m.steps.last.kind, HsStepKind.clear);
      expect(g.cleared, 10);
      expect(g.won, isTrue);
      expect(g.stacks[1], [1]);
      expect(g.stacks[0], [2]);
    });

    test('nine is not enough; more than ten clears the whole run', () {
      final g = HsGame(_lv(_row(3), initial: {
        0: [0, 0, 0, 0, 0],
      }, script: [
        [0, 0, 0, 0],
        [1, 0, 0],
      ], goal: 100));
      expect(g.place(0, 1)!.cleared, 0);
      expect(hsTopRun(g.stacks[0]), 9);
      expect(g.stacks[1], isEmpty);
      final m = g.place(1, 1)!; // 9 + 2 = 11
      expect(m.cleared, 11);
      expect(g.stacks[0], isEmpty);
      expect(g.stacks[1], [1]);
    });

    test('a clear reveals a colour that chains again (combo)', () {
      final g = HsGame(_lv(_row(3), initial: {
        1: [1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        2: [1, 1],
      }, script: [
        [0],
      ], goal: 100));
      // 9 zeros pour onto the placed 0 and clear; cell 1 then shows eight 1s
      // which collect cell 2's pair and clear again.
      final m = g.place(0, 0)!;
      expect(m.clears, 2);
      expect(g.cleared, 20);
      expect(g.stacks.every((s) => s.isEmpty), isTrue);
    });
  });

  group('game over', () {
    test('board full without reaching the goal loses', () {
      final g = HsGame(_lv(_row(3), script: [
        [0],
        [1],
        [2],
      ], goal: 10));
      g.place(0, 0);
      g.place(1, 1);
      expect(g.lost, isFalse);
      g.place(2, 2);
      expect(g.lost, isTrue);
      expect(g.over, isTrue);
      expect(g.canPlace(0, 0), isFalse);
      final freed = g.revive(2);
      expect(freed.length, 2);
      expect(g.lost, isFalse);
      expect(g.continues, 1);
    });

    test('refresh replaces all offers deterministically', () {
      final a = HsGame(hsGenerate(HsTier.medium, 4));
      final b = HsGame(hsGenerate(HsTier.medium, 4));
      a.refreshOffers();
      b.refreshOffers();
      expect(a.offers, b.offers);
      expect(a.refreshes, 1);
    });

    test('stars', () {
      expect(hsStars(fill: 0.3, continues: 0), 3);
      expect(hsStars(fill: 0.7, continues: 0), 2);
      expect(hsStars(fill: 0.9, continues: 0), 1);
      expect(hsStars(fill: 0.3, continues: 1), 2);
      expect(hsStars(fill: 0.3, continues: 5), 1);
    });
  });

  group('generation', () {
    test('deterministic and shaped per tier', () {
      for (final t in HsTier.values) {
        for (final n in [1, 37, 100]) {
          final a = hsGenerate(t, n);
          final b = HsGame(a);
          final c = HsGame(a);
          expect(b.offers, c.offers);
          expect(b.stacks, c.stacks);
          final spec = hsSpec(t);
          expect(a.board.rows, spec.rows);
          expect(a.board.cols, spec.cols);
          expect(a.goal % 10, 0);
          expect(a.goal, greaterThanOrEqualTo(10));
          expect(a.colors, inInclusiveRange(spec.minColors, spec.maxColors));
          for (final o in b.offers) {
            expect(o!.length, inInclusiveRange(2, spec.maxHeight));
            expect(o.every((x) => x >= 0 && x < a.colors), isTrue);
          }
          for (final MapEntry(:key, :value) in a.initial.entries) {
            expect(a.board.isOpen(key), isTrue);
            expect(a.board.neighbors[key].any((x) => a.initial[x]?.last == value.last), isFalse);
          }
        }
      }
      expect(hsGenerate(HsTier.easy, 1).board.blocked, isEmpty);
      expect(hsGenerate(HsTier.hard, 50).board.blocked, isNotEmpty);
      expect(hsGenerate(HsTier.extreme, 100).board.blocked.length, greaterThanOrEqualTo(3));
      expect(hsGenerate(HsTier.extreme, 100).colors, 8);
      expect(hsGenerate(HsTier.easy, 2).seed, isNot(hsGenerate(HsTier.easy, 3).seed));
    });

    test('goals grow with the level and tier', () {
      expect(hsGenerate(HsTier.easy, 100).goal, greaterThan(hsGenerate(HsTier.easy, 1).goal));
      expect(hsGenerate(HsTier.extreme, 50).goal, greaterThan(hsGenerate(HsTier.easy, 50).goal));
    });

    test('resolution always terminates on random boards', () {
      final r = HsRng(99);
      for (var k = 0; k < 300; k++) {
        final b = HsBoard(rows: 5, cols: 5);
        final stacks = [
          for (var i = 0; i < b.size; i++)
            b.isOpen(i) && r.nextInt(4) > 0 ? [for (var j = 0; j < 1 + r.nextInt(8); j++) r.nextInt(3)] : <int>[],
        ];
        final total = stacks.fold(0, (a, s) => a + s.length);
        final start = b.openCells.elementAt(r.nextInt(b.openCells.length));
        final steps = hsResolve(b, stacks, start);
        final cleared = steps.where((s) => s.kind == HsStepKind.clear).fold(0, (a, s) => a + s.count);
        expect(stacks.fold(0, (a, s) => a + s.length) + cleared, total);
        for (final s in stacks) {
          expect(hsTopRun(s) < kHsClearAt, isTrue);
        }
      }
    });
  });

  test('greedy bot wins every Easy and Medium level within budget', () {
    for (final t in [HsTier.easy, HsTier.medium]) {
      for (var n = 1; n <= kHsLevels; n++) {
        final lv = hsGenerate(t, n);
        final r = hsGreedyPlay(lv, maxMoves: hsBotBudget(lv.goal));
        expect(r.won, isTrue, reason: '${t.id} level $n (goal ${lv.goal})');
        expect(r.moves, lessThanOrEqualTo(hsBotBudget(lv.goal)));
      }
    }
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('hard and extreme sample levels are beatable by the bot', () {
    for (final t in [HsTier.hard, HsTier.extreme]) {
      for (final n in [1, 50, 100]) {
        final lv = hsGenerate(t, n);
        expect(hsGreedyPlay(lv, maxMoves: 600).won, isTrue, reason: '${t.id} $n');
      }
    }
  });
}
