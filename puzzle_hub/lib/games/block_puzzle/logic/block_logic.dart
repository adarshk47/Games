import 'dart:math';

/// A polyomino: list of (row, col) offsets normalised to start at 0,0.
class Piece {
  Piece(this.cells, this.color)
      : h = cells.map((c) => c.$1).reduce(max) + 1,
        w = cells.map((c) => c.$2).reduce(max) + 1;
  final List<(int, int)> cells;
  final int color; // 0..7
  final int h, w;
  int get size => cells.length;
}

List<(int, int)> _normalise(List<(int, int)> cs) {
  final mr = cs.map((c) => c.$1).reduce(min);
  final mc = cs.map((c) => c.$2).reduce(min);
  final out = cs.map((c) => (c.$1 - mr, c.$2 - mc)).toList()
    ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
  return out;
}

List<(int, int)> _parse(List<String> rows) {
  final out = <(int, int)>[];
  for (var r = 0; r < rows.length; r++) {
    for (var c = 0; c < rows[r].length; c++) {
      if (rows[r][c] == '#') out.add((r, c));
    }
  }
  return out;
}

List<List<(int, int)>> _orientations(List<(int, int)> base) {
  final seen = <String>{};
  final res = <List<(int, int)>>[];
  var cur = base;
  for (var f = 0; f < 2; f++) {
    for (var r = 0; r < 4; r++) {
      cur = _normalise(cur.map((c) => (c.$2, -c.$1)).toList());
      final k = cur.join();
      if (seen.add(k)) res.add(cur);
    }
    cur = _normalise(cur.map((c) => (c.$1, -c.$2)).toList());
  }
  return res;
}

/// Catalogue of every shape (each rotation is its own shape: no rotating in game).
class Shapes {
  Shapes._();

  static final List<List<String>> _bases = [
    ['#'],
    ['##'],
    ['###'],
    ['####'],
    ['#####'],
    ['##', '##'],
    ['##', '#.'], // small L (3)
    ['#.', '#.', '##'], // L (4)
    ['###', '.#.'], // T (4)
    ['.##', '##.'], // S (4)
    ['#..', '#..', '###'], // big corner (5)
    ['###', '.#.', '.#.'], // big T (5)
    ['##', '##', '#.'], // P (5)
    ['#.#', '###'], // U (5)
  ];

  static final List<List<(int, int)>> all = [
    for (final b in _bases) ..._orientations(_parse(b)),
  ];
}

enum Tier { easy, medium, hard, extreme }

extension TierInfo on Tier {
  String get label => const ['Easy', 'Medium', 'Hard', 'Extreme'][index];
  int get boardSize => this == Tier.extreme ? 10 : 8;
  int get prefill => const [0, 0, 7, 22][index];
  bool get guarantee => this == Tier.easy;
  int get winScore => const [800, 700, 600, 500][index];

  /// Relative weight of a shape with [n] cells.
  double weight(int n) {
    switch (this) {
      case Tier.easy:
        return const {1: 2.5, 2: 3.0, 3: 2.5, 4: 1.2, 5: 0.5}[n] ?? 1;
      case Tier.medium:
        return 1;
      case Tier.hard:
        return const {1: 0.4, 2: 0.7, 3: 1.0, 4: 1.6, 5: 2.0}[n] ?? 1;
      case Tier.extreme:
        return const {1: 0.1, 2: 0.4, 3: 0.8, 4: 1.8, 5: 3.0}[n] ?? 1;
    }
  }
}

class PlaceResult {
  const PlaceResult(this.rows, this.cols, this.cleared, this.gained, this.streak);
  final List<int> rows;
  final List<int> cols;

  /// Cells removed as (row, col, color).
  final List<(int, int, int)> cleared;
  final int gained;
  final int streak;
  int get lines => rows.length + cols.length;
}

/// Pure game state. Grid cells: -1 empty, otherwise colour index.
class BlockGame {
  BlockGame(this.tier, {Random? rng}) : rng = rng ?? Random() {
    n = tier.boardSize;
    grid = List.generate(n, (_) => List.filled(n, -1));
    _prefill();
    refill();
  }

  /// Custom state for tests.
  BlockGame.custom(this.tier, this.grid, {Random? rng}) : rng = rng ?? Random() {
    n = grid.length;
  }

  final Tier tier;
  final Random rng;
  late final int n;
  late List<List<int>> grid;
  List<Piece?> tray = [null, null, null];
  int score = 0;
  int streak = 0; // consecutive placements that cleared lines
  bool over = false;

  /// Board / tray / score before each of the last 3 placements (undo).
  final List<(List<List<int>>, List<Piece?>, int, int)> _undo = [];
  static const maxUndo = 3;

  int get undoDepth => _undo.length;

  /// Saved-game snapshot (board, tray, score) so a game can be continued.
  Map<String, Object> toJson() => {
        'tier': tier.name,
        'grid': [for (final row in grid) List<int>.of(row)],
        'tray': [
          for (final p in tray)
            p == null ? null : {'c': p.color, 'cells': [for (final (r, c) in p.cells) [r, c]]},
        ],
        'score': score,
        'streak': streak,
      };

  /// Rebuilds a game from [toJson]; null if the data does not fit [tier].
  static BlockGame? fromJson(Tier tier, Map<String, dynamic> j) {
    try {
      if (j['tier'] != tier.name) return null;
      final grid = [for (final row in j['grid'] as List) (row as List).cast<int>().toList()];
      if (grid.length != tier.boardSize) return null;
      final g = BlockGame.custom(tier, grid);
      g.tray = [
        for (final p in j['tray'] as List)
          p == null
              ? null
              : Piece([for (final rc in (p as Map)['cells'] as List) ((rc as List)[0] as int, rc[1] as int)], p['c'] as int),
      ];
      g.score = j['score'] as int;
      g.streak = j['streak'] as int;
      if (g.tray.every((p) => p == null)) g.refill();
      g.over = g.isGameOver;
      return g;
    } catch (_) {
      return null;
    }
  }

  /// Takes back the last placement. Returns false when there is none.
  bool undo() {
    if (_undo.isEmpty) return false;
    final (g, t, sc, st) = _undo.removeLast();
    grid = g;
    tray = t;
    score = sc;
    streak = st;
    over = false;
    return true;
  }

  void _prefill() {
    var left = tier.prefill;
    var guard = 0;
    while (left > 0 && guard++ < 500) {
      final r = rng.nextInt(n), c = rng.nextInt(n);
      if (grid[r][c] != -1) continue;
      grid[r][c] = rng.nextInt(8);
      left--;
    }
  }

  bool canPlace(Piece p, int r, int c) {
    for (final (dr, dc) in p.cells) {
      final rr = r + dr, cc = c + dc;
      if (rr < 0 || cc < 0 || rr >= n || cc >= n || grid[rr][cc] != -1) return false;
    }
    return true;
  }

  bool fitsAnywhere(Piece p) {
    for (var r = 0; r <= n - p.h; r++) {
      for (var c = 0; c <= n - p.w; c++) {
        if (canPlace(p, r, c)) return true;
      }
    }
    return false;
  }

  bool get isGameOver {
    final left = tray.whereType<Piece>();
    if (left.isEmpty) return false;
    return !left.any(fitsAnywhere);
  }

  Piece _pick() {
    final pool = Shapes.all;
    final ws = pool.map((s) => tier.weight(s.length)).toList();
    var t = rng.nextDouble() * ws.reduce((a, b) => a + b);
    var i = 0;
    for (; i < pool.length - 1; i++) {
      t -= ws[i];
      if (t <= 0) break;
    }
    return Piece(pool[i], rng.nextInt(8));
  }

  /// Fills the tray with 3 new pieces. Easy guarantees at least one fits.
  void refill() {
    for (var attempt = 0; attempt < 60; attempt++) {
      tray = [_pick(), _pick(), _pick()];
      if (!tier.guarantee || tray.whereType<Piece>().any(fitsAnywhere)) return;
    }
    // Fallback: force a single-cell piece (fits whenever any cell is free).
    tray = [_pick(), Piece(const [(0, 0)], rng.nextInt(8)), _pick()];
  }

  /// Places tray piece [slot] with its top-left at (r,c). Returns null if invalid.
  PlaceResult? place(int slot, int r, int c) {
    final p = tray[slot];
    if (p == null || over || !canPlace(p, r, c)) return null;
    _undo.add(([for (final row in grid) List<int>.from(row)], List<Piece?>.from(tray), score, streak));
    if (_undo.length > maxUndo) _undo.removeAt(0);
    for (final (dr, dc) in p.cells) {
      grid[r + dr][c + dc] = p.color;
    }
    tray[slot] = null;

    final rows = [for (var i = 0; i < n; i++) if (grid[i].every((v) => v != -1)) i];
    final cols = [
      for (var j = 0; j < n; j++)
        if (List.generate(n, (i) => grid[i][j]).every((v) => v != -1)) j
    ];
    final cleared = <(int, int, int)>[];
    final seen = <int>{};
    for (final i in rows) {
      for (var j = 0; j < n; j++) {
        if (seen.add(i * n + j)) cleared.add((i, j, grid[i][j]));
      }
    }
    for (final j in cols) {
      for (var i = 0; i < n; i++) {
        if (seen.add(i * n + j)) cleared.add((i, j, grid[i][j]));
      }
    }
    for (final (i, j, _) in cleared) {
      grid[i][j] = -1;
    }
    final lines = rows.length + cols.length;
    streak = lines > 0 ? streak + 1 : 0;
    final gained = scoreFor(p.size, lines, streak);
    score += gained;
    if (tray.every((e) => e == null)) refill();
    if (isGameOver) over = true;
    return PlaceResult(rows, cols, cleared, gained, streak);
  }

  /// Cells placed + 10 per line scaled by simultaneous lines (combo bonus)
  /// + streak bonus for chained clears.
  static int scoreFor(int cells, int lines, int streak) {
    if (lines == 0) return cells;
    return cells + 10 * lines * lines + (streak > 1 ? 5 * (streak - 1) * lines : 0);
  }
}
