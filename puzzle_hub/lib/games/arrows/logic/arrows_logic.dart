import 'dart:math';

enum Dir {
  up(-1, 0),
  down(1, 0),
  left(0, -1),
  right(0, 1);

  const Dir(this.dr, this.dc);
  final int dr, dc;
}

class ArrowPiece {
  const ArrowPiece(this.id, this.r, this.c, this.dir);
  final int id, r, c;
  final Dir dir;
}

/// Mutable board state; arrows are removed as they slide out.
class ArrowsBoard {
  ArrowsBoard(this.size, Iterable<ArrowPiece> pieces)
      : _grid = List.generate(size, (_) => List<ArrowPiece?>.filled(size, null)) {
    for (final p in pieces) {
      _grid[p.r][p.c] = p;
    }
  }

  final int size;
  final List<List<ArrowPiece?>> _grid;

  ArrowPiece? at(int r, int c) => _grid[r][c];

  List<ArrowPiece> get pieces => [
        for (final row in _grid)
          for (final p in row) ?p
      ];

  int get remaining => pieces.length;
  bool get isCleared => remaining == 0;

  /// True if every cell between the arrow and the edge (in its direction) is empty.
  bool canRemove(ArrowPiece p) {
    var r = p.r + p.dir.dr, c = p.c + p.dir.dc;
    while (r >= 0 && c >= 0 && r < size && c < size) {
      if (_grid[r][c] != null) return false;
      r += p.dir.dr;
      c += p.dir.dc;
    }
    return true;
  }

  /// Taps the arrow at (r,c). Returns true if removed, false if blocked,
  /// null if the cell is empty.
  bool? tap(int r, int c) {
    final p = _grid[r][c];
    if (p == null) return null;
    if (!canRemove(p)) return false;
    _grid[r][c] = null;
    return true;
  }

  /// First removable arrow, or null.
  ArrowPiece? hint() {
    for (final p in pieces) {
      if (canRemove(p)) return p;
    }
    return null;
  }

  /// Removing never blocks anything, so greedy clearing decides solvability.
  bool isSolvable() {
    final copy = ArrowsBoard(size, pieces);
    while (!copy.isCleared) {
      final h = copy.hint();
      if (h == null) return false;
      copy._grid[h.r][h.c] = null;
    }
    return true;
  }
}

enum ArrowsTier {
  easy('easy', 'Easy', 3, 4, 6, 0.45, 0.60),
  medium('medium', 'Medium', 3, 5, 7, 0.50, 0.70),
  hard('hard', 'Hard', 2, 7, 9, 0.60, 0.80),
  extreme('extreme', 'Extreme', 1, 9, 12, 0.75, 0.90);

  const ArrowsTier(this.id, this.label, this.lives, this.minSize, this.maxSize,
      this.minDensity, this.maxDensity);
  final String id, label;
  final int lives, minSize, maxSize;
  final double minDensity, maxDensity;

  static ArrowsTier fromId(String? id) =>
      values.firstWhere((t) => t.id == id, orElse: () => ArrowsTier.easy);
}

class ArrowsLevels {
  /// Levels per tier.
  static const int count = 30;

  static int sizeFor(ArrowsTier t, int level) {
    final span = t.maxSize - t.minSize;
    return t.minSize + ((level - 1) * (span + 1)) ~/ count;
  }

  static double densityFor(ArrowsTier t, int level) =>
      t.minDensity + (t.maxDensity - t.minDensity) * (level - 1) / (count - 1);

  /// Deterministic and always solvable. Arrows are placed one at a time and
  /// each new arrow must have a clear path among those already placed, so the
  /// reverse placement order is a valid clearing order.
  static ArrowsBoard generate(ArrowsTier tier, int level) {
    final n = sizeFor(tier, level);
    final rng = Random(level * 7919 + 13 + tier.index * 100003);
    final target = max(4, (n * n * densityFor(tier, level)).round());
    final cells = <(int, int)>[
      for (var r = 0; r < n; r++)
        for (var c = 0; c < n; c++) (r, c)
    ]..shuffle(rng);
    final board = ArrowsBoard(n, const []);
    var id = 0;
    for (final (r, c) in cells) {
      if (id >= target) break;
      final dirs = Dir.values.toList()..shuffle(rng);
      for (final d in dirs) {
        final p = ArrowPiece(id, r, c, d);
        if (board.canRemove(p)) {
          board._grid[r][c] = p;
          id++;
          break;
        }
      }
    }
    return board;
  }
}
