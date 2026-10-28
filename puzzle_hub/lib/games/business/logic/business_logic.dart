import 'dart:math' as math;

/// Business (Vyapar) rules engine – pure Dart, shared by offline and (later)
/// online games. Dice and card order come from the game seed, so replaying
/// the same action log always gives the same game on every phone.
///
/// Board: 36 squares. 0 Start, 9 Jail, 18 Club (rest), 27 Go to Jail.
enum Sq { start, city, transport, utility, kismat, khazana, tax, jail, club, goJail }

class Square {
  const Square(this.kind, {this.group = -1, this.price = 0, this.amount = 0});
  final Sq kind;

  /// Colour group of a city (0..7).
  final int group;
  final int price;

  /// Tax to pay.
  final int amount;

  bool get ownable => kind == Sq.city || kind == Sq.transport || kind == Sq.utility;
}

class Biz {
  static const size = 36;
  static const jail = 9;
  static const startMoney = 15000;
  static const salary = 1500;
  static const transportPrice = 2000;
  static const utilityPrice = 1500;
  static const groupPrice = [600, 1000, 1400, 1800, 2200, 2600, 3000, 3800];

  static final List<Square> board = () {
    Square c(int g) => Square(Sq.city, group: g, price: groupPrice[g]);
    const t = Square(Sq.transport, price: transportPrice);
    const u = Square(Sq.utility, price: utilityPrice);
    const k = Square(Sq.kismat);
    const kh = Square(Sq.khazana);
    return [
      const Square(Sq.start), c(0), kh, c(0), const Square(Sq.tax, amount: 1000), t, c(1), k, c(1), //
      const Square(Sq.jail), c(2), u, c(2), c(2), t, c(3), kh, c(3), //
      const Square(Sq.club), c(4), k, c(4), c(4), t, c(5), u, c(5), //
      const Square(Sq.goJail), c(6), c(6), const Square(Sq.tax, amount: 500), c(6), t, k, c(7), c(7),
    ];
  }();

  /// Squares of a city group.
  static List<int> groupSquares(int g) => [
        for (var i = 0; i < size; i++)
          if (board[i].kind == Sq.city && board[i].group == g) i,
      ];

  /// Cost of one house (4th level = hotel) on a city.
  static int houseCost(int sq) => board[sq].price ~/ 2;

  /// Rent multipliers for 0..3 houses and a hotel (level 4).
  static const _rentLevels = [1, 5, 15, 30, 45];

  static const kismatCards = 10;
  static const khazanaCards = 10;
}

enum Phase { roll, buy, over }

/// One move. Encoded as an int for online logs: `seat * 1000 + code`.
/// Codes: 0 roll, 1 buy, 2 skip buying, 100+sq build, 200+sq sell a house.
class BizAction {
  const BizAction(this.seat, this.code);
  const BizAction.roll(this.seat) : code = 0;
  const BizAction.buy(this.seat) : code = 1;
  const BizAction.skip(this.seat) : code = 2;
  BizAction.build(this.seat, int sq) : code = 100 + sq;
  BizAction.sell(this.seat, int sq) : code = 200 + sq;
  final int seat, code;

  int toInt() => seat * 1000 + code;
  static BizAction fromInt(int v) => BizAction(v ~/ 1000, v % 1000);
}

/// What the last action did (for messages, sounds and animation).
class BizEvent {
  BizEvent(this.seat);
  final int seat;
  int? d1, d2;
  int? from, to;
  bool passedStart = false;
  bool toJail = false;
  bool jailWait = false;
  int? paid; // money paid (rent / tax / card)
  int? paidTo; // seat that received rent
  int? got; // money received
  int? card; // card shown: kismat 0..9 or khazana 100..109
  bool bought = false;
  bool built = false;
  bool sold = false;
  bool bankrupt = false;
}

class BusinessGame {
  BusinessGame({required this.players, required this.seed, this.maxRounds = 0})
      : money = List.filled(players, Biz.startMoney),
        pos = List.filled(players, 0),
        jailTurns = List.filled(players, 0),
        out = List.filled(players, false) {
    assert(players >= 2 && players <= 4);
    final r = math.Random(seed ^ 0x5eed);
    _kismat = List.generate(Biz.kismatCards, (i) => i)..shuffle(r);
    _khazana = List.generate(Biz.khazanaCards, (i) => i)..shuffle(r);
  }

  final int players, seed;

  /// 0 = play until one player is left; otherwise the richest player after
  /// this many rounds wins.
  final int maxRounds;

  final List<int> money, pos, jailTurns;
  final List<bool> out;

  /// Owner seat per square (-1 = bank) and houses (0..4, 4 = hotel).
  final List<int> owner = List.filled(Biz.size, -1);
  final List<int> houses = List.filled(Biz.size, 0);

  final List<BizAction> log = [];
  late final List<int> _kismat, _khazana;
  int _kismatNext = 0, _khazanaNext = 0;

  int turn = 0;
  int round = 1;
  Phase phase = Phase.roll;
  int _rolls = 0; // dice thrown so far (drives the dice sequence)
  int _doubles = 0; // doubles in a row this turn
  bool _again = false; // threw a double: same player rolls again
  BizEvent last = BizEvent(0);

  int? get winner {
    if (phase != Phase.over) return null;
    final alive = [for (var i = 0; i < players; i++) if (!out[i]) i];
    if (alive.length == 1) return alive.first;
    var best = alive.first;
    for (final p in alive) {
      if (worth(p) > worth(best)) best = p;
    }
    return best;
  }

  /// Dice for roll number [n] (same on every phone).
  (int, int) diceAt(int n) {
    final r = math.Random(seed * 7919 + n * 104729);
    return (1 + r.nextInt(6), 1 + r.nextInt(6));
  }

  /// Cash + property prices + houses built (for "richest wins").
  int worth(int p) {
    var w = money[p];
    for (var s = 0; s < Biz.size; s++) {
      if (owner[s] == p) w += Biz.board[s].price + houses[s] * Biz.houseCost(s);
    }
    return w;
  }

  bool ownsGroup(int p, int g) => Biz.groupSquares(g).every((s) => owner[s] == p);

  int ownedOfKind(int p, Sq k) => [for (var s = 0; s < Biz.size; s++) if (owner[s] == p && Biz.board[s].kind == k) s].length;

  /// Rent for landing on [sq] with dice total [roll].
  int rent(int sq, int roll) {
    final b = Biz.board[sq];
    final o = owner[sq];
    if (o < 0) return 0;
    switch (b.kind) {
      case Sq.city:
        final base = b.price ~/ 10;
        if (houses[sq] == 0) return ownsGroup(o, b.group) ? base * 2 : base;
        return base * Biz._rentLevels[houses[sq]];
      case Sq.transport:
        return 250 * (1 << (ownedOfKind(o, Sq.transport) - 1));
      case Sq.utility:
        return roll * (ownedOfKind(o, Sq.utility) == 2 ? 100 : 40);
      default:
        return 0;
    }
  }

  /// Squares where [p] may build now (whole group owned, below a hotel).
  List<int> buildable(int p) => [
        for (var s = 0; s < Biz.size; s++)
          if (owner[s] == p && Biz.board[s].kind == Sq.city && houses[s] < 4 && ownsGroup(p, Biz.board[s].group) && money[p] >= Biz.houseCost(s)) s,
      ];

  bool apply(BizAction a) {
    if (phase == Phase.over || a.seat != turn || out[a.seat]) return false;
    final ok = switch (a.code) {
      0 => phase == Phase.roll && _roll(a.seat),
      1 => phase == Phase.buy && _buy(a.seat),
      2 => phase == Phase.buy && _skip(a.seat),
      >= 100 && < 100 + Biz.size => phase == Phase.roll && _build(a.seat, a.code - 100),
      >= 200 && < 200 + Biz.size => phase == Phase.roll && _sell(a.seat, a.code - 200),
      _ => false,
    };
    if (ok) log.add(a);
    return ok;
  }

  static BusinessGame replay({required int players, required int seed, int maxRounds = 0, required Iterable<BizAction> actions}) {
    final g = BusinessGame(players: players, seed: seed, maxRounds: maxRounds);
    for (final a in actions) {
      g.apply(a);
    }
    return g;
  }

  // ------------------------------------------------------------------ moves

  bool _roll(int p) {
    final e = last = BizEvent(p);
    final (d1, d2) = diceAt(_rolls++);
    e
      ..d1 = d1
      ..d2 = d2;
    if (jailTurns[p] > 0) {
      // One turn in jail: this roll only releases you.
      jailTurns[p] = 0;
      e.jailWait = true;
      _nextTurn();
      return true;
    }
    final dbl = d1 == d2;
    _doubles = dbl ? _doubles + 1 : 0;
    if (_doubles == 3) {
      _toJail(p, e);
      _nextTurn();
      return true;
    }
    _again = dbl;
    _moveBy(p, d1 + d2, e);
    _land(p, d1 + d2, e);
    if (phase == Phase.roll) _finishMove(p);
    return true;
  }

  void _moveBy(int p, int steps, BizEvent e) {
    e.from = pos[p];
    final to = (pos[p] + steps) % Biz.size;
    if (steps > 0 && to < pos[p]) {
      money[p] += Biz.salary;
      e.passedStart = true;
    }
    pos[p] = to;
    e.to = to;
  }

  void _moveTo(int p, int to, BizEvent e, {bool salary = true}) {
    if (salary && to < pos[p]) {
      money[p] += Biz.salary;
      e.passedStart = true;
    }
    e.from ??= pos[p];
    pos[p] = to;
    e.to = to;
  }

  void _toJail(int p, BizEvent e) {
    e.from ??= pos[p];
    pos[p] = Biz.jail;
    e.to = Biz.jail;
    jailTurns[p] = 1;
    e.toJail = true;
    _again = false;
    _doubles = 0;
  }

  /// Resolves the square [p] landed on. May switch to the buy phase.
  void _land(int p, int roll, BizEvent e, {int depth = 0}) {
    final sq = pos[p];
    final b = Biz.board[sq];
    switch (b.kind) {
      case Sq.city:
      case Sq.transport:
      case Sq.utility:
        final o = owner[sq];
        if (o < 0) {
          phase = money[p] >= b.price ? Phase.buy : Phase.roll;
        } else if (o != p) {
          final r = rent(sq, roll);
          _pay(p, r, to: o, e: e);
        }
      case Sq.tax:
        _pay(p, b.amount, e: e);
      case Sq.goJail:
        _toJail(p, e);
      case Sq.kismat:
        if (depth == 0) _card(p, kismat: true, roll: roll, e: e);
      case Sq.khazana:
        if (depth == 0) _card(p, kismat: false, roll: roll, e: e);
      case Sq.start:
      case Sq.jail:
      case Sq.club:
        break;
    }
  }

  void _card(int p, {required bool kismat, required int roll, required BizEvent e}) {
    final id = kismat ? _kismat[_kismatNext++ % Biz.kismatCards] : _khazana[_khazanaNext++ % Biz.khazanaCards];
    e.card = kismat ? id : 100 + id;
    void gain(int v) {
      money[p] += v;
      e.got = (e.got ?? 0) + v;
    }

    if (kismat) {
      switch (id) {
        case 0: // advance to Start
          _moveTo(p, 0, e);
        case 1:
          _toJail(p, e);
        case 2:
          gain(2000);
        case 3:
          _pay(p, 300, e: e);
        case 4: // nearest transport
          var s = pos[p];
          while (Biz.board[s].kind != Sq.transport) {
            s = (s + 1) % Biz.size;
          }
          _moveTo(p, s, e);
          _land(p, roll, e, depth: 1);
        case 5: // back 3 squares
          e.from ??= pos[p];
          pos[p] = (pos[p] - 3 + Biz.size) % Biz.size;
          e.to = pos[p];
          _land(p, roll, e, depth: 1);
        case 6: // repairs
          var cost = 0;
          for (var s = 0; s < Biz.size; s++) {
            if (owner[s] == p) cost += houses[s] == 4 ? 1000 : houses[s] * 250;
          }
          if (cost > 0) _pay(p, cost, e: e);
        case 7: // birthday: everyone pays 200
          for (var q = 0; q < players; q++) {
            if (q != p && !out[q]) {
              final paid = _collect(q, 200, p);
              e.got = (e.got ?? 0) + paid;
            }
          }
        case 8:
          gain(1000);
        default:
          _pay(p, 500, e: e);
      }
    } else {
      switch (id) {
        case 0:
          gain(2000);
        case 1:
          _pay(p, 500, e: e);
        case 2:
          gain(500);
        case 3:
          _pay(p, 1000, e: e);
        case 4:
          gain(800);
        case 5:
          _toJail(p, e);
        case 6:
          _moveTo(p, 0, e);
        case 7: // pay every player 100
          for (var q = 0; q < players; q++) {
            if (q != p && !out[q]) _pay(p, 100, to: q, e: e);
          }
        case 8:
          gain(1500);
        default:
          gain(250);
      }
    }
  }

  /// [p] pays [amount] to [to] (or the bank), selling houses / properties to
  /// the bank at half price if needed. Goes bankrupt if that is not enough.
  void _pay(int p, int amount, {int? to, required BizEvent e}) {
    if (out[p] || amount <= 0) return;
    _raise(p, amount);
    final paid = math.min(amount, money[p]);
    money[p] -= paid;
    if (to != null) money[to] += paid;
    e
      ..paid = (e.paid ?? 0) + paid
      ..paidTo = to;
    if (paid < amount) _bankrupt(p, e);
  }

  /// Like [_pay] for someone else paying [p] (card "birthday"); returns paid.
  int _collect(int from, int amount, int p) {
    _raise(from, amount);
    final paid = math.min(amount, money[from]);
    money[from] -= paid;
    money[p] += paid;
    if (paid < amount) {
      _bankrupt(from, BizEvent(from));
    }
    return paid;
  }

  /// Sells houses (cheapest first), then properties, at half price until
  /// [p] has [amount] in cash.
  void _raise(int p, int amount) {
    while (money[p] < amount) {
      final withHouses = [for (var s = 0; s < Biz.size; s++) if (owner[s] == p && houses[s] > 0) s];
      if (withHouses.isNotEmpty) {
        withHouses.sort((a, b) => Biz.houseCost(a).compareTo(Biz.houseCost(b)));
        final s = withHouses.first;
        houses[s]--;
        money[p] += Biz.houseCost(s) ~/ 2;
        continue;
      }
      final owned = [for (var s = 0; s < Biz.size; s++) if (owner[s] == p) s];
      if (owned.isEmpty) return;
      owned.sort((a, b) => Biz.board[a].price.compareTo(Biz.board[b].price));
      final s = owned.first;
      owner[s] = -1;
      money[p] += Biz.board[s].price ~/ 2;
    }
  }

  void _bankrupt(int p, BizEvent e) {
    out[p] = true;
    money[p] = 0;
    for (var s = 0; s < Biz.size; s++) {
      if (owner[s] == p) {
        owner[s] = -1;
        houses[s] = 0;
      }
    }
    if (p == e.seat) e.bankrupt = true;
    if (out.where((x) => !x).length <= 1) phase = Phase.over;
  }

  bool _buy(int p) {
    final s = pos[p];
    final price = Biz.board[s].price;
    if (owner[s] >= 0 || money[p] < price) return false;
    money[p] -= price;
    owner[s] = p;
    last = BizEvent(p)
      ..bought = true
      ..to = s;
    phase = Phase.roll;
    _finishMove(p);
    return true;
  }

  bool _skip(int p) {
    last = BizEvent(p)..to = pos[p];
    phase = Phase.roll;
    _finishMove(p);
    return true;
  }

  bool _build(int p, int s) {
    if (!buildable(p).contains(s)) return false;
    money[p] -= Biz.houseCost(s);
    houses[s]++;
    last = BizEvent(p)
      ..built = true
      ..to = s;
    return true;
  }

  bool _sell(int p, int s) {
    if (owner[s] != p || houses[s] == 0) return false;
    houses[s]--;
    money[p] += Biz.houseCost(s) ~/ 2;
    last = BizEvent(p)
      ..sold = true
      ..to = s;
    return true;
  }

  /// After a move is fully resolved: roll again on a double, else next player.
  void _finishMove(int p) {
    if (phase == Phase.over) return;
    if (out[p] || !_again) {
      _nextTurn();
    }
  }

  void _nextTurn() {
    _again = false;
    _doubles = 0;
    if (phase == Phase.over) return;
    var n = turn;
    do {
      n = (n + 1) % players;
      if (n == 0) round++;
    } while (out[n]);
    turn = n;
    phase = Phase.roll;
    if (maxRounds > 0 && round > maxRounds) phase = Phase.over;
  }

  // ------------------------------------------------------------------ bot

  /// The computer's next action ([level] 0 easy .. 2 hard).
  BizAction botAction(int level) {
    final p = turn;
    if (phase == Phase.buy) {
      final price = Biz.board[pos[p]].price;
      final reserve = const [0, 1500, 2500][level.clamp(0, 2)];
      var want = money[p] - price >= reserve;
      if (level >= 2) {
        // Completing a group is worth more cash risk.
        final b = Biz.board[pos[p]];
        if (b.kind == Sq.city && Biz.groupSquares(b.group).where((s) => s != pos[p]).every((s) => owner[s] == p)) {
          want = money[p] >= price;
        }
      }
      if (level == 0) want = money[p] >= price && (seed + _rolls) % 3 != 0;
      return want ? BizAction.buy(p) : BizAction.skip(p);
    }
    // Build before rolling when rich enough.
    if (level > 0) {
      final keep = level == 1 ? 3000 : 2000;
      final opts = buildable(p).where((s) => money[p] - Biz.houseCost(s) >= keep).toList()
        ..sort((a, b) => houses[a].compareTo(houses[b]));
      if (opts.isNotEmpty) return BizAction.build(p, opts.first);
    }
    return BizAction.roll(p);
  }
}
