// Pure-Dart chess rules engine: board, FEN, legal move generation, make /
// unmake, Zobrist hashing and SAN. No Flutter imports so it can run inside an
// isolate (see chess_ai.dart) and in plain unit tests.
//
// Squares are 0..63 with a1 = 0, b1 = 1, ..., h8 = 63 (index = rank * 8 + file).
// Pieces are ints: 0 empty, 1 pawn, 2 knight, 3 bishop, 4 rook, 5 queen,
// 6 king; positive = white, negative = black.

import 'dart:math' as math;

const int pEmpty = 0, pPawn = 1, pKnight = 2, pBishop = 3, pRook = 4, pQueen = 5, pKing = 6;

/// Move flags (bits 15..).
const int mfEnPassant = 1, mfCastle = 2, mfDouble = 4;

/// Moves are packed ints: from | to << 6 | promoType << 12 | flags << 15.
int mkMove(int from, int to, {int promo = 0, int flags = 0}) => from | (to << 6) | (promo << 12) | (flags << 15);
int moveFrom(int m) => m & 63;
int moveTo(int m) => (m >> 6) & 63;
int movePromo(int m) => (m >> 12) & 7;
int moveFlags(int m) => m >> 15;

int sqFile(int s) => s & 7;
int sqRank(int s) => s >> 3;
String sqName(int s) => '${'abcdefgh'[sqFile(s)]}${sqRank(s) + 1}';
int sqParse(String n) => (n.codeUnitAt(1) - 49) * 8 + (n.codeUnitAt(0) - 97);

String moveUci(int m) {
  final p = movePromo(m);
  return '${sqName(moveFrom(m))}${sqName(moveTo(m))}${p == 0 ? '' : 'nbrq'[p - 2]}';
}

const String startFen = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

// ---------------------------------------------------------------- tables

List<List<int>> _jumps(List<List<int>> deltas) => List.generate(64, (s) {
      final f = sqFile(s), r = sqRank(s);
      return [
        for (final d in deltas)
          if (f + d[0] >= 0 && f + d[0] < 8 && r + d[1] >= 0 && r + d[1] < 8) (r + d[1]) * 8 + f + d[0],
      ];
    });

final List<List<int>> knightTargets = _jumps(const [
  [1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2],
]);
final List<List<int>> kingTargets = _jumps(const [
  [1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1],
]);

/// Directions 0..3 are orthogonal (rook), 4..7 diagonal (bishop).
const List<List<int>> _dirs = [
  [0, 1], [0, -1], [1, 0], [-1, 0], [1, 1], [-1, 1], [1, -1], [-1, -1],
];
final List<List<List<int>>> rays = List.generate(8, (d) => List.generate(64, (s) {
      final out = <int>[];
      var f = sqFile(s) + _dirs[d][0], r = sqRank(s) + _dirs[d][1];
      while (f >= 0 && f < 8 && r >= 0 && r < 8) {
        out.add(r * 8 + f);
        f += _dirs[d][0];
        r += _dirs[d][1];
      }
      return out;
    }));

/// Castling-rights mask applied when a move touches a square.
final List<int> _castleMask = List.generate(64, (s) => switch (s) {
      0 => 15 & ~2,
      4 => 15 & ~3,
      7 => 15 & ~1,
      56 => 15 & ~8,
      60 => 15 & ~12,
      63 => 15 & ~4,
      _ => 15,
    });

// Zobrist keys from a fixed seed so every isolate computes identical hashes.
int _rnd64(math.Random r) => (r.nextInt(1 << 30) << 30) ^ r.nextInt(1 << 30) ^ (r.nextInt(1 << 3) << 60);
final List<int> _zKeys = () {
  final r = math.Random(20240611);
  return List.generate(13 * 64 + 16 + 8 + 1, (_) => _rnd64(r));
}();
int _zPiece(int piece, int sq) => _zKeys[(piece + 6) * 64 + sq];
int _zCastle(int c) => _zKeys[13 * 64 + c];
int _zEp(int file) => _zKeys[13 * 64 + 16 + file];
int get _zSide => _zKeys[13 * 64 + 24];

class _Undo {
  _Undo(this.move, this.captured, this.castling, this.ep, this.halfmove, this.hash);
  final int move, captured, castling, ep, halfmove, hash;
}

// ---------------------------------------------------------------- position

class Position {
  Position._();

  factory Position.start() => Position.fromFen(startFen);

  factory Position.fromFen(String fen) {
    final p = Position._();
    final parts = fen.trim().split(RegExp(r'\s+'));
    var r = 7, f = 0;
    for (final ch in parts[0].split('')) {
      if (ch == '/') {
        r--;
        f = 0;
      } else if (RegExp(r'[1-8]').hasMatch(ch)) {
        f += int.parse(ch);
      } else {
        final t = 'pnbrqk'.indexOf(ch.toLowerCase()) + 1;
        if (t == 0) throw FormatException('bad FEN piece $ch');
        p.board[r * 8 + f] = ch == ch.toUpperCase() ? t : -t;
        f++;
      }
    }
    p.whiteToMove = parts.length < 2 || parts[1] == 'w';
    final c = parts.length > 2 ? parts[2] : '-';
    p.castling = (c.contains('K') ? 1 : 0) | (c.contains('Q') ? 2 : 0) | (c.contains('k') ? 4 : 0) | (c.contains('q') ? 8 : 0);
    p.ep = parts.length > 3 && parts[3] != '-' ? sqParse(parts[3]) : -1;
    p.halfmove = parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0;
    p.fullmove = parts.length > 5 ? int.tryParse(parts[5]) ?? 1 : 1;
    p._findKings();
    if (p.ep >= 0 && !p._epCapturable(p.ep, p.whiteToMove)) p.ep = -1;
    p.hash = p.computeHash();
    return p;
  }

  final List<int> board = List<int>.filled(64, 0);
  bool whiteToMove = true;

  /// Bits: 1 white O-O, 2 white O-O-O, 4 black O-O, 8 black O-O-O.
  int castling = 0;

  /// En-passant target square, only set when a capture there is possible.
  int ep = -1;
  int halfmove = 0;
  int fullmove = 1;
  int hash = 0;
  int whiteKing = 4, blackKing = 60;
  final List<_Undo> _stack = [];

  Position copy() => Position.fromFen(toFen());

  void _findKings() {
    for (var s = 0; s < 64; s++) {
      if (board[s] == pKing) whiteKing = s;
      if (board[s] == -pKing) blackKing = s;
    }
  }

  int computeHash() {
    var h = 0;
    for (var s = 0; s < 64; s++) {
      if (board[s] != 0) h ^= _zPiece(board[s], s);
    }
    h ^= _zCastle(castling);
    if (ep >= 0) h ^= _zEp(sqFile(ep));
    if (!whiteToMove) h ^= _zSide;
    return h;
  }

  /// True when a pawn of the side to move ([white]) can capture on [epSq].
  bool _epCapturable(int epSq, bool white) {
    final f = sqFile(epSq);
    final from = white ? epSq - 8 : epSq + 8;
    final pawn = white ? pPawn : -pPawn;
    if (f > 0 && board[from - 1] == pawn) return true;
    if (f < 7 && board[from + 1] == pawn) return true;
    return false;
  }

  String toFen() {
    final sb = StringBuffer();
    for (var r = 7; r >= 0; r--) {
      var empty = 0;
      for (var f = 0; f < 8; f++) {
        final p = board[r * 8 + f];
        if (p == 0) {
          empty++;
          continue;
        }
        if (empty > 0) sb.write(empty);
        empty = 0;
        final ch = 'pnbrqk'[p.abs() - 1];
        sb.write(p > 0 ? ch.toUpperCase() : ch);
      }
      if (empty > 0) sb.write(empty);
      if (r > 0) sb.write('/');
    }
    var c = '';
    if (castling & 1 != 0) c += 'K';
    if (castling & 2 != 0) c += 'Q';
    if (castling & 4 != 0) c += 'k';
    if (castling & 8 != 0) c += 'q';
    return '$sb ${whiteToMove ? 'w' : 'b'} ${c.isEmpty ? '-' : c} ${ep < 0 ? '-' : sqName(ep)} $halfmove $fullmove';
  }

  // ------------------------------------------------------------ attacks

  /// Is [sq] attacked by pieces of colour [byWhite]?
  bool isAttacked(int sq, bool byWhite) {
    final b = board;
    final s = byWhite ? 1 : -1;
    final f = sqFile(sq);
    if (byWhite) {
      if (f > 0 && sq >= 9 && b[sq - 9] == pPawn) return true;
      if (f < 7 && sq >= 7 && b[sq - 7] == pPawn) return true;
    } else {
      if (f < 7 && sq <= 54 && b[sq + 9] == -pPawn) return true;
      if (f > 0 && sq <= 56 && b[sq + 7] == -pPawn) return true;
    }
    for (final t in knightTargets[sq]) {
      if (b[t] == s * pKnight) return true;
    }
    for (final t in kingTargets[sq]) {
      if (b[t] == s * pKing) return true;
    }
    for (var d = 0; d < 8; d++) {
      final straight = d < 4;
      for (final t in rays[d][sq]) {
        final p = b[t];
        if (p == 0) continue;
        if (p * s > 0) {
          final a = p.abs();
          if (a == pQueen || (straight ? a == pRook : a == pBishop)) return true;
        }
        break;
      }
    }
    return false;
  }

  bool get inCheck => whiteToMove ? isAttacked(whiteKing, false) : isAttacked(blackKing, true);

  /// The side that just moved left its own king in check (illegal).
  bool get _leftKingInCheck => whiteToMove ? isAttacked(blackKing, true) : isAttacked(whiteKing, false);

  // ------------------------------------------------------------ move gen

  /// Pseudo-legal moves (may leave the king in check). Castling is fully
  /// checked here. If [capturesOnly], only captures and promotions.
  void pseudoMoves(List<int> out, {bool capturesOnly = false}) {
    final b = board;
    final w = whiteToMove;
    final s = w ? 1 : -1;
    for (var sq = 0; sq < 64; sq++) {
      final p = b[sq];
      if (p == 0 || (p > 0) != w) continue;
      switch (p.abs()) {
        case pPawn:
          final dir = 8 * s;
          final r = sqRank(sq);
          final promoRank = w ? 6 : 1;
          final t = sq + dir;
          if (b[t] == 0) {
            if (r == promoRank) {
              for (var pr = pQueen; pr >= pKnight; pr--) {
                out.add(mkMove(sq, t, promo: pr));
              }
            } else if (!capturesOnly) {
              out.add(mkMove(sq, t));
              if (r == (w ? 1 : 6) && b[t + dir] == 0) out.add(mkMove(sq, t + dir, flags: mfDouble));
            }
          }
          final f = sqFile(sq);
          for (final df in const [-1, 1]) {
            if (f + df < 0 || f + df > 7) continue;
            final c = t + df;
            final q = b[c];
            if (q != 0 && (q > 0) != w) {
              if (r == promoRank) {
                for (var pr = pQueen; pr >= pKnight; pr--) {
                  out.add(mkMove(sq, c, promo: pr));
                }
              } else {
                out.add(mkMove(sq, c));
              }
            } else if (c == ep) {
              out.add(mkMove(sq, c, flags: mfEnPassant));
            }
          }
        case pKnight:
          for (final t in knightTargets[sq]) {
            final q = b[t];
            if (q == 0 ? !capturesOnly : (q > 0) != w) out.add(mkMove(sq, t));
          }
        case pKing:
          for (final t in kingTargets[sq]) {
            final q = b[t];
            if (q == 0 ? !capturesOnly : (q > 0) != w) out.add(mkMove(sq, t));
          }
          if (!capturesOnly) _castles(out, sq);
        default:
          final a = p.abs();
          final d0 = a == pBishop ? 4 : 0;
          final d1 = a == pRook ? 4 : 8;
          for (var d = d0; d < d1; d++) {
            for (final t in rays[d][sq]) {
              final q = b[t];
              if (q == 0) {
                if (!capturesOnly) out.add(mkMove(sq, t));
                continue;
              }
              if ((q > 0) != w) out.add(mkMove(sq, t));
              break;
            }
          }
      }
    }
  }

  void _castles(List<int> out, int sq) {
    final b = board;
    if (whiteToMove) {
      if (sq != 4) return;
      if (castling & 1 != 0 && b[5] == 0 && b[6] == 0 && b[7] == pRook &&
          !isAttacked(4, false) && !isAttacked(5, false) && !isAttacked(6, false)) {
        out.add(mkMove(4, 6, flags: mfCastle));
      }
      if (castling & 2 != 0 && b[3] == 0 && b[2] == 0 && b[1] == 0 && b[0] == pRook &&
          !isAttacked(4, false) && !isAttacked(3, false) && !isAttacked(2, false)) {
        out.add(mkMove(4, 2, flags: mfCastle));
      }
    } else {
      if (sq != 60) return;
      if (castling & 4 != 0 && b[61] == 0 && b[62] == 0 && b[63] == -pRook &&
          !isAttacked(60, true) && !isAttacked(61, true) && !isAttacked(62, true)) {
        out.add(mkMove(60, 62, flags: mfCastle));
      }
      if (castling & 8 != 0 && b[59] == 0 && b[58] == 0 && b[57] == 0 && b[56] == -pRook &&
          !isAttacked(60, true) && !isAttacked(59, true) && !isAttacked(58, true)) {
        out.add(mkMove(60, 58, flags: mfCastle));
      }
    }
  }

  /// All legal moves for the side to move.
  List<int> legalMoves() {
    final pseudo = <int>[];
    pseudoMoves(pseudo);
    final out = <int>[];
    for (final m in pseudo) {
      if (makeMove(m)) {
        out.add(m);
        unmakeMove();
      }
    }
    return out;
  }

  // ------------------------------------------------------------ make / unmake

  /// Plays [m]. Returns false (and restores the position) if it would leave
  /// the mover's king in check.
  bool makeMove(int m) {
    final b = board;
    final from = moveFrom(m), to = moveTo(m), promo = movePromo(m), flags = moveFlags(m);
    final p = b[from];
    final s = p > 0 ? 1 : -1;
    var captured = b[to];
    _stack.add(_Undo(m, captured, castling, ep, halfmove, hash));
    var h = hash;
    if (ep >= 0) h ^= _zEp(sqFile(ep));
    h ^= _zCastle(castling);

    if (flags & mfEnPassant != 0) {
      final cs = to - 8 * s;
      captured = b[cs];
      b[cs] = 0;
      h ^= _zPiece(captured, cs);
    } else if (captured != 0) {
      h ^= _zPiece(captured, to);
    }
    final placed = promo != 0 ? promo * s : p;
    b[from] = 0;
    b[to] = placed;
    h ^= _zPiece(p, from) ^ _zPiece(placed, to);

    if (flags & mfCastle != 0) {
      final (rf, rt) = switch (to) { 6 => (7, 5), 2 => (0, 3), 62 => (63, 61), _ => (56, 59) };
      final rook = b[rf];
      b[rf] = 0;
      b[rt] = rook;
      h ^= _zPiece(rook, rf) ^ _zPiece(rook, rt);
    }
    if (p == pKing) whiteKing = to;
    if (p == -pKing) blackKing = to;

    castling &= _castleMask[from] & _castleMask[to];
    h ^= _zCastle(castling);
    halfmove = (p.abs() == pPawn || captured != 0) ? 0 : halfmove + 1;
    if (s < 0) fullmove++;
    whiteToMove = !whiteToMove;
    h ^= _zSide;
    ep = -1;
    if (flags & mfDouble != 0) {
      final e = (from + to) >> 1;
      if (_epCapturable(e, whiteToMove)) {
        ep = e;
        h ^= _zEp(sqFile(e));
      }
    }
    hash = h;
    if (_leftKingInCheck) {
      unmakeMove();
      return false;
    }
    return true;
  }

  void unmakeMove() {
    final u = _stack.removeLast();
    final b = board;
    final m = u.move;
    final from = moveFrom(m), to = moveTo(m), promo = movePromo(m), flags = moveFlags(m);
    whiteToMove = !whiteToMove;
    final s = whiteToMove ? 1 : -1;
    final moved = promo != 0 ? pPawn * s : b[to];
    b[from] = moved;
    if (flags & mfEnPassant != 0) {
      b[to] = 0;
      b[to - 8 * s] = -pPawn * s;
    } else {
      b[to] = u.captured;
    }
    if (flags & mfCastle != 0) {
      final (rf, rt) = switch (to) { 6 => (7, 5), 2 => (0, 3), 62 => (63, 61), _ => (56, 59) };
      b[rf] = b[rt];
      b[rt] = 0;
    }
    if (moved == pKing) whiteKing = from;
    if (moved == -pKing) blackKing = from;
    castling = u.castling;
    ep = u.ep;
    halfmove = u.halfmove;
    hash = u.hash;
    if (s < 0) fullmove--;
  }

  /// Null move for search pruning helpers (not used for legal play).
  int get plyCount => _stack.length;

  // ------------------------------------------------------------ helpers

  /// The legal move matching from/to (and promotion piece, default queen).
  int? findMove(int from, int to, [int promo = 0]) {
    for (final m in legalMoves()) {
      if (moveFrom(m) == from && moveTo(m) == to && (movePromo(m) == promo || (promo == 0 && movePromo(m) == pQueen))) {
        return m;
      }
    }
    return null;
  }

  int? findUci(String uci) {
    final promo = uci.length > 4 ? 'nbrq'.indexOf(uci[4]) + 2 : 0;
    return findMove(sqParse(uci.substring(0, 2)), sqParse(uci.substring(2, 4)), promo);
  }

  /// Neither side can ever checkmate (K v K, K+minor v K, K+B v K+B same colour).
  bool get insufficientMaterial {
    final minors = <int>[];
    final bishopsColor = <int>[];
    for (var s = 0; s < 64; s++) {
      final a = board[s].abs();
      if (a == 0 || a == pKing) continue;
      if (a == pPawn || a == pRook || a == pQueen) return false;
      minors.add(board[s]);
      if (a == pBishop) bishopsColor.add((sqFile(s) + sqRank(s)) & 1);
    }
    if (minors.length <= 1) return true;
    // Only bishops, all on the same square colour.
    if (minors.every((p) => p.abs() == pBishop) && bishopsColor.toSet().length == 1) return true;
    return false;
  }

  /// Whether [white] has enough material that a checkmate is at all possible
  /// (used when the other side flags: a lone king / single minor vs lone king
  /// cannot win on time).
  bool canMate(bool white) {
    var count = 0, heavy = false, other = 0;
    for (var s = 0; s < 64; s++) {
      final p = board[s];
      if (p == 0 || p.abs() == pKing) continue;
      if ((p > 0) == white) {
        count++;
        if (p.abs() != pKnight && p.abs() != pBishop) heavy = true;
      } else {
        other++;
      }
    }
    if (count == 0) return false;
    if (heavy || count >= 2) return true;
    return other > 0; // single minor can only mate with help from enemy pieces
  }

  // ------------------------------------------------------------ SAN

  /// Standard algebraic notation for legal move [m] (with +/#).
  String san(int m, [List<int>? legal]) {
    legal ??= legalMoves();
    final from = moveFrom(m), to = moveTo(m), promo = movePromo(m);
    final p = board[from].abs();
    String s;
    if (moveFlags(m) & mfCastle != 0) {
      s = sqFile(to) == 6 ? 'O-O' : 'O-O-O';
    } else {
      final capture = board[to] != 0 || moveFlags(m) & mfEnPassant != 0;
      final sb = StringBuffer();
      if (p == pPawn) {
        if (capture) sb.write('abcdefgh'[sqFile(from)]);
      } else {
        sb.write('  NBRQK'[p]);
        final rivals = [
          for (final o in legal)
            if (o != m && moveTo(o) == to && board[moveFrom(o)].abs() == p && moveFrom(o) != from) moveFrom(o),
        ];
        if (rivals.isNotEmpty) {
          final sameFile = rivals.any((r) => sqFile(r) == sqFile(from));
          final sameRank = rivals.any((r) => sqRank(r) == sqRank(from));
          if (!sameFile) {
            sb.write('abcdefgh'[sqFile(from)]);
          } else if (!sameRank) {
            sb.write(sqRank(from) + 1);
          } else {
            sb.write(sqName(from));
          }
        }
      }
      if (capture) sb.write('x');
      sb.write(sqName(to));
      if (promo != 0) sb.write('=${'  NBRQK'[promo]}');
      s = sb.toString();
    }
    makeMove(m);
    if (inCheck) s += legalMoves().isEmpty ? '#' : '+';
    unmakeMove();
    return s;
  }

  int? findSan(String san) {
    final clean = san.replaceAll(RegExp(r'[+#!?]'), '');
    final legal = legalMoves();
    for (final m in legal) {
      if (this.san(m, legal).replaceAll(RegExp(r'[+#]'), '') == clean) return m;
    }
    return null;
  }
}

/// Counts leaf nodes of the legal move tree (engine correctness check).
int perft(Position p, int depth) {
  if (depth == 0) return 1;
  final moves = <int>[];
  p.pseudoMoves(moves);
  var n = 0;
  for (final m in moves) {
    if (!p.makeMove(m)) continue;
    n += depth == 1 ? 1 : perft(p, depth - 1);
    p.unmakeMove();
  }
  return n;
}
