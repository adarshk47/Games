/// Pure-Dart rules, level generator and greedy bot for Hexa Sort.
///
/// Board model: a hex grid in "odd-r" offset layout ([HsBoard.rows] x
/// [HsBoard.cols], odd rows shifted half a cell to the right). The last cell
/// of every odd row is a hole so the board is symmetric. Some cells may be
/// blocked (stone) on harder tiers. Every open cell holds a stack of colored
/// tiles (bottom -> top), possibly empty.
///
/// A move places one of the offered stacks onto an empty open cell. Then the
/// board resolves: stacks next to each other whose top colors match pour
/// their whole top run of that color into one target stack (the stack with
/// most matching neighbours). Revealed tops can match again, so chains
/// happen. When a stack's top run reaches [kHsClearAt] tiles it clears and
/// counts towards the level goal. Reaching the goal wins; a board with no
/// empty cell left (and not yet won) loses.
library;

/// Difficulty tiers.
enum HsTier {
  easy,
  medium,
  hard,
  extreme;

  String get id => name;

  static HsTier fromId(String? id) => values.firstWhere((t) => t.id == id, orElse: () => easy);
}

/// Levels per tier.
const kHsLevels = 100;

/// A top run of this many tiles of one color clears.
const kHsClearAt = 10;

/// Number of offered stacks.
const kHsOffers = 3;

/// Size of the tile palette.
const kHsPalette = 8;

/// Per-tier generator parameters (values at level 1 -> level 100).
class HsTierSpec {
  const HsTierSpec({
    required this.rows,
    required this.cols,
    required this.minColors,
    required this.maxColors,
    required this.minGoal,
    required this.maxGoal,
    required this.minBlocked,
    required this.maxBlocked,
    required this.maxHeight,
    required this.multiRun,
    required this.bias,
    required this.maxPre,
  });
  final int rows, cols, minColors, maxColors, minGoal, maxGoal, minBlocked, maxBlocked, maxHeight, maxPre;

  /// Chance that an offered stack has more than one color run.
  final double multiRun;

  /// Chance that an offered stack's top color is taken from the board.
  final double bias;

  /// Open cells of the shaped board without blocked cells.
  int get cells => rows * cols - rows ~/ 2;
}

HsTierSpec hsSpec(HsTier t) => switch (t) {
      HsTier.easy => const HsTierSpec(
          rows: 5, cols: 4, minColors: 3, maxColors: 4, minGoal: 30, maxGoal: 100,
          minBlocked: 0, maxBlocked: 0, maxHeight: 5, multiRun: 0.5, bias: 0.35, maxPre: 2),
      HsTier.medium => const HsTierSpec(
          rows: 6, cols: 5, minColors: 4, maxColors: 6, minGoal: 60, maxGoal: 180,
          minBlocked: 0, maxBlocked: 1, maxHeight: 6, multiRun: 0.7, bias: 0.18, maxPre: 3),
      HsTier.hard => const HsTierSpec(
          rows: 7, cols: 5, minColors: 5, maxColors: 6, minGoal: 90, maxGoal: 220,
          minBlocked: 1, maxBlocked: 3, maxHeight: 6, multiRun: 0.8, bias: 0.12, maxPre: 4),
      HsTier.extreme => const HsTierSpec(
          rows: 7, cols: 6, minColors: 6, maxColors: 8, minGoal: 120, maxGoal: 280,
          minBlocked: 2, maxBlocked: 5, maxHeight: 7, multiRun: 0.9, bias: 0.05, maxPre: 5),
    };

int _lerp(int a, int b, int level) {
  final l = level.clamp(1, kHsLevels);
  return a + ((b - a) * (l - 1) / (kHsLevels - 1)).round();
}

int hsColorsFor(HsTier t, int level) => _lerp(hsSpec(t).minColors, hsSpec(t).maxColors, level);

/// Small deterministic PRNG (mulberry32), identical on every platform.
class HsRng {
  HsRng(int seed) : _s = seed & 0xFFFFFFFF;
  HsRng._copy(this._s);
  int _s;

  HsRng copy() => HsRng._copy(_s);

  int next() {
    _s = (_s + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _s;
    t = ((t ^ (t >> 15)) * (t | 1)) & 0xFFFFFFFF;
    t = (t ^ (t + (((t ^ (t >> 7)) * (t | 61)) & 0xFFFFFFFF))) & 0xFFFFFFFF;
    return (t ^ (t >> 14)) & 0xFFFFFFFF;
  }

  int nextInt(int n) => n <= 1 ? 0 : next() % n;
  double nextDouble() => next() / 4294967296.0;
}

/// Board geometry: cell index = row * cols + col.
class HsBoard {
  HsBoard({required this.rows, required this.cols, Set<int>? holes, Set<int> blocked = const {}})
      : holes = holes ?? {for (var r = 1; r < rows; r += 2) r * cols + cols - 1},
        blocked = Set.unmodifiable(blocked) {
    neighbors = List.unmodifiable([
      for (var i = 0; i < size; i++)
        isOpen(i) ? List<int>.unmodifiable([for (final n in _adjacent(i)) if (isOpen(n)) n]) : const <int>[],
    ]);
  }

  final int rows, cols;

  /// Positions that are not part of the board at all.
  final Set<int> holes;

  /// Stone cells: drawn but can never hold a stack.
  final Set<int> blocked;

  /// Open neighbours of each cell.
  late final List<List<int>> neighbors;

  int get size => rows * cols;
  int row(int i) => i ~/ cols;
  int col(int i) => i % cols;
  bool isCell(int i) => i >= 0 && i < size && !holes.contains(i);
  bool isOpen(int i) => isCell(i) && !blocked.contains(i);
  Iterable<int> get openCells => [for (var i = 0; i < size; i++) if (isOpen(i)) i];
  Iterable<int> get allCells => [for (var i = 0; i < size; i++) if (isCell(i)) i];

  static const _even = [(0, -1), (0, 1), (-1, -1), (-1, 0), (1, -1), (1, 0)];
  static const _odd = [(0, -1), (0, 1), (-1, 0), (-1, 1), (1, 0), (1, 1)];

  /// Grid neighbours (inside the rectangle) in odd-r layout.
  List<int> _adjacent(int i) {
    final r = row(i), c = col(i);
    return [
      for (final (dr, dc) in r.isOdd ? _odd : _even)
        if (r + dr >= 0 && r + dr < rows && c + dc >= 0 && c + dc < cols) (r + dr) * cols + c + dc,
    ];
  }

  bool adjacent(int a, int b) => neighbors[a].contains(b);
}

/// Length of the top single-color run of [s].
int hsTopRun(List<int> s) {
  if (s.isEmpty) return 0;
  final c = s.last;
  var n = 0;
  for (var i = s.length - 1; i >= 0 && s[i] == c; i--) {
    n++;
  }
  return n;
}

/// Number of color runs in [s].
int hsRuns(List<int> s) {
  var n = 0;
  for (var i = 0; i < s.length; i++) {
    if (i == 0 || s[i] != s[i - 1]) n++;
  }
  return n;
}

enum HsStepKind { transfer, clear }

/// One animation-worthy event of a resolution.
class HsStep {
  const HsStep.transfer(this.from, this.to, this.color, this.count) : kind = HsStepKind.transfer;
  const HsStep.clear(int cell, this.color, this.count)
      : kind = HsStepKind.clear,
        from = cell,
        to = cell;
  final HsStepKind kind;
  final int from, to, color, count;

  /// Applies this step to [stacks] (used by the UI to replay steps).
  void apply(List<List<int>> stacks) {
    if (kind == HsStepKind.transfer) {
      final src = stacks[from];
      src.removeRange(src.length - count, src.length);
      stacks[to].addAll(List.filled(count, color));
    } else {
      final s = stacks[from];
      s.removeRange(s.length - count, s.length);
    }
  }

  @override
  String toString() => kind == HsStepKind.transfer ? 'T($from->$to c$color x$count)' : 'C($from c$color x$count)';
}

/// Resolves the board after [start] changed. Mutates [stacks] and returns the
/// ordered steps. Always terminates: every transfer merges two runs into one
/// and every clear removes a run.
List<HsStep> hsResolve(HsBoard b, List<List<int>> stacks, int start) {
  final steps = <HsStep>[];
  final queue = <int>[start];

  bool matches(int n, int c) => stacks[n].isNotEmpty && stacks[n].last == c;
  int matchCount(int i, int c) => b.neighbors[i].where((n) => matches(n, c)).length;

  bool clearAt(int i) {
    final run = hsTopRun(stacks[i]);
    if (run < kHsClearAt) return false;
    final step = HsStep.clear(i, stacks[i].last, run);
    step.apply(stacks);
    steps.add(step);
    return true;
  }

  void enqueue(int i) {
    if (!queue.contains(i)) queue.add(i);
  }

  if (clearAt(start)) enqueue(start);
  while (queue.isNotEmpty) {
    final x = queue.removeAt(0);
    if (stacks[x].isEmpty) continue;
    final c = stacks[x].last;
    final group = [x, ...b.neighbors[x].where((n) => matches(n, c))];
    if (group.length == 1) continue;

    // Target: most matching neighbours, then a pure stack, then the longest
    // top run, then the cell being processed, then the lowest index.
    var target = x;
    (int, int, int, int, int) key(int i) =>
        (matchCount(i, c), hsRuns(stacks[i]) == 1 ? 1 : 0, hsTopRun(stacks[i]), i == x ? 1 : 0, -i);
    var best = key(x);
    for (final g in group) {
      final k = key(g);
      if (_cmp(k, best) > 0) {
        best = k;
        target = g;
      }
    }
    final sources = [for (final n in b.neighbors[target]) if (matches(n, c)) n];
    for (final src in sources) {
      final step = HsStep.transfer(src, target, c, hsTopRun(stacks[src]));
      step.apply(stacks);
      steps.add(step);
    }
    if (clearAt(target)) queue.insert(0, target);
    for (final src in sources) {
      enqueue(src);
    }
  }
  return steps;
}

int _cmp((int, int, int, int, int) a, (int, int, int, int, int) b) {
  if (a.$1 != b.$1) return a.$1.compareTo(b.$1);
  if (a.$2 != b.$2) return a.$2.compareTo(b.$2);
  if (a.$3 != b.$3) return a.$3.compareTo(b.$3);
  if (a.$4 != b.$4) return a.$4.compareTo(b.$4);
  return a.$5.compareTo(b.$5);
}

/// A level: geometry, palette, goal, starting stacks and dealing seed.
class HsLevel {
  HsLevel({
    required this.tier,
    required this.number,
    required this.board,
    required this.colors,
    required this.goal,
    required this.seed,
    this.initial = const {},
    this.script = const [],
    this.maxHeight = 5,
    this.multiRun = 0.5,
    this.bias = 0.5,
  });

  final HsTier tier;
  final int number;
  final HsBoard board;

  /// Colors used (0 until colors-1).
  final int colors;

  /// Tiles to clear to win.
  final int goal;

  /// Seed of the offered-stack stream.
  final int seed;

  /// Stacks on the board at the start (cell -> bottom..top).
  final Map<int, List<int>> initial;

  /// Offered stacks dealt before the random stream (tutorial / tests).
  final List<List<int>> script;

  final int maxHeight;
  final double multiRun, bias;

  HsLevel withGoal(int g) => HsLevel(
        tier: tier,
        number: number,
        board: board,
        colors: colors,
        goal: g,
        seed: seed,
        initial: initial,
        script: script,
        maxHeight: maxHeight,
        multiRun: multiRun,
        bias: bias,
      );
}

/// Result of one placement.
class HsMove {
  HsMove(this.offer, this.cell, this.stack, this.steps, this.dealt);
  final int offer, cell;
  final List<int> stack;
  final List<HsStep> steps;

  /// True when the placement used the last offer and a new set was dealt.
  final bool dealt;

  int get cleared => steps.where((s) => s.kind == HsStepKind.clear).fold(0, (a, s) => a + s.count);
  int get clears => steps.where((s) => s.kind == HsStepKind.clear).length;
}

/// Mutable game state.
class HsGame {
  HsGame(this.level)
      : stacks = [for (var i = 0; i < level.board.size; i++) List<int>.of(level.initial[i] ?? const [])],
        offers = List.filled(kHsOffers, null),
        _rng = HsRng(level.seed ^ 0x7F4A7C15) {
    _deal();
  }

  HsGame._clone(HsGame g)
      : level = g.level,
        stacks = [for (final s in g.stacks) List<int>.of(s)],
        offers = [for (final o in g.offers) o == null ? null : List<int>.of(o)],
        _rng = g._rng.copy(),
        _script = g._script,
        cleared = g.cleared,
        moves = g.moves,
        continues = g.continues,
        refreshes = g.refreshes;

  final HsLevel level;
  final List<List<int>> stacks;
  final List<List<int>?> offers;
  final HsRng _rng;
  int _script = 0;
  int cleared = 0;
  int moves = 0;
  int continues = 0;
  int refreshes = 0;

  HsBoard get board => level.board;
  HsGame clone() => HsGame._clone(this);

  bool get won => cleared >= level.goal;
  List<int> get emptyCells => [for (final i in board.openCells) if (stacks[i].isEmpty) i];
  bool get lost => !won && emptyCells.isEmpty;
  bool get over => won || lost;
  int get goalLeft => (level.goal - cleared).clamp(0, level.goal);

  /// Fraction of open cells holding a stack.
  double get fill {
    final open = board.openCells.length;
    return open == 0 ? 1 : (open - emptyCells.length) / open;
  }

  bool canPlace(int offer, int cell) =>
      !over && offer >= 0 && offer < kHsOffers && offers[offer] != null && board.isOpen(cell) && stacks[cell].isEmpty;

  /// Places offer [offer] on [cell] and resolves. Null when illegal.
  HsMove? place(int offer, int cell) {
    if (!canPlace(offer, cell)) return null;
    final stack = offers[offer]!;
    offers[offer] = null;
    stacks[cell].addAll(stack);
    moves++;
    final steps = hsResolve(board, stacks, cell);
    for (final s in steps) {
      if (s.kind == HsStepKind.clear) cleared += s.count;
    }
    var dealt = false;
    if (offers.every((o) => o == null)) {
      _deal();
      dealt = true;
    }
    return HsMove(offer, cell, stack, steps, dealt);
  }

  /// Booster: replaces all offered stacks with fresh ones.
  void refreshOffers() {
    refreshes++;
    for (var i = 0; i < kHsOffers; i++) {
      offers[i] = _makeStack();
    }
  }

  /// Booster after the board filled up: removes the [k] messiest stacks.
  /// Returns the emptied cells.
  List<int> revive([int k = 4]) {
    final filled = [for (final i in board.openCells) if (stacks[i].isNotEmpty) i];
    filled.sort((a, b) {
      final r = hsRuns(stacks[b]).compareTo(hsRuns(stacks[a]));
      if (r != 0) return r;
      final h = stacks[b].length.compareTo(stacks[a].length);
      return h != 0 ? h : a.compareTo(b);
    });
    final out = filled.take(k).toList()..sort();
    for (final i in out) {
      stacks[i].clear();
    }
    continues++;
    return out;
  }

  void _deal() {
    for (var i = 0; i < kHsOffers; i++) {
      if (_script < level.script.length) {
        offers[i] = List<int>.of(level.script[_script++]);
      } else {
        offers[i] = _makeStack();
      }
    }
  }

  List<int> _makeStack() {
    final r = _rng;
    final maxH = level.maxHeight;
    final h = 2 + r.nextInt(maxH - 1);
    var runs = 1;
    if (h >= 3 && r.nextDouble() < level.multiRun) runs = 2;
    if (runs == 2 && h >= 5 && level.colors >= 5 && r.nextDouble() < 0.3) runs = 3;
    // Split h into run lengths, top run first.
    final lens = List.filled(runs, 1);
    for (var left = h - runs; left > 0; left--) {
      lens[r.nextInt(runs)]++;
    }
    final tops = {for (final s in stacks) if (s.isNotEmpty) s.last}.toList()..sort();
    final colors = <int>[];
    for (var k = 0; k < runs; k++) {
      int c;
      if (k == 0 && tops.isNotEmpty && r.nextDouble() < level.bias) {
        c = tops[r.nextInt(tops.length)];
      } else {
        c = r.nextInt(level.colors);
        if (k > 0 && c == colors[k - 1]) c = (c + 1 + r.nextInt(level.colors - 1)) % level.colors;
      }
      colors.add(c);
    }
    final out = <int>[];
    for (var k = runs - 1; k >= 0; k--) {
      out.addAll(List.filled(lens[k], colors[k]));
    }
    return out;
  }
}

/// Stars for a win: by how full the board was, minus one per continue.
int hsStars({required double fill, required int continues}) {
  final base = fill <= 0.5 ? 3 : (fill <= 0.75 ? 2 : 1);
  return (base - continues).clamp(1, 3);
}

// ---------------------------------------------------------------------------
// Greedy bot

/// Heuristic value of a position (higher is better).
double _value(HsGame g) {
  var v = g.cleared * 12.0;
  for (final i in g.board.openCells) {
    final s = g.stacks[i];
    if (s.isEmpty) {
      v += 6;
      continue;
    }
    final top = hsTopRun(s);
    v += top * top * 0.6 - hsRuns(s) * 4;
    // Mismatched neighbours with a different top are mildly bad.
    for (final n in g.board.neighbors[i]) {
      if (g.stacks[n].isNotEmpty && g.stacks[n].last != s.last) v -= 0.5;
    }
  }
  return v;
}

/// Best greedy placement, or null when there is none.
({int offer, int cell})? hsBestMove(HsGame g) {
  ({int offer, int cell})? best;
  var bestV = double.negativeInfinity;
  final empty = g.emptyCells;
  for (var o = 0; o < kHsOffers; o++) {
    if (g.offers[o] == null) continue;
    for (final cell in empty) {
      final sim = g.clone();
      sim.place(o, cell);
      var v = _value(sim);
      if (sim.won) v += 100000;
      if (sim.lost) v -= 100000;
      if (v > bestV) {
        bestV = v;
        best = (offer: o, cell: cell);
      }
    }
  }
  return best;
}

/// Plays [level] greedily. Returns whether it won and the moves used.
({bool won, int moves}) hsGreedyPlay(HsLevel level, {int maxMoves = 400}) {
  final g = HsGame(level);
  while (!g.over && g.moves < maxMoves) {
    final m = hsBestMove(g);
    if (m == null) break;
    g.place(m.offer, m.cell);
  }
  return (won: g.won, moves: g.moves);
}

/// Move budget the bot must win within for a level to count as fair.
int hsBotBudget(int goal) => goal ~/ 2 + 30;

// ---------------------------------------------------------------------------
// Generator

final Map<(HsTier, int), HsLevel> _cache = {};

/// Deterministic level [level] (1..[kHsLevels]) of tier [t]. Easy and Medium
/// levels are verified winnable by the greedy bot (the goal is eased when a
/// seed proves too hard).
HsLevel hsGenerate(HsTier t, int level) {
  final n = level.clamp(1, kHsLevels);
  return _cache[(t, n)] ??= _generate(t, n);
}

HsLevel _generate(HsTier t, int n) {
  final verify = t == HsTier.easy || t == HsTier.medium;
  HsLevel? first;
  for (var attempt = 0; attempt < 8; attempt++) {
    final lv = _build(t, n, attempt);
    first ??= lv;
    if (!verify) return lv;
    if (hsGreedyPlay(lv, maxMoves: hsBotBudget(lv.goal)).won) return lv;
  }
  // Ease the goal until the bot wins on the first seed.
  var lv = first!;
  while (lv.goal > 20) {
    lv = lv.withGoal(lv.goal - 10);
    if (hsGreedyPlay(lv, maxMoves: hsBotBudget(lv.goal)).won) return lv;
  }
  return lv.withGoal(10);
}

HsLevel _build(HsTier t, int n, int attempt) {
  final spec = hsSpec(t);
  final seed = 0x48E5 + t.index * 1000003 + n * 7919 + attempt * 104729;
  final r = HsRng(seed);
  final colors = hsColorsFor(t, n);
  var goal = _lerp(spec.minGoal, spec.maxGoal, n) + (r.nextInt(3) - 1) * 10;
  goal = (goal ~/ 10 * 10).clamp(10, 1000);

  // Blocked cells: interior-ish cells, never adjacent to each other.
  final shape = HsBoard(rows: spec.rows, cols: spec.cols);
  final nBlocked = _lerp(spec.minBlocked, spec.maxBlocked, n) - (n % 5 == 1 && n > 1 ? 1 : 0);
  final blocked = <int>{};
  final candidates = shape.openCells.toList();
  var guard = 0;
  while (blocked.length < nBlocked.clamp(0, 8) && guard++ < 200) {
    final c = candidates[r.nextInt(candidates.length)];
    if (blocked.contains(c) || shape.neighbors[c].any(blocked.contains)) continue;
    blocked.add(c);
  }
  final board = HsBoard(rows: spec.rows, cols: spec.cols, blocked: blocked);

  // A few starting stacks whose tops differ from their neighbours.
  final initial = <int, List<int>>{};
  final pre = n <= 3 ? 0 : _lerp(1, spec.maxPre, n) - r.nextInt(2);
  final open = board.openCells.toList();
  guard = 0;
  while (initial.length < pre && guard++ < 200) {
    final cell = open[r.nextInt(open.length)];
    if (initial.containsKey(cell)) continue;
    final h = 2 + r.nextInt(3);
    final a = r.nextInt(colors);
    var b = r.nextInt(colors);
    if (b == a) b = (a + 1) % colors;
    final s = [for (var k = 0; k < h; k++) k < h ~/ 2 ? b : a];
    final top = s.last;
    if (board.neighbors[cell].any((x) => initial[x]?.last == top)) continue;
    initial[cell] = s;
  }

  return HsLevel(
    tier: t,
    number: n,
    board: board,
    colors: colors,
    goal: goal,
    seed: seed,
    initial: initial,
    maxHeight: spec.maxHeight - (n <= 10 ? 1 : 0),
    multiRun: spec.multiRun,
    bias: spec.bias,
  );
}
