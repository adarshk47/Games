/// Pure-Dart rules, level generator and solver for Bus Jam.
///
/// Board model: a [BjLevel.cols] x [BjLevel.rows] grid. Row 0 touches the
/// exit (the bus stop sits above it). Cells hold a passenger, nothing, a wall
/// (obstacle) or a tunnel. A tunnel is a blocked cell with a queue of hidden
/// passengers; whenever the cell in front of it is empty the next one steps
/// out into that cell.
///
/// A passenger can leave when a path of empty cells (4-neighbour BFS) joins
/// their cell to row 0. Leaving passengers board the bus at the stop when it
/// has their color (a bus seats [kBjSeats]), otherwise they take a spot in the
/// waiting area. A full bus departs and the next one in the queue arrives;
/// waiting passengers of its color board it automatically. Every bus gone =
/// win; the waiting area full = lose.
library;

/// Difficulty tiers.
enum BjTier {
  easy,
  medium,
  hard,
  extreme;

  String get id => name;

  static BjTier fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => easy);
}

/// Levels per tier.
const kBjLevels = 100;

/// Seats per bus.
const kBjSeats = 3;

/// How many extra waiting spots can be bought in one level.
const kBjMaxExtraSlots = 3;

/// Number of passenger colors the UI can paint.
const kBjMaxColors = 8;

/// Per-tier generator parameters (value pairs grow from level 1 to 100).
class BjTierSpec {
  const BjTierSpec({
    required this.cols,
    required this.rows,
    required this.colors,
    required this.waiting,
    required this.walls,
    required this.tunnels,
    required this.tunnelLen,
    required this.window,
    required this.shuffle,
    required this.slack,
  });
  final (int, int) cols, rows, colors, walls, tunnels;

  /// Waiting-area spots.
  final int waiting;

  /// Max passengers hidden in one tunnel.
  final int tunnelLen;

  /// How far apart two passengers may be (in the winning order) to swap colors.
  final int window;

  /// Color swaps tried per passenger.
  final int shuffle;

  /// Waiting spots the generated winning line keeps free (peak <= waiting - slack).
  final int slack;
}

BjTierSpec bjSpec(BjTier t) => switch (t) {
      BjTier.easy => const BjTierSpec(
          cols: (5, 6), rows: (6, 7), colors: (3, 4), waiting: 7, walls: (0, 0), tunnels: (0, 0),
          tunnelLen: 0, window: 3, shuffle: 1, slack: 3),
      BjTier.medium => const BjTierSpec(
          cols: (6, 6), rows: (7, 8), colors: (4, 5), waiting: 6, walls: (0, 3), tunnels: (0, 1),
          tunnelLen: 3, window: 6, shuffle: 2, slack: 2),
      BjTier.hard => const BjTierSpec(
          cols: (6, 7), rows: (8, 9), colors: (5, 6), waiting: 6, walls: (2, 5), tunnels: (1, 2),
          tunnelLen: 4, window: 9, shuffle: 3, slack: 2),
      BjTier.extreme => const BjTierSpec(
          cols: (7, 7), rows: (9, 10), colors: (6, 7), waiting: 5, walls: (3, 6), tunnels: (2, 3),
          tunnelLen: 5, window: 12, shuffle: 4, slack: 1),
    };

int _lerp((int, int) ab, int level) {
  final l = level.clamp(1, kBjLevels);
  return ab.$1 + ((ab.$2 - ab.$1) * (l - 1) / (kBjLevels - 1)).round();
}

int bjColorsFor(BjTier t, int level) => _lerp(bjSpec(t).colors, level);

/// Direction offsets: 0 up, 1 right, 2 down, 3 left.
const _dc = [0, 1, 0, -1];
const _dr = [-1, 0, 1, 0];

class BjPassenger {
  const BjPassenger({required this.id, required this.color, this.cell = -1, this.tunnel = -1});
  final int id, color;

  /// Starting cell (r * cols + c), -1 for passengers hidden in a tunnel.
  final int cell;

  /// Tunnel id for hidden passengers, else -1.
  final int tunnel;
}

class BjTunnel {
  const BjTunnel({required this.id, required this.cell, required this.out, required this.dir, required this.queue});
  final int id;

  /// The tunnel's own (blocked) cell and the cell passengers step out into.
  final int cell, out;

  /// Direction from [cell] to [out] (0 up, 1 right, 2 down, 3 left).
  final int dir;

  /// Passenger ids in the order they come out.
  final List<int> queue;
}

class BjLevel {
  BjLevel({
    required this.tier,
    required this.number,
    required this.cols,
    required this.rows,
    required this.walls,
    required this.tunnels,
    required this.passengers,
    required this.buses,
    required this.waiting,
    required this.colorCount,
    required this.solution,
  });
  final BjTier tier;
  final int number, cols, rows;
  final Set<int> walls;
  final List<BjTunnel> tunnels;
  final List<BjPassenger> passengers;

  /// Bus colors in arrival order.
  final List<int> buses;

  /// Waiting-area capacity.
  final int waiting;
  final int colorCount;

  /// A winning tap order (passenger ids).
  final List<int> solution;

  int cellOf(int c, int r) => r * cols + c;
  int colOf(int cell) => cell % cols;
  int rowOf(int cell) => cell ~/ cols;
}

class BjDeparture {
  const BjDeparture(this.bus, this.color, this.riders);
  final int bus, color;
  final List<int> riders;
}

class BjAutoBoard {
  const BjAutoBoard(this.id, this.fromIndex, this.bus);

  /// Passenger, its waiting-area index before the move, bus index boarded.
  final int id, fromIndex, bus;
}

/// Result of a tap.
class BjMove {
  const BjMove({
    required this.id,
    required this.path,
    required this.bus,
    required this.waitIndex,
    required this.departures,
    required this.autoBoard,
    required this.spawned,
  });
  final int id;

  /// Cells walked, from the passenger's cell to a row-0 cell.
  final List<int> path;

  /// Bus index boarded directly, or -1 when the passenger went to waiting.
  final int bus;

  /// Waiting index taken, or -1 when boarded.
  final int waitIndex;
  final List<BjDeparture> departures;
  final List<BjAutoBoard> autoBoard;

  /// (tunnel, passenger) pairs that stepped out of a tunnel.
  final List<(int, int)> spawned;

  bool get boarded => bus >= 0;
}

/// Mutable game state.
class BjGame {
  BjGame(this.level)
      : grid = List.filled(level.cols * level.rows, -1),
        pos = List.filled(level.passengers.length, -1),
        tunnelNext = List.filled(level.tunnels.length, 0),
        capacity = level.waiting {
    for (final w in level.walls) {
      grid[w] = _blocked;
    }
    for (final t in level.tunnels) {
      grid[t.cell] = _blocked;
    }
    for (final p in level.passengers) {
      if (p.cell >= 0) {
        grid[p.cell] = p.id;
        pos[p.id] = p.cell;
      }
    }
    _spawn();
  }

  BjGame._copy(BjGame o)
      : level = o.level,
        grid = List.of(o.grid),
        pos = List.of(o.pos),
        tunnelNext = List.of(o.tunnelNext),
        capacity = o.capacity {
    busIndex = o.busIndex;
    seated.addAll(o.seated);
    waiting.addAll(o.waiting);
    extraSlots = o.extraSlots;
    peakWaiting = o.peakWaiting;
    moves = o.moves;
  }

  static const _blocked = -2;

  final BjLevel level;

  /// Passenger id per cell, -1 empty, -2 wall / tunnel.
  final List<int> grid;

  /// Cell per passenger (-1 when not on the grid).
  final List<int> pos;

  /// Next queue index per tunnel.
  final List<int> tunnelNext;
  int capacity;
  int busIndex = 0;
  final List<int> seated = [];
  final List<int> waiting = [];
  int extraSlots = 0;
  int peakWaiting = 0;
  int moves = 0;

  BjGame clone() => BjGame._copy(this);

  int colorOf(int id) => level.passengers[id].color;
  int get busColor => busIndex < level.buses.length ? level.buses[busIndex] : -1;
  int get busesLeft => level.buses.length - busIndex;
  bool get won => busIndex >= level.buses.length;
  bool get lost => !won && waiting.length >= capacity;
  bool get over => won || lost;
  bool get canAddSlot => extraSlots < kBjMaxExtraSlots;

  bool onGrid(int id) => pos[id] >= 0;

  /// Passengers currently standing on the grid.
  Iterable<int> get crowd sync* {
    for (final v in grid) {
      if (v >= 0) yield v;
    }
  }

  /// Passengers left inside tunnel [t].
  int tunnelLeft(int t) => level.tunnels[t].queue.length - tunnelNext[t];

  /// Shortest walk (cells) from [id] to row 0 through empty cells, or null.
  List<int>? pathFor(int id) {
    final start = pos[id];
    if (start < 0) return null;
    final cols = level.cols, rows = level.rows;
    if (start < cols) return [start];
    final prev = List.filled(grid.length, -2);
    prev[start] = -1;
    final q = <int>[start];
    for (var qi = 0; qi < q.length; qi++) {
      final cur = q[qi];
      final c = cur % cols, r = cur ~/ cols;
      for (var d = 0; d < 4; d++) {
        final nc = c + _dc[d], nr = r + _dr[d];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        final n = nr * cols + nc;
        if (prev[n] != -2 || grid[n] != -1) continue;
        prev[n] = cur;
        if (nr == 0) {
          final out = <int>[];
          for (var x = n; x != -1; x = prev[x]) {
            out.add(x);
          }
          return out.reversed.toList();
        }
        q.add(n);
      }
    }
    return null;
  }

  bool canTap(int id) => !over && pathFor(id) != null;

  /// Every passenger with a way out.
  List<int> get removable {
    final cols = level.cols, rows = level.rows;
    final reach = List.filled(grid.length, false);
    final q = <int>[];
    for (var c = 0; c < cols; c++) {
      if (grid[c] == -1) {
        reach[c] = true;
        q.add(c);
      }
    }
    for (var qi = 0; qi < q.length; qi++) {
      final cur = q[qi];
      final c = cur % cols, r = cur ~/ cols;
      for (var d = 0; d < 4; d++) {
        final nc = c + _dc[d], nr = r + _dr[d];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        final n = nr * cols + nc;
        if (reach[n] || grid[n] != -1) continue;
        reach[n] = true;
        q.add(n);
      }
    }
    final out = <int>[];
    for (var i = 0; i < grid.length; i++) {
      final id = grid[i];
      if (id < 0) continue;
      final c = i % cols, r = i ~/ cols;
      var ok = r == 0;
      for (var d = 0; d < 4 && !ok; d++) {
        final nc = c + _dc[d], nr = r + _dr[d];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        if (reach[nr * cols + nc]) ok = true;
      }
      if (ok) out.add(id);
    }
    return out;
  }

  /// Takes [id] off the grid and lets tunnels refill free cells.
  List<(int, int)> _extract(int id) {
    grid[pos[id]] = -1;
    pos[id] = -1;
    return _spawn();
  }

  List<(int, int)> _spawn() {
    final out = <(int, int)>[];
    for (final t in level.tunnels) {
      if (tunnelNext[t.id] < t.queue.length && grid[t.out] == -1) {
        final p = t.queue[tunnelNext[t.id]++];
        grid[t.out] = p;
        pos[p] = t.out;
        out.add((t.id, p));
      }
    }
    return out;
  }

  /// Taps passenger [id]. Returns null when the tap is not allowed.
  BjMove? tap(int id) {
    if (over || id < 0 || id >= pos.length) return null;
    final path = pathFor(id);
    if (path == null) return null;
    moves++;
    final spawned = _extract(id);
    final before = List.of(waiting);
    final departures = <BjDeparture>[];
    final auto = <BjAutoBoard>[];
    var bus = -1, wi = -1;
    if (colorOf(id) == busColor) {
      bus = busIndex;
      seated.add(id);
      while (!won && seated.length >= kBjSeats) {
        departures.add(BjDeparture(busIndex, busColor, List.of(seated)));
        seated.clear();
        busIndex++;
        if (won) break;
        final c = busColor;
        for (final w in List.of(waiting)) {
          if (seated.length >= kBjSeats) break;
          if (colorOf(w) == c) {
            waiting.remove(w);
            seated.add(w);
            auto.add(BjAutoBoard(w, before.indexOf(w), busIndex));
          }
        }
      }
    } else {
      waiting.add(id);
      wi = waiting.length - 1;
      if (waiting.length > peakWaiting) peakWaiting = waiting.length;
    }
    return BjMove(id: id, path: path, bus: bus, waitIndex: wi, departures: departures, autoBoard: auto, spawned: spawned);
  }

  /// Buys one more waiting spot (after the area filled up).
  void addSlot() {
    if (!canAddSlot) return;
    extraSlots++;
    capacity++;
  }

  /// Memo key: the passengers already off the grid decide the whole state.
  String get key {
    final b = StringBuffer();
    for (var i = 0; i < pos.length; i++) {
      b.write(pos[i] >= 0 ? '1' : (_hiddenInTunnel(i) ? '2' : '0'));
    }
    return b.toString();
  }

  bool _hiddenInTunnel(int id) {
    final t = level.passengers[id].tunnel;
    if (t < 0) return false;
    return level.tunnels[t].queue.indexOf(id) >= tunnelNext[t];
  }
}

/// Stars: 3 by default, minus one for buying an extra spot, minus one if the
/// waiting area came within one spot of being full. Always at least 1.
int bjStars({required int peakWaiting, required int capacity, required int continues}) {
  var s = 3;
  if (continues > 0) s--;
  if (peakWaiting >= capacity - 1) s--;
  return s.clamp(1, 3);
}

/// How soon (in buses from the current one) color [c] is needed.
int _need(BjGame g, int c) {
  for (var i = g.busIndex; i < g.level.buses.length; i++) {
    if (g.level.buses[i] == c) return i - g.busIndex;
  }
  return 1 << 20;
}

/// Depth-first solver with memo; boarding taps first (always safe), then
/// passengers whose bus comes soonest.
List<int>? bjSolve(BjGame start, {int maxNodes = 200000}) {
  final seen = <String>{};
  final path = <int>[];
  var nodes = 0;
  bool dfs(BjGame s) {
    if (s.won) return true;
    if (s.lost) return false;
    if (++nodes > maxNodes) return false;
    if (!seen.add(s.key)) return false;
    final moves = s.removable;
    final board = [for (final m in moves) if (s.colorOf(m) == s.busColor) m];
    final List<int> order;
    if (board.isNotEmpty) {
      order = [board.first];
    } else {
      order = List.of(moves)..sort((a, b) => _need(s, s.colorOf(a)).compareTo(_need(s, s.colorOf(b))));
    }
    for (final m in order) {
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

/// A good next tap: a passenger that boards right away, else the first step
/// of a solution found quickly, else whoever's bus comes soonest.
int? bjHint(BjGame g, {int maxNodes = 3000}) {
  if (g.over) return null;
  final moves = g.removable;
  if (moves.isEmpty) return null;
  for (final m in moves) {
    if (g.colorOf(m) == g.busColor) return m;
  }
  final sol = bjSolve(g, maxNodes: maxNodes);
  if (sol != null && sol.isNotEmpty) return sol.first;
  moves.sort((a, b) => _need(g, g.colorOf(a)).compareTo(_need(g, g.colorOf(b))));
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
  void shuffle<T>(List<T> l) {
    for (var i = l.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final t = l[i];
      l[i] = l[j];
      l[j] = t;
    }
  }
}

final Map<String, BjLevel> _cache = {};

/// Deterministic, guaranteed-solvable level [level] (1-based) of [tier].
BjLevel bjGenerate(BjTier tier, int level) {
  final n = level.clamp(1, kBjLevels);
  return _cache.putIfAbsent('${tier.id}-$n', () => _build(tier, n));
}

/// Peak waiting-area use when passengers of colors [seq] leave in that order
/// and buses come in [buses] order (same rules as [BjGame.tap]).
int _peak(List<int> seq, List<int> buses) {
  final wait = <int>[];
  var bus = 0, seated = 0, peak = 0;
  for (final c in seq) {
    if (bus < buses.length && c == buses[bus]) {
      seated++;
      while (bus < buses.length && seated >= kBjSeats) {
        bus++;
        seated = 0;
        if (bus >= buses.length) break;
        final bc = buses[bus];
        for (var i = 0; i < wait.length && seated < kBjSeats;) {
          if (wait[i] == bc) {
            wait.removeAt(i);
            seated++;
          } else {
            i++;
          }
        }
      }
    } else {
      wait.add(c);
      if (wait.length > peak) peak = wait.length;
    }
  }
  return peak;
}

BjLevel _build(BjTier tier, int level) {
  final spec = bjSpec(tier);
  final rng = _Rng(0xB05 + tier.index * 100003 + level * 7919);
  final cols = _lerp(spec.cols, level), rows = _lerp(spec.rows, level);
  final colors = bjColorsFor(tier, level);
  final wallCount = _lerp(spec.walls, level);
  final tunnelCount = _lerp(spec.tunnels, level);
  final size = cols * rows;

  bool connected(Set<int> blocked) {
    final seen = <int>{};
    final q = <int>[];
    for (var c = 0; c < cols; c++) {
      if (!blocked.contains(c)) {
        seen.add(c);
        q.add(c);
      }
    }
    for (var qi = 0; qi < q.length; qi++) {
      final cur = q[qi];
      final c = cur % cols, r = cur ~/ cols;
      for (var d = 0; d < 4; d++) {
        final nc = c + _dc[d], nr = r + _dr[d];
        if (nc < 0 || nr < 0 || nc >= cols || nr >= rows) continue;
        final n = nr * cols + nc;
        if (blocked.contains(n) || !seen.add(n)) continue;
        q.add(n);
      }
    }
    return seen.length == size - blocked.length;
  }

  // Obstacles (never on the exit row) that keep every cell reachable.
  final walls = <int>{};
  for (var tries = 0; walls.length < wallCount && tries < 200; tries++) {
    final cell = rng.range(cols, size - 1);
    if (walls.contains(cell)) continue;
    walls.add(cell);
    if (!connected(walls)) walls.remove(cell);
  }

  // Tunnels (rows >= 2) facing a free cell.
  final tunnelSpots = <(int, int, int, int)>[]; // cell, out, dir, length
  final outs = <int>{};
  for (var tries = 0; tunnelSpots.length < tunnelCount && tries < 300; tries++) {
    final cell = rng.range(cols * 2, size - 1);
    final c = cell % cols, r = cell ~/ cols;
    final dir = rng.nextInt(4);
    final nc = c + _dc[dir], nr = r + _dr[dir];
    if (nc < 0 || nr < 1 || nc >= cols || nr >= rows) continue;
    final out = nr * cols + nc;
    final blocked = {...walls, for (final t in tunnelSpots) t.$1};
    if (blocked.contains(cell) || blocked.contains(out) || outs.contains(out) || outs.contains(cell)) continue;
    blocked.add(cell);
    if (!connected(blocked)) continue;
    outs.add(out);
    tunnelSpots.add((cell, out, dir, rng.range(2, spec.tunnelLen)));
  }
  final blocked = {...walls, for (final t in tunnelSpots) t.$1};

  // Free cells, trimmed so the passengers fill whole buses.
  final free = [for (var i = 0; i < size; i++) if (!blocked.contains(i)) i];
  final hidden = tunnelSpots.fold<int>(0, (a, t) => a + t.$4);
  final drop = (free.length + hidden) % kBjSeats;
  final dropable = [for (final f in free) if (!outs.contains(f)) f];
  rng.shuffle(dropable);
  final empty = dropable.take(drop).toSet();

  // Passengers with placeholder colors.
  final cells = [for (final f in free) if (!empty.contains(f)) f];
  var ps = <BjPassenger>[for (var i = 0; i < cells.length; i++) BjPassenger(id: i, color: 0, cell: cells[i])];
  final tunnels = <BjTunnel>[];
  for (final (cell, out, dir, len) in tunnelSpots) {
    final ids = <int>[];
    for (var k = 0; k < len; k++) {
      ids.add(ps.length);
      ps.add(BjPassenger(id: ps.length, color: 0, tunnel: tunnels.length));
    }
    tunnels.add(BjTunnel(id: tunnels.length, cell: cell, out: out, dir: dir, queue: ids));
  }
  final n = ps.length;
  final busCount = n ~/ kBjSeats;

  BjLevel make(List<BjPassenger> passengers, List<int> buses, List<int> solution) => BjLevel(
        tier: tier,
        number: level,
        cols: cols,
        rows: rows,
        walls: walls,
        tunnels: tunnels,
        passengers: passengers,
        buses: buses,
        waiting: spec.waiting,
        colorCount: colors,
        solution: solution,
      );

  // A winning removal order: random legal taps (paths only depend on who is
  // still standing, never on colors).
  final sim = BjGame(make(ps, List.filled(busCount, -1), const []));
  final order = <int>[];
  while (order.length < n) {
    final open = sim.removable;
    final pick = open[rng.nextInt(open.length)];
    order.add(pick);
    sim._extract(pick);
  }

  // Bus queue: every color at least once, no color three times in a row.
  final buses = <int>[];
  final perm = [for (var i = 0; i < colors; i++) i];
  rng.shuffle(perm);
  for (var i = 0; i < busCount; i++) {
    if (i < colors) {
      buses.add(perm[i]);
    } else {
      var c = rng.nextInt(colors);
      if (buses.length >= 2 && buses[buses.length - 1] == c && buses[buses.length - 2] == c) c = (c + 1) % colors;
      buses.add(c);
    }
  }
  rng.shuffle(buses);
  for (var i = 2; i < buses.length; i++) {
    if (buses[i] == buses[i - 1] && buses[i] == buses[i - 2]) {
      final j = rng.nextInt(buses.length);
      final t = buses[i];
      buses[i] = buses[j];
      buses[j] = t;
    }
  }

  // Colors in removal order: chunks of 3 match the bus queue (a perfect run),
  // then swaps mix them up while that order still fits in the waiting area.
  final seq = [for (var i = 0; i < n; i++) buses[i ~/ kBjSeats]];
  final limit = spec.waiting - spec.slack;
  final tries = n * spec.shuffle;
  for (var k = 0; k < tries; k++) {
    final i = rng.nextInt(n);
    final j = i + 1 + rng.nextInt(spec.window);
    if (j >= n || seq[i] == seq[j]) continue;
    final t = seq[i];
    seq[i] = seq[j];
    seq[j] = t;
    if (_peak(seq, buses) > limit) {
      seq[j] = seq[i];
      seq[i] = t;
    }
  }
  final colorOf = List.filled(n, 0);
  for (var i = 0; i < n; i++) {
    colorOf[order[i]] = seq[i];
  }
  ps = [for (final p in ps) BjPassenger(id: p.id, color: colorOf[p.id], cell: p.cell, tunnel: p.tunnel)];
  return make(ps, buses, order);
}
