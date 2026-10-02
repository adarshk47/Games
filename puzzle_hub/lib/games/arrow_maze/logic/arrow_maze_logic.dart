import 'dart:math' as math;

enum Dir {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  const Dir(this.dr, this.dc);
  final int dr, dc;
}

/// A snake-like arrow. [cells] are flat grid indices (r * cols + c) ordered
/// from tail to head; the head points along [dir] (last segment direction).
class Snake {
  const Snake(this.id, this.cells, this.dir);
  final int id;
  final List<int> cells;
  final Dir dir;
  int get head => cells.last;
  int get length => cells.length;
}

class ArrowMazeBoard {
  ArrowMazeBoard(this.rows, this.cols, this.snakes)
      : owner = List<int>.filled(rows * cols, -1) {
    for (final s in snakes) {
      for (final c in s.cells) {
        owner[c] = s.id;
      }
    }
  }

  final int rows, cols;
  final List<Snake> snakes;
  final List<int> owner; // snake id or -1
  final Set<int> removed = {};
  final List<int> history = [];

  int get remaining => snakes.length - removed.length;
  bool get isCleared => remaining == 0;
  int get occupiedCells => snakes.fold(0, (a, s) => a + s.length);
  double get density => occupiedCells / (rows * cols);

  /// Flat indices of cells ahead of the head up to the board edge.
  List<int> rayCells(Snake s) {
    final out = <int>[];
    var r = s.head ~/ cols + s.dir.dr;
    var c = s.head % cols + s.dir.dc;
    while (r >= 0 && r < rows && c >= 0 && c < cols) {
      out.add(r * cols + c);
      r += s.dir.dr;
      c += s.dir.dc;
    }
    return out;
  }

  bool canEscape(int id) {
    if (removed.contains(id)) return false;
    for (final c in rayCells(snakes[id])) {
      if (owner[c] != -1) return false;
    }
    return true;
  }

  /// Taps a snake. Returns true if it left the board, false if blocked,
  /// null if it was already gone.
  bool? tap(int id) {
    if (removed.contains(id)) return null;
    if (!canEscape(id)) return false;
    _remove(id);
    history.add(id);
    return true;
  }

  void _remove(int id) {
    removed.add(id);
    for (final c in snakes[id].cells) {
      owner[c] = -1;
    }
  }

  /// Undoes the last successful removal; returns the restored id.
  int? undo() {
    if (history.isEmpty) return null;
    final id = history.removeLast();
    removed.remove(id);
    for (final c in snakes[id].cells) {
      owner[c] = id;
    }
    return id;
  }

  int? snakeAtCell(int idx) => owner[idx] >= 0 ? owner[idx] : null;

  /// An arrow that can currently leave (prefers longest), or null.
  Snake? hint() {
    Snake? best;
    for (final s in snakes) {
      if (canEscape(s.id) && (best == null || s.length > best.length)) best = s;
    }
    return best;
  }

  /// Greedy solver on a copy of the state; returns removal order or null.
  List<int>? solve() {
    final b = ArrowMazeBoard(rows, cols, snakes);
    for (final id in removed) {
      b._remove(id);
    }
    final order = <int>[];
    var progress = true;
    while (progress && !b.isCleared) {
      progress = false;
      for (final s in snakes) {
        if (b.canEscape(s.id)) {
          b._remove(s.id);
          order.add(s.id);
          progress = true;
        }
      }
    }
    return b.isCleared ? order : null;
  }
}

class LevelSpec {
  const LevelSpec(this.rows, this.cols, this.maxLen);
  final int rows, cols, maxLen;
}

enum MazeTier {
  easy('Easy', 'easy', 30, 3, 5, 5, 7, 8, 11, 3, 6, 'Small boards, short arrows'),
  medium('Medium', 'medium', 60, 3, 3, 8, 6, 20, 14, 5, 14, 'Classic tangle'),
  hard('Hard', 'hard', 40, 2, 2, 12, 8, 22, 15, 6, 18, 'Big, dense, 2 lives'),
  extreme('Extreme', 'extreme', 40, 1, 1, 16, 10, 24, 16, 8, 26,
      'Giant mazes, one life');

  const MazeTier(this.label, this.key, this.count, this.lives, this.hints,
      this.minRows, this.minCols, this.maxRows, this.maxCols, this.minLen,
      this.maxLen, this.blurb);
  final String label, key, blurb;
  final int count, lives, hints;
  final int minRows, minCols, maxRows, maxCols, minLen, maxLen;
}

class ArrowMazeLevels {
  static LevelSpec spec(MazeTier tier, int level) {
    final t = ((level - 1) / (tier.count - 1)).clamp(0.0, 1.0);
    int lerp(int a, int b) => (a + (b - a) * t).round();
    return LevelSpec(lerp(tier.minRows, tier.maxRows),
        lerp(tier.minCols, tier.maxCols), lerp(tier.minLen, tier.maxLen));
  }

  static ArrowMazeBoard generate(MazeTier tier, int level) {
    final sp = spec(tier, level);
    // Several deterministic candidates; keep the densest solvable one.
    final cands = sp.rows * sp.cols > 120 ? 4 : 6;
    ArrowMazeBoard? best;
    for (var attempt = 0; attempt < cands + 16; attempt++) {
      final rng = math.Random(
          level * 7919 + 13 + attempt * 104729 + tier.index * 1299709);
      final b = ArrowMazeBoard(
          sp.rows, sp.cols, generateSnakes(sp.rows, sp.cols, sp.maxLen, rng));
      if (b.solve() == null) continue;
      if (best == null || b.density > best.density) best = b;
      if (attempt >= cands - 1) break;
    }
    if (best != null) return best;
    // Practically unreachable: construction guarantees solvability.
    throw StateError('Could not generate ${tier.key} level $level');
  }

  /// Snakes are placed one by one; each snake's head ray must be clear of all
  /// previously placed snakes. Therefore removing snakes in reverse placement
  /// order is always possible -> the level is solvable.
  static List<Snake> generateSnakes(
      int rows, int cols, int maxLen, math.Random rng) {
    final n = rows * cols;
    final occ = List<bool>.filled(n, false);
    final snakes = <Snake>[];

    int freeNeighbors(int i, Set<int>? inPath) {
      final r = i ~/ cols, c = i % cols;
      var k = 0;
      for (final d in Dir.values) {
        final nr = r + d.dr, nc = c + d.dc;
        if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
        final j = nr * cols + nc;
        if (!occ[j] && !(inPath?.contains(j) ?? false)) k++;
      }
      return k;
    }

    bool rayClear(int head, Dir d, Set<int> own) {
      var r = head ~/ cols + d.dr;
      var c = head % cols + d.dc;
      while (r >= 0 && r < rows && c >= 0 && c < cols) {
        final i = r * cols + c;
        if (occ[i] || own.contains(i)) return false;
        r += d.dr;
        c += d.dc;
      }
      return true;
    }

    Dir dirOf(int from, int to) {
      final dr = to ~/ cols - from ~/ cols;
      final dc = to % cols - from % cols;
      if (dr < 0) return Dir.up;
      if (dr > 0) return Dir.down;
      return dc < 0 ? Dir.left : Dir.right;
    }

    // Walks hug walls / existing snakes (fewest free neighbours first) so the
    // board packs tightly, with some randomness for variety.
    List<int> walk(int start, int target) {
      final path = [start];
      final inPath = {start};
      var lastDir = Dir.values[rng.nextInt(4)];
      final hug = rng.nextDouble() * 0.85;
      while (path.length < target) {
        final cur = path.last;
        final r = cur ~/ cols, c = cur % cols;
        final opts = <Dir>[];
        for (final d in Dir.values) {
          final nr = r + d.dr, nc = c + d.dc;
          if (nr < 0 || nr >= rows || nc < 0 || nc >= cols) continue;
          final i = nr * cols + nc;
          if (occ[i] || inPath.contains(i)) continue;
          opts.add(d);
        }
        if (opts.isEmpty) break;
        Dir pick;
        final roll = rng.nextDouble();
        if (path.length > 1 && opts.contains(lastDir) && roll < 0.35) {
          pick = lastDir;
        } else if (roll < 0.35 + hug) {
          var bestK = 99.0;
          pick = opts.first;
          for (final d in opts) {
            final k = freeNeighbors((r + d.dr) * cols + (c + d.dc), inPath) +
                rng.nextDouble() * 0.9;
            if (k < bestK) {
              bestK = k;
              pick = d;
            }
          }
        } else {
          pick = opts[rng.nextInt(opts.length)];
        }
        lastDir = pick;
        final nxt = (r + pick.dr) * cols + (c + pick.dc);
        path.add(nxt);
        inPath.add(nxt);
      }
      return path;
    }

    void place(List<int> cells, Dir d) {
      snakes.add(Snake(snakes.length, cells, d));
      for (final c in cells) {
        occ[c] = true;
      }
    }

    final phases = <List<int>>[
      [maxLen, math.max(4, (maxLen * 0.5).round())],
      [(maxLen * 0.6).round().clamp(3, maxLen), 3],
      [5, 3],
      [4, 3],
      [3, 2],
      [2, 2],
    ];
    final tries = n > 200 ? 40 : 28;
    for (final ph in phases) {
      final hi = ph[0], lo = ph[1];
      var fails = 0;
      final maxFails = n ~/ 2 + 8;
      while (fails < maxFails) {
        final empty = [
          for (var i = 0; i < n; i++)
            if (!occ[i]) i
        ];
        if (empty.length < 2) break;
        // Start in a cramped spot: best of a few random empty cells.
        var start = empty[rng.nextInt(empty.length)];
        var startK = freeNeighbors(start, null);
        for (var s = 0; s < 4; s++) {
          final cand = empty[rng.nextInt(empty.length)];
          final k = freeNeighbors(cand, null);
          if (k < startK) {
            start = cand;
            startK = k;
          }
        }
        List<int>? best;
        Dir? bestDir;
        for (var t = 0; t < tries; t++) {
          final target = lo + rng.nextInt(math.max(1, hi - lo + 1));
          final w = walk(start, target);
          if (w.length < lo) continue;
          if (best != null && w.length <= best.length) continue;
          final own = w.toSet();
          // Try both ends as the head.
          final cands = [w, w.reversed.toList()]..shuffle(rng);
          for (final cand in cands) {
            final d = dirOf(cand[cand.length - 2], cand.last);
            if (rayClear(cand.last, d, own)) {
              best = cand;
              bestDir = d;
              break;
            }
          }
        }
        if (best == null) {
          fails++;
        } else {
          place(best, bestDir!);
          fails = 0;
        }
      }
    }
    // Final exhaustive sweep: squeeze in any domino that still fits.
    for (final len in [3, 2]) {
      final order = [for (var i = 0; i < n; i++) i]..shuffle(rng);
      for (final start in order) {
        if (occ[start]) continue;
        for (var t = 0; t < 12; t++) {
          final w = walk(start, len);
          if (w.length < len) continue;
          final own = w.toSet();
          var done = false;
          for (final cand in [w, w.reversed.toList()]) {
            final d = dirOf(cand[cand.length - 2], cand.last);
            if (rayClear(cand.last, d, own)) {
              place(cand, d);
              done = true;
              break;
            }
          }
          if (done) break;
        }
      }
    }
    return snakes;
  }
}
