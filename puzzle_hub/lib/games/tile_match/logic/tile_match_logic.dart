/// Pure-Dart rules and level generator for Tile Match (triple match).
///
/// Board model: tiles are 2x2 squares on an integer unit grid of
/// [TmLevel.width] x [TmLevel.height] units, stacked in layers ([TmTile.z],
/// higher = on top). Tile A covers tile B when A is on a higher layer and their
/// squares overlap (|dx| < 2 and |dy| < 2). Only tiles that no remaining tile
/// covers can be tapped. A tapped tile moves into the tray (capacity
/// [kTmTray]); it is inserted next to identical tiles, and three identical
/// tiles vanish. A full tray without a match loses; an empty board wins.
///
/// Solvability: the generator first fixes the tile positions, then simulates a
/// random winning play order (each pick is a tile that is free at that time)
/// and hands out icons along that order so the tray never overflows. That
/// order is stored as [TmLevel.solution].
library;

/// Difficulty tiers.
enum TmTier {
  easy,
  medium,
  hard,
  extreme;

  String get id => name;

  static TmTier fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => easy);
}

/// Levels per tier.
const kTmLevels = 100;

/// Tray slots.
const kTmTray = 7;

/// Number of tile icons available (see the UI art table).
const kTmIconCount = 24;

/// Small deterministic PRNG (mulberry32) so levels are identical on every
/// platform and Dart version.
class TmRng {
  TmRng(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;

  int _next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = _imul(t ^ (t >> 15), t | 1);
    t ^= (t + _imul(t ^ (t >> 7), t | 61)) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  static int _imul(int a, int b) => (a * b) & 0xFFFFFFFF;

  /// 0 <= result < [n].
  int nextInt(int n) => n <= 1 ? 0 : _next() % n;

  /// 0 <= result < 1.
  double nextDouble() => _next() / 4294967296.0;

  void shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

/// Per-tier generator parameters.
class TmTierSpec {
  const TmTierSpec({
    required this.cols,
    required this.rows,
    required this.layers,
    required this.minTiles,
    required this.maxTiles,
    required this.minTypes,
    required this.maxTypes,
    required this.maxGroups,
    required this.newGroupChance,
  });

  /// Bottom layer size in tiles.
  final int cols, rows;
  final int layers, minTiles, maxTiles, minTypes, maxTypes;

  /// Hidden solution: max different icons waiting in the tray at once.
  final int maxGroups;

  /// Hidden solution: chance to start a new icon instead of finishing one.
  final double newGroupChance;
}

TmTierSpec tmSpec(TmTier t) => switch (t) {
      TmTier.easy => const TmTierSpec(
          cols: 5, rows: 6, layers: 3, minTiles: 18, maxTiles: 45, minTypes: 5, maxTypes: 8,
          maxGroups: 2, newGroupChance: 0.3),
      TmTier.medium => const TmTierSpec(
          cols: 6, rows: 7, layers: 4, minTiles: 42, maxTiles: 66, minTypes: 8, maxTypes: 11,
          maxGroups: 3, newGroupChance: 0.4),
      TmTier.hard => const TmTierSpec(
          cols: 7, rows: 7, layers: 5, minTiles: 60, maxTiles: 84, minTypes: 10, maxTypes: 13,
          maxGroups: 3, newGroupChance: 0.55),
      TmTier.extreme => const TmTierSpec(
          cols: 7, rows: 8, layers: 6, minTiles: 78, maxTiles: 105, minTypes: 12, maxTypes: 16,
          maxGroups: 3, newGroupChance: 0.7),
    };

int _lerp(int a, int b, int level) {
  final l = level.clamp(1, kTmLevels);
  return a + ((b - a) * (l - 1) / (kTmLevels - 1)).round();
}

/// Approximate tile count for a level (exact count may be a little lower).
int tmTilesFor(TmTier t, int level) => _lerp(tmSpec(t).minTiles, tmSpec(t).maxTiles, level) ~/ 3 * 3;

/// Different icons used by a level.
int tmTypesFor(TmTier t, int level) => _lerp(tmSpec(t).minTypes, tmSpec(t).maxTypes, level);

/// One tile. [x], [y] are unit coordinates of its top-left corner.
class TmTile {
  const TmTile({required this.id, required this.x, required this.y, required this.z});
  final int id, x, y, z;

  bool overlaps(TmTile o) => (x - o.x).abs() < 2 && (y - o.y).abs() < 2;

  @override
  String toString() => 'T$id($x,$y,$z)';
}

/// A generated level. Tiles are sorted bottom-up (z, then y, then x), so their
/// list order is also a valid paint order.
class TmLevel {
  TmLevel({
    required this.tier,
    required this.number,
    required this.width,
    required this.height,
    required this.tiles,
    required this.icons,
    required this.solution,
  }) : above = _computeAbove(tiles);

  final TmTier tier;
  final int number;

  /// Board size in units (a tile is 2x2 units).
  final int width, height;
  final List<TmTile> tiles;

  /// Starting icon of every tile (index = tile id).
  final List<int> icons;

  /// A winning tap order.
  final List<int> solution;

  /// For every tile, the tiles that cover it.
  final List<List<int>> above;

  int get layers => tiles.isEmpty ? 0 : tiles.map((t) => t.z).reduce((a, b) => a > b ? a : b) + 1;

  int get typeCount => icons.toSet().length;

  static List<List<int>> _computeAbove(List<TmTile> tiles) => [
        for (final t in tiles) [for (final o in tiles) if (o.z > t.z && o.overlaps(t)) o.id],
      ];
}

// ---------------------------------------------------------------------------
// Icon assignment along a simulated winning order.
// ---------------------------------------------------------------------------

/// Result of [tmAssignIcons].
class TmAssignment {
  TmAssignment(this.icons, this.order);

  /// Tile id -> icon.
  final Map<int, int> icons;

  /// The simulated winning pick order.
  final List<int> order;
}

/// Simulates a winning play over the tiles in [onBoard] and assigns icons.
///
/// [open] = icons already waiting in the tray (icon -> count, 1 or 2).
/// [triples] = icons of the full triples still to hand out (one entry per
/// triple). Together they must cover exactly `onBoard.length` tiles.
/// Returns null when this attempt got stuck (try another seed).
TmAssignment? tmAssignIcons({
  required List<List<int>> above,
  required Set<int> onBoard,
  required Map<int, int> open,
  required List<int> triples,
  required TmRng rng,
  int maxGroups = 3,
  double newGroupChance = 0.5,
  int tray = kTmTray,
}) {
  final board = {...onBoard};
  final groups = {...open};
  final pool = [...triples];
  rng.shuffle(pool);
  var occ = groups.values.fold<int>(0, (a, b) => a + b);
  final icons = <int, int>{};
  final order = <int>[];

  while (board.isNotEmpty) {
    final free = [
      for (final t in board)
        if (above[t].every((a) => !board.contains(a))) t,
    ]..sort();
    if (free.isEmpty) return null;
    final t = free[rng.nextInt(free.length)];

    final complete = [for (final e in groups.entries) if (e.value == 2) e.key];
    final extend = [for (final e in groups.entries) if (e.value == 1 && occ + 1 < tray) e.key];
    final newIdx = groups.length < maxGroups && occ + 1 < tray ? pool.indexWhere((i) => !groups.containsKey(i)) : -1;

    int icon;
    final existing = [...complete, ...extend];
    if (existing.isEmpty && newIdx < 0) return null;
    if (occ >= tray - 2 && complete.isNotEmpty) {
      icon = complete[rng.nextInt(complete.length)];
    } else if (newIdx >= 0 && (existing.isEmpty || rng.nextDouble() < newGroupChance)) {
      icon = pool.removeAt(newIdx);
    } else {
      icon = existing[rng.nextInt(existing.length)];
    }

    final c = (groups[icon] ?? 0) + 1;
    if (c == 3) {
      groups.remove(icon);
      occ -= 2;
    } else {
      groups[icon] = c;
      occ += 1;
    }
    icons[t] = icon;
    order.add(t);
    board.remove(t);
  }
  if (groups.isNotEmpty || pool.isNotEmpty) return null;
  return TmAssignment(icons, order);
}

// ---------------------------------------------------------------------------
// Layout generator.
// ---------------------------------------------------------------------------

/// Layout styles: pyramid (each layer half a tile in and one tile smaller),
/// checker (odd layers offset by half a tile), brick (odd layers shifted
/// horizontally only).
enum _Style { pyramid, checker, brick }

List<(int, int, int)> _fullLayout(_Style s, int cols, int rows, int layers) {
  final out = <(int, int, int)>[];
  for (var z = 0; z < layers; z++) {
    int ox, oy, nc, nr;
    switch (s) {
      case _Style.pyramid:
        ox = z;
        oy = z;
        nc = cols - z;
        nr = rows - z;
      case _Style.checker:
        ox = z % 2;
        oy = z % 2;
        nc = cols - z % 2;
        nr = rows - z % 2;
      case _Style.brick:
        // Odd layers shift right half a tile; every second layer half a tile down.
        ox = z % 2;
        oy = z ~/ 2;
        nc = cols - z % 2;
        nr = (rows * 2 - oy) ~/ 2;
    }
    if (nc <= 0 || nr <= 0) break;
    for (var j = 0; j < nr; j++) {
      for (var i = 0; i < nc; i++) {
        out.add((ox + 2 * i, oy + 2 * j, z));
      }
    }
  }
  return out;
}

int _seed(TmTier t, int level) => 0x7A11E5 ^ (t.index + 1) * 1000003 ^ level * 7919;

/// Deterministic, guaranteed-solvable level for ([tier], [level]).
TmLevel tmGenerate(TmTier tier, int level) {
  final spec = tmSpec(tier);
  final lv = level.clamp(1, kTmLevels);
  final rng = TmRng(_seed(tier, lv));
  final w = spec.cols * 2, h = spec.rows * 2;

  final style = lv <= 2 ? _Style.pyramid : _Style.values[rng.nextInt(_Style.values.length)];
  // Taller stacks as the tier progresses.
  final layers = (lv > 30 ? spec.layers : spec.layers - 1).clamp(2, spec.layers);
  var target = tmTilesFor(tier, lv) + (rng.nextInt(3) - 1) * 3;
  target = target.clamp(9, _fullLayout(style, spec.cols, spec.rows, layers).length ~/ 3 * 3);

  // Shrink the footprint for small levels so they keep their height, then
  // centre it on the board.
  var fc = spec.cols, fr = spec.rows;
  while (fc > 3 || fr > 3) {
    final nc = fr >= fc ? fc : fc - 1, nr = fr >= fc ? fr - 1 : fr;
    if (_fullLayout(style, nc, nr, layers).length < target * 1.35) break;
    fc = nc;
    fr = nr;
  }
  final cells = [
    for (final c in _fullLayout(style, fc, fr, layers)) (c.$1 + spec.cols - fc, c.$2 + spec.rows - fr, c.$3),
  ];

  // Trim: repeatedly remove an uncovered tile (with its mirror for symmetry)
  // until the count matches. Removing only uncovered tiles keeps every upper
  // tile fully supported.
  final present = {...cells};
  bool coveredBy((int, int, int) a, (int, int, int) b) =>
      b.$3 > a.$3 && (a.$1 - b.$1).abs() < 2 && (a.$2 - b.$2).abs() < 2;
  bool uncovered((int, int, int) c) => !present.any((o) => coveredBy(c, o));
  (int, int, int) mirror((int, int, int) c) => (w - 2 - c.$1, c.$2, c.$3);

  while (present.length > target) {
    final open = present.where(uncovered).toList()
      ..sort((a, b) => a.$3 != b.$3
          ? a.$3.compareTo(b.$3)
          : a.$2 != b.$2
              ? a.$2.compareTo(b.$2)
              : a.$1.compareTo(b.$1));
    final excess = present.length - target;
    // Prefer lower layers so the stacks stay tall.
    final top = open.map((o) => o.$3).reduce((a, b) => a > b ? a : b);
    final weights = [for (final o in open) (top - o.$3 + 1) * (top - o.$3 + 1)];
    var roll = rng.nextInt(weights.fold(0, (a, b) => a + b));
    var c = open.last;
    for (var i = 0; i < open.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        c = open[i];
        break;
      }
    }
    final m = mirror(c);
    if (m == c) {
      present.remove(c);
      continue;
    }
    if (excess >= 2 && present.contains(m) && uncovered(m)) {
      present
        ..remove(c)
        ..remove(m);
      continue;
    }
    if (excess == 1) {
      // Prefer a centre tile to keep the shape symmetric.
      final centre = open.where((o) => mirror(o) == o).toList();
      if (centre.isNotEmpty) c = centre[rng.nextInt(centre.length)];
    }
    present.remove(c);
  }

  final sorted = present.toList()
    ..sort((a, b) => a.$3 != b.$3
        ? a.$3.compareTo(b.$3)
        : a.$2 != b.$2
            ? a.$2.compareTo(b.$2)
            : a.$1.compareTo(b.$1));
  final tiles = [
    for (var i = 0; i < sorted.length; i++) TmTile(id: i, x: sorted[i].$1, y: sorted[i].$2, z: sorted[i].$3),
  ];
  final above = TmLevel._computeAbove(tiles);

  // Icons: pick the icon types, one triple per group, cycling through types.
  final types = List<int>.generate(kTmIconCount, (i) => i);
  rng.shuffle(types);
  final nTypes = tmTypesFor(tier, lv).clamp(1, tiles.length ~/ 3);
  final groups = tiles.length ~/ 3;
  final triples = [for (var g = 0; g < groups; g++) types[g % nTypes]];

  TmAssignment? a;
  for (var attempt = 0; a == null && attempt < 50; attempt++) {
    a = tmAssignIcons(
      above: above,
      onBoard: {for (final t in tiles) t.id},
      open: const {},
      triples: triples,
      rng: rng,
      maxGroups: spec.maxGroups,
      newGroupChance: spec.newGroupChance,
    );
  }
  // With maxGroups <= 3 the simulation can never get stuck; keep a safe
  // fallback anyway (finish groups one by one).
  a ??= tmAssignIcons(
    above: above,
    onBoard: {for (final t in tiles) t.id},
    open: const {},
    triples: triples,
    rng: rng,
    maxGroups: 1,
    newGroupChance: 0,
  )!;
  return TmLevel(
    tier: tier,
    number: lv,
    width: w,
    height: h,
    tiles: tiles,
    icons: [for (final t in tiles) a.icons[t.id]!],
    solution: a.order,
  );
}

// ---------------------------------------------------------------------------
// Game state.
// ---------------------------------------------------------------------------

/// Outcome of one tap.
class TmMove {
  TmMove({required this.tile, required this.index, required this.preClear, required this.cleared});

  final int tile;

  /// Where the tile was inserted in [preClear].
  final int index;

  /// Tray contents right after inserting the tile (before a match vanished).
  final List<int> preClear;

  /// Tiles that vanished as a triple (empty when no match).
  final List<int> cleared;
}

class _Snap {
  _Snap(this.onBoard, this.tray, this.moves);
  final Set<int> onBoard;
  final List<int> tray;
  final int moves;
}

/// Mutable play state of one level attempt.
class TmGame {
  TmGame(this.level)
      : icons = [...level.icons],
        onBoard = {for (final t in level.tiles) t.id};

  final TmLevel level;

  /// Current icon of every tile (shuffle changes it).
  final List<int> icons;

  /// Tiles still on the board.
  final Set<int> onBoard;

  /// Tiles in the tray, in display order.
  final List<int> tray = [];

  /// Order in which the tiles still in the tray arrived.
  final List<int> _arrivals = [];

  final List<_Snap> _history = [];

  int capacity = kTmTray;
  int moves = 0;
  int peakTray = 0;

  bool get won => onBoard.isEmpty && tray.isEmpty;
  bool get lost => tray.length >= capacity;
  bool get over => won || lost;
  bool get canUndo => _history.isNotEmpty && !won;
  int get tilesLeft => onBoard.length + tray.length;

  bool isFree(int id) => onBoard.contains(id) && level.above[id].every((a) => !onBoard.contains(a));

  bool canTap(int id) => !over && isFree(id);

  Iterable<int> get freeTiles => onBoard.where(isFree);

  /// Moves tile [id] to the tray. Returns null if it can't be tapped.
  TmMove? tap(int id) {
    if (!canTap(id)) return null;
    _history.add(_Snap({...onBoard}, [...tray], moves));
    onBoard.remove(id);
    final icon = icons[id];
    final last = tray.lastIndexWhere((t) => icons[t] == icon);
    final index = last < 0 ? tray.length : last + 1;
    tray.insert(index, id);
    _arrivals.add(id);
    final pre = [...tray];
    final same = tray.where((t) => icons[t] == icon).toList();
    var cleared = <int>[];
    if (same.length >= 3) {
      cleared = same.take(3).toList();
      tray.removeWhere(cleared.contains);
      _arrivals.removeWhere(cleared.contains);
    }
    moves++;
    if (pre.length > peakTray && cleared.isEmpty) peakTray = pre.length;
    return TmMove(tile: id, index: index, preClear: pre, cleared: cleared);
  }

  /// Reverts the last tap (also restoring a vanished triple). Returns the tile
  /// that went back to the board, or null.
  int? undo() {
    if (!canUndo) return null;
    final s = _history.removeLast();
    final returned = s.onBoard.difference(onBoard).firstOrNull;
    onBoard
      ..clear()
      ..addAll(s.onBoard);
    tray
      ..clear()
      ..addAll(s.tray);
    _arrivals.removeWhere((t) => !tray.contains(t));
    for (final t in tray) {
      if (!_arrivals.contains(t)) _arrivals.add(t);
    }
    moves = s.moves;
    return returned;
  }

  /// Continue after a full tray: the last [n] tiles that arrived go back to
  /// their board spots (nothing can cover them there). Returns them.
  List<int> returnLast([int n = 3]) {
    final back = _arrivals.reversed.take(n).toList();
    for (final t in back) {
      tray.remove(t);
      _arrivals.remove(t);
      onBoard.add(t);
    }
    _history.clear();
    return back;
  }

  /// Re-deals the icons of the tiles on the board (keeping the same icon
  /// multiset). It searches for a deal that is still winnable from the current
  /// tray; if none is found a plain random deal is used.
  void shuffle(TmRng rng) {
    final ids = onBoard.toList()..sort();
    if (ids.isEmpty) return;
    final counts = <int, int>{};
    for (final t in tray) {
      counts[icons[t]] = (counts[icons[t]] ?? 0) + 1;
    }
    final remaining = <int, int>{};
    for (final t in ids) {
      remaining[icons[t]] = (remaining[icons[t]] ?? 0) + 1;
    }
    final triples = <int>[];
    var ok = true;
    for (final e in remaining.entries) {
      final need = (3 - (counts[e.key] ?? 0)) % 3;
      final rest = e.value - need;
      if (rest < 0 || rest % 3 != 0) ok = false;
      for (var i = 0; i < rest ~/ 3; i++) {
        triples.add(e.key);
      }
    }
    final open = {for (final e in counts.entries) if (remaining.containsKey(e.key)) e.key: e.value};
    if (ok) {
      for (var attempt = 0; attempt < 60; attempt++) {
        final a = tmAssignIcons(
          above: level.above,
          onBoard: onBoard,
          open: open,
          triples: triples,
          rng: rng,
          maxGroups: 3,
          newGroupChance: 0.5,
          tray: capacity,
        );
        if (a != null) {
          for (final e in a.icons.entries) {
            icons[e.key] = e.value;
          }
          _history.clear();
          return;
        }
      }
    }
    final pool = [for (final t in ids) icons[t]];
    rng.shuffle(pool);
    for (var i = 0; i < ids.length; i++) {
      icons[ids[i]] = pool[i];
    }
    _history.clear();
  }
}

/// Stars: 3 = no help, 2 = used undo / shuffle, 1 = needed a continue.
int tmStars({required int helpers, required int continues}) => continues > 0 ? 1 : (helpers > 0 ? 2 : 3);
