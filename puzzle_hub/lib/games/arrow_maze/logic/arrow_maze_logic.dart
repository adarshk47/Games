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

class ArrowMazeLevels {
  static const count = 60;

  static LevelSpec spec(int level) {
    final t = ((level - 1) / (count - 1)).clamp(0.0, 1.0);
    return LevelSpec(
        8 + (12 * t).round(), 6 + (8 * t).round(), 5 + (9 * t).round());
  }

  static ArrowMazeBoard generate(int level) {
    final sp = spec(level);
    for (var attempt = 0; attempt < 20; attempt++) {
      final rng = math.Random(level * 7919 + 13 + attempt * 104729);
      final b = ArrowMazeBoard(
          sp.rows, sp.cols, generateSnakes(sp.rows, sp.cols, sp.maxLen, rng));
      if (b.solve() != null) return b;
    }
    // Practically unreachable: construction guarantees solvability.
    throw StateError('Could not generate level $level');
  }

  /// Snakes are placed one by one; each snake's head ray must be clear of all
  /// previously placed snakes. Therefore removing snakes in reverse placement
  /// order is always possible -> the level is solvable.
  static List<Snake> generateSnakes(
      int rows, int cols, int maxLen, math.Random rng) {
    final n = rows * cols;
    final occ = List<bool>.filled(n, false);
    final snakes = <Snake>[];

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

    List<int> walk(int start, int target) {
      final path = [start];
      final inPath = {start};
      var lastDir = Dir.values[rng.nextInt(4)];
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
        if (path.length > 1 && opts.contains(lastDir) && rng.nextDouble() < 0.5) {
          pick = lastDir;
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
      [maxLen, 4],
      [(maxLen * 0.6).round().clamp(3, maxLen), 3],
      [4, 3],
      [3, 2],
      [2, 2],
    ];
    for (final ph in phases) {
      final hi = ph[0], lo = ph[1];
      var fails = 0;
      final maxFails = n;
      while (fails < maxFails) {
        final empty = [
          for (var i = 0; i < n; i++)
            if (!occ[i]) i
        ];
        if (empty.length < 2) break;
        final start = empty[rng.nextInt(empty.length)];
        List<int>? best;
        Dir? bestDir;
        for (var t = 0; t < 24; t++) {
          final target = lo + rng.nextInt(math.max(1, hi - lo + 1));
          final w = walk(start, target);
          if (w.length < lo) continue;
          if (best != null && w.length <= best.length) continue;
          final own = w.toSet();
          // Try both ends as the head.
          final fwd = w;
          final rev = w.reversed.toList();
          final cands = [fwd, rev]..shuffle(rng);
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
    return snakes;
  }
}
