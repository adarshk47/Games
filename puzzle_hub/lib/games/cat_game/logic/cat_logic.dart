import 'dart:collection';
import 'dart:math';

enum Dir { up, down, left, right }

extension DirX on Dir {
  int get dr => this == Dir.up ? -1 : (this == Dir.down ? 1 : 0);
  int get dc => this == Dir.left ? -1 : (this == Dir.right ? 1 : 0);
}

enum Cell { empty, wall, yarn, dog }

enum SlideOutcome { blocked, moved, fish, dog }

class SlideResult {
  const SlideResult(this.outcome, this.path);

  /// Cells entered, in order (excluding the start cell). Includes the fish/dog
  /// cell when the outcome is fish/dog.
  final List<int> path;
  final SlideOutcome outcome;
  int get end => path.last;
}

class CatLevel {
  CatLevel({
    required this.width,
    required this.height,
    required this.cells,
    required this.start,
    required this.fish,
  });

  /// Parses rows: '.' empty, '#' box, 'Y' yarn, 'D' dog, 'C' cat, 'F' fish.
  factory CatLevel.parse(List<String> rows) {
    final h = rows.length, w = rows.first.length;
    final cells = List<Cell>.filled(w * h, Cell.empty);
    var start = -1, fish = -1;
    for (var r = 0; r < h; r++) {
      for (var c = 0; c < w; c++) {
        final i = r * w + c;
        switch (rows[r][c]) {
          case '#':
            cells[i] = Cell.wall;
          case 'Y':
            cells[i] = Cell.yarn;
          case 'D':
            cells[i] = Cell.dog;
          case 'C':
            start = i;
          case 'F':
            fish = i;
        }
      }
    }
    return CatLevel(width: w, height: h, cells: cells, start: start, fish: fish);
  }

  final int width, height;
  final List<Cell> cells;
  final int start, fish;

  /// Optimal number of moves; null if unsolvable. Cached.
  late final int? optimal = CatSolver.solve(this)?.length;

  /// Slide rules: cat moves until the next cell is out of bounds or an
  /// obstacle (box/yarn). Fish stops the cat (win); dog stops the cat (fail).
  SlideResult slide(int from, Dir d) {
    var r = from ~/ width, c = from % width;
    final path = <int>[];
    while (true) {
      final nr = r + d.dr, nc = c + d.dc;
      if (nr < 0 || nc < 0 || nr >= height || nc >= width) break;
      final i = nr * width + nc;
      final cell = cells[i];
      if (cell == Cell.wall || cell == Cell.yarn) break;
      path.add(i);
      r = nr;
      c = nc;
      if (cell == Cell.dog) return SlideResult(SlideOutcome.dog, path);
      if (i == fish) return SlideResult(SlideOutcome.fish, path);
    }
    return SlideResult(
        path.isEmpty ? SlideOutcome.blocked : SlideOutcome.moved, path);
  }
}

class CatSolver {
  /// BFS; returns shortest list of directions to reach the fish, or null.
  static List<Dir>? solve(CatLevel level, [int? from]) {
    final s = from ?? level.start;
    final prev = <int, (int, Dir)>{};
    final seen = {s};
    final q = Queue<int>()..add(s);
    while (q.isNotEmpty) {
      final p = q.removeFirst();
      for (final d in Dir.values) {
        final res = level.slide(p, d);
        if (res.outcome == SlideOutcome.blocked ||
            res.outcome == SlideOutcome.dog) {
          continue;
        }
        final e = res.end;
        if (res.outcome == SlideOutcome.fish) {
          final out = <Dir>[d];
          var cur = p;
          while (cur != s) {
            final (pp, pd) = prev[cur]!;
            out.add(pd);
            cur = pp;
          }
          return out.reversed.toList();
        }
        if (seen.add(e)) {
          prev[e] = (p, d);
          q.add(e);
        }
      }
    }
    return null;
  }
}

int starsFor(int moves, int par) {
  if (moves <= par) return 3;
  if (moves <= par + 2) return 2;
  return 1;
}

/// Procedural, deterministic levels (seeded) verified solvable via BFS.
class CatLevels {
  static const int count = 40;
  static final Map<int, CatLevel> _cache = {};

  static CatLevel level(int index) => _cache[index] ??= _generate(index);

  static CatLevel _generate(int index) {
    final rng = Random(4242 + index * 7919);
    final size = 5 + index ~/ 10;
    final n = size * size;
    var target = min(2 + index ~/ 4, 9);
    final dogs = index < 4 ? 0 : min(1 + index ~/ 8, 4);
    final obstacles = (n * (0.14 + 0.004 * index)).round();
    for (var attempt = 0; attempt < 6000; attempt++) {
      if (attempt > 0 && attempt % 150 == 0 && target > 1) target--;
      final cells = List<Cell>.filled(n, Cell.empty);
      final free = List<int>.generate(n, (i) => i)..shuffle(rng);
      var k = 0;
      for (var i = 0; i < obstacles; i++) {
        cells[free[k++]] = rng.nextInt(4) == 0 ? Cell.yarn : Cell.wall;
      }
      for (var i = 0; i < dogs; i++) {
        cells[free[k++]] = Cell.dog;
      }
      final start = free[k++];
      final fish = free[k++];
      final lvl = CatLevel(
          width: size, height: size, cells: cells, start: start, fish: fish);
      final opt = lvl.optimal;
      if (opt != null && opt >= target) return lvl;
    }
    return CatLevel.parse(['C...F', '.....', '.....', '.....', '.....']);
  }
}
