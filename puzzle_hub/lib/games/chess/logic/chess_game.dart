// Game wrapper around [Position]: move history (SAN), repetition tracking,
// end-of-game detection, captured material, and the chess clock.

import 'chess_engine.dart';

enum ChessResult { ongoing, whiteWins, blackWins, draw }

enum EndReason { none, checkmate, stalemate, repetition, fiftyMove, insufficient, timeout, timeoutMaterial, resign, agreement }

class ChessGame {
  ChessGame([String fen = startFen]) : pos = Position.fromFen(fen) {
    _hashes.add(pos.hash);
    _refresh();
  }

  final Position pos;
  final List<int> moves = [];
  final List<String> sans = [];
  final List<int> _hashes = [];
  List<int> _legal = const [];
  ChessResult result = ChessResult.ongoing;
  EndReason reason = EndReason.none;

  List<int> get legal => _legal;
  bool get over => result != ChessResult.ongoing;
  bool get whiteToMove => pos.whiteToMove;
  bool get inCheck => pos.inCheck;
  int? get lastMove => moves.isEmpty ? null : moves.last;

  /// Position hashes from the start up to now (for repetition checks).
  List<int> get hashHistory => List.unmodifiable(_hashes);

  int get repetitions => _hashes.where((h) => h == pos.hash).length;

  List<int> movesFrom(int sq) => [for (final m in _legal) if (moveFrom(m) == sq) m];

  /// Plays legal move [m]. Returns false if it is not legal or the game is over.
  bool play(int m) {
    if (over || !_legal.contains(m)) return false;
    final s = pos.san(m, _legal);
    pos.makeMove(m);
    moves.add(m);
    sans.add(s);
    _hashes.add(pos.hash);
    _refresh();
    return true;
  }

  bool playUci(String uci) {
    final m = pos.findUci(uci);
    return m != null && play(m);
  }

  bool playSan(String san) {
    final m = pos.findSan(san);
    return m != null && play(m);
  }

  /// Takes back the last [n] plies (game result is cleared).
  void undo([int n = 1]) {
    for (var i = 0; i < n && moves.isNotEmpty; i++) {
      pos.unmakeMove();
      moves.removeLast();
      sans.removeLast();
      _hashes.removeLast();
    }
    result = ChessResult.ongoing;
    reason = EndReason.none;
    _refresh();
  }

  void _refresh() {
    _legal = pos.legalMoves();
    if (over) return;
    if (_legal.isEmpty) {
      if (pos.inCheck) {
        _end(pos.whiteToMove ? ChessResult.blackWins : ChessResult.whiteWins, EndReason.checkmate);
      } else {
        _end(ChessResult.draw, EndReason.stalemate);
      }
    } else if (pos.insufficientMaterial) {
      _end(ChessResult.draw, EndReason.insufficient);
    } else if (repetitions >= 3) {
      _end(ChessResult.draw, EndReason.repetition);
    } else if (pos.halfmove >= 100) {
      _end(ChessResult.draw, EndReason.fiftyMove);
    }
  }

  void _end(ChessResult r, EndReason why) {
    result = r;
    reason = why;
  }

  /// [white] ran out of time: loss, unless the opponent cannot possibly mate.
  void flag(bool white) {
    if (over) return;
    if (pos.canMate(!white)) {
      _end(white ? ChessResult.blackWins : ChessResult.whiteWins, EndReason.timeout);
    } else {
      _end(ChessResult.draw, EndReason.timeoutMaterial);
    }
  }

  void resign(bool white) {
    if (over) return;
    _end(white ? ChessResult.blackWins : ChessResult.whiteWins, EndReason.resign);
  }

  void agreeDraw() {
    if (over) return;
    _end(ChessResult.draw, EndReason.agreement);
  }

  /// Pieces of colour [white] that have been captured (by type, sorted),
  /// derived from material still on the board.
  List<int> captured(bool white) {
    const initial = {pPawn: 8, pKnight: 2, pBishop: 2, pRook: 2, pQueen: 1};
    final count = <int, int>{};
    for (final p in pos.board) {
      if (p != 0 && (p > 0) == white) count[p.abs()] = (count[p.abs()] ?? 0) + 1;
    }
    final out = <int>[];
    for (final MapEntry(:key, :value) in initial.entries) {
      final missing = value - (count[key] ?? 0);
      for (var i = 0; i < missing; i++) {
        out.add(key);
      }
    }
    return out;
  }

  /// Material balance in pawns from white's point of view.
  int materialDiff() {
    const v = [0, 1, 3, 3, 5, 9, 0];
    var d = 0;
    for (final p in pos.board) {
      if (p != 0) d += p > 0 ? v[p] : -v[-p];
    }
    return d;
  }
}

/// A time control: base minutes + increment seconds.
class TimeControl {
  const TimeControl(this.minutes, [this.increment = 0]);
  final int minutes;
  final int increment;

  String get id => increment == 0 ? '${minutes}m' : '${minutes}m$increment';
  String get label => '$minutes | $increment';
  int get baseMs => minutes * 60000;
  int get incMs => increment * 1000;

  static const all = [
    TimeControl(2),
    TimeControl(3),
    TimeControl(3, 2),
    TimeControl(5),
    TimeControl(5, 3),
    TimeControl(10),
  ];

  @override
  bool operator ==(Object other) => other is TimeControl && other.minutes == minutes && other.increment == increment;

  @override
  int get hashCode => Object.hash(minutes, increment);
}

/// Two-sided chess clock. Time is fed in by the caller ([consume]) so it is
/// fully deterministic and testable.
class ChessClock {
  ChessClock(this.control)
      : whiteMs = control.baseMs,
        blackMs = control.baseMs;

  final TimeControl control;
  int whiteMs;
  int blackMs;

  int msFor(bool white) => white ? whiteMs : blackMs;

  bool flagged(bool white) => msFor(white) <= 0;

  /// Removes [ms] from [white]'s clock. Returns true when that side flagged.
  bool consume(bool white, int ms) {
    if (white) {
      whiteMs = (whiteMs - ms).clamp(0, 1 << 31);
    } else {
      blackMs = (blackMs - ms).clamp(0, 1 << 31);
    }
    return flagged(white);
  }

  /// [white] completed a move: add the increment.
  void moved(bool white) {
    if (flagged(white)) return;
    if (white) {
      whiteMs += control.incMs;
    } else {
      blackMs += control.incMs;
    }
  }

  /// Under 20 s (or 10 % of the base for very short controls).
  bool low(bool white) => msFor(white) < (control.baseMs ~/ 10).clamp(10000, 20000);

  static String format(int ms) {
    if (ms < 10000) {
      final t = (ms / 100).ceil();
      return '0:0${t ~/ 10}.${t % 10}';
    }
    final s = (ms / 1000).ceil();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}
