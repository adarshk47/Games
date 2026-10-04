import 'dart:math' as math;

enum MineTier { easy, medium, hard, extreme }

class MineConfig {
  const MineConfig(this.tier, this.label, this.cols, this.rows, this.mines, this.parSeconds);
  final MineTier tier;
  final String label;
  final int cols, rows, mines, parSeconds;
}

const mineConfigs = <MineTier, MineConfig>{
  MineTier.easy: MineConfig(MineTier.easy, 'Easy', 8, 8, 8, 60),
  MineTier.medium: MineConfig(MineTier.medium, 'Medium', 10, 10, 18, 150),
  MineTier.hard: MineConfig(MineTier.hard, 'Hard', 12, 16, 40, 360),
  MineTier.extreme: MineConfig(MineTier.extreme, 'Extreme', 14, 20, 70, 720),
};

enum MineStatus { ready, playing, won, lost }

/// 1-3 stars from the time versus the tier's par time.
int starsForTime(int seconds, int par, {bool usedHint = false}) {
  var s = seconds <= par ? 3 : (seconds <= par * 2 ? 2 : 1);
  if (usedHint && s > 2) s = 2;
  return s;
}

/// Pure-Dart Minesweeper board. Mines are placed lazily on the first reveal so
/// the first tap (and its neighbours) are always safe.
class MineGame {
  MineGame(this.cols, this.rows, this.mineCount, {math.Random? random, List<bool>? mines})
      : assert(mineCount < cols * rows),
        _rng = random ?? math.Random(),
        mine = List<bool>.filled(cols * rows, false),
        revealed = List<bool>.filled(cols * rows, false),
        flagged = List<bool>.filled(cols * rows, false),
        adj = List<int>.filled(cols * rows, 0) {
    if (mines != null) {
      for (var i = 0; i < mines.length; i++) {
        mine[i] = mines[i];
      }
      _placed = true;
      _computeAdj();
    }
  }

  factory MineGame.forTier(MineTier t, {math.Random? random}) {
    final c = mineConfigs[t]!;
    return MineGame(c.cols, c.rows, c.mines, random: random);
  }

  final int cols, rows, mineCount;
  final math.Random _rng;
  final List<bool> mine, revealed, flagged;
  final List<int> adj;
  bool _placed = false;
  MineStatus status = MineStatus.ready;
  int? explodedAt;

  int get size => cols * rows;
  bool get minesPlaced => _placed;
  int get flagCount => flagged.where((f) => f).length;
  int get minesLeft => mineCount - flagCount;
  int get revealedCount => revealed.where((r) => r).length;
  bool get over => status == MineStatus.won || status == MineStatus.lost;

  int idx(int r, int c) => r * cols + c;

  Iterable<int> neighbors(int i) sync* {
    final r = i ~/ cols, c = i % cols;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final nr = r + dr, nc = c + dc;
        if (nr < 0 || nc < 0 || nr >= rows || nc >= cols) continue;
        yield nr * cols + nc;
      }
    }
  }

  void _place(int safe) {
    final banned = <int>{safe, ...neighbors(safe)};
    var candidates = [for (var i = 0; i < size; i++) if (!banned.contains(i)) i];
    // Tiny boards: fall back to excluding only the tapped cell.
    if (candidates.length < mineCount) {
      candidates = [for (var i = 0; i < size; i++) if (i != safe) i];
    }
    candidates.shuffle(_rng);
    for (var k = 0; k < mineCount; k++) {
      mine[candidates[k]] = true;
    }
    _placed = true;
    _computeAdj();
  }

  void _computeAdj() {
    for (var i = 0; i < size; i++) {
      adj[i] = neighbors(i).where((n) => mine[n]).length;
    }
  }

  /// Reveals [i]. Returns the list of newly revealed cells in reveal (BFS)
  /// order; empty when nothing happened.
  List<int> reveal(int i) {
    if (over || revealed[i] || flagged[i]) return const [];
    if (!_placed) _place(i);
    if (status == MineStatus.ready) status = MineStatus.playing;
    if (mine[i]) {
      _lose(i);
      return [i];
    }
    final out = <int>[];
    final q = <int>[i];
    revealed[i] = true;
    while (q.isNotEmpty) {
      final cur = q.removeAt(0);
      out.add(cur);
      if (adj[cur] != 0) continue;
      for (final n in neighbors(cur)) {
        if (revealed[n] || flagged[n] || mine[n]) continue;
        revealed[n] = true;
        q.add(n);
      }
    }
    _checkWin();
    return out;
  }

  void _lose(int at) {
    explodedAt = at;
    status = MineStatus.lost;
    for (var i = 0; i < size; i++) {
      if (mine[i] && !flagged[i]) revealed[i] = true;
    }
    revealed[at] = true;
  }

  void _checkWin() {
    if (status != MineStatus.playing) return;
    if (revealedCount == size - mineCount) {
      status = MineStatus.won;
      for (var i = 0; i < size; i++) {
        if (mine[i]) flagged[i] = true;
      }
    }
  }

  bool toggleFlag(int i) {
    if (over || revealed[i]) return false;
    flagged[i] = !flagged[i];
    return true;
  }

  /// Chord: on a revealed number whose adjacent flag count equals its number,
  /// reveals all unflagged neighbours (may hit a mine if flags are wrong).
  List<int> chord(int i) {
    if (over || !revealed[i] || adj[i] == 0 || mine[i]) return const [];
    final ns = neighbors(i).toList();
    if (ns.where((n) => flagged[n]).length != adj[i]) return const [];
    final out = <int>[];
    for (final n in ns) {
      if (flagged[n] || revealed[n]) continue;
      out.addAll(reveal(n));
      if (status == MineStatus.lost) break;
    }
    return out;
  }

  /// Reveals one safe unrevealed cell (prefers frontier cells next to numbers).
  /// Returns the cells revealed, empty if none available.
  List<int> hint() {
    if (over) return const [];
    if (!_placed) return reveal(idx(rows ~/ 2, cols ~/ 2));
    final safe = [for (var i = 0; i < size; i++) if (!mine[i] && !revealed[i]) i];
    if (safe.isEmpty) return const [];
    final frontier = safe.where((i) => neighbors(i).any((n) => revealed[n])).toList();
    final pool = frontier.isNotEmpty ? frontier : safe;
    final pick = pool[_rng.nextInt(pool.length)];
    flagged[pick] = false;
    return reveal(pick);
  }
}
