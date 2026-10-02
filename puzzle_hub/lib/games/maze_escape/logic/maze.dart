import 'dart:math';

/// Direction indices: N=0, E=1, S=2, W=3 (bit = 1 << dir).
const List<int> kDx = [0, 1, 0, -1];
const List<int> kDy = [-1, 0, 1, 0];

int opposite(int d) => (d + 2) % 4;

/// A perfect maze (spanning tree): exactly one route between any two cells.
class Maze {
  Maze(this.w, this.h, this.open, this.start, this.exit);
  final int w;
  final int h;

  /// Per cell bitmask of open passages (bit d set = can walk in direction d).
  final List<int> open;
  final int start;
  final int exit;

  int idx(int x, int y) => y * w + x;
  int xOf(int i) => i % w;
  int yOf(int i) => i ~/ w;
  int get cellCount => w * h;

  bool canMove(int cell, int dir) => (open[cell] & (1 << dir)) != 0;

  /// Neighbour index in [dir] (ignores walls), or -1 if outside.
  int neighbour(int cell, int dir) {
    final x = xOf(cell) + kDx[dir];
    final y = yOf(cell) + kDy[dir];
    if (x < 0 || y < 0 || x >= w || y >= h) return -1;
    return idx(x, y);
  }

  int openings(int cell) {
    var n = 0;
    for (var d = 0; d < 4; d++) {
      if (canMove(cell, d)) n++;
    }
    return n;
  }

  bool isDeadEnd(int cell) => openings(cell) == 1 && cell != start && cell != exit;

  int get deadEndCount => [for (var i = 0; i < cellCount; i++) if (isDeadEnd(i)) i].length;

  /// Number of open passages (each counted once). A perfect maze has cells-1.
  int get edgeCount {
    var n = 0;
    for (var i = 0; i < cellCount; i++) {
      n += openings(i);
    }
    return n ~/ 2;
  }

  /// BFS shortest path from [from] to [to], inclusive. Empty if unreachable.
  List<int> solve({int? from, int? to}) {
    final a = from ?? start;
    final b = to ?? exit;
    final prev = List<int>.filled(cellCount, -2);
    prev[a] = -1;
    final q = <int>[a];
    for (var qi = 0; qi < q.length; qi++) {
      final c = q[qi];
      if (c == b) break;
      for (var d = 0; d < 4; d++) {
        if (!canMove(c, d)) continue;
        final n = neighbour(c, d);
        if (n < 0 || prev[n] != -2) continue;
        prev[n] = c;
        q.add(n);
      }
    }
    if (prev[b] == -2) return const [];
    final path = <int>[];
    for (var c = b; c != -1; c = prev[c]) {
      path.add(c);
    }
    return path.reversed.toList();
  }

  /// Number of moves on the optimal route start -> exit.
  int get optimalMoves => solve().length - 1;

  /// Number of cells reachable from [start].
  int reachableCount() {
    final seen = List<bool>.filled(cellCount, false);
    final st = <int>[start];
    seen[start] = true;
    var n = 0;
    while (st.isNotEmpty) {
      final c = st.removeLast();
      n++;
      for (var d = 0; d < 4; d++) {
        if (!canMove(c, d)) continue;
        final nb = neighbour(c, d);
        if (nb >= 0 && !seen[nb]) {
          seen[nb] = true;
          st.add(nb);
        }
      }
    }
    return n;
  }

  /// Seeded recursive-backtracker generator. Start is the top-left cell, the
  /// exit is the cell farthest from it.
  static Maze generate(int seed, int w, int h) {
    final rnd = Random(seed);
    final open = List<int>.filled(w * h, 0);
    final seen = List<bool>.filled(w * h, false);
    final stack = <int>[0];
    seen[0] = true;
    while (stack.isNotEmpty) {
      final c = stack.last;
      final cx = c % w, cy = c ~/ w;
      final dirs = <int>[];
      for (var d = 0; d < 4; d++) {
        final nx = cx + kDx[d], ny = cy + kDy[d];
        if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
        if (!seen[ny * w + nx]) dirs.add(d);
      }
      if (dirs.isEmpty) {
        stack.removeLast();
        continue;
      }
      final d = dirs[rnd.nextInt(dirs.length)];
      final n = (cy + kDy[d]) * w + cx + kDx[d];
      open[c] |= 1 << d;
      open[n] |= 1 << opposite(d);
      seen[n] = true;
      stack.add(n);
    }
    final tmp = Maze(w, h, open, 0, 0);
    final dist = List<int>.filled(w * h, -1);
    dist[0] = 0;
    final q = <int>[0];
    var far = 0;
    for (var qi = 0; qi < q.length; qi++) {
      final c = q[qi];
      if (dist[c] > dist[far]) far = c;
      for (var d = 0; d < 4; d++) {
        if (!tmp.canMove(c, d)) continue;
        final n = tmp.neighbour(c, d);
        if (dist[n] == -1) {
          dist[n] = dist[c] + 1;
          q.add(n);
        }
      }
    }
    return Maze(w, h, open, 0, far);
  }
}
