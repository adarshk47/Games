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

  BoardStats stats() {
    final b = ArrowMazeBoard(rows, cols, snakes);
    var blocked = 0;
    for (final s in snakes) {
      if (!b.canEscape(s.id)) blocked++;
    }
    var rounds = 0;
    while (!b.isCleared) {
      final free = [
        for (final s in snakes)
          if (b.canEscape(s.id)) s.id
      ];
      if (free.isEmpty) break;
      free.forEach(b._remove);
      rounds++;
    }
    return BoardStats(snakes.isEmpty ? 0 : blocked / snakes.length, rounds);
  }
}

class BoardStats {
  const BoardStats(this.blockedFraction, this.depth);

  /// Share of arrows that cannot leave at the start.
  final double blockedFraction;

  /// Rounds needed when every free arrow is removed at once (length of the
  /// longest dependency chain).
  final int depth;
}

class LevelSpec {
  const LevelSpec(this.rows, this.cols, this.minLen, this.maxLen);
  final int rows, cols, minLen, maxLen;
}

enum MazeTier {
  easy('Easy', 'easy', 100, 3, 5, 7, 5, 12, 9, 2, 5, 'Small boards, short arrows'),
  medium('Medium', 'medium', 100, 3, 3, 10, 7, 20, 14, 3, 9, 'Classic tangle'),
  hard('Hard', 'hard', 100, 2, 2, 16, 11, 26, 17, 3, 14, 'Big, dense, 2 lives'),
  extreme('Extreme', 'extreme', 100, 1, 1, 20, 14, 30, 20, 4, 22,
      'Giant tangles, tons of arrows, one life');

  const MazeTier(this.label, this.key, this.count, this.lives, this.hints,
      this.minRows, this.minCols, this.maxRows, this.maxCols, this.minLen,
      this.maxLen, this.blurb);
  final String label, key, blurb;
  final int count, lives, hints;
  final int minRows, minCols, maxRows, maxCols, minLen, maxLen;

  /// Hard and Extreme build heavily interlocked boards.
  bool get tangled => index >= MazeTier.hard.index;

  /// Chance to aim an arrow so it lengthens the dependency chain.
  double get deepBias => const [0.1, 0.45, 0.85, 0.97][index];

  /// Target board density (Easy/Medium are thinned to open free lanes).
  double get thinTo => const [0.88, 0.85, 1.0, 1.0][index];
}

class ArrowMazeLevels {
  static LevelSpec spec(MazeTier tier, int level) {
    final t = ((level - 1) / (tier.count - 1)).clamp(0.0, 1.0);
    int lerp(int a, int b) => (a + (b - a) * t).round();
    return LevelSpec(lerp(tier.minRows, tier.maxRows),
        lerp(tier.minCols, tier.maxCols), tier.minLen,
        lerp(tier.minLen, tier.maxLen));
  }

  static final Map<int, List<Snake>> _cache = {};

  /// Snakes of a level (cached; snakes are immutable).
  static List<Snake> snakesFor(MazeTier tier, int level) {
    final key = tier.index * 100000 + level;
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length > 48) _cache.clear();
    return _cache[key] = _build(tier, level);
  }

  /// Fresh (mutable) board for a level. Deterministic and always solvable.
  static ArrowMazeBoard generate(MazeTier tier, int level) {
    final sp = spec(tier, level);
    return ArrowMazeBoard(sp.rows, sp.cols, snakesFor(tier, level));
  }

  static int _seed(MazeTier tier, int level, int attempt) =>
      level * 7919 + 13 + attempt * 104729 + tier.index * 1299709;

  static List<Snake> _build(MazeTier tier, int level) {
    final sp = spec(tier, level);
    // Deterministic candidates. Easy/Medium take the first one (thinned out
    // so free lanes appear); Hard/Extreme keep the most interlocked of three.
    final tries = tier.tangled ? 3 : 1;
    List<Snake>? best;
    var bestScore = -1.0;
    for (var attempt = 0; attempt < tries + 4; attempt++) {
      final rng = math.Random(_seed(tier, level, attempt));
      var snakes = generateTangle(sp.rows, sp.cols, sp.minLen, sp.maxLen, rng,
          deepBias: tier.deepBias);
      if (tier.thinTo < 1) {
        snakes = thinOut(sp.rows, sp.cols, snakes, tier.thinTo);
      }
      final b = ArrowMazeBoard(sp.rows, sp.cols, snakes);
      if (snakes.isEmpty || b.solve() == null) continue;
      final st = b.stats();
      final score = st.depth / 4 + st.blockedFraction * 4 + b.density * 6;
      if (score > bestScore) {
        bestScore = score;
        best = snakes;
      }
      if (attempt >= tries - 1) break;
    }
    if (best != null) return List.unmodifiable(best);
    // Unreachable: construction guarantees solvability.
    throw StateError('Could not generate ${tier.key} level $level');
  }

  /// Removes the arrows that block the most others until the board density
  /// drops to about [target]. Removing arrows never makes a level unsolvable.
  static List<Snake> thinOut(
      int rows, int cols, List<Snake> snakes, double target) {
    var list = snakes;
    final total = rows * cols;
    var occ = list.fold<int>(0, (a, s) => a + s.length);
    while (occ / total > target && list.length > 2) {
      final b = ArrowMazeBoard(rows, cols, list);
      final blocks = List<int>.filled(list.length, 0);
      for (final s in list) {
        final hit = <int>{};
        for (final c in b.rayCells(s)) {
          final o = b.owner[c];
          if (o >= 0 && o != s.id) hit.add(o);
        }
        for (final o in hit) {
          blocks[o]++;
        }
      }
      var pick = -1;
      for (final s in list) {
        if ((occ - s.length) / total < target - 0.03) continue;
        if (pick < 0 || blocks[s.id] > blocks[pick]) pick = s.id;
      }
      if (pick < 0) break;
      occ -= list[pick].length;
      list = [
        for (final s in list)
          if (s.id != pick) s
      ];
      list = [
        for (var i = 0; i < list.length; i++)
          Snake(i, list[i].cells, list[i].dir)
      ];
    }
    return list;
  }

  /// Interlocking generator. The board is first tiled with long snake paths
  /// (cramped cells first, so almost no holes are left), then every path gets
  /// a head end such that the "is blocked by" graph stays acyclic. An acyclic
  /// graph always has a free arrow, and removing arrows never blocks others,
  /// so the level is solvable by construction. Paths whose both ends would
  /// close a cycle (or hit their own body) are split, or dropped when tiny.
  static List<Snake> generateTangle(
      int rows, int cols, int minLen, int maxLen, math.Random rng,
      {double deepBias = 0.9}) {
    final n = rows * cols;
    const hole = -2;
    final own = List<int>.filled(n, -1);
    final pieces = <List<int>>[];

    int freeN(int i) {
      final r = i ~/ cols, c = i % cols;
      var k = 0;
      if (r > 0 && own[i - cols] == -1) k++;
      if (r < rows - 1 && own[i + cols] == -1) k++;
      if (c > 0 && own[i - 1] == -1) k++;
      if (c < cols - 1 && own[i + 1] == -1) k++;
      return k;
    }

    List<int> nbrs(int i) {
      final r = i ~/ cols, c = i % cols;
      return [
        if (r > 0) i - cols,
        if (r < rows - 1) i + cols,
        if (c > 0) i - 1,
        if (c < cols - 1) i + 1,
      ];
    }

    // ---- 1. tile the board with paths.
    while (true) {
      var start = -1, bestK = 9, ties = 0;
      for (var i = 0; i < n; i++) {
        if (own[i] != -1) continue;
        final k = freeN(i);
        if (k < bestK) {
          bestK = k;
          start = i;
          ties = 1;
        } else if (k == bestK && rng.nextInt(++ties) == 0) {
          start = i;
        }
      }
      if (start < 0) break;
      final id = pieces.length;
      final target = minLen + rng.nextInt(math.max(1, maxLen - minLen + 1));
      final path = [start];
      own[start] = id;
      var last = -1;
      final straight = 0.25 + rng.nextDouble() * 0.35;
      while (path.length < target) {
        final cur = path.last;
        final opts = [
          for (final j in nbrs(cur))
            if (own[j] == -1) j
        ];
        if (opts.isEmpty) break;
        int pick;
        final ahead = last < 0 ? -1 : cur + (cur - last);
        if (opts.contains(ahead) &&
            rng.nextDouble() < straight &&
            freeN(ahead) > 0) {
          pick = ahead;
        } else {
          // Hug walls / other paths so no isolated cells are left behind.
          var bk = 99.0;
          pick = opts.first;
          for (final j in opts) {
            final k = freeN(j) + rng.nextDouble() * 1.2;
            if (k < bk) {
              bk = k;
              pick = j;
            }
          }
        }
        last = cur;
        path.add(pick);
        own[pick] = id;
      }
      if (path.length >= 2) {
        pieces.add(path);
        continue;
      }
      // A lone cell: glue it to the end of a neighbouring path if possible.
      own[start] = hole;
      for (final j in nbrs(start)) {
        final p = own[j];
        if (p < 0) continue;
        final cells = pieces[p];
        if (cells.length >= maxLen + 2) continue;
        if (cells.first == j) {
          cells.insert(0, start);
        } else if (cells.last == j) {
          cells.add(start);
        } else {
          continue;
        }
        own[start] = p;
        break;
      }
    }

    // ---- 2. choose heads keeping the blocked-by graph acyclic.
    final rays = <int, List<int>>{}; // piece -> ray cells (oriented pieces)
    final orient = <int, List<int>>{}; // piece -> cells tail..head
    var stamp = 0;
    final seen = <int>[];

    Dir dirOf(int from, int to) {
      final d = to - from;
      if (d == -cols) return Dir.up;
      if (d == cols) return Dir.down;
      return d < 0 ? Dir.left : Dir.right;
    }

    List<int>? ray(List<int> cells, int self) {
      final h = cells.last;
      final d = dirOf(cells[cells.length - 2], h);
      var r = h ~/ cols + d.dr, c = h % cols + d.dc;
      final out = <int>[];
      while (r >= 0 && r < rows && c >= 0 && c < cols) {
        final i = r * cols + c;
        if (own[i] == self) return null; // would hit its own body
        out.add(i);
        r += d.dr;
        c += d.dc;
      }
      return out;
    }

    // Can [from] reach [p] following blocked-by edges?
    bool reaches(int from, int p) {
      stamp++;
      while (seen.length < pieces.length) {
        seen.add(0);
      }
      final stack = [from];
      seen[from] = stamp;
      while (stack.isNotEmpty) {
        final u = stack.removeLast();
        if (u == p) return true;
        final rc = rays[u];
        if (rc == null) continue;
        for (final i in rc) {
          final v = own[i];
          if (v < 0 || v == u || seen[v] == stamp) continue;
          seen[v] = stamp;
          stack.add(v);
        }
      }
      return false;
    }

    // Longest blocked-by chain starting at u (memoised per query).
    final depthMemo = <int, int>{};
    int depth(int u) {
      final m = depthMemo[u];
      if (m != null) return m;
      depthMemo[u] = 0; // graph is acyclic; guards re-entry anyway
      final rc = rays[u];
      var best = 0;
      if (rc != null) {
        for (final i in rc) {
          final v = own[i];
          if (v < 0 || v == u) continue;
          best = math.max(best, 1 + depth(v));
        }
      }
      return depthMemo[u] = best;
    }

    bool orientPiece(int p) {
      final cells = pieces[p];
      final opts = <(List<int>, List<int>, int)>[];
      for (final cand in [cells, cells.reversed.toList()]) {
        final rc = ray(cand, p);
        if (rc == null) continue;
        final targets = <int>{
          for (final i in rc)
            if (own[i] >= 0) own[i]
        };
        if (targets.any((t) => reaches(t, p))) continue;
        depthMemo.clear();
        var dep = 0;
        for (final t in targets) {
          dep = math.max(dep, 1 + depth(t));
        }
        opts.add((cand, rc, dep));
      }
      if (opts.isEmpty) return false;
      var pick = opts.first;
      if (opts.length == 2) {
        final a = opts[0], b = opts[1];
        final deep = a.$3 >= b.$3 ? a : b;
        final shallow = identical(deep, a) ? b : a;
        pick = rng.nextDouble() < deepBias ? deep : shallow;
      }
      orient[p] = pick.$1;
      rays[p] = pick.$2;
      return true;
    }

    final queue = [for (var i = 0; i < pieces.length; i++) i]..shuffle(rng);
    var qi = 0;
    while (qi < queue.length) {
      final p = queue[qi++];
      if (orientPiece(p)) continue;
      final cells = pieces[p];
      if (cells.length >= 4) {
        // Split into two paths and try again.
        final cut = 2 + rng.nextInt(cells.length - 3);
        final tail = cells.sublist(cut);
        cells.removeRange(cut, cells.length);
        final q = pieces.length;
        pieces.add(tail);
        for (final i in tail) {
          own[i] = q;
        }
        queue.insert(qi, q);
        queue.insert(qi, p);
      } else if (cells.length == 3) {
        own[cells.removeAt(rng.nextInt(2) * 2)] = hole;
        queue.insert(qi, p);
      } else {
        for (final i in cells) {
          own[i] = hole;
        }
      }
    }

    // ---- 3. plug holes: grow tails into them, or drop in new dominoes.
    var grew = true;
    while (grew) {
      grew = false;
      for (var x = 0; x < n; x++) {
        if (own[x] != hole) continue;
        for (final j in nbrs(x)) {
          final t = own[j];
          if (t < 0) continue;
          final cells = orient[t];
          if (cells == null || cells.first != j) continue;
          if (cells.length >= maxLen + 4 || rays[t]!.contains(x)) continue;
          var ok = true;
          for (final e in rays.entries) {
            if (e.key != t && e.value.contains(x) && reaches(t, e.key)) {
              ok = false;
              break;
            }
          }
          if (!ok) continue;
          cells.insert(0, x);
          own[x] = t;
          grew = true;
          break;
        }
      }
    }
    for (var x = 0; x < n; x++) {
      if (own[x] != hole) continue;
      for (final y in nbrs(x)) {
        if (own[y] != hole) continue;
        final q = pieces.length;
        pieces.add([x, y]);
        own[x] = own[y] = q;
        if (orientPiece(q)) break;
        own[x] = own[y] = hole;
        pieces.removeLast();
      }
    }

    final snakes = <Snake>[];
    for (var p = 0; p < pieces.length; p++) {
      final cells = orient[p];
      if (cells == null || own[cells.first] != p) continue;
      snakes.add(Snake(snakes.length, List.unmodifiable(cells),
          dirOf(cells[cells.length - 2], cells.last)));
    }
    return snakes;
  }
}
