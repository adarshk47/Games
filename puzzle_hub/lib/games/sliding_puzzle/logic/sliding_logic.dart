import 'dart:math';

/// Difficulty tiers: board size per tier and the scramble depth per level.
enum SlideTier {
  easy('easy', 'Easy', 3, 8, 4),
  medium('medium', 'Medium', 4, 14, 6),
  hard('hard', 'Hard', 5, 20, 8),
  extreme('extreme', 'Extreme', 6, 30, 10);

  const SlideTier(this.key, this.label, this.size, this.baseDepth, this.depthStep);
  final String key;
  final String label;
  final int size;
  final int baseDepth;
  final int depthStep;

  static const levelCount = 20;

  /// Number of random single-tile moves used to scramble [level] (1-based).
  int depthFor(int level) => baseDepth + depthStep * level;
}

/// Pure sliding-puzzle rules. A board is a flat row-major list of length n*n;
/// 0 is the gap, tiles are 1..n*n-1.
class SlidingLogic {
  SlidingLogic._();

  static List<int> solved(int n) => [for (var i = 1; i < n * n; i++) i, 0];

  static bool isSolved(List<int> t) {
    for (var i = 0; i < t.length - 1; i++) {
      if (t[i] != i + 1) return false;
    }
    return t.last == 0;
  }

  /// Indices (in order from the gap outwards) that move if the tile at [index]
  /// is tapped; empty if the tap is invalid (gap itself or not in line).
  static List<int> movers(List<int> t, int n, int index) {
    final gap = t.indexOf(0);
    if (index == gap || index < 0 || index >= t.length) return const [];
    final gr = gap ~/ n, gc = gap % n, r = index ~/ n, c = index % n;
    if (gr != r && gc != c) return const [];
    final step = gr == r ? (c > gc ? 1 : -1) : (r > gr ? n : -n);
    final out = <int>[];
    for (var i = gap + step; ; i += step) {
      out.add(i);
      if (i == index) break;
    }
    return out;
  }

  /// Slides the tile at [index] (and every tile between it and the gap).
  /// Returns the new board, or null for an invalid tap.
  static List<int>? slide(List<int> t, int n, int index) {
    final m = movers(t, n, index);
    if (m.isEmpty) return null;
    final out = List<int>.of(t);
    var hole = t.indexOf(0);
    for (final i in m) {
      out[hole] = out[i];
      hole = i;
    }
    out[hole] = 0;
    return out;
  }

  /// Standard solvability test (inversion parity + gap row).
  static bool isSolvable(List<int> t, int n) {
    var inv = 0;
    for (var i = 0; i < t.length; i++) {
      if (t[i] == 0) continue;
      for (var j = i + 1; j < t.length; j++) {
        if (t[j] != 0 && t[j] < t[i]) inv++;
      }
    }
    if (n.isOdd) return inv.isEven;
    final rowFromBottom = n - t.indexOf(0) ~/ n;
    return (inv + rowFromBottom).isOdd;
  }

  /// Scrambles from the solved state with [depth] random legal single moves
  /// (never undoing the previous one), so the result is always solvable and is
  /// guaranteed not to be already solved.
  static List<int> shuffle(int n, int depth, Random rng) {
    var t = solved(n);
    var gap = t.length - 1;
    var prev = -1;
    var moves = 0;
    while (moves < depth || isSolved(t)) {
      final r = gap ~/ n, c = gap % n;
      final opts = <int>[
        if (r > 0) gap - n,
        if (r < n - 1) gap + n,
        if (c > 0) gap - 1,
        if (c < n - 1) gap + 1,
      ]..remove(prev);
      final pick = opts[rng.nextInt(opts.length)];
      t[gap] = t[pick];
      t[pick] = 0;
      prev = gap;
      gap = pick;
      moves++;
    }
    return t;
  }

  /// Par (move target) for a scramble depth.
  static int par(int depth) => depth;

  /// 3 stars within 1.5x par, 2 within 2.5x par, otherwise 1.
  static int starsFor(int moves, int depth) {
    final p = par(depth);
    if (moves <= (p * 1.5).ceil()) return 3;
    if (moves <= (p * 2.5).ceil()) return 2;
    return 1;
  }
}
