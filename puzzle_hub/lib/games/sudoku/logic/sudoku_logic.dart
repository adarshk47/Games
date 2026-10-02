import 'dart:math';

enum Difficulty { easy, medium, hard, expert }

extension DifficultyX on Difficulty {
  String get label => name[0].toUpperCase() + name.substring(1);

  /// Target number of given cells.
  int get clues => switch (this) {
        Difficulty.easy => 40,
        Difficulty.medium => 34,
        Difficulty.hard => 29,
        Difficulty.expert => 25,
      };
}

class SudokuPuzzle {
  final List<int> puzzle; // 81 cells, 0 = empty
  final List<int> solution;
  const SudokuPuzzle(this.puzzle, this.solution);
}

int _bit(int v) => 1 << v;

/// Counts solutions of [grid] (81 ints, 0 = empty) up to [limit].
int countSolutions(List<int> grid, {int limit = 2}) {
  final g = List<int>.from(grid);
  final rows = List<int>.filled(9, 0);
  final cols = List<int>.filled(9, 0);
  final boxes = List<int>.filled(9, 0);
  for (var i = 0; i < 81; i++) {
    final v = g[i];
    if (v != 0) {
      final r = i ~/ 9, c = i % 9, b = (r ~/ 3) * 3 + c ~/ 3;
      if ((rows[r] & _bit(v)) != 0 || (cols[c] & _bit(v)) != 0 || (boxes[b] & _bit(v)) != 0) {
        return 0;
      }
      rows[r] |= _bit(v);
      cols[c] |= _bit(v);
      boxes[b] |= _bit(v);
    }
  }
  var count = 0;
  void rec() {
    if (count >= limit) return;
    var best = -1, bestMask = 0, bestN = 10;
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final r = i ~/ 9, c = i % 9, b = (r ~/ 3) * 3 + c ~/ 3;
      final avail = ~(rows[r] | cols[c] | boxes[b]) & 0x3FE;
      final n = _pop(avail);
      if (n < bestN) {
        bestN = n;
        best = i;
        bestMask = avail;
        if (n <= 1) break;
      }
    }
    if (best == -1) {
      count++;
      return;
    }
    if (bestN == 0) return;
    final r = best ~/ 9, c = best % 9, b = (r ~/ 3) * 3 + c ~/ 3;
    for (var v = 1; v <= 9; v++) {
      if ((bestMask & _bit(v)) == 0) continue;
      g[best] = v;
      rows[r] |= _bit(v);
      cols[c] |= _bit(v);
      boxes[b] |= _bit(v);
      rec();
      rows[r] &= ~_bit(v);
      cols[c] &= ~_bit(v);
      boxes[b] &= ~_bit(v);
      g[best] = 0;
      if (count >= limit) return;
    }
  }

  rec();
  return count;
}

int _pop(int x) {
  var n = 0;
  while (x != 0) {
    x &= x - 1;
    n++;
  }
  return n;
}

/// Solves [grid]; returns null if no solution.
List<int>? solve(List<int> grid) {
  final g = List<int>.from(grid);
  return _fill(g, null) ? g : null;
}

/// Backtracking fill; if [rng] given, digit order is randomized.
bool _fill(List<int> g, Random? rng) {
  var best = -1, bestN = 10;
  List<int> bestCands = const [];
  for (var i = 0; i < 81; i++) {
    if (g[i] != 0) continue;
    final cands = candidates(g, i);
    if (cands.length < bestN) {
      bestN = cands.length;
      best = i;
      bestCands = cands;
      if (bestN <= 1) break;
    }
  }
  if (best == -1) return true;
  final list = List<int>.from(bestCands);
  if (rng != null) list.shuffle(rng);
  for (final v in list) {
    g[best] = v;
    if (_fill(g, rng)) return true;
  }
  g[best] = 0;
  return false;
}

List<int> candidates(List<int> g, int i) {
  final r = i ~/ 9, c = i % 9;
  var used = 0;
  for (var k = 0; k < 9; k++) {
    used |= _bit(g[r * 9 + k]) | _bit(g[k * 9 + c]);
  }
  final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
  for (var a = 0; a < 3; a++) {
    for (var b = 0; b < 3; b++) {
      used |= _bit(g[(br + a) * 9 + bc + b]);
    }
  }
  return [for (var v = 1; v <= 9; v++) if ((used & _bit(v)) == 0) v];
}

List<int> generateFullGrid(Random rng) {
  final g = List<int>.filled(81, 0);
  _fill(g, rng);
  return g;
}

bool isValidSolvedGrid(List<int> g) {
  if (g.length != 81) return false;
  for (var u = 0; u < 9; u++) {
    var r = 0, c = 0, b = 0;
    for (var k = 0; k < 9; k++) {
      r |= _bit(g[u * 9 + k]);
      c |= _bit(g[k * 9 + u]);
      final br = u ~/ 3 * 3 + k ~/ 3, bc = u % 3 * 3 + k % 3;
      b |= _bit(g[br * 9 + bc]);
    }
    if (r != 0x3FE || c != 0x3FE || b != 0x3FE) return false;
  }
  return true;
}

SudokuPuzzle generatePuzzle(Difficulty d, {int? seed}) {
  final rng = Random(seed);
  final solution = generateFullGrid(rng);
  final puzzle = List<int>.from(solution);
  final order = List<int>.generate(81, (i) => i)..shuffle(rng);
  var clues = 81;
  for (final i in order) {
    if (clues <= d.clues) break;
    final old = puzzle[i];
    puzzle[i] = 0;
    if (countSolutions(puzzle) != 1) {
      puzzle[i] = old;
    } else {
      clues--;
    }
  }
  return SudokuPuzzle(puzzle, solution);
}

/// Top-level entry usable with `compute`: [args] = [difficultyIndex, seed or -1].
Map<String, List<int>> generateForIsolate(List<int> args) {
  final p = generatePuzzle(Difficulty.values[args[0]], seed: args[1] < 0 ? null : args[1]);
  return {'puzzle': p.puzzle, 'solution': p.solution};
}

int dailySeed(DateTime d) => d.year * 10000 + d.month * 100 + d.day;
