// Computer opponent: iterative-deepening alpha-beta (negamax) with
// quiescence search, MVV-LVA / killer / history move ordering, a small
// transposition table for best-move ordering and piece-square tables.
// Pure Dart; run it via [chessSearchEntry] inside `compute` so the UI never
// blocks.

import 'dart:math' as math;

import 'chess_engine.dart';

enum ChessLevel { easy, medium, hard, extreme }

/// Search settings for a level.
class AiConfig {
  const AiConfig(this.depth, this.timeMs, this.noise);
  final int depth;
  final int timeMs;

  /// Random centipawns added to root scores (makes weak levels human-like).
  final int noise;

  static const Map<ChessLevel, AiConfig> levels = {
    ChessLevel.easy: AiConfig(1, 300, 140),
    ChessLevel.medium: AiConfig(2, 700, 45),
    ChessLevel.hard: AiConfig(4, 1500, 0),
    ChessLevel.extreme: AiConfig(32, 3000, 0),
  };
}

const int _mate = 100000;
const List<int> _value = [0, 100, 320, 330, 500, 900, 0];

// Piece-square tables (Simplified Evaluation Function), written from
// white's point of view with rank 8 on the first row.
const List<int> _pstPawn = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  50, 50, 50, 50, 50, 50, 50, 50,
  10, 10, 20, 30, 30, 20, 10, 10,
  5, 5, 10, 25, 25, 10, 5, 5,
  0, 0, 0, 20, 20, 0, 0, 0,
  5, -5, -10, 0, 0, -10, -5, 5,
  5, 10, 10, -20, -20, 10, 10, 5,
  0, 0, 0, 0, 0, 0, 0, 0,
];
const List<int> _pstKnight = [
  -50, -40, -30, -30, -30, -30, -40, -50, //
  -40, -20, 0, 0, 0, 0, -20, -40,
  -30, 0, 10, 15, 15, 10, 0, -30,
  -30, 5, 15, 20, 20, 15, 5, -30,
  -30, 0, 15, 20, 20, 15, 0, -30,
  -30, 5, 10, 15, 15, 10, 5, -30,
  -40, -20, 0, 5, 5, 0, -20, -40,
  -50, -40, -30, -30, -30, -30, -40, -50,
];
const List<int> _pstBishop = [
  -20, -10, -10, -10, -10, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 10, 10, 5, 0, -10,
  -10, 5, 5, 10, 10, 5, 5, -10,
  -10, 0, 10, 10, 10, 10, 0, -10,
  -10, 10, 10, 10, 10, 10, 10, -10,
  -10, 5, 0, 0, 0, 0, 5, -10,
  -20, -10, -10, -10, -10, -10, -10, -20,
];
const List<int> _pstRook = [
  0, 0, 0, 0, 0, 0, 0, 0, //
  5, 10, 10, 10, 10, 10, 10, 5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  -5, 0, 0, 0, 0, 0, 0, -5,
  0, 0, 0, 5, 5, 0, 0, 0,
];
const List<int> _pstQueen = [
  -20, -10, -10, -5, -5, -10, -10, -20, //
  -10, 0, 0, 0, 0, 0, 0, -10,
  -10, 0, 5, 5, 5, 5, 0, -10,
  -5, 0, 5, 5, 5, 5, 0, -5,
  0, 0, 5, 5, 5, 5, 0, -5,
  -10, 5, 5, 5, 5, 5, 0, -10,
  -10, 0, 5, 0, 0, 0, 0, -10,
  -20, -10, -10, -5, -5, -10, -10, -20,
];
const List<int> _pstKingMid = [
  -30, -40, -40, -50, -50, -40, -40, -30, //
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -30, -40, -40, -50, -50, -40, -40, -30,
  -20, -30, -30, -40, -40, -30, -30, -20,
  -10, -20, -20, -20, -20, -20, -20, -10,
  20, 20, 0, 0, 0, 0, 20, 20,
  20, 30, 10, 0, 0, 10, 30, 20,
];
const List<int> _pstKingEnd = [
  -50, -40, -30, -20, -20, -30, -40, -50, //
  -30, -20, -10, 0, 0, -10, -20, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 30, 40, 40, 30, -10, -30,
  -30, -10, 20, 30, 30, 20, -10, -30,
  -30, -30, 0, 0, 0, 0, -30, -30,
  -50, -30, -30, -30, -30, -30, -30, -50,
];
const List<List<int>> _pst = [[], _pstPawn, _pstKnight, _pstBishop, _pstRook, _pstQueen, _pstKingMid];

/// Static evaluation in centipawns from the side to move's point of view.
int evaluate(Position p) {
  final b = p.board;
  var score = 0, phase = 0;
  for (var s = 0; s < 64; s++) {
    final q = b[s];
    if (q == 0) continue;
    final a = q.abs();
    if (a == pKnight || a == pBishop) phase += 1;
    if (a == pRook) phase += 2;
    if (a == pQueen) phase += 4;
  }
  final endgame = phase <= 6;
  for (var s = 0; s < 64; s++) {
    final q = b[s];
    if (q == 0) continue;
    final a = q.abs();
    final idx = q > 0 ? (7 - sqRank(s)) * 8 + sqFile(s) : sqRank(s) * 8 + sqFile(s);
    final table = a == pKing && endgame ? _pstKingEnd : _pst[a];
    final v = _value[a] + table[idx];
    score += q > 0 ? v : -v;
  }
  return p.whiteToMove ? score : -score;
}

class _Timeout implements Exception {}

class ChessSearcher {
  ChessSearcher(this.pos, {List<int> history = const [], int seed = 0}) : _rng = math.Random(seed) {
    _path.addAll(history);
  }

  final Position pos;
  final math.Random _rng;
  final List<int> _path = [];
  final Map<int, int> _tt = {};
  final List<List<int>> _killers = List.generate(128, (_) => [0, 0]);
  final List<int> _historyH = List.filled(64 * 64, 0);
  final Stopwatch _sw = Stopwatch();
  int _deadline = 0;
  int nodes = 0;
  int lastDepth = 0;

  /// Best move for the side to move, or null when there are no legal moves.
  int? search({int depth = 4, int timeMs = 1500, int noise = 0}) {
    final root = pos.legalMoves();
    if (root.isEmpty) return null;
    if (root.length == 1) return root.first;
    _sw
      ..reset()
      ..start();
    _deadline = timeMs;
    int best = root.first;
    if (noise > 0) {
      // Exact scores for each root move, plus noise (weak levels).
      var bestScore = -_mate * 2;
      for (final m in _ordered(root, 0, 0)) {
        pos.makeMove(m);
        _path.add(pos.hash);
        int sc;
        try {
          sc = -_negamax(depth - 1, -_mate * 2, _mate * 2, 1);
        } on _Timeout {
          _path.removeLast();
          pos.unmakeMove();
          break;
        }
        _path.removeLast();
        pos.unmakeMove();
        sc += _rng.nextInt(noise * 2 + 1) - noise;
        if (sc > bestScore) {
          bestScore = sc;
          best = m;
        }
      }
      lastDepth = depth;
      return best;
    }
    for (var d = 1; d <= depth; d++) {
      int? iterBest;
      var alpha = -_mate * 2;
      try {
        for (final m in _ordered(root, 0, _tt[pos.hash] ?? best)) {
          pos.makeMove(m);
          _path.add(pos.hash);
          int sc;
          try {
            sc = -_negamax(d - 1, -_mate * 2, -alpha, 1);
          } finally {
            _path.removeLast();
            pos.unmakeMove();
          }
          if (sc > alpha) {
            alpha = sc;
            iterBest = m;
          }
        }
      } on _Timeout {
        // The previous best is searched first, so a partial result is usable.
        if (iterBest != null) best = iterBest;
        break;
      }
      if (iterBest != null) best = iterBest;
      _tt[pos.hash] = best;
      lastDepth = d;
      if (alpha >= _mate - 200) break; // found a mate
      if (_sw.elapsedMilliseconds * 3 > _deadline) break; // next depth won't finish
    }
    return best;
  }

  bool _repeated() {
    if (pos.halfmove >= 100) return true;
    final h = pos.hash;
    final n = _path.length;
    // Only positions since the last irreversible move can repeat.
    for (var i = n - 3; i >= 0 && i >= n - 1 - pos.halfmove; i -= 2) {
      if (_path[i] == h) return true;
    }
    return false;
  }

  int _negamax(int depth, int alpha, int beta, int ply) {
    if ((++nodes & 1023) == 0 && _sw.elapsedMilliseconds > _deadline) throw _Timeout();
    if (_repeated()) return 0;
    final inCheck = pos.inCheck;
    if (inCheck) depth++;
    if (depth <= 0) return _quiesce(alpha, beta, ply);
    final moves = <int>[];
    pos.pseudoMoves(moves);
    final ttMove = _tt[pos.hash] ?? 0;
    var legal = 0;
    var bestMove = 0;
    for (final m in _ordered(moves, ply, ttMove)) {
      if (!pos.makeMove(m)) continue;
      legal++;
      _path.add(pos.hash);
      int sc;
      try {
        sc = -_negamax(depth - 1, -beta, -alpha, ply + 1);
      } finally {
        _path.removeLast();
        pos.unmakeMove();
      }
      if (sc > alpha) {
        alpha = sc;
        bestMove = m;
        if (alpha >= beta) {
          if (pos.board[moveTo(m)] == 0 && ply < 128) {
            final k = _killers[ply];
            if (k[0] != m) {
              k[1] = k[0];
              k[0] = m;
            }
            _historyH[moveFrom(m) * 64 + moveTo(m)] += depth * depth;
          }
          break;
        }
      }
    }
    if (legal == 0) return inCheck ? -_mate + ply : 0;
    if (bestMove != 0) _tt[pos.hash] = bestMove;
    if (_tt.length > 200000) _tt.clear();
    return alpha;
  }

  int _quiesce(int alpha, int beta, int ply) {
    if ((++nodes & 1023) == 0 && _sw.elapsedMilliseconds > _deadline) throw _Timeout();
    final stand = evaluate(pos);
    if (stand >= beta) return stand;
    if (stand > alpha) alpha = stand;
    if (ply > 40) return alpha;
    final moves = <int>[];
    pos.pseudoMoves(moves, capturesOnly: true);
    for (final m in _ordered(moves, 128, 0)) {
      // Delta pruning: even winning this piece cannot raise alpha.
      final victim = pos.board[moveTo(m)].abs();
      if (movePromo(m) == 0 && stand + _value[victim] + 200 < alpha) continue;
      if (!pos.makeMove(m)) continue;
      final sc = -_quiesce(-beta, -alpha, ply + 1);
      pos.unmakeMove();
      if (sc >= beta) return sc;
      if (sc > alpha) alpha = sc;
    }
    return alpha;
  }

  List<int> _ordered(List<int> moves, int ply, int ttMove) {
    final b = pos.board;
    final k = ply < 128 ? _killers[ply] : const [0, 0];
    final scored = <(int, int)>[];
    for (final m in moves) {
      int s;
      if (m == ttMove) {
        s = 1 << 30;
      } else {
        final victim = b[moveTo(m)].abs();
        if (victim != 0 || moveFlags(m) & mfEnPassant != 0) {
          s = (1 << 20) + _value[victim == 0 ? pPawn : victim] * 10 - _value[b[moveFrom(m)].abs()] ~/ 10;
        } else if (movePromo(m) != 0) {
          s = (1 << 19) + movePromo(m);
        } else if (m == k[0]) {
          s = 1 << 18;
        } else if (m == k[1]) {
          s = (1 << 18) - 1;
        } else {
          s = _historyH[moveFrom(m) * 64 + moveTo(m)].clamp(0, (1 << 17));
        }
      }
      scored.add((s, m));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in scored) e.$2];
  }
}

/// Isolate entry point for `compute`. Request keys: fen (String),
/// history (List of int hashes), depth, time, noise, seed (ints).
/// Returns the move as a UCI string, or '' if there is none.
String chessSearchEntry(Map<String, Object> req) {
  final pos = Position.fromFen(req['fen']! as String);
  final s = ChessSearcher(pos, history: (req['history'] as List?)?.cast<int>() ?? const [], seed: req['seed'] as int? ?? 0);
  final m = s.search(depth: req['depth']! as int, timeMs: req['time']! as int, noise: req['noise'] as int? ?? 0);
  return m == null ? '' : moveUci(m);
}

/// Builds a [chessSearchEntry] request.
Map<String, Object> chessSearchRequest(Position pos, List<int> history, AiConfig cfg, {int? timeMs, int seed = 0}) => {
      'fen': pos.toFen(),
      // Game hashes up to and including the current position (repetitions).
      'history': List<int>.of(history),
      'depth': cfg.depth,
      'time': timeMs ?? cfg.timeMs,
      'noise': cfg.noise,
      'seed': seed,
    };
