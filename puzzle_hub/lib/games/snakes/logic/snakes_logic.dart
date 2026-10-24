import '../../ludo/logic/ludo_logic.dart';

/// Saanp-Seedhi (Snakes & Ladders) rules engine. Pure Dart; offline and
/// online games replay the same log of rolls. Dice come from the seed (same
/// random stream as Ludo), so every phone sees the same game.
///
/// Squares 1..100, numbered from the bottom-left in a zig-zag. A token
/// starts at 0 (off the board). Exactly 100 wins; a roll that would pass
/// 100 is lost. A 6 gives another roll (three 6s in a row lose the turn).
class Snakes {
  /// Ladders: bottom -> top.
  static const ladders = {1: 38, 4: 14, 9: 31, 21: 42, 28: 84, 36: 44, 51: 67, 71: 91, 80: 100};

  /// Snakes: head -> tail.
  static const snakes = {16: 6, 47: 26, 49: 11, 56: 53, 62: 19, 64: 60, 87: 24, 93: 73, 95: 75, 98: 78};

  /// (row, col) of square [n] on a 10×10 grid, row 0 at the top.
  static (int, int) cellOf(int n) {
    final i = n - 1;
    final rowFromBottom = i ~/ 10;
    final c = rowFromBottom.isEven ? i % 10 : 9 - i % 10;
    return (9 - rowFromBottom, c);
  }
}

/// What the last roll did (for sounds and the status line).
class SnakesEvent {
  const SnakesEvent({this.rolled, this.seat, this.from = 0, this.to = 0, this.via, this.ladder = false, this.snake = false, this.blocked = false, this.lostTurn = false});
  final int? rolled;
  final int? seat;
  final int from, to;

  /// Square reached by the dice before a snake / ladder moved the token.
  final int? via;
  final bool ladder, snake;

  /// Roll would pass 100: no move.
  final bool blocked;
  final bool lostTurn;
}

class SnakesGame {
  SnakesGame({required this.seats, required this.seed}) : pos = List.filled(seats.length, 0);

  final List<LudoSeat> seats;
  final int seed;
  final List<int> pos;

  /// One entry per roll: the seat, or seat + 10 × dice when the value was
  /// given (a real dice at home: 1..6; a wrong riddle answer: 0 → +70).
  final List<int> log = [];
  int turn = 0;
  int? winner;
  int _sixes = 0;
  SnakesEvent last = const SnakesEvent();
  late int _x = _start(seed);

  bool get over => winner != null;

  static const _m = 2147483647;
  static int _start(int seed) {
    var x = (seed.abs() % (_m - 1)) + 1;
    for (var i = 0; i < 4; i++) {
      x = ((x * 48271) % _m + 12345) % (_m - 1) + 1;
    }
    return x;
  }

  int _nextDice() {
    _x = (_x * 48271) % _m;
    return _x * 6 ~/ _m + 1;
  }

  /// Rolls for [seat]. False if it is not that seat's turn. [dice] (offline
  /// only) is a value from a real dice (1..6), or 0 = wrong riddle answer
  /// (the turn passes).
  bool roll(int seat, {int? dice}) {
    if (over || seat != turn) return false;
    if (dice != null && (dice < 0 || dice > 6)) return false;
    log.add(dice == null ? seat : seat + 10 * (dice == 0 ? 7 : dice));
    if (dice == 0) {
      last = SnakesEvent(seat: seat, from: pos[seat], to: pos[seat], blocked: true);
      _next();
      return true;
    }
    final d = dice ?? _nextDice();
    final from = pos[seat];
    if (d == 6) {
      _sixes++;
      if (_sixes == 3) {
        // Third six: the turn is lost (and so are the first two moves' bonus).
        last = SnakesEvent(rolled: d, seat: seat, from: from, to: from, lostTurn: true);
        _next();
        return true;
      }
    } else {
      _sixes = 0;
    }
    var to = from + d;
    if (to > 100) {
      last = SnakesEvent(rolled: d, seat: seat, from: from, to: from, blocked: true);
      if (d != 6) _next();
      return true;
    }
    final via = to;
    var ladder = false, snake = false;
    if (Snakes.ladders.containsKey(to)) {
      to = Snakes.ladders[to]!;
      ladder = true;
    } else if (Snakes.snakes.containsKey(to)) {
      to = Snakes.snakes[to]!;
      snake = true;
    }
    pos[seat] = to;
    last = SnakesEvent(rolled: d, seat: seat, from: from, to: to, via: ladder || snake ? via : null, ladder: ladder, snake: snake);
    if (to == 100) {
      winner = seat;
      return true;
    }
    if (d != 6) _next();
    return true;
  }

  void _next() {
    _sixes = 0;
    turn = (turn + 1) % seats.length;
  }

  static SnakesGame replay({required List<LudoSeat> seats, required int seed, required Iterable<int> rolls}) {
    final g = SnakesGame(seats: seats, seed: seed);
    for (final v in rolls) {
      if (v < 10) {
        g.roll(v);
      } else {
        final dice = v ~/ 10;
        g.roll(v % 10, dice: dice == 7 ? 0 : dice);
      }
    }
    return g;
  }
}
