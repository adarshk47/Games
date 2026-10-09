import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/bus_jam/logic/bus_jam_logic.dart';

/// 3x3 hand-made level:
///   row0: A(0) B(1) C(2)
///   row1: D(3) #    E(4)
///   row2: F(5) G(6) H(7)  + one hidden in a tunnel? (none)
/// Colors: 0 for A,D,F; 1 for B,C,E; 2 for G,H + 1 more.
BjLevel _mini({List<int>? buses, int waiting = 3, List<int>? colors}) {
  final cs = colors ?? [0, 1, 1, 0, 1, 0, 2, 2, 2];
  final cells = [0, 1, 2, 3, 5, 6, 7, 8];
  final ps = <BjPassenger>[
    for (var i = 0; i < cells.length; i++) BjPassenger(id: i, color: cs[i], cell: cells[i]),
    BjPassenger(id: 8, color: cs[8], tunnel: 0),
  ];
  return BjLevel(
    tier: BjTier.easy,
    number: 1,
    cols: 3,
    rows: 4,
    walls: {4},
    tunnels: [const BjTunnel(id: 0, cell: 10, out: 9, dir: 3, queue: [8])],
    passengers: ps,
    buses: buses ?? [0, 1, 2],
    waiting: waiting,
    colorCount: 3,
    solution: const [],
  );
}

void main() {
  test('paths: only passengers with a way to row 0 can leave', () {
    final g = BjGame(_mini());

    expect(g.pos[8], 9, reason: 'tunnel fills its free output cell at start');
    expect(g.canTap(0), isTrue);
    expect(g.canTap(3), isFalse);
    expect(g.tap(3), isNull);
    expect(g.removable.toSet(), {0, 1, 2});
    g.tap(0); // color 0 boards bus 0
    expect(g.seated, [0]);
    expect(g.pathFor(3), [3, 0]);
    expect(g.canTap(5), isFalse);
  });

  test('boarding, waiting, departure and auto-boarding', () {
    final g = BjGame(_mini());
    final m1 = g.tap(1)!; // color 1, bus is 0 -> waits
    expect(m1.boarded, isFalse);
    expect(m1.waitIndex, 0);
    g.tap(2); // color 1 waits
    g.tap(0); // board
    g.tap(3); // board (D now free)
    expect(g.removable.contains(5), isTrue);
    final m = g.tap(5)!;
    expect(m.boarded, isTrue);
    expect(m.departures.single.color, 0);
    // bus 1 (color 1) arrives, 2 waiting color-1 passengers auto-board.
    expect(m.autoBoard.map((a) => a.id), [1, 2]);
    expect(m.autoBoard.map((a) => a.fromIndex), [0, 1]);
    expect(g.waiting, isEmpty);
    expect(g.busIndex, 1);
    expect(g.seated.length, 2);
    expect(g.peakWaiting, 2);
  });

  test('tunnel spawns when its output frees and win when all buses leave', () {
    final g = BjGame(_mini());
    for (final id in [0, 3, 5, 1, 2, 4]) {
      expect(g.tap(id), isNotNull, reason: 'tap $id');
    }
    expect(g.busIndex, 2);
    final m = g.tap(6)!;
    expect(m.boarded, isTrue);
    g.tap(7);
    final last = g.tap(8);
    expect(last, isNotNull);
    expect(g.won, isTrue);
    expect(g.over, isTrue);
  });

  test('a full waiting area loses; an extra spot continues', () {
    final g = BjGame(_mini(buses: [2, 1, 0], waiting: 2));
    g.tap(0);
    expect(g.lost, isFalse);
    g.tap(1);
    expect(g.lost, isTrue);
    expect(g.tap(2), isNull);
    g.addSlot();
    expect(g.lost, isFalse);
    expect(g.capacity, 3);
    g.addSlot();
    g.addSlot();
    expect(g.canAddSlot, isFalse);
  });

  test('stars', () {
    expect(bjStars(peakWaiting: 1, capacity: 7, continues: 0), 3);
    expect(bjStars(peakWaiting: 6, capacity: 7, continues: 0), 2);
    expect(bjStars(peakWaiting: 6, capacity: 7, continues: 1), 1);
    expect(bjStars(peakWaiting: 0, capacity: 7, continues: 2), 2);
  });

  test('generation is deterministic and differs per tier/level', () {
    final a = bjGenerate(BjTier.hard, 17), b = bjGenerate(BjTier.hard, 17);
    expect(identical(a, b) || a.solution.toString() == b.solution.toString(), isTrue);
    final c = bjGenerate(BjTier.hard, 18);
    expect([for (final p in a.passengers) p.color].toString() == [for (final p in c.passengers) p.color].toString(),
        isFalse);
  });

  test('tiers grow: bigger crowds, more colors, obstacles and tunnels later', () {
    final e1 = bjGenerate(BjTier.easy, 1), x100 = bjGenerate(BjTier.extreme, 100);
    expect(x100.passengers.length, greaterThan(e1.passengers.length));
    expect(x100.colorCount, greaterThan(e1.colorCount));
    expect(e1.walls, isEmpty);
    expect(e1.tunnels, isEmpty);
    expect(x100.walls, isNotEmpty);
    expect(x100.tunnels, isNotEmpty);
    expect(bjSpec(BjTier.extreme).waiting, lessThan(bjSpec(BjTier.easy).waiting));
  });

  test('every level of every tier is valid and solvable by its winning line', () {
    for (final t in BjTier.values) {
      var mixed = 0;
      for (var l = 1; l <= kBjLevels; l++) {
        final lv = bjGenerate(t, l);
        final why = '${t.id} L$l';
        expect(lv.passengers.length % kBjSeats, 0, reason: why);
        expect(lv.buses.length * kBjSeats, lv.passengers.length, reason: why);
        expect(lv.buses.toSet().length, lv.colorCount, reason: why);
        expect(lv.colorCount, lessThanOrEqualTo(kBjMaxColors), reason: why);
        for (var c = 0; c < lv.colorCount; c++) {
          final count = lv.passengers.where((p) => p.color == c).length;
          expect(count, lv.buses.where((b) => b == c).length * kBjSeats, reason: '$why color $c');
        }
        expect(lv.solution.toSet().length, lv.passengers.length, reason: why);
        final g = BjGame(lv);
        for (final id in lv.solution) {
          expect(g.tap(id), isNotNull, reason: '$why tap $id');
          expect(g.lost, isFalse, reason: '$why lost at $id');
        }
        expect(g.won, isTrue, reason: why);
        expect(g.peakWaiting, lessThanOrEqualTo(lv.waiting - bjSpec(t).slack), reason: why);
        if (g.peakWaiting > 0) mixed++;
      }
      // Colors are actually mixed up, not handed out in neat bus-sized groups.
      expect(mixed, greaterThan(kBjLevels ~/ 2), reason: t.id);
    }
  });

  test('hint points at a passenger who can leave', () {
    for (final t in BjTier.values) {
      final g = BjGame(bjGenerate(t, 40));
      for (var i = 0; i < 6 && !g.over; i++) {
        final h = bjHint(g);
        expect(h, isNotNull);
        expect(g.canTap(h!), isTrue);
        g.tap(h);
      }
    }
  });
}
