/// Pure-Dart rules, level generator and solver for Screw Jam.
///
/// Board model: an integer grid of [SjLevel.cols] x [SjLevel.rows] cells.
/// Plates are unions of axis-aligned cell rectangles stacked in layers (the
/// plate index is its layer, higher = on top). Every screw sits in one cell of
/// exactly one plate; no two screws share a cell. A screw can be unscrewed
/// only when no remaining plate on a higher layer covers its cell.
///
/// Unscrewed screws go to the first active toolbox of the same color with room
/// (each box holds [kSjBoxSize]); otherwise into the holding tray. A full box
/// leaves and the next queued box takes its slot, pulling matching screws out
/// of the tray. A plate with no screws left falls off. All plates gone = win;
/// a full tray = lose.
library;

/// Difficulty tiers.
enum SjTier {
  easy,
  medium,
  hard,
  extreme;

  String get id => name;

  static SjTier fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => easy);
}

/// Levels per tier.
const kSjLevels = 30;

/// Screws per toolbox.
const kSjBoxSize = 3;

/// Toolboxes visible at the same time.
const kSjSlots = 2;

/// How many extra tray slots can be bought in one level.
const kSjMaxExtraSlots = 3;

/// Per-tier generator parameters.
class SjTierSpec {
  const SjTierSpec({
    required this.cols,
    required this.rows,
    required this.minPlates,
    required this.maxPlates,
    required this.minColors,
    required this.maxColors,
    required this.tray,
  });
  final int cols, rows, minPlates, maxPlates, minColors, maxColors, tray;
}

SjTierSpec sjSpec(SjTier t) => switch (t) {
      SjTier.easy => const SjTierSpec(cols: 6, rows: 7, minPlates: 3, maxPlates: 7, minColors: 3, maxColors: 4, tray: 7),
      SjTier.medium => const SjTierSpec(cols: 6, rows: 8, minPlates: 6, maxPlates: 10, minColors: 4, maxColors: 5, tray: 6),
      SjTier.hard => const SjTierSpec(cols: 7, rows: 9, minPlates: 9, maxPlates: 13, minColors: 5, maxColors: 6, tray: 5),
      SjTier.extreme => const SjTierSpec(cols: 7, rows: 9, minPlates: 12, maxPlates: 16, minColors: 6, maxColors: 8, tray: 4),
    };

int _lerp(int a, int b, int level) {
  final l = level.clamp(1, kSjLevels);
  return a + ((b - a) * (l - 1) / (kSjLevels - 1)).round();
}

int sjPlatesFor(SjTier t, int level) => _lerp(sjSpec(t).minPlates, sjSpec(t).maxPlates, level);
int sjColorsFor(SjTier t, int level) => _lerp(sjSpec(t).minColors, sjSpec(t).maxColors, level);

/// A cell rectangle (column, row, width, height).
class SjRect {
  const SjRect(this.c, this.r, this.w, this.h);
  final int c, r, w, h;
  bool contains(int cc, int rr) => cc >= c && cc < c + w && rr >= r && rr < r + h;
  @override
  String toString() => '($c,$r,${w}x$h)';
}

/// One plate. [layer] equals its index in [SjLevel.plates].
class SjPlate {
  SjPlate({required this.id, required this.parts, required this.material, required this.tint});
  final int id;
  final List<SjRect> parts;

  /// 0 = wood, 1 = metal.
  final int material;

  /// Index into the UI plate-color palette.
  final int tint;

  int get layer => id;

  bool covers(int c, int r) => parts.any((p) => p.contains(c, r));

  Iterable<(int, int)> get cells sync* {
    final seen = <int>{};
    for (final p in parts) {
      for (var r = p.r; r < p.r + p.h; r++) {
        for (var c = p.c; c < p.c + p.w; c++) {
          if (seen.add(r * 1000 + c)) yield (c, r);
        }
      }
    }
  }

  /// Bounding box.
  SjRect get bounds {
    var c0 = 1 << 20, r0 = 1 << 20, c1 = -1, r1 = -1;
    for (final p in parts) {
      if (p.c < c0) c0 = p.c;
      if (p.r < r0) r0 = p.r;
      if (p.c + p.w > c1) c1 = p.c + p.w;
      if (p.r + p.h > r1) r1 = p.r + p.h;
    }
    return SjRect(c0, r0, c1 - c0, r1 - r0);
  }
}

class SjScrew {
  SjScrew({required this.id, required this.plate, required this.c, required this.r, required this.color});
  final int id;
  final int plate;
  final int c, r;
  int color;
}

/// A generated level. [solution] is a winning tap order (verified in tests).
class SjLevel {
  SjLevel({
    required this.tier,
    required this.number,
    required this.cols,
    required this.rows,
    required this.plates,
    required this.screws,
    required this.boxQueue,
    required this.trayCapacity,
    required this.colorCount,
    required this.solution,
  }) {
    // Precompute, per screw, the plates above it that cover its cell.
    coverers = [
      for (final s in screws)
        [
          for (final p in plates)
            if (p.layer > plates[s.plate].layer && p.covers(s.c, s.r)) p.id,
        ],
    ];
    plateScrews = [
      for (final p in plates) [for (final s in screws) if (s.plate == p.id) s.id],
    ];
  }

  final SjTier tier;
  final int number;
  final int cols, rows;
  final List<SjPlate> plates;
  final List<SjScrew> screws;

  /// Box colors in arrival order.
  final List<int> boxQueue;
  final int trayCapacity;
  final int colorCount;
  final List<int> solution;

  late final List<List<int>> coverers;
  late final List<List<int>> plateScrews;

  /// Compact signature used to check determinism / uniqueness.
  String get key =>
      '${plates.map((p) => p.parts.join()).join('|')}#${screws.map((s) => '${s.c},${s.r},${s.color}').join(';')}';
}

/// One visible toolbox.
class SjBox {
  SjBox(this.queueIndex, this.color, [List<int>? screws]) : screws = screws ?? [];
  final int queueIndex;
  final int color;
  final List<int> screws;
  bool get full => screws.length >= kSjBoxSize;
  SjBox clone() => SjBox(queueIndex, color, [...screws]);
}

/// Where an unscrewed screw went.
class SjMove {
  SjMove(this.screw);
  final int screw;

  /// Box slot it went into, or null if it went to the tray.
  int? boxSlot;

  /// Tray index (when [boxSlot] is null).
  int trayIndex = -1;

  /// Boxes that filled up and left, in order: (slot, color, queueIndex,
  /// screws inside).
  final List<(int, int, int, List<int>)> completed = [];

  /// Tray screws pulled into a newly arrived box: (screw, tray index right
  /// after the tap, slot, index in [completed] of the box that made room).
  final List<(int, int, int, int)> fromTray = [];

  /// Plates that fell off because of this tap.
  final List<int> fallen = [];
}

/// Mutable game state.
class SjGame {
  SjGame(this.level) : trayCapacity = level.trayCapacity {
    final q = level.boxQueue;
    slots = [for (var i = 0; i < kSjSlots; i++) i < q.length ? SjBox(i, q[i]) : null];
    nextBox = q.length < kSjSlots ? q.length : kSjSlots;
  }

  SjGame._copy(SjGame o)
      : level = o.level,
        trayCapacity = o.trayCapacity {
    removed.addAll(o.removed);
    fallen.addAll(o.fallen);
    slots = [for (final b in o.slots) b?.clone()];
    nextBox = o.nextBox;
    tray.addAll(o.tray);
    moves = o.moves;
    peakTray = o.peakTray;
    extraSlots = o.extraSlots;
  }

  final SjLevel level;
  final Set<int> removed = {};
  final Set<int> fallen = {};
  late List<SjBox?> slots;
  late int nextBox;
  final List<int> tray = [];
  int trayCapacity;
  int moves = 0;
  int peakTray = 0;
  int extraSlots = 0;

  SjGame clone() => SjGame._copy(this);

  bool get won => fallen.length == level.plates.length;
  bool get lost => !won && tray.length >= trayCapacity;
  bool get over => won || lost;

  /// Boxes not yet completed (visible + queued).
  int get boxesLeft => slots.where((b) => b != null).length + (level.boxQueue.length - nextBox);

  bool isBlocked(int screw) => level.coverers[screw].any((p) => !fallen.contains(p));

  bool canTap(int screw) => !over && !removed.contains(screw) && !isBlocked(screw);

  Iterable<int> get removable sync* {
    for (final s in level.screws) {
      if (canTap(s.id)) yield s.id;
    }
  }

  /// Box slot that would accept [screw] right now, or null.
  int? slotFor(int screw) {
    final color = level.screws[screw].color;
    for (var i = 0; i < slots.length; i++) {
      final b = slots[i];
      if (b != null && b.color == color && !b.full) return i;
    }
    return null;
  }

  bool get canAddSlot => extraSlots < kSjMaxExtraSlots;

  /// Bought continue: one more tray slot.
  bool addTraySlot() {
    if (!canAddSlot) return false;
    extraSlots++;
    trayCapacity++;
    return true;
  }

  /// Unscrew [screw]. Returns null (and changes nothing) if it is not allowed.
  SjMove? tap(int screw) {
    if (!canTap(screw)) return null;
    final m = SjMove(screw);
    removed.add(screw);
    moves++;
    final slot = slotFor(screw);
    if (slot != null) {
      slots[slot]!.screws.add(screw);
      m.boxSlot = slot;
    } else {
      tray.add(screw);
      m.trayIndex = tray.length - 1;
    }
    final snapshot = [...tray];
    // Resolve full boxes (cascades when tray screws fill the new box).
    var changed = true;
    while (changed) {
      changed = false;
      for (var i = 0; i < slots.length; i++) {
        final b = slots[i];
        if (b == null || !b.full) continue;
        m.completed.add((i, b.color, b.queueIndex, [...b.screws]));
        final q = level.boxQueue;
        if (nextBox < q.length) {
          final nb = SjBox(nextBox, q[nextBox]);
          nextBox++;
          slots[i] = nb;
          for (final t in [...tray]) {
            if (nb.full) break;
            if (level.screws[t].color == nb.color) {
              tray.remove(t);
              nb.screws.add(t);
              m.fromTray.add((t, snapshot.indexOf(t), i, m.completed.length - 1));
            }
          }
        } else {
          slots[i] = null;
        }
        changed = true;
      }
    }
    // Plates with no screws left fall off.
    final p = level.screws[screw].plate;
    if (level.plateScrews[p].every(removed.contains) && fallen.add(p)) m.fallen.add(p);
    if (tray.length > peakTray) peakTray = tray.length;
    return m;
  }

  /// State signature for the solver.
  String get key {
    final sb = StringBuffer();
    final ids = removed.toList()..sort();
    sb.write(ids.join(','));
    sb.write('|');
    final tc = [for (final t in tray) level.screws[t].color]..sort();
    sb.write(tc.join(','));
    sb.write('|$nextBox|');
    for (final b in slots) {
      sb.write(b == null ? '-' : '${b.queueIndex}:${b.screws.length}');
      sb.write(';');
    }
    return sb.toString();
  }
}

/// Stars: 3 by default, minus one for using a continue, minus one if the tray
/// came within one slot of being full. Always at least 1.
int sjStars({required int peakTray, required int trayCapacity, required int continues}) {
  var s = 3;
  if (continues > 0) s--;
  if (peakTray >= trayCapacity - 1) s--;
  return s.clamp(1, 3);
}

/// Depth-first solver with memo; prefers taps that go straight into a box.
/// Returns a winning tap order from [start], or null if none was found
/// within [maxNodes].
List<int>? sjSolve(SjGame start, {int maxNodes = 200000}) {
  final seen = <String>{};
  final path = <int>[];
  var nodes = 0;
  bool dfs(SjGame s) {
    if (s.won) return true;
    if (s.lost) return false;
    if (++nodes > maxNodes) return false;
    if (!seen.add(s.key)) return false;
    final moves = s.removable.toList();
    final toBox = [for (final m in moves) if (s.slotFor(m) != null) m];
    final toTray = [for (final m in moves) if (s.slotFor(m) == null) m];
    // Try only one tray move per color (they are equivalent for the rules
    // except for which plate they free up, so keep them all but box first).
    for (final m in [...toBox, ...toTray]) {
      final c = s.clone()..tap(m);
      path.add(m);
      if (dfs(c)) return true;
      path.removeLast();
      if (nodes > maxNodes) return false;
    }
    return false;
  }

  return dfs(start.clone()) ? path : null;
}

/// A good next tap for the hint button: the first step of a solution if the
/// solver finds one quickly, else an exposed screw that fits a box, else any
/// exposed screw.
int? sjHint(SjGame g, {int maxNodes = 6000}) {
  if (g.over) return null;
  final sol = sjSolve(g, maxNodes: maxNodes);
  if (sol != null && sol.isNotEmpty) return sol.first;
  final moves = g.removable.toList();
  if (moves.isEmpty) return null;
  for (final m in moves) {
    if (g.slotFor(m) != null) return m;
  }
  return moves.first;
}

/// Small deterministic PRNG (mulberry32) so levels never change between
/// Dart versions.
class _Rng {
  _Rng(int seed) : _s = seed & 0xFFFFFFFF;
  int _s;
  int nextInt(int max) {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t ^= (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF)) & 0xFFFFFFFF;
    t = (t ^ (t >> 14)) & 0xFFFFFFFF;
    return t % max;
  }

  int range(int a, int b) => a + nextInt(b - a + 1);
  bool chance(int percent) => nextInt(100) < percent;
  void shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

final Map<String, SjLevel> _cache = {};

/// Deterministic, guaranteed-solvable level [level] (1-based) of [tier].
SjLevel sjGenerate(SjTier tier, int level) {
  final n = level.clamp(1, kSjLevels);
  return _cache.putIfAbsent('${tier.id}-$n', () => _build(tier, n));
}

SjLevel _build(SjTier tier, int level) {
  final spec = sjSpec(tier);
  final rng = _Rng(0x5C3E + tier.index * 100003 + level * 7919);
  final cols = spec.cols, rows = spec.rows;
  final plateCount = sjPlatesFor(tier, level);
  final colors = sjColorsFor(tier, level);

  final plates = <SjPlate>[];
  final screws = <SjScrew>[];
  final used = <int>{}; // r * 100 + c of every screw
  int cellKey(int c, int r) => r * 100 + c;

  // Anchor cells (extremities) of a shape where screws look natural.
  List<(int, int)> anchors(List<SjRect> parts) {
    final out = <(int, int)>[];
    void add(int c, int r) {
      if (!out.contains((c, r))) out.add((c, r));
    }

    for (final p in parts) {
      add(p.c, p.r);
      add(p.c + p.w - 1, p.r + p.h - 1);
      add(p.c + p.w - 1, p.r);
      add(p.c, p.r + p.h - 1);
    }
    return out;
  }

  List<SjRect> randomShape() {
    final kind = rng.nextInt(level < 4 && tier == SjTier.easy ? 3 : 4);
    switch (kind) {
      case 0: // horizontal bar
        final w = rng.range(3, cols - 1 < 5 ? cols - 1 : 5);
        return [SjRect(rng.range(0, cols - w), rng.range(0, rows - 1), w, 1)];
      case 1: // vertical bar
        final h = rng.range(3, rows - 2 < 5 ? rows - 2 : 5);
        return [SjRect(rng.range(0, cols - 1), rng.range(0, rows - h), 1, h)];
      case 2: // rectangle
        final w = rng.range(2, 3), h = rng.range(2, 3);
        return [SjRect(rng.range(0, cols - w), rng.range(0, rows - h), w, h)];
      default: // L shape: arm along a row + arm along a column sharing a corner
        final w = rng.range(2, 4), h = rng.range(3, 4);
        final c = rng.range(0, cols - w), r = rng.range(0, rows - h);
        final top = rng.chance(50), left = rng.chance(50);
        final hr = top ? r : r + h - 1;
        final vc = left ? c : c + w - 1;
        return [SjRect(c, hr, w, 1), SjRect(vc, r, 1, h)];
    }
  }

  bool overlapsAny(List<SjRect> parts) {
    final tmp = SjPlate(id: -1, parts: parts, material: 0, tint: 0);
    for (final (c, r) in tmp.cells) {
      for (final p in plates) {
        if (p.covers(c, r)) return true;
      }
    }
    return false;
  }

  var lastTint = -1;
  for (var i = 0; i < plateCount; i++) {
    for (var attempt = 0; attempt < 80; attempt++) {
      final parts = randomShape();
      // Keep the pile together: most plates overlap something below.
      if (plates.isNotEmpty && attempt < 60 && !overlapsAny(parts) && !rng.chance(25)) continue;
      final tmp = SjPlate(id: -1, parts: parts, material: 0, tint: 0);
      final free = [for (final a in anchors(parts)) if (!used.contains(cellKey(a.$1, a.$2))) a];
      final cells = tmp.cells.length;
      if (free.isEmpty) continue;
      final want = cells <= 3 ? 2 : (cells >= 6 ? rng.range(2, 4) : rng.range(2, 3));
      rng.shuffle(free);
      final pick = free.take(want).toList();
      var tint = rng.nextInt(6);
      if (tint == lastTint) tint = (tint + 1) % 6;
      lastTint = tint;
      final plate = SjPlate(id: plates.length, parts: parts, material: rng.chance(35) ? 1 : 0, tint: tint);
      plates.add(plate);
      for (final (c, r) in pick) {
        used.add(cellKey(c, r));
        screws.add(SjScrew(id: screws.length, plate: plate.id, c: c, r: r, color: 0));
      }
      break;
    }
  }

  // Total screws must fill whole boxes.
  var guard = 0;
  while (screws.length % kSjBoxSize != 0 && guard++ < 200) {
    final p = plates[rng.nextInt(plates.length)];
    final free = [for (final cell in p.cells) if (!used.contains(cellKey(cell.$1, cell.$2))) cell];
    final count = screws.where((s) => s.plate == p.id).length;
    if (free.isNotEmpty && count < 4) {
      final (c, r) = free[rng.nextInt(free.length)];
      used.add(cellKey(c, r));
      screws.add(SjScrew(id: screws.length, plate: p.id, c: c, r: r, color: 0));
    } else if (count >= 2) {
      final s = screws.lastWhere((s) => s.plate == p.id);
      used.remove(cellKey(s.c, s.r));
      screws.remove(s);
    }
  }
  // Re-number screws (removals may have left gaps).
  final ordered = [for (var i = 0; i < screws.length; i++) SjScrew(id: i, plate: screws[i].plate, c: screws[i].c, r: screws[i].r, color: 0)];

  // Build a removal order by simulating random legal taps (plates fall when
  // empty). Coloring that order in chunks of 3 = the box queue makes this
  // order a winning line that never even touches the tray.
  final tmpLevel = SjLevel(
    tier: tier,
    number: level,
    cols: cols,
    rows: rows,
    plates: plates,
    screws: ordered,
    boxQueue: const [],
    trayCapacity: spec.tray,
    colorCount: colors,
    solution: const [],
  );
  final removed = <int>{};
  final fallen = <int>{};
  final order = <int>[];
  while (order.length < ordered.length) {
    final open = [
      for (final s in ordered)
        if (!removed.contains(s.id) && tmpLevel.coverers[s.id].every(fallen.contains)) s.id,
    ];
    final pick = open[rng.nextInt(open.length)];
    order.add(pick);
    removed.add(pick);
    final p = ordered[pick].plate;
    if (tmpLevel.plateScrews[p].every(removed.contains)) fallen.add(p);
  }

  final chunks = ordered.length ~/ kSjBoxSize;
  final perm = [for (var i = 0; i < colors; i++) i];
  rng.shuffle(perm);
  final queue = <int>[];
  for (var i = 0; i < chunks; i++) {
    if (i < colors) {
      queue.add(perm[i]);
    } else {
      var c = rng.nextInt(colors);
      if (colors > 1 && c == queue.last) c = (c + 1 + rng.nextInt(colors - 1)) % colors;
      queue.add(c);
    }
  }
  for (var i = 0; i < order.length; i++) {
    ordered[order[i]].color = queue[i ~/ kSjBoxSize];
  }

  return SjLevel(
    tier: tier,
    number: level,
    cols: cols,
    rows: rows,
    plates: plates,
    screws: ordered,
    boxQueue: queue,
    trayCapacity: spec.tray,
    colorCount: colors,
    solution: order,
  );
}
