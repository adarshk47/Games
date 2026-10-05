// Pure-Dart rules, generator and solver for Parking Jam.
import 'dart:math' as math;

/// Difficulty tiers.
enum PjTier {
  easy('easy'),
  medium('medium'),
  hard('hard'),
  extreme('extreme');

  const PjTier(this.id);
  final String id;

  static PjTier fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => easy);
}

/// Levels per tier.
const kPjLevels = 30;

/// Extra moves granted by the "extra life" continue offer.
const kPjExtraMoves = 5;

/// Free hints per level before the paid offer.
const kPjFreeHints = 2;

/// Number of distinct car colors the UI can draw.
const kPjColors = 8;

/// A car (length 2) or truck / bus (length 3). [row]/[col] is the top-left cell.
/// [facing] is +1 when the nose points toward increasing col (right) / row (down),
/// -1 toward decreasing col (left) / row (up).
class Vehicle {
  Vehicle({
    required this.id,
    required this.row,
    required this.col,
    required this.length,
    required this.horizontal,
    required this.facing,
    this.color = 0,
  }) : assert(facing == 1 || facing == -1);

  final int id;
  int row, col;
  final int length;
  final bool horizontal;
  final int facing;
  final int color;

  Vehicle copy() =>
      Vehicle(id: id, row: row, col: col, length: length, horizontal: horizontal, facing: facing, color: color);

  /// Cells covered, as (row, col).
  List<(int, int)> get cells => [
        for (var k = 0; k < length; k++) horizontal ? (row, col + k) : (row + k, col),
      ];

  @override
  String toString() => 'V$id(${horizontal ? 'H' : 'V'}$length @$row,$col f$facing)';
}

/// Outcome of driving a vehicle.
class MoveResult {
  const MoveResult({required this.id, required this.dir, required this.distance, required this.exited, this.blocker});
  final int id;

  /// +1 forward (nose first), -1 reverse.
  final int dir;

  /// Cells travelled inside the lot (to the edge when [exited]).
  final int distance;
  final bool exited;

  /// Id of the vehicle hit, [kObstacle] for a cone, null when it exited.
  final int? blocker;

  /// True if anything changed (counts as a move).
  bool get moved => exited || distance > 0;

  static const kObstacle = -2;
}

/// Board state. Obstacles are cell indices (row * size + col).
class ParkingState {
  ParkingState({required this.size, required this.vehicles, Set<int>? obstacles, this.moves = 0})
      : obstacles = obstacles ?? <int>{};

  final int size;
  final List<Vehicle> vehicles;
  final Set<int> obstacles;
  int moves;

  ParkingState clone() => ParkingState(
        size: size,
        vehicles: [for (final v in vehicles) v.copy()],
        obstacles: {...obstacles},
        moves: moves,
      );

  bool get isSolved => vehicles.isEmpty;

  Vehicle? byId(int id) {
    for (final v in vehicles) {
      if (v.id == id) return v;
    }
    return null;
  }

  /// -1 empty, -2 obstacle, otherwise the vehicle id.
  List<int> grid() {
    final g = List<int>.filled(size * size, -1);
    for (final o in obstacles) {
      g[o] = MoveResult.kObstacle;
    }
    for (final v in vehicles) {
      for (final (r, c) in v.cells) {
        g[r * size + c] = v.id;
      }
    }
    return g;
  }

  /// Simulates a drive without changing the state.
  MoveResult probe(int id, int dir, [List<int>? g]) {
    final v = byId(id);
    if (v == null) return MoveResult(id: id, dir: dir, distance: 0, exited: false);
    g ??= grid();
    final s = v.facing * dir; // step along the axis
    final start = v.horizontal ? v.col : v.row;
    final fixed = v.horizontal ? v.row : v.col;
    var pos = s > 0 ? start + v.length : start - 1;
    var k = 0;
    while (true) {
      if (pos < 0 || pos >= size) return MoveResult(id: id, dir: dir, distance: k, exited: true);
      final cell = v.horizontal ? fixed * size + pos : pos * size + fixed;
      final o = g[cell];
      if (o != -1) return MoveResult(id: id, dir: dir, distance: k, exited: false, blocker: o);
      k++;
      pos += s;
    }
  }

  bool canExit(int id, [int dir = 1, List<int>? g]) => probe(id, dir, g).exited;

  /// Drives vehicle [id] forward (dir = 1) or in reverse (dir = -1) until it
  /// hits something or leaves the lot. Counts a move if it moved at all.
  MoveResult move(int id, [int dir = 1]) {
    final r = probe(id, dir);
    final v = byId(id);
    if (v == null) return r;
    if (r.exited) {
      vehicles.remove(v);
    } else if (r.distance > 0) {
      final d = r.distance * v.facing * dir;
      if (v.horizontal) {
        v.col += d;
      } else {
        v.row += d;
      }
    }
    if (r.moved) moves++;
    return r;
  }

  /// A vehicle that can leave right now, preferring forward exits.
  /// Returns (id, dir) or null when nothing can exit.
  (int, int)? exitHint() {
    final g = grid();
    for (final v in vehicles) {
      if (canExit(v.id, 1, g)) return (v.id, 1);
    }
    for (final v in vehicles) {
      if (canExit(v.id, -1, g)) return (v.id, -1);
    }
    return null;
  }
}

/// Greedy exits-only solver: removing a vehicle only frees cells, so exiting
/// any vehicle that can leave is always safe. Returns the exit order as
/// (id, dir) or null if the lot gets stuck. Set [forwardOnly] to only drive
/// vehicles nose first (taps).
List<(int, int)>? greedySolve(ParkingState s, {bool forwardOnly = false}) {
  final st = s.clone();
  final out = <(int, int)>[];
  while (st.vehicles.isNotEmpty) {
    final g = st.grid();
    (int, int)? pick;
    for (final v in st.vehicles) {
      if (st.canExit(v.id, 1, g)) {
        pick = (v.id, 1);
        break;
      }
    }
    if (pick == null && !forwardOnly) {
      for (final v in st.vehicles) {
        if (st.canExit(v.id, -1, g)) {
          pick = (v.id, -1);
          break;
        }
      }
    }
    if (pick == null) return null;
    st.move(pick.$1, pick.$2);
    out.add(pick);
  }
  return out;
}

/// A generated level: start state, a guaranteed (tap-only) solution and limits.
class PjLevel {
  PjLevel({required this.tier, required this.level, required this.state, required this.solution, this.moveLimit});
  final PjTier tier;
  final int level;
  final ParkingState state;

  /// Vehicle ids in exit order, each driven forward.
  final List<int> solution;

  /// Null = unlimited.
  final int? moveLimit;

  /// Every vehicle must leave, and one exit is one move.
  int get par => solution.length;
}

/// Tier configuration for [level] (1-based).
class PjConfig {
  const PjConfig({
    required this.size,
    required this.vehicles,
    required this.truckChance,
    required this.obstacles,
    required this.blockWeight,
    required this.limitSlack,
  });
  final int size;
  final int vehicles;
  final double truckChance;
  final int obstacles;
  final double blockWeight;

  /// Extra moves over par, or null for no limit.
  final int? Function(int par) limitSlack;

  static PjConfig of(PjTier t, int level) {
    final l = level.clamp(1, kPjLevels);
    final p = (l - 1) / (kPjLevels - 1); // 0..1 progress
    switch (t) {
      case PjTier.easy:
        return PjConfig(
            size: 6,
            vehicles: 5 + (p * 5).round(),
            truckChance: 0.15,
            obstacles: 0,
            blockWeight: 1,
            limitSlack: (_) => null);
      case PjTier.medium:
        return PjConfig(
            size: 7,
            vehicles: 9 + (p * 5).round(),
            truckChance: 0.25,
            obstacles: l < 6 ? 0 : 1 + (p * 2).round(),
            blockWeight: 2,
            limitSlack: (par) => par ~/ 2 + 3);
      case PjTier.hard:
        return PjConfig(
            size: l <= 15 ? 8 : 9,
            vehicles: (l <= 15 ? 13 : 17) + (p * 6).round(),
            truckChance: 0.3,
            obstacles: 2 + (p * 2).round(),
            blockWeight: 3,
            limitSlack: (par) => l <= 15 ? 4 : 3);
      case PjTier.extreme:
        return PjConfig(
            size: l <= 10 ? 9 : 10,
            vehicles: (l <= 10 ? 19 : 23) + (p * 7).round(),
            truckChance: 0.35,
            obstacles: 3 + (p * 3).round(),
            blockWeight: 4,
            limitSlack: (par) => 2);
    }
  }
}

/// Small deterministic xorshift RNG (identical on every platform).
class _Rng {
  _Rng(int seed) : _s = (seed & 0x7fffffff) == 0 ? 0x2545F491 : (seed & 0x7fffffff);
  int _s;

  int next() {
    var x = _s;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _s = x & 0xFFFFFFFF;
    return _s;
  }

  int nextInt(int n) => next() % n;
  double nextDouble() => next() / 4294967296.0;
}

class _Cand {
  _Cand(this.row, this.col, this.length, this.horizontal, this.facing, this.weight);
  final int row, col, length, facing;
  final bool horizontal;
  final double weight;
}

final Map<String, PjLevel> _cache = {};

/// Deterministic level for [tier] + [level]. Built by reverse insertion: each
/// new vehicle is placed with a clear forward path to the edge given the
/// vehicles already placed, so exiting them in reverse placement order (all
/// taps) always clears the lot. The returned state is a fresh copy.
PjLevel generateLevel(PjTier tier, int level) {
  final key = '${tier.id}-$level';
  final cached = _cache[key] ??= _generate(tier, level);
  return PjLevel(
    tier: cached.tier,
    level: cached.level,
    state: cached.state.clone(),
    solution: cached.solution,
    moveLimit: cached.moveLimit,
  );
}

/// Number of "waves" when every vehicle that can leave (forward) leaves at
/// once: 1 means nothing blocks anything. Higher is harder.
int pjDepth(ParkingState s) {
  final st = s.clone();
  var depth = 0;
  while (st.vehicles.isNotEmpty) {
    final g = st.grid();
    final out = [for (final v in st.vehicles) if (st.canExit(v.id, 1, g)) v.id];
    if (out.isEmpty) return -1;
    st.vehicles.removeWhere((v) => out.contains(v.id));
    depth++;
  }
  return depth;
}

/// Tries several seeds and keeps the densest / deepest lot.
PjLevel _generate(PjTier tier, int level) {
  PjLevel? best;
  var bestScore = -1.0;
  for (var attempt = 0; attempt < 8; attempt++) {
    final lv = _generateOnce(tier, level, attempt);
    final depth = pjDepth(lv.state);
    final score = lv.state.vehicles.length + depth * 2.5;
    if (score > bestScore) {
      bestScore = score;
      best = lv;
    }
  }
  return best!;
}

PjLevel _generateOnce(PjTier tier, int level, int attempt) {
  final cfg = PjConfig.of(tier, level);
  final rng = _Rng((tier.index + 1) * 7919 + level * 104729 + attempt * 15485863 + 9973);
  final n = cfg.size;
  final obstacles = <int>{};
  // Cones go in the interior so lanes along the edge stay usable.
  var guard = 0;
  while (obstacles.length < cfg.obstacles && guard++ < 200) {
    final r = 1 + rng.nextInt(n - 2), c = 1 + rng.nextInt(n - 2);
    obstacles.add(r * n + c);
  }
  final st = ParkingState(size: n, vehicles: [], obstacles: obstacles);
  final placed = <Vehicle>[];
  var nextId = 0;
  var lastColor = -1;

  while (placed.length < cfg.vehicles) {
    final g = st.grid();
    final wantTruck = rng.nextDouble() < cfg.truckChance;
    var cands = _candidates(st, g, wantTruck ? 3 : 2, placed, cfg.blockWeight);
    if (cands.isEmpty) cands = _candidates(st, g, wantTruck ? 2 : 3, placed, cfg.blockWeight);
    if (cands.isEmpty) break;
    final total = cands.fold<double>(0, (a, c) => a + c.weight);
    var pick = rng.nextDouble() * total;
    var chosen = cands.last;
    for (final c in cands) {
      pick -= c.weight;
      if (pick <= 0) {
        chosen = c;
        break;
      }
    }
    var color = rng.nextInt(kPjColors);
    if (color == lastColor) color = (color + 1) % kPjColors;
    lastColor = color;
    final v = Vehicle(
      id: nextId++,
      row: chosen.row,
      col: chosen.col,
      length: chosen.length,
      horizontal: chosen.horizontal,
      facing: chosen.facing,
      color: color,
    );
    st.vehicles.add(v);
    placed.add(v);
  }
  final solution = [for (var i = placed.length - 1; i >= 0; i--) placed[i].id];
  final slack = cfg.limitSlack(solution.length);
  return PjLevel(
    tier: tier,
    level: level,
    state: st,
    solution: solution,
    moveLimit: slack == null ? null : solution.length + slack,
  );
}

List<_Cand> _candidates(ParkingState st, List<int> g, int len, List<Vehicle> placed, double blockWeight) {
  final n = st.size;
  // Cells on each placed vehicle's forward path (what a new vehicle would block).
  final pathOf = <int, int>{};
  for (final v in placed) {
    final s = v.facing;
    final start = v.horizontal ? v.col : v.row;
    final fixed = v.horizontal ? v.row : v.col;
    for (var pos = s > 0 ? start + v.length : start - 1; pos >= 0 && pos < n; pos += s) {
      final cell = v.horizontal ? fixed * n + pos : pos * n + fixed;
      pathOf[cell] = (pathOf[cell] ?? 0) + 1;
    }
  }
  final out = <_Cand>[];
  for (final horizontal in const [true, false]) {
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        final endR = horizontal ? r : r + len - 1;
        final endC = horizontal ? c + len - 1 : c;
        if (endR >= n || endC >= n) continue;
        var free = true;
        var blocks = 0;
        for (var k = 0; k < len; k++) {
          final cell = horizontal ? r * n + c + k : (r + k) * n + c;
          if (g[cell] != -1) {
            free = false;
            break;
          }
          blocks += pathOf[cell] ?? 0;
        }
        if (!free) continue;
        for (final facing in const [1, -1]) {
          if (!_clearToEdge(g, n, r, c, len, horizontal, facing)) continue;
          // Prefer spots that block earlier vehicles: deeper dependency chains.
          out.add(_Cand(r, c, len, horizontal, facing, 1 + blockWeight * math.min(blocks, 4)));
        }
      }
    }
  }
  return out;
}

bool _clearToEdge(List<int> g, int n, int r, int c, int len, bool horizontal, int facing) {
  final start = horizontal ? c : r;
  final fixed = horizontal ? r : c;
  for (var pos = facing > 0 ? start + len : start - 1; pos >= 0 && pos < n; pos += facing) {
    final cell = horizontal ? fixed * n + pos : pos * n + fixed;
    if (g[cell] != -1) return false;
  }
  return true;
}

/// Stars for finishing in [moves] with the given [par].
int pjStars(int moves, int par) {
  if (moves <= par) return 3;
  if (moves <= par + math.max(2, (par * 0.3).ceil())) return 2;
  return 1;
}
