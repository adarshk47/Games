import 'dart:async';
import '../../core/ui/player_names.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/dominoes_logic.dart';

const _tint = Color(0xFF0E9F6E);
const _ivory = Color(0xFFFFF8E7);
const _pip = Color(0xFF1B1B2F);

/// Dominoes (Draw game) against 1–3 computer players.
class DominoesScreen extends StatefulWidget {
  const DominoesScreen({super.key});

  @override
  State<DominoesScreen> createState() => _DominoesScreenState();
}

class _DominoesScreenState extends State<DominoesScreen> {
  late int _players = Storage.getInt('dominoes.pref.players', 2).clamp(2, 4);
  late int _level = Storage.getInt('dominoes.pref.level', 1).clamp(0, 2);
  late int _target = Storage.getInt('dominoes.pref.target', 100) == 50 ? 50 : 100;

  void _start() {
    Storage.setInt('dominoes.pref.players', _players);
    Storage.setInt('dominoes.pref.level', _level);
    Storage.setInt('dominoes.pref.target', _target);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DominoesPlayScreen(players: _players, level: _level, target: _target),
    ));
  }

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(t, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
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
  Widget build(BuildContext context) => GameScaffold(
        title: tr('game.dominoes.title'),
        tint: _tint,
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                DominoTile(Domino(6, 6), size: 26, vertical: true),
                SizedBox(width: 8),
                DominoTile(Domino(3, 5), size: 26),
                SizedBox(width: 8),
                DominoTile(Domino(1, 2), size: 26, vertical: true),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Text(tr('domino.intro'), style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4)),
          _section(tr('domino.players')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in const [2, 3, 4])
              _chip(tr('domino.vs_cpu', {'n': n - 1}), _players == n, () => setState(() => _players = n), key: ValueKey('domino_players_$n')),
          ]),
          _section(tr('ludo.difficulty')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, k) in const ['ludo.easy', 'ludo.medium', 'ludo.hard'].indexed)
              _chip(tr(k), _level == i, () => setState(() => _level = i), key: ValueKey('domino_level_$i')),
          ]),
          _section(tr('domino.target')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final t in const [50, 100])
              _chip(tr('domino.points', {'n': t}), _target == t, () => setState(() => _target = t), key: ValueKey('domino_target_$t')),
          ]),
          const SizedBox(height: 14),
          GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              const Icon(Icons.emoji_events_rounded, color: Pal.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(tr('domino.stats', {'w': Rewards.wins('dominoes'), 'p': Rewards.plays('dominoes')}),
                    style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 13)),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          PremiumButton(
            key: const ValueKey('domino_start'),
            label: tr('domino.start'),
            icon: Icons.play_arrow_rounded,
            color: _tint,
            onTap: _start,
          ),
        ]),
      );
}

class DominoesPlayScreen extends StatefulWidget {
  const DominoesPlayScreen({super.key, required this.players, required this.level, required this.target, this.random});
  final int players, level, target;
  final math.Random? random;

  /// Delay before computer moves (shorter in tests).
  @visibleForTesting
  static Duration botDelay = const Duration(milliseconds: 750);

  @override
  State<DominoesPlayScreen> createState() => _DominoesPlayScreenState();
}

class _DominoesPlayScreenState extends State<DominoesPlayScreen> {
  late final DominoGame _g = DominoGame(players: widget.players, target: widget.target, random: widget.random);
  Timer? _bot;
  int? _picked; // hand index waiting for an end choice
  String? _note; // last action, e.g. "CPU 1 drew a tile"
  bool _ended = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _bot?.cancel();
    super.dispose();
  }

  String _name(int seat) => seat == 0 ? tr('domino.you') : PlayerNames.bot(seat);

  void _drive() {
    _bot?.cancel();
    if (!mounted || _g.roundOver) return;
    if (_g.turn == 0) return;
    _bot = Timer(DominoesPlayScreen.botDelay, () {
      if (!mounted || _g.roundOver || _g.turn == 0) return;
      final seat = _g.turn;
      final a = _g.botAction(widget.level);
      setState(() {
        switch (a.kind) {
          case 'play':
            _g.play(seat, a.move!.index, a.move!.end);
            AppAudio.play(Sound.place);
            _note = null;
          case 'draw':
            _g.noteCannotFollow(seat);
            _g.draw(seat);
            AppAudio.play(Sound.flip, volume: 0.5);
            _note = tr('domino.cpu_drew', {'name': _name(seat)});
          default:
            _g.noteCannotFollow(seat);
            _g.pass(seat);
            _note = tr('domino.cpu_passed', {'name': _name(seat)});
        }
      });
      _afterMove();
    });
  }

  void _afterMove() {
    if (_g.roundOver) {
      _roundEnd();
    } else {
      _drive();
    }
  }

  void _tapTile(int i) {
    if (_g.turn != 0 || _g.roundOver) return;
    final ends = _g.endsFor(0, i);
    if (ends.isEmpty) {
      AppAudio.play(Sound.fail, volume: 0.4);
      AppAudio.haptic();
      return;
    }
    if (ends.length == 1) {
      _playMine(i, ends.first);
    } else {
      setState(() => _picked = i);
    }
  }

  void _playMine(int i, End end) {
    setState(() {
      _g.play(0, i, end);
      _picked = null;
      _note = null;
    });
    AppAudio.play(Sound.place);
    _afterMove();
  }

  void _drawOrPass() {
    if (_g.turn != 0 || _g.canPlay(0)) return;
    setState(() {
      _g.noteCannotFollow(0);
      if (_g.boneyard.isNotEmpty) {
        _g.draw(0);
        AppAudio.play(Sound.flip, volume: 0.6);
      } else {
        _g.pass(0);
      }
      _note = null;
    });
    _afterMove();
  }

  void _roundEnd() {
    final w = _g.roundWinner!;
    final match = _g.matchWinner;
    if (match != null) {
      _matchEnd(match);
      return;
    }
    AppAudio.play(w == 0 ? Sound.success : Sound.fail, volume: 0.7);
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        emoji: w == 0 ? '🎉' : '🁫',
        title: tr('domino.round_won', {'name': _name(w), 'n': _g.roundPoints}),
        message: [
          if (_g.blocked) tr('domino.blocked'),
          for (var p = 0; p < _g.players; p++) '${_name(p)}: ${_g.scores[p]} / ${widget.target}',
        ].join('\n'),
        actions: [
          DialogAction(tr('domino.next_round'), () {
            setState(() {
              _g.newRound();
              _note = null;
            });
            _drive();
          }, primary: true),
        ],
      );
    });
  }

  void _matchEnd(int w) {
    if (_ended) return;
    _ended = true;
    final won = w == 0;
    Rewards.onGameEnd('dominoes', score: _g.scores[0], won: won, tier: ['easy', 'medium', 'hard'][widget.level]);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        emoji: won ? '🏆' : '🁫',
        title: won ? tr('domino.match_won') : tr('domino.match_lost', {'name': _name(w)}),
        message: [for (var p = 0; p < _g.players; p++) '${_name(p)}: ${_g.scores[p]}'].join('\n'),
        actions: [
          DialogAction(tr('ludo.play_again'), () {
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => DominoesPlayScreen(players: widget.players, level: widget.level, target: widget.target),
            ));
          }, primary: true),
          DialogAction(tr('ludo.menu'), () => Navigator.of(context).maybePop()),
        ],
      );
    });
  }

  Widget _opponent(int seat) {
    final active = _g.turn == seat && !_g.roundOver;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: active ? 0.16 : 0.06),
        border: Border.all(color: active ? Pal.gold : Pal.glassBorder, width: active ? 2 : 1),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_name(seat), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 4),
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < math.min(_g.hands[seat].length, 7); i++)
            Container(
              width: 7,
              height: 14,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(color: _ivory.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(2)),
            ),
          if (_g.hands[seat].length > 7) Text(' +${_g.hands[seat].length - 7}', style: const TextStyle(color: Pal.textDim, fontSize: 11)),
        ]),
        const SizedBox(height: 4),
        Text('${_g.scores[seat]} ${tr('domino.pts')}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 12)),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myTurn = _g.turn == 0 && !_g.roundOver;
    final hand = _g.hands[0];
    final canPlay = myTurn && _g.canPlay(0);
    final status = _g.roundOver
        ? ''
        : myTurn
            ? (canPlay ? tr('domino.your_turn') : (_g.boneyard.isNotEmpty ? tr('domino.cant_play') : tr('domino.must_pass')))
            : (_note ?? tr('domino.cpu_turn', {'name': _name(_g.turn)}));
    return GameScaffold(
      title: tr('game.dominoes.title'),
      tint: _tint,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
            for (var s = 1; s < _g.players; s++) _opponent(s),
          ]),
        ),
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const RadialGradient(colors: [Color(0xFF16774F), Color(0xFF0B3D2A)]),
              border: Border.all(color: const Color(0xFF6B4A2B), width: 5),
            ),
            child: _Board(line: _g.line, highlightEnds: _picked != null),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(children: [
            Text('🁣 ${tr('domino.boneyard', {'n': _g.boneyard.length})}', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700, fontSize: 12)),
            const Spacer(),
            Text('${tr('domino.you')}: ${_g.scores[0]} / ${widget.target}', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900)),
          ]),
        ),
        Text(status, key: const ValueKey('domino_status'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
        if (_picked != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              PremiumButton(key: const ValueKey('domino_left'), label: '◀ ${tr('domino.left')}', compact: true, color: _tint, onTap: () => _playMine(_picked!, End.left)),
              const SizedBox(width: 12),
              PremiumButton(key: const ValueKey('domino_right'), label: '${tr('domino.right')} ▶', compact: true, color: _tint, onTap: () => _playMine(_picked!, End.right)),
            ]),
          ),
        Container(
          margin: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: Colors.white.withValues(alpha: 0.06),
            border: Border.all(color: myTurn ? Pal.gold : Pal.glassBorder, width: myTurn ? 2 : 1),
          ),
          child: Column(children: [
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
              for (var i = 0; i < hand.length; i++)
                Pressable(
                  key: ValueKey('domino_hand_$i'),
                  onTap: () => _tapTile(i),
                  child: Opacity(
                    opacity: !myTurn || _g.endsFor(0, i).isNotEmpty ? 1 : 0.4,
                    child: DominoTile(
                      hand[i],
                      size: 22,
                      vertical: true,
                      glow: myTurn && _g.endsFor(0, i).isNotEmpty,
                      selected: _picked == i,
                    ),
                  ),
                ),
            ]),
            if (myTurn && !canPlay) ...[
              const SizedBox(height: 10),
              PremiumButton(
                key: const ValueKey('domino_draw'),
                label: _g.boneyard.isNotEmpty ? tr('domino.draw') : tr('domino.pass'),
                icon: _g.boneyard.isNotEmpty ? Icons.add_card_rounded : Icons.skip_next_rounded,
                compact: true,
                color: _tint,
                onTap: _drawOrPass,
              ),
            ],
          ]),
        ),
      ]),
    );
  }
}

/// The line of tiles, laid out in a snake (left→right, then right→left …)
/// so it always fits the table. Doubles stand across the line.
class _Board extends StatelessWidget {
  const _Board({required this.line, required this.highlightEnds});
  final List<Placed> line;
  final bool highlightEnds;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        if (line.isEmpty) return const SizedBox.shrink();
        // Unit = one half-tile. Normal tiles are 2 units wide, doubles 1.
        final units = line.fold<double>(0, (a, p) => a + (p.isDouble ? 1.1 : 2.1));
        var u = 26.0;
        int rowsFor(double unit) {
          final perRow = math.max(2.2, (c.maxWidth - 16) / unit);
          return (units / (perRow * 0.92)).ceil();
        }
        while (u > 9 && rowsFor(u) * u * 2.3 > c.maxHeight - 16) {
          u -= 1;
        }
        final perRow = (c.maxWidth - 16) / u;
        final rows = <List<(Placed, bool)>>[[]];
        var used = 0.0;
        for (var i = 0; i < line.length; i++) {
          final w = line[i].isDouble ? 1.1 : 2.1;
          if (used + w > perRow && rows.last.isNotEmpty) {
            rows.add([]);
            used = 0;
          }
          rows.last.add((line[i], i == 0 || i == line.length - 1));
          used += w;
        }
        return Center(
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              for (final (r, row) in rows.indexed)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: u * 0.12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final (p, isEnd) in (r.isOdd ? row.reversed : row))
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: u * 0.05),
                          child: DominoTile(
                            r.isOdd ? Domino(p.right, p.left) : Domino(p.left, p.right),
                            size: u,
                            vertical: p.isDouble,
                            glow: highlightEnds && isEnd,
                          ),
                        ),
                    ],
                  ),
                ),
            ]),
          ),
        );
      });
}

/// One domino: two halves with pips, ivory with a dark divider.
class DominoTile extends StatelessWidget {
  const DominoTile(this.d, {super.key, this.size = 24, this.vertical = false, this.glow = false, this.selected = false});
  final Domino d;

  /// Size of one half (square).
  final double size;
  final bool vertical, glow, selected;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: vertical ? size : size * 2,
        height: vertical ? size * 2 : size,
        decoration: BoxDecoration(
          color: _ivory,
          borderRadius: BorderRadius.circular(size * 0.18),
          border: Border.all(color: selected ? Pal.gold : (glow ? const Color(0xFF34D399) : Colors.black26), width: selected || glow ? 2.5 : 1),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 3, offset: const Offset(1, 2)),
            if (glow || selected) BoxShadow(color: (selected ? Pal.gold : const Color(0xFF34D399)).withValues(alpha: 0.6), blurRadius: 10),
          ],
        ),
        child: CustomPaint(painter: _DominoPainter(d.a, d.b, vertical)),
      );
}

class _DominoPainter extends CustomPainter {
  _DominoPainter(this.a, this.b, this.vertical);
  final int a, b;
  final bool vertical;

  static const _spots = {
    0: <Offset>[],
    1: [Offset(.5, .5)],
    2: [Offset(.25, .25), Offset(.75, .75)],
    3: [Offset(.25, .25), Offset(.5, .5), Offset(.75, .75)],
    4: [Offset(.25, .25), Offset(.75, .25), Offset(.25, .75), Offset(.75, .75)],
    5: [Offset(.25, .25), Offset(.75, .25), Offset(.5, .5), Offset(.25, .75), Offset(.75, .75)],
    6: [Offset(.25, .22), Offset(.75, .22), Offset(.25, .5), Offset(.75, .5), Offset(.25, .78), Offset(.75, .78)],
  };

  @override
  void paint(Canvas canvas, Size s) {
    final half = vertical ? Size(s.width, s.height / 2) : Size(s.width / 2, s.height);
    final line = Paint()
      ..color = Colors.black45
      ..strokeWidth = math.max(1, half.shortestSide * 0.06);
    if (vertical) {
      canvas.drawLine(Offset(s.width * 0.15, s.height / 2), Offset(s.width * 0.85, s.height / 2), line);
    } else {
      canvas.drawLine(Offset(s.width / 2, s.height * 0.15), Offset(s.width / 2, s.height * 0.85), line);
    }
    final dot = Paint()..color = _pip;
    final r = half.shortestSide * 0.09;
    for (final (k, v) in [(0, a), (1, b)]) {
      final origin = vertical ? Offset(0, half.height * k) : Offset(half.width * k, 0);
      for (final o in _spots[v]!) {
        canvas.drawCircle(origin + Offset(o.dx * half.width, o.dy * half.height), r, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_DominoPainter old) => old.a != a || old.b != b || old.vertical != vertical;
}
