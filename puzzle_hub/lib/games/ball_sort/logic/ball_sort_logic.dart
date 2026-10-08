import 'dart:math';

const int kTubeCapacity = 4;
const int kMaxExtraTubes = 2;

/// Max tubes that can be bought per level once the free ones are used.
const int kMaxPaidTubes = 3;

enum BsDifficulty {
  easy('easy', 'Easy'),
  medium('medium', 'Medium'),
  hard('hard', 'Hard'),
  extreme('extreme', 'Extreme');

  const BsDifficulty(this.id, this.label);
  final String id;
  final String label;

  static BsDifficulty fromId(String? id) =>
      BsDifficulty.values.firstWhere((d) => d.id == id, orElse: () => BsDifficulty.easy);
}

/// Levels per difficulty.
const int kBsLevelCount = 100;

/// Colour range per difficulty: Easy 3-5, Medium 6-9, Hard 10-14, Extreme 15-20.
const Map<BsDifficulty, (int, int)> _colorRange = {
  BsDifficulty.easy: (3, 5),
  BsDifficulty.medium: (6, 9),
  BsDifficulty.hard: (10, 14),
  BsDifficulty.extreme: (15, 20),
};

/// Level at which a difficulty reaches its most colours; later levels grow
/// harder through deeper scrambles instead.
const int _kFullColorsAt = 70;

/// Number of colors for a level (1-based). Rises step by step over the first
/// [_kFullColorsAt] levels from the tier's minimum to its maximum.
int colorsForLevel(BsDifficulty d, int level) {
  final (lo, hi) = _colorRange[d]!;
  final l = level.clamp(1, kBsLevelCount) - 1;
  return min(hi, lo + l * (hi - lo + 1) ~/ _kFullColorsAt);
}

/// Number of reverse moves used to scramble a level: grows with both the
/// number of colours and the level, so difficulty keeps rising to level 100.
int scrambleSteps(BsDifficulty d, int level) => 80 + colorsForLevel(d, level) * 50 + level.clamp(1, kBsLevelCount) * 4;

/// Number of empty tubes for a level.
/// Extreme starts with two spare tubes, then drops to a single one.
int emptyTubesForLevel(BsDifficulty d, int level) =>
    d == BsDifficulty.extreme && level > 4 ? 1 : 2;

/// Target move count for 3 stars.
int parMoves(BsDifficulty d, int level) {
  final c = colorsForLevel(d, level);
  final perColor = d == BsDifficulty.extreme ? 3.7 : 3.3;
  return (c * perColor).round() + 3;
}

/// 1..3 stars from the number of moves used.
int starsFor(BsDifficulty d, int level, int moves) {
  final par = parMoves(d, level);
  if (moves <= par) return 3;
  if (moves <= par * 1.7) return 2;
  return 1;
}

/// Pure game state. Tubes are listed bottom -> top, values are color ids.
class BallSortState {
  BallSortState(this.tubes, {this.capacity = kTubeCapacity, this.extraUsed = 0, this.moves = 0, this.paidTubes = 0});

  final List<List<int>> tubes;
  final int capacity;
  int extraUsed;
  int moves;

  /// Extra tubes bought (coins/ad) after the free ones ran out.
  int paidTubes;

  BallSortState clone() => BallSortState([for (final t in tubes) List<int>.of(t)],
      capacity: capacity, extraUsed: extraUsed, moves: moves, paidTubes: paidTubes);

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

  /// Free tubes are used up but more can still be bought.
  bool get canBuyTube => !canAddTube && paidTubes < kMaxPaidTubes;

  /// Adds a bought tube (does not consume a free one).
  bool addPaidTube() {
    if (paidTubes >= kMaxPaidTubes) return false;
    tubes.add([]);
    paidTubes++;
    return true;
  }

  String get key => (tubes.map((t) => t.join(',')).toList()..sort()).join('|');
}

/// A generated level together with a known solution (move list of [from,to]).
class BallSortLevel {
  BallSortLevel(this.state, this.solution);
  final BallSortState state;
  final List<List<int>> solution;
}

/// Deterministic level generator. Scrambles a solved state with reverse
/// moves that are each the exact inverse of a legal forward pour (exactly one
/// ball moved), so the recorded reversed move list is a valid solution:
/// every generated level is solvable by construction.
BallSortLevel generateLevelWithSolution(BsDifficulty d, int level) {
  final colors = colorsForLevel(d, level);
  final empties = emptyTubesForLevel(d, level);
  final rng = Random(level * 7919 + 13 + d.index * 104729);
  final total = colors + empties;
  while (true) {
    final tubes = <List<int>>[
      for (var c = 0; c < colors; c++) List<int>.filled(kTubeCapacity, c, growable: true),
      for (var e = 0; e < empties; e++) <int>[],
    ];
    final rev = <List<int>>[]; // reverse moves [from, to] (ball taken from `from`, put on `to`)
    final steps = scrambleSteps(d, level);
    for (var s = 0; s < steps; s++) {
      final from = rng.nextInt(total);
      final to = rng.nextInt(total);
      if (from == to || tubes[from].isEmpty || tubes[to].length >= kTubeCapacity) continue;
      final x = tubes[from].last;
      final rest = tubes[from].length - 1;
      // Forward counterpart (to -> from) must move exactly this one ball:
      // the ball must not extend a same-colour run on `to`.
      if (tubes[to].isNotEmpty && tubes[to].last == x) continue;
      // from's remaining top must accept x (same colour) or be empty.
      if (rest > 0 && tubes[from][rest - 1] != x) continue;
      // Forward would be a pointless whole-tube-to-empty move: not allowed.
      if (rest == 0 && tubes[to].isEmpty) continue;
      tubes[from].removeLast();
      tubes[to].add(x);
      rev.add([from, to]);
    }
    if (BallSortState(tubes).isSolved) continue;
    final perm = List<int>.generate(total, (i) => i)..shuffle(rng);
    final inv = List<int>.filled(total, 0);
    for (var k = 0; k < total; k++) {
      inv[perm[k]] = k;
    }
    final shuffled = [for (var k = 0; k < total; k++) tubes[perm[k]]];
    final solution = [
      for (final m in rev.reversed) [inv[m[1]], inv[m[0]]],
    ];
    return BallSortLevel(BallSortState(shuffled), solution);
  }
}

BallSortState generateLevel(BsDifficulty d, int level) => generateLevelWithSolution(d, level).state;

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
