import 'dart:async';
import '../ludo/online/ludo_online_lobby.dart';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'business_board.dart';
import 'logic/business_logic.dart';

const _tint = Color(0xFF2E7D32);

String bizCardText(int id, {required bool world}) => tr(id < 100 ? 'biz.card.k$id' : 'biz.card.c${id - 100}', {'cur': world ? '\$' : '₹'});

/// One line telling what the last action did (shared by offline and online).
String describeBiz(BusinessGame g, int seat, BizAction a, BizEvent e, String Function(int) name, {required bool world}) {
  String money(int v) => BizNames.money(v, world: world);
  final who = name(seat);
  if (e.bankrupt) return tr('biz.bankrupt', {'name': who});
  if (e.bought) return tr('biz.bought', {'name': who, 'sq': BizNames.square(e.to!, world: world)});
  if (e.built) return tr('biz.built', {'name': who, 'sq': BizNames.square(e.to!, world: world)});
  if (a.code == 2) return tr('biz.skipped', {'name': who});
  if (e.jailWait) return tr('biz.left_jail', {'name': who});
  final parts = <String>[];
  if (e.d1 != null) parts.add(tr('biz.rolled', {'name': who, 'a': e.d1!, 'b': e.d2!}));
  if (e.passedStart) parts.add(tr('biz.salary', {'m': money(Biz.salary)}));
  if (e.toJail) parts.add(tr('biz.to_jail'));
  if (e.card != null) parts.add('${e.card! < 100 ? '❓' : '💰'} ${bizCardText(e.card!, world: world)}');
  if ((e.paid ?? 0) > 0) {
    parts.add(e.paidTo != null ? tr('biz.paid_rent', {'m': money(e.paid!), 'name': name(e.paidTo!)}) : tr('biz.paid', {'m': money(e.paid!)}));
  }
  if (g.phase == Phase.buy && g.turn == seat) {
    parts.add(tr('biz.can_buy', {'sq': BizNames.square(g.pos[seat], world: world), 'm': money(Biz.board[g.pos[seat]].price)}));
  } else if (g.turn == seat && g.phase == Phase.roll && !e.toJail && e.d1 != null) {
    parts.add(tr('biz.double_again'));
  }
  return parts.join('  ·  ');
}

/// Business (Vyapar): buy cities, build houses and hotels, collect rent.
class BusinessScreen extends StatefulWidget {
  const BusinessScreen({super.key});

  @override
  State<BusinessScreen> createState() => _BusinessScreenState();
}

class _BusinessScreenState extends State<BusinessScreen> {
  late bool _cpu = Storage.getInt('business.pref.mode') == 0;
  late int _players = Storage.getInt('business.pref.players', 4).clamp(2, 4);
  late int _level = Storage.getInt('business.pref.level', 1).clamp(0, 2);
  late bool _world = Storage.getBool('business.pref.world');
  late int _rounds = Storage.getInt('business.pref.rounds', 20);

  void _start() {
    Storage.setInt('business.pref.mode', _cpu ? 0 : 1);
    Storage.setInt('business.pref.players', _players);
    Storage.setInt('business.pref.level', _level);
    Storage.setBool('business.pref.world', _world);
    Storage.setInt('business.pref.rounds', _rounds);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => BusinessPlayScreen(
        players: _players,
        cpu: _cpu,
        level: _level,
        world: _world,
        maxRounds: _rounds,
        seed: math.Random().nextInt(1 << 30),
      ),
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
            color: sel ? _tint.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: sel ? Pal.gold : Pal.glassBorder),
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ),
      );

  @override
  Widget build(BuildContext context) => GameScaffold(
        title: tr('game.business.title'),
        tint: _tint,
        body: ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
          Text(tr('biz.intro'), style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4)),
          _section(tr('ludo.mode')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('🤖 ${tr('ludo.vs_cpu')}', _cpu, () => setState(() => _cpu = true), key: const ValueKey('biz_mode_cpu')),
            _chip('👥 ${tr('ludo.pass_play')}', !_cpu, () => setState(() => _cpu = false), key: const ValueKey('biz_mode_local')),
            _chip('🌐 ${tr('online.title')}', false,
                () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const LudoOnlineLobby(game: 'business'))),
                key: const ValueKey('biz_mode_online')),
          ]),
          _section(tr('ludo.players')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final n in const [2, 3, 4]) _chip(tr('ludo.n_players', {'n': n}), _players == n, () => setState(() => _players = n), key: ValueKey('biz_players_$n')),
          ]),
          if (_cpu) ...[
            _section(tr('ludo.difficulty')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final (i, k) in const ['ludo.easy', 'ludo.medium', 'ludo.hard'].indexed) _chip(tr(k), _level == i, () => setState(() => _level = i)),
            ]),
          ],
          _section(tr('biz.board')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _chip('🇮🇳 ${tr('biz.board_india')}', !_world, () => setState(() => _world = false), key: const ValueKey('biz_board_india')),
            _chip('🌍 ${tr('biz.board_world')}', _world, () => setState(() => _world = true), key: const ValueKey('biz_board_world')),
          ]),
          _section(tr('biz.length')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in const [15, 30, 0])
              _chip(r == 0 ? tr('biz.until_bankrupt') : tr('biz.rounds', {'n': r}), _rounds == r, () => setState(() => _rounds = r), key: ValueKey('biz_rounds_$r')),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(tr('biz.length_help'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.4)),
          ),
          const SizedBox(height: 20),
          PremiumButton(key: const ValueKey('biz_start'), label: tr('ludo.start'), icon: Icons.play_arrow_rounded, color: _tint, onTap: _start),
        ]),
      );
}

class BusinessPlayScreen extends StatefulWidget {
  const BusinessPlayScreen({
    super.key,
    required this.players,
    required this.cpu,
    required this.level,
    required this.world,
    required this.maxRounds,
    required this.seed,
  });
  final int players, level, maxRounds, seed;
  final bool cpu, world;

  /// Delay before computer moves (shorter in tests).
  @visibleForTesting
  static Duration botDelay = const Duration(milliseconds: 900);

  @override
  State<BusinessPlayScreen> createState() => _BusinessPlayScreenState();
}

class _BusinessPlayScreenState extends State<BusinessPlayScreen> {
  late final BusinessGame _g = BusinessGame(players: widget.players, seed: widget.seed, maxRounds: widget.maxRounds);
  Timer? _bot;
  bool _ended = false;
  String _msg = '';

  bool _isBot(int seat) => widget.cpu && seat > 0;

  String _name(int seat) => widget.cpu
      ? (seat == 0 ? tr('domino.you') : tr('domino.cpu', {'n': seat}))
      : tr('biz.player_n', {'n': seat + 1});

  String _money(int v) => BizNames.money(v, world: widget.world);

  @override
  void initState() {
    super.initState();
    _msg = tr('biz.roll_hint', {'name': _name(0)});
    WidgetsBinding.instance.addPostFrameCallback((_) => _drive());
  }

  @override
  void dispose() {
    _bot?.cancel();
    super.dispose();
  }

  void _drive() {
    _bot?.cancel();
    if (!mounted || _g.phase == Phase.over) return;
    if (!_isBot(_g.turn)) return;
    _bot = Timer(BusinessPlayScreen.botDelay, () {
      if (!mounted || _g.phase == Phase.over || !_isBot(_g.turn)) return;
      _act(_g.botAction(widget.level));
    });
  }

  void _act(BizAction a) {
    final seat = _g.turn;
    if (!_g.apply(a)) return;
    final e = _g.last;
    switch (a.code) {
      case 0:
        AppAudio.play(Sound.dice);
      case 1:
        AppAudio.play(Sound.coin);
      case >= 100 && < 200:
        AppAudio.play(Sound.place);
    }
    if (e.card != null || e.toJail || (e.paid ?? 0) > 0 || e.bankrupt) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        AppAudio.play(e.bankrupt || e.toJail || (e.paid ?? 0) > 0 ? Sound.fail : Sound.success, volume: 0.6);
      });
    }
    setState(() => _msg = _describe(seat, a, e));
    if (e.card != null && !_isBot(seat)) _showCard(e.card!);
    if (_g.phase == Phase.over) {
      _finish();
    } else {
      _drive();
    }
  }

  String _describe(int seat, BizAction a, BizEvent e) => describeBiz(_g, seat, a, e, _name, world: widget.world);

  String _cardText(int id) => bizCardText(id, world: widget.world);

  void _showCard(int id) {
    showPremiumDialog(
      context,
      emoji: id < 100 ? '❓' : '💰',
      title: tr(id < 100 ? 'biz.kismat' : 'biz.khazana'),
      message: _cardText(id),
      dismissible: true,
      actions: [DialogAction(tr('common.ok'), () {}, primary: true)],
    );
  }

  void _openBuild() {
    final seat = _g.turn;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1B1245),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(builder: (sheet, set) {
        final opts = _g.buildable(seat);
        final sellable = [for (var s = 0; s < Biz.size; s++) if (_g.owner[s] == seat && _g.houses[s] > 0) s];
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(tr('biz.build_title'), style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(opts.isEmpty ? tr('biz.build_none') : tr('biz.build_help'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
              const SizedBox(height: 8),
              for (final s in {...opts, ...sellable})
                ListTile(
                  dense: true,
                  leading: Container(width: 14, height: 30, color: bizGroupColors[Biz.board[s].group]),
                  title: Text('${BizNames.square(s, world: widget.world)}  ${_g.houses[s] == 4 ? '🏨' : '🏠' * _g.houses[s]}',
                      style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (sellable.contains(s))
                      TextButton(
                        onPressed: () {
                          _act(BizAction.sell(seat, s));
                          set(() {});
                        },
                        child: Text(tr('biz.sell', {'m': _money(Biz.houseCost(s) ~/ 2)})),
                      ),
                    if (opts.contains(s))
                      FilledButton(
                        key: ValueKey('biz_build_$s'),
                        onPressed: () {
                          _act(BizAction.build(seat, s));
                          set(() {});
                        },
                        child: Text(tr('biz.build_for', {'m': _money(Biz.houseCost(s))})),
                      ),
                  ]),
                ),
            ]),
          ),
        );
      }),
    );
  }

  void _showSquare(int s) {
    final b = Biz.board[s];
    if (!b.ownable) return;
    final o = _g.owner[s];
    final lines = <String>[
      '${tr('biz.price')}: ${_money(b.price)}',
      if (o >= 0) '${tr('biz.owner')}: ${_name(o)}',
      if (b.kind == Sq.city) ...[
        '${tr('biz.rent')}: ${_money(b.price ~/ 10)} → ${tr('biz.with_hotel')}: ${_money(b.price ~/ 10 * 45)}',
        '${tr('biz.house_cost')}: ${_money(Biz.houseCost(s))}',
      ],
      if (b.kind == Sq.transport) tr('biz.transport_rent', {'m': _money(250)}),
      if (b.kind == Sq.utility) tr('biz.utility_rent'),
    ];
    showPremiumDialog(
      context,
      emoji: b.kind == Sq.city ? '🏙️' : (b.kind == Sq.transport ? '🚆' : '💡'),
      title: BizNames.square(s, world: widget.world),
      message: lines.join('\n'),
      dismissible: true,
      actions: [DialogAction(tr('common.ok'), () {}, primary: true)],
    );
  }

  void _finish() {
    if (_ended) return;
    _ended = true;
    final w = _g.winner!;
    final iWon = widget.cpu ? w == 0 : true;
    if (widget.cpu) {
      Rewards.onGameEnd('business', score: _g.worth(0), won: iWon, tier: ['easy', 'medium', 'hard'][widget.level]);
    } else {
      Rewards.onGameEnd('business', score: 0, won: false);
    }
    final order = [for (var p = 0; p < _g.players; p++) p]..sort((a, b) => _g.worth(b).compareTo(_g.worth(a)));
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        emoji: iWon ? '🏆' : '💼',
        title: tr('biz.winner', {'name': _name(w)}),
        message: [for (final (i, p) in order.indexed) '${i + 1}. ${_name(p)} – ${_money(_g.worth(p))}${_g.out[p] ? ' (${tr('biz.out')})' : ''}'].join('\n'),
        actions: [
          DialogAction(tr('ludo.play_again'), () {
            Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => BusinessPlayScreen(
                players: widget.players,
                cpu: widget.cpu,
                level: widget.level,
                world: widget.world,
                maxRounds: widget.maxRounds,
                seed: math.Random().nextInt(1 << 30),
              ),
            ));
          }, primary: true),
          DialogAction(tr('ludo.menu'), () => Navigator.of(context).maybePop()),
        ],
      );
    });
  }

  Widget _center() {
    final seat = _g.turn;
    final human = !_isBot(seat) && _g.phase != Phase.over;
    final e = _g.last;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(widget.cpu ? '💼 ${tr('game.business.title')}' : '💼 ${_name(seat)}',
            style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 16)),
        if (widget.maxRounds > 0)
          Text(tr('biz.round', {'n': math.min(_g.round, widget.maxRounds), 'max': widget.maxRounds}), style: const TextStyle(color: Colors.black54, fontSize: 11)),
        const SizedBox(height: 6),
        if (e.d1 != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final d in [e.d1!, e.d2!])
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.black26)),
                child: Text('$d', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1B1B2F))),
              ),
          ]),
        const SizedBox(height: 4),
        Expanded(
          child: SingleChildScrollView(
            child: Text(_msg,
                key: const ValueKey('biz_msg'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF1B1B2F), fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
          ),
        ),
        if (human && _g.phase == Phase.buy)
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
            FilledButton(
              key: const ValueKey('biz_buy'),
              style: FilledButton.styleFrom(backgroundColor: _tint),
              onPressed: () => _act(BizAction.buy(seat)),
              child: Text(tr('biz.buy', {'m': _money(Biz.board[_g.pos[seat]].price)})),
            ),
            OutlinedButton(key: const ValueKey('biz_skip'), onPressed: () => _act(BizAction.skip(seat)), child: Text(tr('biz.skip'))),
          ])
        else if (human && _g.phase == Phase.roll)
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
            FilledButton.icon(
              key: const ValueKey('biz_roll'),
              style: FilledButton.styleFrom(backgroundColor: _tint),
              onPressed: () => _act(BizAction.roll(seat)),
              icon: const Icon(Icons.casino_rounded),
              label: Text(tr('biz.roll')),
            ),
            OutlinedButton(
              key: const ValueKey('biz_build'),
              onPressed: _g.buildable(seat).isEmpty && !_g.houses.any((h) => h > 0) ? null : _openBuild,
              child: Text('🏠 ${tr('biz.build')}'),
            ),
          ]),
      ]),
    );
  }

  Widget _playerBar() => Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
        for (var p = 0; p < _g.players; p++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: _g.turn == p && _g.phase != Phase.over ? 0.18 : 0.06),
              border: Border.all(color: _g.turn == p ? Pal.gold : Pal.glassBorder, width: _g.turn == p ? 2 : 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: bizPlayerColors[p])),
              const SizedBox(width: 6),
              Text(_g.out[p] ? '${_name(p)} ✖' : '${_name(p)} ${_money(_g.money[p])}',
                  key: ValueKey('biz_money_$p'),
                  style: TextStyle(color: _g.out[p] ? Pal.textDim : Pal.text, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
      ]);

  @override
  Widget build(BuildContext context) => GameScaffold(
        title: tr('game.business.title'),
        tint: _tint,
        body: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(8, 4, 8, 6), child: _playerBar()),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
              child: BusinessBoard(game: _g, world: widget.world, center: _center(), onSquare: _showSquare),
            ),
          ),
        ]),
      );
}
