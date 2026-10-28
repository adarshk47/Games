import 'dart:async';
import '../../core/ui/player_names.dart';
import '../ludo/dice_input.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import '../ludo/logic/ludo_logic.dart';
import '../ludo/ludo_board.dart';
import '../ludo/online/ludo_online_lobby.dart';
import 'logic/snakes_logic.dart';
import 'snakes_board.dart';

const _tint = Color(0xFF43A047);

/// Saved offline game: players, bots, seed and rolls.
class SnakesSave {
  static const key = 'snakes.inprogress';

  static ({int players, bool cpu, int seed, List<int> rolls, DiceMode dice})? load() {
    final raw = Storage.getString(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (players: j['p'] as int, cpu: j['c'] as bool, seed: j['s'] as int, rolls: (j['r'] as List).cast<int>(), dice: DiceMode.fromName(j['d'] as String?));
    } catch (_) {
      return null;
    }
  }

  static void save(int players, bool cpu, SnakesGame g, [DiceMode dice = DiceMode.auto]) =>
      Storage.setString(key, jsonEncode({'p': players, 'c': cpu, 's': g.seed, 'r': g.log, 'd': dice.name}));

  static void clear() => Storage.remove(key);
}

List<LudoSeat> snakesSeats(int players, bool cpu) {
  final cols = ludoColours(players);
  return [
    for (var i = 0; i < players; i++)
      LudoSeat(cols[i], cpu && i > 0 ? SeatKind.bot : SeatKind.human,
          name: cpu ? (i == 0 ? tr('ludo.you') : PlayerNames.bot(i)) : PlayerNames.friend(i)),
  ];
}

/// Saanp-Seedhi menu: vs computer, friends on one phone, or online.
class SnakesScreen extends StatefulWidget {
  const SnakesScreen({super.key});

  @override
  State<SnakesScreen> createState() => _SnakesScreenState();
}

class _SnakesScreenState extends State<SnakesScreen> {
  int _players = 2;
  bool _cpu = true;
  DiceMode _dice = DiceMode.auto;

  Future<void> _start({required int players, required bool cpu, int? seed, List<int> rolls = const [], DiceMode? dice}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SnakesPlayScreen(players: players, cpu: cpu, seed: seed ?? math.Random().nextInt(1 << 30), resume: rolls, dice: dice ?? _dice),
    ));
    if (mounted) setState(() {});
  }

  Widget _chip(String label, bool sel, VoidCallback onTap, {Key? key}) => Pressable(
        key: key,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: sel ? _tint.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: sel ? Pal.gold : Pal.glassBorder),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      );

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(t, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );

  @override
  Widget build(BuildContext context) {
    final saved = SnakesSave.load();
    return GameScaffold(
      title: tr('game.snakes.title'),
      tint: _tint,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
        const Center(child: Text('🐍🪜🎲', style: TextStyle(fontSize: 40))),
        const SizedBox(height: 6),
        Text(tr('snakes.intro'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, height: 1.4)),
        if (saved != null) ...[
          const SizedBox(height: 12),
          PremiumButton(
            key: const ValueKey('snakes_continue'),
            label: tr('ludo.continue'),
            icon: Icons.play_arrow_rounded,
            onTap: () => _start(players: saved.players, cpu: saved.cpu, seed: saved.seed, rolls: saved.rolls, dice: saved.dice),
          ),
        ],
        _section(tr('ludo.mode')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(tr('ludo.vs_cpu'), _cpu, () => setState(() => _cpu = true), key: const ValueKey('snakes_cpu')),
          _chip(tr('ludo.pass_play'), !_cpu, () => setState(() => _cpu = false), key: const ValueKey('snakes_local')),
        ]),
        _section(tr('ludo.players')),
        Wrap(spacing: 8, children: [
          for (final n in const [2, 3, 4]) _chip(tr('ludo.n_players', {'n': n}), _players == n, () => setState(() => _players = n)),
        ]),
        if (!_cpu) ...[
          _section(tr('players.names')),
          PlayerNamesEditor(count: _players, colors: [for (final c in ludoColours(_players)) ludoColors[c]]),
        ],
        _section(tr('dice.title')),
        DiceModePicker(value: _dice, color: _tint, onChanged: (m) => setState(() => _dice = m)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(tr('dice.help.${_dice.name}'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.4)),
        ),
        const SizedBox(height: 20),
        PremiumButton(
          key: const ValueKey('snakes_start'),
          label: tr('ludo.start'),
          icon: Icons.casino_rounded,
          color: _tint,
          onTap: () => _start(players: _players, cpu: _cpu),
        ),
        const SizedBox(height: 12),
        PremiumButton(
          key: const ValueKey('snakes_online'),
          label: tr('online.title'),
          icon: Icons.public_rounded,
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LudoOnlineLobby(game: 'snakes'))),
        ),
      ]),
    );
  }
}

/// Bottom bar shared by offline and online Saanp-Seedhi: whose turn, the
/// last move and the dice.
class SnakesTable extends StatelessWidget {
  const SnakesTable({super.key, required this.game, required this.canRoll, required this.onRoll, this.rollSeq = 0, this.secondsLeft});
  final SnakesGame game;
  final bool canRoll;
  final VoidCallback onRoll;
  final int rollSeq;
  final int? secondsLeft;

  String _name(int s) => game.seats[s].name;

  String _status() {
    final e = game.last;
    if (e.rolled == null) return tr('ludo.tap_dice');
    final who = _name(e.seat!);
    if (e.lostTurn) return tr('ludo.three_sixes');
    if (e.blocked) return tr('snakes.need_exact', {'name': who});
    if (e.ladder) return tr('snakes.ladder', {'name': who, 'from': e.via ?? 0, 'to': e.to});
    if (e.snake) return tr('snakes.snake', {'name': who, 'from': e.via ?? 0, 'to': e.to});
    return tr('snakes.moved', {'name': who, 'n': e.rolled!, 'to': e.to});
  }

  @override
  Widget build(BuildContext context) {
    final colour = ludoColors[game.seats[game.turn].colour];
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(children: [
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (var s = 0; s < game.seats.length; s++)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: ludoColors[game.seats[s].colour].withValues(alpha: s == game.turn ? 0.5 : 0.18),
                border: Border.all(color: s == game.turn ? Colors.white : Colors.transparent, width: 1.5),
              ),
              child: Text('${game.seats[s].name} · ${game.pos[s]}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
        ]),
        const SizedBox(height: 8),
        Expanded(child: Center(child: SnakesBoard(key: const ValueKey('snakesBoard'), game: game))),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(game.over ? tr('ludo.winner', {'name': _name(game.winner!)}) : (_name(game.turn) == tr('ludo.you') ? tr('online.your_turn') : tr('ludo.turn_of', {'name': _name(game.turn)})),
                  style: TextStyle(color: colour, fontWeight: FontWeight.w900, fontSize: 16)),
              Text(_status(), style: const TextStyle(color: Pal.textDim, fontSize: 13)),
              if (secondsLeft != null && !game.over)
                Text(tr('ludo.seconds', {'n': secondsLeft}), style: const TextStyle(color: Pal.textDim, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
          ),
          LudoDice(key: const ValueKey('snakes_dice'), value: game.last.rolled, color: colour, enabled: canRoll && !game.over, rollSeq: rollSeq, onTap: onRoll),
        ]),
      ]),
    );
  }
}

/// Offline game (computer players or friends on this phone).
class SnakesPlayScreen extends StatefulWidget {
  const SnakesPlayScreen({super.key, required this.players, required this.cpu, required this.seed, this.resume = const [], this.dice = DiceMode.auto});
  final DiceMode dice;
  final int players;
  final bool cpu;
  final int seed;
  final List<int> resume;

  @visibleForTesting
  static Duration botDelay = const Duration(milliseconds: 750);

  @override
  State<SnakesPlayScreen> createState() => _SnakesPlayScreenState();
}

class _SnakesPlayScreenState extends State<SnakesPlayScreen> {
  late final SnakesGame _g = SnakesGame.replay(seats: snakesSeats(widget.players, widget.cpu), seed: widget.seed, rolls: widget.resume);
  int _rollSeq = 0;
  Timer? _bot;
  bool _ended = false;

  bool get _humanTurn => _g.seats[_g.turn].kind == SeatKind.human;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _bot?.cancel();
    if (!_g.over && _g.log.isNotEmpty) SnakesSave.save(widget.players, widget.cpu, _g, widget.dice);
    super.dispose();
  }

  /// A player's roll: the app's dice, or a real dice / riddle answer.
  Future<void> _humanRoll() async {
    final seat = _g.turn;
    if (widget.dice == DiceMode.auto) {
      _roll();
      return;
    }
    final v = await askDice(context, widget.dice, ludoColors[_g.seats[seat].colour]);
    if (!mounted || v == null || _g.turn != seat || _g.over) return;
    _roll(v);
  }

  void _roll([int? dice]) {
    if (!_g.roll(_g.turn, dice: dice)) return;
    _rollSeq++;
    final e = _g.last;
    AppAudio.play(Sound.dice);
    if (e.ladder || e.snake) {
      Future<void>.delayed(const Duration(milliseconds: 450), () => AppAudio.play(e.ladder ? Sound.success : Sound.fail));
    }
    if (e.snake || e.ladder) AppAudio.haptic();
    SnakesSave.save(widget.players, widget.cpu, _g, widget.dice);
    setState(() {});
    if (_g.over) {
      _finish();
    } else {
      _drive();
    }
  }

  void _drive() {
    _bot?.cancel();
    if (!mounted || _g.over || _humanTurn) return;
    _bot = Timer(SnakesPlayScreen.botDelay, () {
      if (mounted && !_humanTurn && !_g.over) _roll();
    });
  }

  void _finish() {
    if (_ended) return;
    _ended = true;
    SnakesSave.clear();
    final w = _g.winner!;
    final iWon = !widget.cpu || w == 0;
    if (widget.cpu && iWon) {
      final n = Storage.getInt('snakes.wins') + 1;
      Storage.setInt('snakes.wins', n);
      Rewards.onLevelComplete('snakes', 'win-$n', stars: 2, score: 100 * (widget.players - 1));
    } else {
      Rewards.onGameEnd('snakes', score: 0, won: !widget.cpu);
    }
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: widget.cpu ? tr(iWon ? 'ludo.you_won' : 'ludo.cpu_won', {'name': _g.seats[w].name}) : tr('ludo.winner', {'name': _g.seats[w].name}),
        emoji: iWon ? '🏆' : '🐍',
        actions: [
          DialogAction(tr('ludo.play_again'), () {
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => SnakesPlayScreen(players: widget.players, cpu: widget.cpu, seed: math.Random().nextInt(1 << 30), dice: widget.dice),
            ));
          }, primary: true),
          DialogAction(tr('ludo.menu'), () => Navigator.of(context).maybePop()),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) => GameScaffold(
        title: tr('game.snakes.title'),
        tint: _tint,
        body: SnakesTable(game: _g, canRoll: _humanTurn, onRoll: _humanRoll, rollSeq: _rollSeq),
      );
}
