import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/screw_jam/logic/screw_jam_logic.dart';

/// Hand-made level: plate 0 (bottom) with screws 0,1; plate 1 (top) covers
/// screw 1 and holds screw 2.
SjLevel _mini({List<int> queue = const [0], int tray = 3}) {
  final plates = [
    SjPlate(id: 0, parts: const [SjRect(0, 0, 3, 1)], material: 0, tint: 0),
    SjPlate(id: 1, parts: const [SjRect(2, 0, 1, 3)], material: 1, tint: 1),
  ];
  final screws = [
    SjScrew(id: 0, plate: 0, c: 0, r: 0, color: 0),
    SjScrew(id: 1, plate: 0, c: 2, r: 0, color: 0),
    SjScrew(id: 2, plate: 1, c: 2, r: 2, color: 0),
  ];
  return SjLevel(
    tier: SjTier.easy,
    number: 1,
    cols: 3,
    rows: 3,
    plates: plates,
    screws: screws,
    boxQueue: queue,
    trayCapacity: tray,
    colorCount: 1,
    solution: const [2, 0, 1],
  );
}

void main() {
  test('blocked screws cannot be tapped until the cover falls', () {
    final g = SjGame(_mini());
    expect(g.isBlocked(1), isTrue);
    expect(g.canTap(1), isFalse);
    expect(g.tap(1), isNull);
    expect(g.canTap(0), isTrue);
    final m = g.tap(2)!;
    expect(m.boxSlot, 0);
    expect(m.fallen, [1]);
    expect(g.canTap(1), isTrue);
    g.tap(0);
    final last = g.tap(1)!;
    expect(last.completed.single.$2, 0);
    expect(last.fallen, [0]);
    expect(g.won, isTrue);
    expect(g.tray, isEmpty);
    expect(g.boxesLeft, 0);
  });

  test('non-matching screws go to the tray and a full tray loses', () {
    final lv = _mini(tray: 2);
    for (final s in lv.screws) {
      s.color = 1;
    }
    final g = SjGame(lv);
    final m = g.tap(0)!;
    expect(m.boxSlot, isNull);
    expect(m.trayIndex, 0);
    expect(g.lost, isFalse);
    g.tap(2);
    expect(g.tray.length, 2);
    expect(g.lost, isTrue);
    expect(g.canTap(1), isFalse);
    // Bought slot continues the game.
    expect(g.addTraySlot(), isTrue);
    expect(g.lost, isFalse);
    expect(g.canTap(1), isTrue);
  });

  test('a new box pulls matching screws out of the tray', () {
    final lv = _mini(queue: [1, 0, 2], tray: 5);
    // Two boxes visible: color 1 and color 0. Screws are 0 -> box 1 (slot 1).
    lv.screws[0].color = 2;
    lv.screws[1].color = 2;
    lv.screws[2].color = 2;
    final g = SjGame(lv);
    expect(g.slots.map((b) => b?.color), [1, 0]);
    g.tap(0);
    g.tap(2);
    expect(g.tray.length, 2);
    // Nothing fills color 1/0 boxes here, so color 2 never arrives.
    expect(g.slotFor(1), isNull);
  });

  test('box completion cascades and refills from tray', () {
    final plates = [SjPlate(id: 0, parts: const [SjRect(0, 0, 6, 1)], material: 0, tint: 0)];
    final colors = [1, 1, 0, 0, 0, 1];
    final screws = [for (var i = 0; i < 6; i++) SjScrew(id: i, plate: 0, c: i, r: 0, color: colors[i])];
    final lv = SjLevel(
      tier: SjTier.easy,
      number: 1,
      cols: 6,
      rows: 1,
      plates: plates,
      screws: screws,
      boxQueue: const [0, 2, 1],
      trayCapacity: 5,
      colorCount: 3,
      solution: const [],
    );
    final g = SjGame(lv);
    g.tap(0);
    g.tap(1);
    expect(g.tray, [0, 1]);
    g.tap(2);
    g.tap(3);
    final m = g.tap(4)!;
    expect(m.completed.first.$1, 0);
    expect(m.fromTray.map((e) => e.$1), [0, 1]);
    expect(g.tray, isEmpty);
    expect(g.slots[0]!.color, 1);
    expect(g.slots[0]!.screws.length, 2);
    g.tap(5);
    expect(g.won, isTrue);
  });

  test('stars', () {
    expect(sjStars(peakTray: 0, trayCapacity: 5, continues: 0), 3);
    expect(sjStars(peakTray: 4, trayCapacity: 5, continues: 0), 2);
    expect(sjStars(peakTray: 4, trayCapacity: 5, continues: 1), 1);
  });

  test('tier progression grows', () {
    for (final t in SjTier.values) {
      expect(sjPlatesFor(t, kSjLevels) >= sjPlatesFor(t, 1), isTrue);
      expect(sjColorsFor(t, kSjLevels) >= sjColorsFor(t, 1), isTrue);
    }
    expect(sjSpec(SjTier.extreme).tray < sjSpec(SjTier.easy).tray, isTrue);
    expect(sjPlatesFor(SjTier.extreme, 30) > sjPlatesFor(SjTier.easy, 30), isTrue);
    expect(kSjLevels, 100);
    // Smooth: plates / colors never drop and never jump by more than one.
    for (final t in SjTier.values) {
      for (var n = 2; n <= kSjLevels; n++) {
        final dp = sjPlatesFor(t, n) - sjPlatesFor(t, n - 1);
        final dc = sjColorsFor(t, n) - sjColorsFor(t, n - 1);
        expect(dp >= 0 && dp <= 1, isTrue, reason: '${t.id} L$n plates');
        expect(dc >= 0 && dc <= 1, isTrue, reason: '${t.id} L$n colors');
      }
    }
  });

  test('generation is deterministic and differs per tier/level', () {
    expect(sjGenerate(SjTier.hard, 7).key, _buildFresh(SjTier.hard, 7));
    expect(sjGenerate(SjTier.easy, 5).key, isNot(sjGenerate(SjTier.easy, 6).key));
    expect(sjGenerate(SjTier.easy, 5).key, isNot(sjGenerate(SjTier.medium, 5).key));
  });

  test('every level of every tier is valid and solvable', () {
    for (final t in SjTier.values) {
      for (var n = 1; n <= kSjLevels; n++) {
        final lv = sjGenerate(t, n);
        final why = '${t.id} L$n';
        expect(lv.plates.length, sjPlatesFor(t, n), reason: why);
        expect(lv.screws.length % kSjBoxSize, 0, reason: why);
        expect(lv.boxQueue.length * kSjBoxSize, lv.screws.length, reason: why);
        expect(lv.plateScrews.every((s) => s.isNotEmpty), isTrue, reason: '$why empty plate');
        final cells = {for (final s in lv.screws) '${s.c},${s.r}'};
        expect(cells.length, lv.screws.length, reason: '$why shared cell');
        for (final s in lv.screws) {
          expect(lv.plates[s.plate].covers(s.c, s.r), isTrue, reason: why);
          expect(s.c >= 0 && s.c < lv.cols && s.r >= 0 && s.r < lv.rows, isTrue, reason: why);
        }
        for (final p in lv.plates) {
          final b = p.bounds;
          expect(b.c >= 0 && b.r >= 0 && b.c + b.w <= lv.cols && b.r + b.h <= lv.rows, isTrue, reason: why);
        }
        // Colors per box count match.
        final perColor = <int, int>{};
        for (final s in lv.screws) {
          perColor[s.color] = (perColor[s.color] ?? 0) + 1;
        }
        for (final e in perColor.entries) {
          expect(lv.boxQueue.where((c) => c == e.key).length * kSjBoxSize, e.value, reason: why);
        }
        // Plates spread over the whole board: every edge row / column is
        // reached and each third of the rows holds some plate.
        final covered = {for (final p in lv.plates) ...p.cells};
        expect(covered.any((x) => x.$2 == 0), isTrue, reason: '$why top');
        expect(covered.any((x) => x.$2 == lv.rows - 1), isTrue, reason: '$why bottom');
        expect(covered.any((x) => x.$1 == 0), isTrue, reason: '$why left');
        expect(covered.any((x) => x.$1 == lv.cols - 1), isTrue, reason: '$why right');
        for (var band = 0; band < 3; band++) {
          final r0 = band * lv.rows ~/ 3, r1 = (band + 1) * lv.rows ~/ 3;
          expect(covered.any((x) => x.$2 >= r0 && x.$2 < r1), isTrue, reason: '$why band $band');
        }
        // Built-in solution wins without ever losing.
        final g = SjGame(lv);
        for (final s in lv.solution) {
          expect(g.tap(s), isNotNull, reason: '$why tap $s');
          expect(g.lost, isFalse, reason: why);
        }
        expect(g.won, isTrue, reason: why);
        // Independent solver also finds a win.
        final sol = sjSolve(SjGame(lv), maxNodes: 50000);
        expect(sol, isNotNull, reason: '$why solver');
        final g2 = SjGame(lv);
        for (final s in sol!) {
          g2.tap(s);
        }
        expect(g2.won, isTrue, reason: why);
      }
    }
  });

  test('hint points at a tappable screw', () {
    final g = SjGame(sjGenerate(SjTier.medium, 10));
    final h = sjHint(g)!;
    expect(g.canTap(h), isTrue);
    expect(g.slotFor(h), isNotNull);
  });
}

String _buildFresh(SjTier t, int n) => sjGenerate(t, n).key;
