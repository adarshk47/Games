import 'dart:math' as math;

/// Ludo rules engine (pure Dart, no Flutter) shared by offline and online
/// games. Every dice value comes from [LudoGame.diceAt] (seed + roll
/// number), so all phones replaying the same log see the same game and
/// nobody can choose their own roll.
///
/// Colours sit clockwise: 0 red (top-left), 1 green (top-right),
/// 2 yellow (bottom-right), 3 blue (bottom-left).
///
/// Token progress: -1 = in the yard, 0..50 = on the shared track (0 is the
/// colour's start square), 51..55 = its home column, 56 = home (finished).
class Ludo {
  static const trackLen = 52;
  static const lastTrack = 50;
  static const home = 56;

  /// Global track index of [colour]'s start square.
  static int startOf(int colour) => colour * 13;

  /// Safe squares (start squares and stars): no capturing there.
  static const safe = {0, 8, 13, 21, 26, 34, 39, 47};

  /// Global track square of a token of [colour] at [progress] (0..50), else null.
  static int? squareOf(int colour, int progress) =>
      progress < 0 || progress > lastTrack ? null : (startOf(colour) + progress) % trackLen;

  /// The 52 shared squares as (row, col) on the 15×15 board, starting at
  /// red's start square and going clockwise.
  static final List<(int, int)> track = _buildTrack();

  static List<(int, int)> _buildTrack() {
    final t = <(int, int)>[];
    for (var c = 1; c <= 5; c++) {
      t.add((6, c));
    }
    for (var r = 5; r >= 0; r--) {
      t.add((r, 6));
    }
    t.add((0, 7));
    for (var r = 0; r <= 5; r++) {
      t.add((r, 8));
    }
    for (var c = 9; c <= 14; c++) {
      t.add((6, c));
    }
    t.add((7, 14));
    for (var c = 14; c >= 9; c--) {
      t.add((8, c));
    }
    for (var r = 9; r <= 14; r++) {
      t.add((r, 8));
    }
    t.add((14, 7));
    for (var r = 14; r >= 9; r--) {
      t.add((r, 6));
    }
    for (var c = 5; c >= 0; c--) {
      t.add((8, c));
    }
    t.add((7, 0));
    t.add((6, 0));
    return t;
  }

  /// Home-column cell (row, col) of [colour] for progress 51..55.
  static (int, int) homeCell(int colour, int progress) {
    final i = progress - 50; // 1..5
    return switch (colour) {
      0 => (7, i),
      1 => (i, 7),
      2 => (7, 14 - i),
      _ => (14 - i, 7),
    };
  }

  /// Board cell of a token (yard and home handled by the board widget).
  static (int, int)? cellOf(int colour, int progress) {
    if (progress < 0 || progress >= home) return null;
    if (progress <= lastTrack) return track[squareOf(colour, progress)!];
    return homeCell(colour, progress);
  }
}

/// A seat at the table.
enum SeatKind { human, bot, remote }

class LudoSeat {
  const LudoSeat(this.colour, this.kind, {this.name = '', this.uid});
  final int colour;
  final SeatKind kind;
  final String name;
  final String? uid;
}

/// One log entry: a roll ([token] null) or moving [token] (0..3).
class LudoAction {
  const LudoAction.roll(this.seat) : token = null;
  const LudoAction.move(this.seat, int this.token);
  final int seat;
  final int? token;

  bool get isRoll => token == null;

  Object toJson() => isRoll ? [seat] : [seat, token];

  static LudoAction? fromJson(Object? j) {
    if (j is! List || j.isEmpty || j[0] is! int) return null;
    final s = j[0] as int;
    if (j.length == 1) return LudoAction.roll(s);
    return j[1] is int ? LudoAction.move(s, j[1] as int) : null;
  }
}

/// What happened on the last applied action (for sounds / animation).
class LudoEvent {
  const LudoEvent({this.rolled, this.moved, this.captured = const [], this.reachedHome = false, this.lostTurn = false, this.passed = false});
  final int? rolled;
  final (int seat, int token, int from, int to)? moved;
  final List<(int seat, int token)> captured;
  final bool reachedHome;

  /// Third six in a row: the turn is lost.
  final bool lostTurn;

  /// Rolled, but no token could move: the turn passed.
  final bool passed;
}

/// Full game state; build it from (seats, seed) and feed actions in order.
class LudoGame {
  LudoGame({required this.seats, required this.seed, this.quick = false})
      : tokens = List.generate(seats.length, (_) => List.filled(4, -1));

  final List<LudoSeat> seats;
  final int seed;

  /// Quick mode: the first player with one token home wins.
  final bool quick;

  /// tokens[seat][i] = progress of that token.
  final List<List<int>> tokens;
  final List<LudoAction> log = [];

  int turn = 0;

  /// Dice value waiting for a move (null = the player must roll).
  int? pending;
  int rolls = 0;
  int _sixes = 0;

  /// Seats in finishing order (1st = winner).
  final List<int> finished = [];
  LudoEvent last = const LudoEvent();

  bool get over => quick ? finished.isNotEmpty : finished.length >= seats.length - 1;
  int? get winner => finished.isEmpty ? null : finished.first;
  int colourOf(int seat) => seats[seat].colour;

  /// Deterministic dice: one Park–Miller random stream per game, so the same
  /// seed gives the same rolls on every phone. Numbers stay below 2^53, so it
  /// also matches on the web.
  static const _m = 2147483647;
  late int _x = _start(seed);

  static int _start(int seed) {
    var x = (seed.abs() % (_m - 1)) + 1;
    // Warm up so that small or similar seeds still give unrelated rolls.
    for (var i = 0; i < 4; i++) {
      x = (_step(x) + 12345) % (_m - 1) + 1;
    }
    return x;
  }

  static int _step(int x) => (x * 48271) % _m;
  static int _face(int x) => x * 6 ~/ _m + 1;

  /// The [n]-th roll of a game with [seed] (0-based).
  static int diceAt(int seed, int n) {
    var x = _start(seed);
    for (var i = 0; i <= n; i++) {
      x = _step(x);
    }
    return _face(x);
  }

  int _nextDice() {
    _x = _step(_x);
    rolls++;
    return _face(_x);
  }

  bool _done(int seat) => tokens[seat].every((p) => p == Ludo.home) || (quick && tokens[seat].contains(Ludo.home));

  /// Tokens [seat] may move with [dice].
  List<int> movable(int seat, int dice) => [
        for (var i = 0; i < 4; i++)
          if (_target(tokens[seat][i], dice) != null) i
      ];

  static int? _target(int p, int dice) {
    if (p == Ludo.home) return null;
    if (p < 0) return dice == 6 ? 0 : null;
    final t = p + dice;
    return t > Ludo.home ? null : t;
  }

  /// Plays [a]. Returns false (and changes nothing) if it is not allowed now.
  bool apply(LudoAction a) {
    if (over || a.seat != turn) return false;
    if (a.isRoll) {
      if (pending != null) return false;
      final d = _nextDice();
      log.add(a);
      if (d == 6) {
        _sixes++;
        if (_sixes == 3) {
          last = LudoEvent(rolled: d, lostTurn: true);
          _nextTurn();
          return true;
        }
      } else {
        _sixes = 0;
      }
      if (movable(turn, d).isEmpty) {
        last = LudoEvent(rolled: d, passed: true);
        // A six with nothing to move still allows another roll.
        if (d != 6) _nextTurn();
        return true;
      }
      pending = d;
      last = LudoEvent(rolled: d);
      return true;
    }
    final d = pending;
    final i = a.token!;
    if (d == null || i < 0 || i > 3) return false;
    final from = tokens[turn][i];
    final to = _target(from, d);
    if (to == null) return false;
    log.add(a);
    tokens[turn][i] = to;
    pending = null;
    final caught = <(int, int)>[];
    final sq = Ludo.squareOf(colourOf(turn), to);
    if (sq != null && !Ludo.safe.contains(sq)) {
      for (var s = 0; s < seats.length; s++) {
        if (s == turn) continue;
        for (var j = 0; j < 4; j++) {
          if (Ludo.squareOf(colourOf(s), tokens[s][j]) == sq) {
            tokens[s][j] = -1;
            caught.add((s, j));
          }
        }
      }
    }
    final home = to == Ludo.home;
    last = LudoEvent(rolled: d, moved: (turn, i, from, to), captured: caught, reachedHome: home);
    if (_done(turn) && !finished.contains(turn)) finished.add(turn);
    if (over) {
      // Last player left takes the remaining place.
      for (var s = 0; s < seats.length; s++) {
        if (!finished.contains(s) && !quick) finished.add(s);
      }
      return true;
    }
    final again = (d == 6 || caught.isNotEmpty || home) && !finished.contains(turn);
    if (!again) _nextTurn();
    return true;
  }

  void _nextTurn() {
    pending = null;
    _sixes = 0;
    for (var k = 1; k <= seats.length; k++) {
      final s = (turn + k) % seats.length;
      if (!finished.contains(s)) {
        turn = s;
        return;
      }
    }
  }

  /// Rebuilds a game from its log (invalid entries are skipped).
  static LudoGame replay({required List<LudoSeat> seats, required int seed, required bool quick, required Iterable<LudoAction> actions}) {
    final g = LudoGame(seats: seats, seed: seed, quick: quick);
    for (final a in actions) {
      g.apply(a);
    }
    return g;
  }

  // ---------------------------------------------------------------- bot

  /// A sensible token for the bot ([level] 0 easy .. 2 hard).
  int botChoice(int level, [math.Random? rnd]) {
    final d = pending!;
    final opts = movable(turn, d);
    if (opts.length == 1) return opts.first;
    final r = rnd ?? math.Random();
    if (level == 0 && r.nextInt(3) == 0) return opts[r.nextInt(opts.length)];
    var best = opts.first;
    var bestScore = -1e9;
    for (final i in opts) {
      final s = _score(i, d) + r.nextDouble() * (level == 2 ? 0.1 : 3);
      if (s > bestScore) {
        bestScore = s;
        best = i;
      }
    }
    return best;
  }

  double _score(int i, int d) {
    final c = colourOf(turn);
    final from = tokens[turn][i];
    final to = _target(from, d)!;
    var s = 0.0;
    if (to == Ludo.home) s += 60;
    if (from < 0) s += 40;
    final sq = Ludo.squareOf(c, to);
    if (sq != null && !Ludo.safe.contains(sq)) {
      // Capture?
      for (var o = 0; o < seats.length; o++) {
        if (o == turn) continue;
        for (final p in tokens[o]) {
          if (Ludo.squareOf(colourOf(o), p) == sq) s += 80 + p;
        }
      }
      // Danger: an opponent 1..6 squares behind the target.
      if (_threat(sq)) s -= 35;
    } else if (sq != null) {
      s += 15; // safe square
    }
    // Leaving danger is good.
    final fromSq = Ludo.squareOf(c, from);
    if (fromSq != null && !Ludo.safe.contains(fromSq) && _threat(fromSq)) s += 25;
    if (to > Ludo.lastTrack) s += 20; // into the home column
    s += to * 0.4;
    return s;
  }

  bool _threat(int sq) {
    for (var o = 0; o < seats.length; o++) {
      if (o == turn) continue;
      for (final p in tokens[o]) {
        final os = Ludo.squareOf(colourOf(o), p);
        if (os == null) continue;
        final gap = (sq - os) % Ludo.trackLen;
        if (gap >= 1 && gap <= 6) return true;
      }
    }
    return false;
  }
}

/// Seat colours for 2, 3 or 4 players (2 players sit opposite).
List<int> ludoColours(int players) => switch (players) {
      2 => const [0, 2],
      3 => const [0, 1, 2],
      _ => const [0, 1, 2, 3],
    };
