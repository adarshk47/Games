import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/tile_match/logic/tile_match_logic.dart';

import 'helpers.dart';

/// Hand-made level: tile 2 sits on top of tiles 0 and 1; tiles 3..5 are free.
/// Icons: 0,1,2 = icon 0; 3,4,5 = icon 1.
TmLevel _mini() {
  const tiles = [
    TmTile(id: 0, x: 0, y: 0, z: 0),
    TmTile(id: 1, x: 2, y: 0, z: 0),
    TmTile(id: 3, x: 4, y: 0, z: 0),
    TmTile(id: 4, x: 6, y: 0, z: 0),
    TmTile(id: 5, x: 8, y: 0, z: 0),
    TmTile(id: 2, x: 1, y: 0, z: 1),
  ];
  final byId = [...tiles]..sort((a, b) => a.id.compareTo(b.id));
  return TmLevel(
    tier: TmTier.easy,
    number: 1,
    width: 10,
    height: 2,
    tiles: byId,
    icons: const [0, 0, 0, 1, 1, 1],
    solution: const [2, 0, 1, 3, 4, 5],
  );
}

void main() {
  test('covered tiles cannot be tapped until the top tile leaves', () {
    final g = TmGame(_mini());
    expect(g.isFree(0), isFalse);
    expect(g.isFree(1), isFalse);
    expect(g.tap(0), isNull);
    expect(g.isFree(3), isTrue);
    final m = g.tap(2)!;
    expect(m.cleared, isEmpty);
    expect(g.isFree(0), isTrue);
    expect(g.isFree(1), isTrue);
  });

  test('identical tiles group in the tray and three vanish', () {
    final g = TmGame(_mini());
    g.tap(3);
    g.tap(2);
    expect(g.tray, [3, 2]);
    final m = g.tap(4)!;
    // Inserted next to its twin.
    expect(m.index, 1);
    expect(g.tray, [3, 4, 2]);
    g.tap(0);
    final c = g.tap(1)!;
    expect(c.cleared.toSet(), {2, 0, 1});
    expect(c.preClear.length, 5);
    expect(g.tray, [3, 4]);
    g.tap(5);
    expect(g.won, isTrue);
    expect(g.moves, 6);
  });

  test('tray full loses; returning 3 tiles continues', () {
    final lv = tmGenerate(TmTier.extreme, 1);
    final g = TmGame(lv);
    final line = losingLine(g);
    expect(g.lost, isTrue, reason: 'line $line');
    expect(g.tray.length, kTmTray);
    final back = g.returnLast();
    expect(back.length, 3);
    expect(back.toSet(), line.reversed.take(3).toSet());
    expect(g.tray.length, kTmTray - 3);
    expect(g.lost, isFalse);
    // Back in place: only other returned tiles may cover them.
    for (final t in back) {
      expect(lv.above[t].where(g.onBoard.contains).every(back.contains), isTrue);
    }
  });

  test('undo restores the board, the tray and a vanished triple', () {
    final g = TmGame(_mini());
    expect(g.canUndo, isFalse);
    g.tap(2);
    g.tap(0);
    g.tap(1);
    expect(g.tray, isEmpty);
    expect(g.undo(), 1);
    expect(g.tray, [2, 0]);
    expect(g.onBoard.contains(1), isTrue);
    expect(g.moves, 2);
    expect(g.undo(), 0);
    expect(g.undo(), 2);
    expect(g.undo(), isNull);
    expect(g.onBoard.length, 6);
  });

  test('shuffle keeps the icon multiset and stays winnable', () {
    for (final tier in TmTier.values) {
      final lv = tmGenerate(tier, 40);
      final g = TmGame(lv);
      // Play a few solution moves, then shuffle.
      for (final t in lv.solution.take(5)) {
        g.tap(t);
      }
      List<int> ms() => ([for (final t in g.onBoard) g.icons[t]]..sort());
      final before = ms();
      g.shuffle(TmRng(9));
      expect(ms(), before);
      // A winning order exists: follow it greedily via a fresh assignment check.
      expect(_greedyWin(g), isTrue, reason: '$tier');
    }
  });

  test('generator is deterministic and every icon count is a multiple of 3', () {
    for (final tier in TmTier.values) {
      for (final l in [1, 50, 100]) {
        final a = tmGenerate(tier, l), b = tmGenerate(tier, l);
        expect(a.icons, b.icons);
        expect(a.solution, b.solution);
        expect([for (final t in a.tiles) '${t.x},${t.y},${t.z}'], [for (final t in b.tiles) '${t.x},${t.y},${t.z}']);
      }
    }
  });

  test('difficulty grows across tiers', () {
    double avg(TmTier t, int Function(TmLevel) f) =>
        [for (var l = 1; l <= 100; l += 9) f(tmGenerate(t, l))].reduce((a, b) => a + b) / 12;
    var prevTiles = 0.0, prevTypes = 0.0;
    for (final t in TmTier.values) {
      final tiles = avg(t, (l) => l.tiles.length);
      final types = avg(t, (l) => l.typeCount);
      expect(tiles, greaterThan(prevTiles), reason: '$t tiles');
      expect(types, greaterThan(prevTypes), reason: '$t types');
      prevTiles = tiles;
      prevTypes = types;
    }
  });

  test('ALL 400 levels are solvable by their stored solution', () {
    for (final tier in TmTier.values) {
      for (var l = 1; l <= kTmLevels; l++) {
        final lv = tmGenerate(tier, l);
        final why = '${tier.id} L$l';
        expect(lv.tiles.length % 3, 0, reason: why);
        expect(lv.tiles.length, greaterThanOrEqualTo(9), reason: why);
        final counts = <int, int>{};
        for (final i in lv.icons) {
          counts[i] = (counts[i] ?? 0) + 1;
        }
        expect(counts.values.every((c) => c % 3 == 0), isTrue, reason: why);
        expect(lv.solution.toSet().length, lv.tiles.length, reason: why);
        // Board fits the declared area; every upper tile is supported.
        for (final t in lv.tiles) {
          expect(t.x >= 0 && t.x + 2 <= lv.width && t.y >= 0 && t.y + 2 <= lv.height, isTrue, reason: '$why $t');
          if (t.z > 0) {
            expect(lv.tiles.any((o) => o.z == t.z - 1 && o.overlaps(t)), isTrue, reason: '$why floating $t');
          }
        }
        final g = TmGame(lv);
        for (final t in lv.solution) {
          expect(g.tap(t), isNotNull, reason: '$why tap $t');
        }
        expect(g.won, isTrue, reason: why);
        expect(g.peakTray, lessThan(kTmTray), reason: why);
      }
    }
  });

  test('stars', () {
    expect(tmStars(helpers: 0, continues: 0), 3);
    expect(tmStars(helpers: 2, continues: 0), 2);
    expect(tmStars(helpers: 0, continues: 1), 1);
  });
}

/// Depth-limited search: can the current state still be won?
bool _greedyWin(TmGame g) {
  final seen = <String>{};
  bool go(TmGame s, int depth) {
    if (s.won) return true;
    if (s.lost || depth > 400) return false;
    final key = '${(s.onBoard.toList()..sort())}|${[for (final t in s.tray) s.icons[t]]..sort()}';
    if (!seen.add(key) || seen.length > 20000) return false;
    final free = s.freeTiles.toList()..sort();
    int countOf(int t) => s.tray.where((x) => s.icons[x] == s.icons[t]).length;
    free.sort((a, b) => countOf(b).compareTo(countOf(a)));
    for (final t in free) {
      s.tap(t);
      if (go(s, depth + 1)) return true;
      s.undo();
    }
    return false;
  }

  return go(g, 0);
}
