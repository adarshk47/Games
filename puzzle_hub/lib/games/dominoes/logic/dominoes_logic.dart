import 'dart:math' as math;

/// One domino tile (double-six set: 0..6 on each half).
class Domino {
  const Domino(this.a, this.b);
  final int a, b;

  bool get isDouble => a == b;
  int get pips => a + b;
  bool has(int n) => a == n || b == n;

  @override
  bool operator ==(Object other) =>
      other is Domino && ((other.a == a && other.b == b) || (other.a == b && other.b == a));

  @override
  int get hashCode => math.min(a, b) * 7 + math.max(a, b);

  @override
  String toString() => '[$a|$b]';

  /// The 28 tiles of a double-six set.
  static List<Domino> fullSet() => [
        for (var i = 0; i <= 6; i++)
          for (var j = i; j <= 6; j++) Domino(i, j),
      ];
}

/// A tile on the table, oriented so [left] faces the left end of the line.
class Placed {
  const Placed(this.left, this.right);
  final int left, right;
  bool get isDouble => left == right;
}

enum End { left, right }

/// A legal move: tile [index] in the hand, put on [end].
class DominoMove {
  const DominoMove(this.index, this.end);
  final int index;
  final End end;
}

/// The "Draw" game: 2 players get 7 tiles, 3–4 players 5. Match the number
/// on an open end; if you cannot, draw from the boneyard (or pass when it is
/// empty). First to play all tiles wins the round and scores the pips left
/// in the other hands. A blocked round goes to the lowest hand. First to
/// [target] points wins the match.
class DominoGame {
  DominoGame({required this.players, this.target = 100, math.Random? random})
      : _r = random ?? math.Random(),
        scores = List.filled(players, 0) {
    assert(players >= 2 && players <= 4);
    newRound();
  }

  final int players;
  final int target;
  final math.Random _r;
  final List<int> scores;

  late List<List<Domino>> hands;
  late List<Domino> boneyard;
  final List<Placed> line = [];
  int turn = 0;
  int round = 0;
  int _passes = 0;

  /// Seat that won the last finished round (null while a round is running).
  int? roundWinner;

  /// Points the round winner got.
  int roundPoints = 0;

  /// True when the last round ended because nobody could play.
  bool blocked = false;

  int get handSize => players == 2 ? 7 : 5;
  bool get roundOver => roundWinner != null;
  int? get matchWinner {
    for (var i = 0; i < players; i++) {
      if (scores[i] >= target) return i;
    }
    return null;
  }

  int get leftEnd => line.first.left;
  int get rightEnd => line.last.right;

  /// Deals a new round. The first round starts with the highest double (or
  /// highest tile), which is played automatically; later rounds are opened
  /// by the previous winner.
  void newRound() {
    final set = Domino.fullSet()..shuffle(_r);
    hands = [for (var p = 0; p < players; p++) set.sublist(p * handSize, (p + 1) * handSize)];
    boneyard = set.sublist(players * handSize);
    line.clear();
    _passes = 0;
    blocked = false;
    final prev = roundWinner;
    roundWinner = null;
    roundPoints = 0;
    round++;
    if (prev != null) {
      turn = prev;
      return;
    }
    // Highest double opens; if nobody has one, the heaviest tile.
    var best = -1, seat = 0, idx = 0;
    for (var p = 0; p < players; p++) {
      for (var i = 0; i < hands[p].length; i++) {
        final d = hands[p][i];
        final rank = d.isDouble ? 100 + d.a : d.pips;
        if (rank > best) {
          best = rank;
          seat = p;
          idx = i;
        }
      }
    }
    final d = hands[seat].removeAt(idx);
    line.add(Placed(d.a, d.b));
    turn = (seat + 1) % players;
  }

  /// Legal moves for [seat] (on an empty line every tile can open).
  List<DominoMove> moves(int seat) {
    final h = hands[seat];
    if (line.isEmpty) return [for (var i = 0; i < h.length; i++) DominoMove(i, End.right)];
    final out = <DominoMove>[];
    for (var i = 0; i < h.length; i++) {
      final d = h[i];
      if (d.has(leftEnd)) out.add(DominoMove(i, End.left));
      // Same tile on the other end only if it makes a different board.
      if (d.has(rightEnd) && !(leftEnd == rightEnd && d.has(leftEnd))) out.add(DominoMove(i, End.right));
    }
    return out;
  }

  bool canPlay(int seat) => moves(seat).isNotEmpty;

  /// Ends where tile [index] of [seat] fits.
  List<End> endsFor(int seat, int index) =>
      [for (final m in moves(seat)) if (m.index == index) m.end];

  /// Plays a tile. Returns false for an illegal move.
  bool play(int seat, int index, End end) {
    if (roundOver || seat != turn || index < 0 || index >= hands[seat].length) return false;
    final d = hands[seat][index];
    if (line.isEmpty) {
      line.add(Placed(d.a, d.b));
    } else if (end == End.left) {
      if (!d.has(leftEnd)) return false;
      line.insert(0, d.b == leftEnd ? Placed(d.a, d.b) : Placed(d.b, d.a));
    } else {
      if (!d.has(rightEnd)) return false;
      line.add(d.a == rightEnd ? Placed(d.a, d.b) : Placed(d.b, d.a));
    }
    hands[seat].removeAt(index);
    _passes = 0;
    if (hands[seat].isEmpty) {
      _endRound(seat);
    } else {
      turn = (turn + 1) % players;
    }
    return true;
  }

  /// Draws one tile for the player to move (only when they cannot play).
  Domino? draw(int seat) {
    if (roundOver || seat != turn || canPlay(seat) || boneyard.isEmpty) return null;
    final d = boneyard.removeLast();
    hands[seat].add(d);
    return d;
  }

  /// Passes (only when the player cannot play and the boneyard is empty).
  bool pass(int seat) {
    if (roundOver || seat != turn || canPlay(seat) || boneyard.isNotEmpty) return false;
    _passes++;
    if (_passes >= players) {
      // Blocked: lowest pip count wins (ties go to the earliest seat).
      var low = 0;
      for (var p = 1; p < players; p++) {
        if (pipsOf(p) < pipsOf(low)) low = p;
      }
      blocked = true;
      _endRound(low);
    } else {
      turn = (turn + 1) % players;
    }
    return true;
  }

  int pipsOf(int seat) => hands[seat].fold(0, (s, d) => s + d.pips);

  void _endRound(int winner) {
    var pts = 0;
    for (var p = 0; p < players; p++) {
      if (p != winner) pts += pipsOf(p);
    }
    // Blocked rounds: the winner's own pips are not counted for them.
    if (blocked) pts -= pipsOf(winner);
    roundPoints = math.max(pts, 0);
    scores[winner] += roundPoints;
    roundWinner = winner;
  }

  /// The computer's move for the player to move: plays, draws or passes.
  /// level 0 = easy (random), 1 = medium (heaviest tile), 2 = hard (keeps
  /// options open and blocks the next player).
  BotAction botAction(int level) {
    final seat = turn;
    final ms = moves(seat);
    if (ms.isEmpty) return boneyard.isNotEmpty ? const BotAction.draw() : const BotAction.pass();
    if (level <= 0) return BotAction.play(ms[_r.nextInt(ms.length)]);
    DominoMove? best;
    var bestScore = -1e9;
    for (final m in ms) {
      final d = hands[seat][m.index];
      var score = d.pips * 1.0 + (d.isDouble ? 4 : 0);
      if (level >= 2) {
        final open = _openAfter(d, m.end);
        final mine = hands[seat].where((x) => x != d);
        // Keep numbers we can still follow.
        score += 3 * mine.where((x) => x.has(open.$1) || x.has(open.$2)).length;
        // Prefer ends the next player is likely missing (they passed / drew).
        score += 6 * (_weak[(seat + 1) % players].contains(open.$1) ? 1 : 0);
        score += 6 * (_weak[(seat + 1) % players].contains(open.$2) ? 1 : 0);
      }
      if (score > bestScore) {
        bestScore = score;
        best = m;
      }
    }
    return BotAction.play(best!);
  }

  /// Numbers each seat could not follow (learned from draws and passes).
  late final List<Set<int>> _weak = List.generate(players, (_) => <int>{});

  /// Remembers that [seat] could not follow the open ends right now.
  void noteCannotFollow(int seat) {
    if (line.isEmpty) return;
    _weak[seat]
      ..add(leftEnd)
      ..add(rightEnd);
  }

  (int, int) _openAfter(Domino d, End end) {
    if (line.isEmpty) return (d.a, d.b);
    if (end == End.left) return (d.b == leftEnd ? d.a : d.b, rightEnd);
    return (leftEnd, d.a == rightEnd ? d.b : d.a);
  }
}

class BotAction {
  const BotAction.play(DominoMove this.move) : kind = 'play';
  const BotAction.draw()
      : kind = 'draw',
        move = null;
  const BotAction.pass()
      : kind = 'pass',
        move = null;
  final String kind;
  final DominoMove? move;
}
