import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio.dart';
import '../../../core/cloud/online_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/rewards.dart';
import '../../../core/storage.dart';
import '../../../core/ui/ui.dart';
import '../../ludo/online/ludo_online_service.dart';
import '../business_board.dart';
import '../business_screen.dart';
import '../logic/business_logic.dart';

/// A live online Business game (2–4 signed-in players) stored in the same
/// `ludo_games` documents as online Ludo (`game: 'business'`). Moves are
/// ints `seat * 1000 + code`; `quick` games last 15 rounds, others 30. If
/// the player to move is silent for 30 s, the next player's phone rolls /
/// skips for them so the game never gets stuck.
class BusinessOnlineGameScreen extends StatefulWidget {
  const BusinessOnlineGameScreen({super.key, required this.gameId});
  final String gameId;

  static int roundsFor(bool quick) => quick ? 15 : 30;

  @override
  State<BusinessOnlineGameScreen> createState() => _BusinessOnlineGameScreenState();
}

class _BusinessOnlineGameScreenState extends State<BusinessOnlineGameScreen> {
  StreamSubscription<LudoOnlineGame?>? _sub;
  LudoOnlineGame? _doc;
  BusinessGame? _g;
  bool _sending = false;
  bool _ended = false;
  String _msg = '';
  Timer? _tick;

  /// Each phone shows its own preferred board; the game itself is the same.
  final bool _world = Storage.getBool('business.pref.world');

  String? get _me => OnlineService.I.uid;
  int get _mySeat => _doc?.players.indexOf(_me ?? '') ?? -1;
  bool get _myTurn => _g != null && _g!.phase != Phase.over && _g!.turn == _mySeat && !_sending;

  String _name(int seat) {
    final d = _doc;
    if (d == null || seat >= d.names.length) return '';
    return seat == _mySeat ? tr('domino.you') : d.names[seat];
  }

  BusinessGame _build(LudoOnlineGame d) => BusinessGame.replay(
        players: d.players.length,
        seed: d.seed,
        maxRounds: BusinessOnlineGameScreen.roundsFor(d.quick),
        actions: d.log.map(BizAction.fromInt),
      );

  @override
  void initState() {
    super.initState();
    _sub = LudoOnline.I.watch(widget.gameId).listen(_onDoc, onError: (e) => debugPrint('business online: $e'));
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {});
      _maybeCover();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _onDoc(LudoOnlineGame? d) {
    if (!mounted || d == null) return;
    final before = _g?.log.length ?? 0;
    final g = _build(d);
    setState(() {
      _doc = d;
      _g = g;
      if (g.log.isNotEmpty) _msg = describeBiz(g, g.log.last.seat, g.log.last, g.last, _name, world: _world);
    });
    if (g.log.length > before && before > 0) {
      final code = g.log.last.code;
      AppAudio.play(code == 0 ? Sound.dice : (code == 1 ? Sound.coin : Sound.place));
    }
    if (g.phase == Phase.over || d.over) _finish(g);
  }

  int get _secondsLeft {
    final t = _doc?.updatedAt;
    if (t == null) return LudoOnline.turnTime.inSeconds;
    return (LudoOnline.turnTime - DateTime.now().difference(t)).inSeconds.clamp(0, LudoOnline.turnTime.inSeconds);
  }

  Future<void> _send(BizAction a) async {
    final d = _doc;
    if (d == null || _sending) return;
    final copy = _build(d);
    if (!copy.apply(a)) return;
    setState(() => _sending = true);
    final winner = copy.phase == Phase.over ? d.players[copy.winner!] : null;
    await LudoOnline.I.actRaw(d.id, d.log.length, a.toInt(), endWinner: winner);
    if (mounted) setState(() => _sending = false);
  }

  /// The player to move went silent: the next seat plays a safe move for them.
  void _maybeCover() {
    final g = _g, d = _doc;
    if (g == null || d == null || g.phase == Phase.over || _sending || _myTurn || _secondsLeft > 0) return;
    var next = (g.turn + 1) % g.players;
    while (g.out[next]) {
      next = (next + 1) % g.players;
    }
    if (next != _mySeat) return;
    _send(g.phase == Phase.buy ? BizAction.skip(g.turn) : BizAction.roll(g.turn));
  }

  void _finish(BusinessGame g) {
    if (_ended) return;
    _ended = true;
    final w = g.winner;
    final iWon = w != null && w == _mySeat;
    final key = 'business.online.done.${widget.gameId}';
    if (!Storage.getBool(key)) {
      Storage.setBool(key, true);
      Rewards.onGameEnd('business', score: _mySeat >= 0 ? g.worth(_mySeat) : 0, won: iWon, tier: 'online');
      unawaited(OnlineService.I.recordResult(won: iWon, lost: !iWon));
    }
    final order = [for (var p = 0; p < g.players; p++) p]..sort((a, b) => g.worth(b).compareTo(g.worth(a)));
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: iWon ? tr('online.you_won') : tr('biz.winner', {'name': w == null ? '' : _name(w)}),
        emoji: iWon ? '🏆' : '💼',
        message: [for (final (i, p) in order.indexed) '${i + 1}. ${_name(p)} – ${BizNames.money(g.worth(p), world: _world)}'].join('\n'),
        actions: [DialogAction(tr('online.back_lobby'), () => Navigator.of(context).maybePop(), primary: true)],
      );
    });
  }

  Widget _center(BusinessGame g) {
    final seat = g.turn;
    final e = g.last;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('💼 ${_myTurn ? tr('biz.your_turn') : tr('ludo.waiting_for', {'name': _name(seat)})}',
            textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1B5E20), fontWeight: FontWeight.w900, fontSize: 14)),
        Text('${tr('biz.round', {'n': g.round.clamp(1, g.maxRounds), 'max': g.maxRounds})} · ⏱ $_secondsLeft s',
            style: const TextStyle(color: Colors.black54, fontSize: 11)),
        const SizedBox(height: 6),
        if (e.d1 != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (final dv in [e.d1!, e.d2!])
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(7), border: Border.all(color: Colors.black26)),
                child: Text('$dv', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1B1B2F))),
              ),
          ]),
        Expanded(
          child: SingleChildScrollView(
            child: Text(_msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF1B1B2F), fontSize: 12, fontWeight: FontWeight.w600, height: 1.3)),
          ),
        ),
        if (_myTurn && g.phase == Phase.buy)
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () => _send(BizAction.buy(seat)),
              child: Text(tr('biz.buy', {'m': BizNames.money(Biz.board[g.pos[seat]].price, world: _world)})),
            ),
            OutlinedButton(onPressed: () => _send(BizAction.skip(seat)), child: Text(tr('biz.skip'))),
          ])
        else if (_myTurn)
          Wrap(alignment: WrapAlignment.center, spacing: 6, runSpacing: 4, children: [
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2E7D32)),
              onPressed: () => _send(BizAction.roll(seat)),
              icon: const Icon(Icons.casino_rounded),
              label: Text(tr('biz.roll')),
            ),
            for (final s in g.buildable(seat).take(3))
              OutlinedButton(
                onPressed: () => _send(BizAction.build(seat, s)),
                child: Text('🏠 ${BizNames.square(s, world: _world)}'),
              ),
          ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return GameScaffold(
      title: tr('game.business.title'),
      tint: const Color(0xFF2E7D32),
      body: g == null
          ? const Center(child: CircularProgressIndicator(color: Pal.gold))
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  for (var p = 0; p < g.players; p++)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white.withValues(alpha: g.turn == p ? 0.18 : 0.06),
                        border: Border.all(color: g.turn == p ? Pal.gold : Pal.glassBorder, width: g.turn == p ? 2 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: bizPlayerColors[p])),
                        const SizedBox(width: 6),
                        Text(g.out[p] ? '${_name(p)} ✖' : '${_name(p)} ${BizNames.money(g.money[p], world: _world)}',
                            style: TextStyle(color: g.out[p] ? Pal.textDim : Pal.text, fontWeight: FontWeight.w800, fontSize: 12)),
                      ]),
                    ),
                ]),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: BusinessBoard(game: g, world: _world, center: _center(g)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ]),
    );
  }
}
