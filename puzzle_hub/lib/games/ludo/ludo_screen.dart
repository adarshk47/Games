import 'dart:async';
import 'dice_input.dart';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/ludo_logic.dart';
import 'ludo_board.dart';
import 'ludo_table.dart';
import 'online/ludo_online_lobby.dart';

const _tint = Color(0xFFE53935);

enum LudoMode { cpu, local }

/// Settings of an offline game (also what is saved to continue later).
class LudoSetup {
  const LudoSetup({required this.mode, required this.players, required this.level, required this.quick, required this.seed, this.dice = DiceMode.auto});
  final LudoMode mode;

  /// App dice, a real dice at home, or riddles.
  final DiceMode dice;
  final int players;
  final int level; // bots: 0 easy, 1 medium, 2 hard
  final bool quick;
  final int seed;

  List<LudoSeat> seats() {
    final cols = ludoColours(players);
    return [
      for (var i = 0; i < players; i++)
        LudoSeat(
          cols[i],
          mode == LudoMode.cpu && i > 0 ? SeatKind.bot : SeatKind.human,
          name: mode == LudoMode.cpu ? (i == 0 ? tr('ludo.you') : tr('ludo.cpu_n', {'n': i})) : '',
        ),
    ];
  }

  Map<String, Object> toJson() => {'m': mode.name, 'p': players, 'l': level, 'q': quick, 's': seed, 'd': dice.name};

  static LudoSetup? fromJson(Map<String, dynamic> j) {
    try {
      return LudoSetup(
        mode: LudoMode.values.byName(j['m'] as String),
        players: j['p'] as int,
        level: j['l'] as int,
        quick: j['q'] as bool,
        seed: j['s'] as int,
        dice: DiceMode.fromName(j['d'] as String?),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Saved offline game: setup + action log (replayed on continue).
class LudoSave {
  static const key = 'ludo.inprogress';

  static (LudoSetup, List<LudoAction>)? load() {
    final raw = Storage.getString(key);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final setup = LudoSetup.fromJson((j['setup'] as Map).cast<String, dynamic>());
      if (setup == null) return null;
      final log = [for (final a in j['log'] as List) LudoAction.fromJson(a)].whereType<LudoAction>().toList();
      return (setup, log);
    } catch (_) {
      return null;
    }
  }

  static void save(LudoSetup s, LudoGame g) =>
      Storage.setString(key, jsonEncode({'setup': s.toJson(), 'log': [for (final a in g.log) a.toJson()]}));

  static void clear() => Storage.remove(key);
}

/// Ludo menu: vs computer, pass & play on one phone, or online.
class LudoScreen extends StatefulWidget {
  const LudoScreen({super.key});

  @override
  State<LudoScreen> createState() => _LudoScreenState();
}

class _LudoScreenState extends State<LudoScreen> {
  LudoMode _mode = LudoMode.cpu;
  int _players = 4;
  int _level = 1;
  bool _quick = false;
  DiceMode _dice = DiceMode.auto;

  Future<void> _start(LudoSetup s, [List<LudoAction> log = const []]) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LudoPlayScreen(setup: s, resume: log)));
    if (mounted) setState(() {});
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(t, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );

  Widget _card({required Key key, required IconData icon, required String label, required bool selected, required VoidCallback onTap, Gradient? gradient}) => Pressable(
        key: key,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: gradient ?? (selected ? Pal.accent(_tint) : const LinearGradient(colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)])),
            border: Border.all(color: selected ? Pal.gold : Pal.glassBorder, width: selected ? 1.5 : 1),
          ),
          child: Column(children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 6),
            Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          ]),
        ),
      );

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

  @override
  Widget build(BuildContext context) {
    final saved = LudoSave.load();
    return GameScaffold(
      title: tr('game.ludo.title'),
      tint: _tint,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
        Center(
          child: SizedBox(
            width: 120,
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              for (final c in ludoColors) SizedBox(width: 22, height: 22, child: LudoToken(color: c)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(tr('ludo.intro'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, height: 1.4)),
        if (saved != null) ...[
          const SizedBox(height: 12),
          PremiumButton(
            key: const ValueKey('ludo_continue'),
            label: tr('ludo.continue'),
            icon: Icons.play_arrow_rounded,
            onTap: () => _start(saved.$1, saved.$2),
          ),
        ],
        _section(tr('ludo.mode')),
        Row(children: [
          Expanded(child: _card(key: const ValueKey('ludo_mode_cpu'), icon: Icons.smart_toy_rounded, label: tr('ludo.vs_cpu'), selected: _mode == LudoMode.cpu, onTap: () => setState(() => _mode = LudoMode.cpu))),
          const SizedBox(width: 8),
          Expanded(child: _card(key: const ValueKey('ludo_mode_local'), icon: Icons.people_alt_rounded, label: tr('ludo.pass_play'), selected: _mode == LudoMode.local, onTap: () => setState(() => _mode = LudoMode.local))),
          const SizedBox(width: 8),
          Expanded(
            child: _card(
              key: const ValueKey('ludo_mode_online'),
              icon: Icons.public_rounded,
              label: tr('online.title'),
              selected: false,
              gradient: Pal.accent(Pal.gold),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LudoOnlineLobby())),
            ),
          ),
        ]),
        _section(tr('ludo.players')),
        Wrap(spacing: 8, children: [
          for (final n in const [2, 3, 4]) _chip(tr('ludo.n_players', {'n': n}), _players == n, () => setState(() => _players = n), key: ValueKey('ludo_players_$n')),
        ]),
        if (_mode == LudoMode.cpu) ...[
          _section(tr('ludo.difficulty')),
          Wrap(spacing: 8, children: [
            for (final (i, k) in const ['ludo.easy', 'ludo.medium', 'ludo.hard'].indexed) _chip(tr(k), _level == i, () => setState(() => _level = i)),
          ]),
        ],
        _section(tr('ludo.rules')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _chip(tr('ludo.classic'), !_quick, () => setState(() => _quick = false), key: const ValueKey('ludo_classic')),
          _chip(tr('ludo.quick'), _quick, () => setState(() => _quick = true), key: const ValueKey('ludo_quick')),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(tr(_quick ? 'ludo.quick_text' : 'ludo.classic_text'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.4)),
        ),
        _section(tr('dice.title')),
        DiceModePicker(value: _dice, color: _tint, onChanged: (m) => setState(() => _dice = m)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(tr('dice.help.${_dice.name}'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.4)),
        ),
        const SizedBox(height: 20),
        PremiumButton(
          key: const ValueKey('ludo_start'),
          label: tr('ludo.start'),
          icon: Icons.casino_rounded,
          color: _tint,
          onTap: () => _start(LudoSetup(mode: _mode, players: _players, level: _level, quick: _quick, seed: math.Random().nextInt(1 << 30), dice: _dice)),
        ),
      ]),
    );
  }
}

/// An offline game (bots and / or players sharing this phone).
class LudoPlayScreen extends StatefulWidget {
  const LudoPlayScreen({super.key, required this.setup, this.resume = const []});
  final LudoSetup setup;
  final List<LudoAction> resume;

  @override
  State<LudoPlayScreen> createState() => _LudoPlayScreenState();
}

class _LudoPlayScreenState extends State<LudoPlayScreen> {
  late LudoGame _g;
  int _rollSeq = 0;
  Timer? _bot;
  bool _ended = false;
  final _rnd = math.Random();

  /// Delay before bots act (shorter in tests).
  @visibleForTesting
  static Duration botDelay = const Duration(milliseconds: 650);

  @override
  void initState() {
    super.initState();
    _g = LudoGame.replay(seats: widget.setup.seats(), seed: widget.setup.seed, quick: widget.setup.quick, actions: widget.resume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _bot?.cancel();
    if (!_g.over && _g.log.isNotEmpty) LudoSave.save(widget.setup, _g);
    super.dispose();
  }

  bool get _humanTurn => _g.seats[_g.turn].kind == SeatKind.human;

  void _act(LudoAction a) {
    if (!_g.apply(a)) return;
    final e = _g.last;
    if (a.isRoll) {
      _rollSeq++;
      AppAudio.play(Sound.tap);
      if (e.lostTurn || e.passed) AppAudio.play(Sound.fail, volume: 0.35);
    } else {
      AppAudio.play(e.captured.isNotEmpty ? Sound.success : (e.reachedHome ? Sound.coin : Sound.pop));
      if (e.captured.isNotEmpty) AppAudio.haptic();
    }
    LudoSave.save(widget.setup, _g);
    setState(() {});
    if (_g.over) {
      _finish();
    } else {
      _drive();
    }
  }

  /// A player's roll: the app's dice, or a real dice / riddle answer.
  Future<void> _humanRoll() async {
    final seat = _g.turn;
    if (widget.setup.dice == DiceMode.auto) {
      _act(LudoAction.roll(seat));
      return;
    }
    final v = await askDice(context, widget.setup.dice, ludoColors[_g.colourOf(seat)]);
    if (!mounted || v == null || _g.turn != seat || _g.pending != null) return;
    _act(LudoAction.roll(seat, dice: v));
  }

  /// Bots play by themselves; a human with exactly one possible move moves
  /// automatically.
  void _drive() {
    _bot?.cancel();
    if (!mounted || _g.over) return;
    if (!_humanTurn) {
      _bot = Timer(botDelay, () {
        if (!mounted || _g.over || _humanTurn) return;
        if (_g.pending == null) {
          _act(LudoAction.roll(_g.turn));
        } else {
          _act(LudoAction.move(_g.turn, _g.botChoice(widget.setup.level, _rnd)));
        }
      });
      return;
    }
    if (_g.pending != null) {
      final opts = _g.movable(_g.turn, _g.pending!);
      if (opts.length == 1) {
        _bot = Timer(botDelay, () {
          if (mounted && _humanTurn && _g.pending != null) _act(LudoAction.move(_g.turn, opts.first));
        });
      }
    }
  }

  void _finish() {
    if (_ended) return;
    _ended = true;
    LudoSave.clear();
    final w = _g.winner!;
    final cpu = widget.setup.mode == LudoMode.cpu;
    final iWon = cpu ? w == 0 : true;
    if (cpu && iWon) {
      final n = Storage.getInt('ludo.wins') + 1;
      Storage.setInt('ludo.wins', n);
      Rewards.onLevelComplete('ludo', 'win-$n', stars: widget.setup.level + 1, score: 100 * (widget.setup.level + 1) * (widget.setup.players - 1), tier: ['easy', 'medium', 'hard'][widget.setup.level]);
    } else {
      Rewards.onGameEnd('ludo', score: 0, won: !cpu);
    }
    final name = _g.seats[w].name.isNotEmpty ? _g.seats[w].name : tr('ludo.colour.${_g.colourOf(w)}');
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: cpu ? tr(iWon ? 'ludo.you_won' : 'ludo.cpu_won', {'name': name}) : tr('ludo.winner', {'name': name}),
        emoji: iWon ? '🏆' : '🎲',
        message: [for (final (i, s) in _g.finished.indexed) '${i + 1}. ${_g.seats[s].name.isNotEmpty ? _g.seats[s].name : tr('ludo.colour.${_g.colourOf(s)}')}'].join('\n'),
        actions: [
          DialogAction(tr('ludo.play_again'), () {
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => LudoPlayScreen(
                setup: LudoSetup(mode: widget.setup.mode, players: widget.setup.players, level: widget.setup.level, quick: widget.setup.quick, seed: _rnd.nextInt(1 << 30), dice: widget.setup.dice),
              ),
            ));
          }, primary: true),
          DialogAction(tr('ludo.menu'), () => Navigator.of(context).maybePop()),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('game.ludo.title'),
      tint: _tint,
      body: LudoTable(
        game: _g,
        canAct: _humanTurn && !_g.over,
        rollSeq: _rollSeq,
        onRoll: _humanRoll,
        onToken: (i) => _act(LudoAction.move(_g.turn, i)),
        status: _g.last.lostTurn
            ? tr('ludo.three_sixes')
            : (_g.last.passed && _g.pending == null ? tr('ludo.no_move', {'n': _g.last.rolled ?? 0}) : null),
      ),
    );
  }
}
