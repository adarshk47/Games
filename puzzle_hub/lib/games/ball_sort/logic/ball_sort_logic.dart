import 'dart:math';

const int kTubeCapacity = 4;
const int kMaxExtraTubes = 2;

/// Number of colors for a level (1-based): 3 up to 12.
int colorsForLevel(int level) => min(12, 3 + (max(1, level) - 1) ~/ 3);

/// Number of empty tubes for a level.
int emptyTubesForLevel(int level) => 2;

/// Pure game state. Tubes are listed bottom -> top, values are color ids.
class BallSortState {
  BallSortState(this.tubes, {this.capacity = kTubeCapacity, this.extraUsed = 0, this.moves = 0});

  final List<List<int>> tubes;
  final int capacity;
  int extraUsed;
  int moves;

  BallSortState clone() => BallSortState([for (final t in tubes) List<int>.of(t)],
      capacity: capacity, extraUsed: extraUsed, moves: moves);

  int? topColor(int tube) => tubes[tube].isEmpty ? null : tubes[tube].last;

  /// Count of contiguous same-colour balls on top of a tube.
  int topRun(int tube) {
    final t = tubes[tube];
    if (t.isEmpty) return 0;
    var n = 0;
    for (var i = t.length - 1; i >= 0 && t[i] == t.last; i--) {
      n++;
    }
    return n;
  }

  /// How many balls a pour from [from] to [to] would move (0 = illegal).
  int pourCount(int from, int to) {
    if (from == to) return 0;
    final src = tubes[from];
    final dst = tubes[to];
    if (src.isEmpty) return 0;
    if (dst.length >= capacity) return 0;
    if (dst.isNotEmpty && dst.last != src.last) return 0;
    // Pointless: moving a whole single-colour tube into an empty tube.
    if (dst.isEmpty && topRun(from) == src.length) return 0;
    return min(topRun(from), capacity - dst.length);
  }

  bool canPour(int from, int to) => pourCount(from, to) > 0;

  /// Performs the pour; returns number of balls moved.
  int pour(int from, int to) {
    final n = pourCount(from, to);
    if (n == 0) return 0;
    final src = tubes[from];
    final moved = src.sublist(src.length - n);
    src.removeRange(src.length - n, src.length);
    tubes[to].addAll(moved);
    moves++;
    return n;
  }

  bool get isSolved =>
      tubes.every((t) => t.isEmpty || (t.length == capacity && t.every((c) => c == t.first)));

  bool get canAddTube => extraUsed < kMaxExtraTubes;

  bool addTube() {
    if (!canAddTube) return false;
    tubes.add([]);
    extraUsed++;
    return true;
  }

  String get key => (tubes.map((t) => t.join(',')).toList()..sort()).join('|');
}

/// Deterministic level generator. Scrambles a solved state with reverse
/// moves, so every generated level is solvable by construction.
BallSortState generateLevel(int level) {
  final colors = colorsForLevel(level);
  final empties = emptyTubesForLevel(level);
  final rng = Random(level * 7919 + 13);
  final total = colors + empties;
  while (true) {
    final tubes = <List<int>>[
      for (var c = 0; c < colors; c++) List<int>.filled(kTubeCapacity, c, growable: true),
      for (var e = 0; e < empties; e++) <int>[],
    ];
    final steps = 60 + colors * 40;
    for (var s = 0; s < steps; s++) {
      final from = rng.nextInt(total);
      final to = rng.nextInt(total);
      if (from == to || tubes[from].isEmpty || tubes[to].length >= kTubeCapacity) continue;
      final x = tubes[from].last;
      // Forward counterpart (to -> from) must be legal: from's remaining top is x or empty.
      final rest = tubes[from].length - 1;
      if (rest > 0 && tubes[from][rest - 1] != x) continue;
      tubes[from].removeLast();
      tubes[to].add(x);
    }
    if (!BallSortState(tubes).isSolved) {
      tubes.shuffle(rng);
      return BallSortState(tubes);
    }
  }
}

/// Depth-first solver with node limit. Returns a move list [from,to] or null
/// if none found within [maxNodes].
List<List<int>>? solve(BallSortState start, {int maxNodes = 200000}) {
  final seen = <String>{};
  var nodes = 0;
  final path = <List<int>>[];
  bool dfs(BallSortState s) {
    if (s.isSolved) return true;
    if (++nodes > maxNodes) return false;
    if (!seen.add(s.key)) return false;
    final n = s.tubes.length;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        if (!s.canPour(i, j)) continue;
        final c = s.clone()..pour(i, j);
        path.add([i, j]);
        if (dfs(c)) return true;
        path.removeLast();
      }
    }
    return false;
  }

  return dfs(start) ? path : null;
}
