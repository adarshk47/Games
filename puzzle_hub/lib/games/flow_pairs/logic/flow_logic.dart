import 'dart:math' as math;

/// Difficulty tiers of Flow / Connect Pairs.
enum FlowTier {
  easy('easy', 'Easy', false),
  medium('medium', 'Medium', false),
  hard('hard', 'Hard', true),
  extreme('extreme', 'Extreme', true);

  const FlowTier(this.id, this.label, this.requireFill);
  final String id;
  final String label;

  /// Whether every cell must be covered to finish a level.
  final bool requireFill;

  static FlowTier fromId(String? id) =>
      FlowTier.values.firstWhere((t) => t.id == id, orElse: () => FlowTier.easy);

  String get sizeLabel => switch (this) {
        FlowTier.easy => '5x5',
        FlowTier.medium => '6x6 - 7x7',
        FlowTier.hard => '8x8 - 9x9',
        FlowTier.extreme => '10x10 - 12x12',
      };
}

/// A pair of same-colored endpoints (cell indices = r * size + c).
class FlowPair {
  const FlowPair(this.a, this.b);
  final int a;
  final int b;
}

class FlowPuzzle {
  const FlowPuzzle({
    required this.size,
    required this.pairs,
    required this.solution,
    required this.requireFill,
  });
  final int size;
  final List<FlowPair> pairs;

  /// Per pair: the cells of a valid path from `pair.a` to `pair.b`. Together
  /// the solution paths tile the whole grid.
  final List<List<int>> solution;
  final bool requireFill;

  int get cells => size * size;
  int get minMoves => pairs.length;
}

class FlowLevels {
  FlowLevels._();
  static const count = 30;
  static final Map<String, FlowPuzzle> _cache = {};

  static int sizeFor(FlowTier t, int level) => switch (t) {
        FlowTier.easy => 5,
        FlowTier.medium => level <= 15 ? 6 : 7,
        FlowTier.hard => level <= 15 ? 8 : 9,
        FlowTier.extreme => 10 + (level - 1) ~/ 10,
      };

  static int pairCountFor(FlowTier t, int level) {
    final s = sizeFor(t, level);
    return switch (t) {
      FlowTier.easy => level < 10 ? 4 : 5,
      FlowTier.medium => s - 1 + (level % 2),
      FlowTier.hard => s - 1 + (level % 3 == 0 ? 1 : 0),
      FlowTier.extreme => s - 1 + (level % 3),
    };
  }

  /// Deterministic per tier + level, always solvable (the stored solution tiles
  /// the grid).
  static FlowPuzzle generate(FlowTier tier, int level) {
    assert(level >= 1 && level <= count);
    return _cache.putIfAbsent('${tier.id}.$level', () => _build(tier, level));
  }

  static FlowPuzzle _build(FlowTier tier, int level) {
    final n = sizeFor(tier, level);
    final k = pairCountFor(tier, level);
    final rnd = math.Random(tier.index * 100003 + level * 7919 + 17);
    final total = n * n;

    // Hamiltonian path: serpentine, then randomised with "backbite" moves.
    var path = <int>[
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++) r * n + (r.isEven ? c : n - 1 - c),
    ];
    List<int> nbrs(int cell) {
      final r = cell ~/ n, c = cell % n;
      return [
        if (r > 0) cell - n,
        if (r < n - 1) cell + n,
        if (c > 0) cell - 1,
        if (c < n - 1) cell + 1,
      ];
    }

    for (var it = 0; it < total * 40; it++) {
      if (rnd.nextBool()) {
        final opts = nbrs(path.first).where((x) => x != path[1]).toList();
        if (opts.isEmpty) continue;
        final j = path.indexOf(opts[rnd.nextInt(opts.length)]);
        path = [...path.sublist(0, j).reversed, ...path.sublist(j)];
      } else {
        final opts = nbrs(path.last).where((x) => x != path[total - 2]).toList();
        if (opts.isEmpty) continue;
        final j = path.indexOf(opts[rnd.nextInt(opts.length)]);
        path = [...path.sublist(0, j + 1), ...path.sublist(j + 1).reversed];
      }
    }

    // Cut into k segments of length >= 3.
    const minLen = 3;
    final extra = total - minLen * k;
    final w = [for (var i = 0; i < k; i++) rnd.nextDouble() + 0.25];
    final wSum = w.fold<double>(0, (a, b) => a + b);
    final lens = [for (var i = 0; i < k; i++) minLen + (extra * w[i] / wSum).floor()];
    var rest = total - lens.fold<int>(0, (a, b) => a + b);
    while (rest > 0) {
      lens[rnd.nextInt(k)]++;
      rest--;
    }
    final pairs = <FlowPair>[];
    final solution = <List<int>>[];
    var pos = 0;
    for (final len in lens) {
      final seg = path.sublist(pos, pos + len);
      pos += len;
      final s = rnd.nextBool() ? seg.reversed.toList() : seg;
      solution.add(s);
      pairs.add(FlowPair(s.first, s.last));
    }
    return FlowPuzzle(size: n, pairs: pairs, solution: solution, requireFill: tier.requireFill);
  }
}

/// Star rating: strokes (moves) versus the minimum (one stroke per pair).
int flowStars(int moves, int pairs) {
  if (moves <= (pairs * 1.25).ceil()) return 3;
  if (moves <= pairs * 2) return 2;
  return 1;
}

enum FlowStep { none, extended, backtracked, cut, blocked, connected }

/// Mutable board: paths, drawing and cutting rules, completion check.
class FlowBoard {
  FlowBoard(this.puzzle)
      : paths = List.generate(puzzle.pairs.length, (_) => <int>[]),
        owner = List.filled(puzzle.cells, -1),
        _endpoint = List.filled(puzzle.cells, -1) {
    for (var i = 0; i < puzzle.pairs.length; i++) {
      _endpoint[puzzle.pairs[i].a] = i;
      _endpoint[puzzle.pairs[i].b] = i;
    }
  }

  final FlowPuzzle puzzle;
  final List<List<int>> paths;

  /// cell -> pair index whose path covers it (or -1).
  final List<int> owner;
  final List<int> _endpoint;

  /// Pair currently being drawn.
  int? active;

  /// Pair that was cut by the last [extend] call (for effects).
  int lastCut = -1;

  int get size => puzzle.size;

  int endpointOf(int cell) => _endpoint[cell];

  int _twin(int pair, int cell) {
    final p = puzzle.pairs[pair];
    return cell == p.a ? p.b : p.a;
  }

  bool isConnected(int pair) {
    final path = paths[pair];
    if (path.length < 2) return false;
    final p = puzzle.pairs[pair];
    return (path.first == p.a && path.last == p.b) || (path.first == p.b && path.last == p.a);
  }

  int get connectedCount {
    var n = 0;
    for (var i = 0; i < paths.length; i++) {
      if (isConnected(i)) n++;
    }
    return n;
  }

  int get filledCount => owner.where((o) => o >= 0).length;

  bool get isSolved {
    if (connectedCount != puzzle.pairs.length) return false;
    return !puzzle.requireFill || filledCount == puzzle.cells;
  }

  void _truncate(int pair, int keep) {
    final p = paths[pair];
    while (p.length > keep) {
      owner[p.removeLast()] = -1;
    }
  }

  void _append(int pair, int cell) {
    paths[pair].add(cell);
    owner[cell] = pair;
  }

  /// Start drawing on [cell]. Returns the pair being drawn or null.
  int? begin(int cell) {
    final e = _endpoint[cell];
    if (e >= 0) {
      _truncate(e, 0);
      _append(e, cell);
      return active = e;
    }
    final o = owner[cell];
    if (o >= 0) {
      _truncate(o, paths[o].indexOf(cell) + 1);
      return active = o;
    }
    return null;
  }

  bool _adjacent(int a, int b) {
    final ar = a ~/ size, ac = a % size, br = b ~/ size, bc = b % size;
    return (ar - br).abs() + (ac - bc).abs() == 1;
  }

  /// Extend the active path to the orthogonally adjacent [cell].
  FlowStep extend(int cell) {
    lastCut = -1;
    final a = active;
    if (a == null) return FlowStep.none;
    final path = paths[a];
    if (path.isEmpty) return FlowStep.none;
    final head = path.last;
    if (cell == head || !_adjacent(head, cell)) return FlowStep.none;
    final start = path.first;
    final complete = path.length >= 2 && head == _twin(a, start);

    if (path.length >= 2 && cell == path[path.length - 2]) {
      _truncate(a, path.length - 1);
      return FlowStep.backtracked;
    }
    if (complete) return FlowStep.none;
    if (owner[cell] == a) {
      _truncate(a, path.indexOf(cell) + 1);
      return FlowStep.backtracked;
    }
    final e = _endpoint[cell];
    if (e >= 0 && e != a) return FlowStep.blocked;
    if (e == a) {
      _append(a, cell);
      return FlowStep.connected;
    }
    final o = owner[cell];
    if (o >= 0) {
      _truncate(o, paths[o].indexOf(cell));
      lastCut = o;
      _append(a, cell);
      return FlowStep.cut;
    }
    _append(a, cell);
    return FlowStep.extended;
  }

  void end() {
    final a = active;
    if (a != null && paths[a].length == 1) _truncate(a, 0);
    active = null;
  }

  List<List<int>> snapshot() => [for (final p in paths) List<int>.of(p)];

  void restore(List<List<int>> snap) {
    for (var i = 0; i < paths.length; i++) {
      paths[i]
        ..clear()
        ..addAll(snap[i]);
    }
    owner.fillRange(0, owner.length, -1);
    for (var i = 0; i < paths.length; i++) {
      for (final c in paths[i]) {
        owner[c] = i;
      }
    }
    active = null;
  }

  bool _matchesSolution(int i) {
    final p = paths[i], s = puzzle.solution[i];
    if (p.length != s.length) return false;
    var fwd = true, bwd = true;
    for (var k = 0; k < s.length; k++) {
      if (p[k] != s[k]) fwd = false;
      if (p[k] != s[s.length - 1 - k]) bwd = false;
    }
    return fwd || bwd;
  }

  /// Reveals one pair's correct path (cutting anything in the way). Returns the
  /// pair index, or null when nothing is left to reveal.
  int? applyHint() {
    int? pick;
    for (var i = 0; i < paths.length; i++) {
      if (!_matchesSolution(i) && !isConnected(i)) {
        pick = i;
        break;
      }
    }
    if (pick == null) {
      for (var i = 0; i < paths.length; i++) {
        if (!_matchesSolution(i)) {
          pick = i;
          break;
        }
      }
    }
    if (pick == null) return null;
    _truncate(pick, 0);
    for (final c in puzzle.solution[pick]) {
      final o = owner[c];
      if (o >= 0 && o != pick) _truncate(o, paths[o].indexOf(c));
    }
    for (final c in puzzle.solution[pick]) {
      _append(pick, c);
    }
    active = null;
    return pick;
  }
}

class _UndoEntry {
  _UndoEntry(this.snap, this.counted);
  final List<List<int>> snap;
  final bool counted;
}

/// A play session: board + undo stack + stroke counter + hints.
class FlowGame {
  FlowGame(this.puzzle, {this.maxHints = 3})
      : board = FlowBoard(puzzle),
        hintsLeft = maxHints;

  final FlowPuzzle puzzle;
  final int maxHints;
  final FlowBoard board;
  final List<_UndoEntry> _undo = [];
  List<List<int>>? _pre;
  int moves = 0;
  int hintsLeft;

  bool get solved => board.isSolved;
  bool get canUndo => _undo.isNotEmpty;

  int? begin(int cell) {
    if (solved) return null;
    _pre = board.snapshot();
    final a = board.begin(cell);
    if (a == null) _pre = null;
    return a;
  }

  FlowStep extend(int cell) => solved ? FlowStep.none : board.extend(cell);

  /// Finish the current stroke; counts as a move only if something changed.
  /// Returns true if it counted.
  bool end() {
    final pre = _pre;
    board.end();
    _pre = null;
    if (pre == null) return false;
    if (_same(pre, board.snapshot())) return false;
    _undo.add(_UndoEntry(pre, true));
    moves++;
    return true;
  }

  bool _same(List<List<int>> a, List<List<int>> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].length != b[i].length) return false;
      for (var k = 0; k < a[i].length; k++) {
        if (a[i][k] != b[i][k]) return false;
      }
    }
    return true;
  }

  bool undo() {
    if (_undo.isEmpty || solved) return false;
    final e = _undo.removeLast();
    board.restore(e.snap);
    if (e.counted && moves > 0) moves--;
    return true;
  }

  /// Returns the revealed pair index, or null if none left / no hints.
  /// Hints are not counted as strokes.
  int? hint() {
    if (hintsLeft <= 0 || solved) return null;
    final pre = board.snapshot();
    final p = board.applyHint();
    if (p == null) return null;
    _undo.add(_UndoEntry(pre, false));
    hintsLeft--;
    return p;
  }

  void restart() {
    board.restore(List.generate(puzzle.pairs.length, (_) => <int>[]));
    _undo.clear();
    _pre = null;
    moves = 0;
    hintsLeft = maxHints;
  }
}
