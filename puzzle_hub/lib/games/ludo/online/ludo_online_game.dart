import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/audio.dart';
import '../../../core/cloud/online_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/rewards.dart';
import '../../../core/storage.dart';
import '../../../core/ui/ui.dart';
import '../logic/ludo_logic.dart';
import '../ludo_table.dart';
import 'ludo_online_service.dart';

/// A live online Ludo game (2–4 signed-in players). Each player acts only on
/// their own turn; if someone is silent for 30 s, the next player's phone
/// plays that turn for them so the game never gets stuck.
class LudoOnlineGameScreen extends StatefulWidget {
  const LudoOnlineGameScreen({super.key, required this.gameId});
  final String gameId;

  @override
  State<LudoOnlineGameScreen> createState() => _LudoOnlineGameScreenState();
}

class _LudoOnlineGameScreenState extends State<LudoOnlineGameScreen> {
  StreamSubscription<LudoOnlineGame?>? _sub;
  LudoOnlineGame? _doc;
  LudoGame? _g;
  int _rollSeq = 0;
  bool _sending = false;
  bool _ended = false;
  Timer? _tick, _auto;
  final _rnd = math.Random();

  String? get _me => OnlineService.I.uid;
  bool get _myTurn => _g != null && !_g!.over && _g!.seats[_g!.turn].uid == _me && !_sending;

  @override
  void initState() {
    super.initState();
    _sub = LudoOnline.I.watch(widget.gameId).listen(_onDoc, onError: (e) => debugPrint('ludo online: $e'));
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
    _auto?.cancel();
    super.dispose();
  }

  void _onDoc(LudoOnlineGame? d) {
    if (!mounted || d == null) return;
    final before = _g?.log.length ?? 0;
    final g = d.build(_me);
    setState(() {
      _doc = d;
      _g = g;
      if (g.log.length > before && g.log.isNotEmpty && g.log.last.isRoll) _rollSeq++;
    });
    if (g.log.length > before && before > 0) {
      final e = g.last;
      AppAudio.play(e.captured.isNotEmpty ? Sound.capture : (e.rolled != null && g.log.last.isRoll ? Sound.dice : Sound.pop));
    }
    if (g.over || d.over) {
      _finish(g);
      return;
    }
    _autoSingle();
  }

  int get _secondsLeft {
    final t = _doc?.updatedAt;
    if (t == null) return LudoOnline.turnTime.inSeconds;
    return (LudoOnline.turnTime - DateTime.now().difference(t)).inSeconds.clamp(0, LudoOnline.turnTime.inSeconds);
  }

  Future<void> _send(LudoAction a) async {
    final d = _doc, g = _g;
    if (d == null || g == null || _sending) return;
    // Check locally first (and whether this action ends the game).
    final copy = d.build(_me);
    if (!copy.apply(a)) return;
    setState(() => _sending = true);
    final winner = copy.over ? copy.seats[copy.winner!].uid : null;
    await LudoOnline.I.act(d.id, d.log.length, a, endWinner: winner);
    if (mounted) setState(() => _sending = false);
  }

  /// My move when only one token can move.
  void _autoSingle() {
    _auto?.cancel();
    final g = _g;
    if (g == null || !_myTurn || g.pending == null) return;
    final opts = g.movable(g.turn, g.pending!);
    if (opts.length == 1) {
      _auto = Timer(const Duration(milliseconds: 600), () {
        if (mounted && _myTurn && _g?.pending != null) _send(LudoAction.move(_g!.turn, opts.first));
      });
    }
  }

  /// The player to move went silent: the next player in order (that is
  /// me) plays for them.
  void _maybeCover() {
    final g = _g, d = _doc;
    if (g == null || d == null || g.over || _sending || _myTurn || _secondsLeft > 0) return;
    // Only one phone covers: the first seat after the silent one that is me.
    final next = (g.turn + 1) % g.seats.length;
    if (g.seats[next].uid != _me) return;
    final a = g.pending == null ? LudoAction.roll(g.turn) : LudoAction.move(g.turn, g.botChoice(1, _rnd));
    _send(a);
  }

  void _finish(LudoGame g) {
    if (_ended) return;
    _ended = true;
    final w = g.winner;
    final iWon = w != null && g.seats[w].uid == _me;
    final key = 'ludo.online.done.${widget.gameId}';
    if (!Storage.getBool(key)) {
      Storage.setBool(key, true);
      if (iWon) {
        Rewards.onLevelComplete('ludo', 'online-${widget.gameId}', stars: 3, score: 300 * (g.seats.length - 1), tier: 'online');
      } else {
        Rewards.onGameEnd('ludo', score: 0, won: false, tier: 'online');
      }
      unawaited(OnlineService.I.recordResult(won: iWon, lost: !iWon));
    }
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: iWon ? tr('online.you_won') : tr('ludo.winner', {'name': w == null ? '' : g.seats[w].name}),
        emoji: iWon ? '🏆' : '🎲',
        message: [for (final (i, s) in g.finished.indexed) '${i + 1}. ${g.seats[s].name}'].join('\n'),
        actions: [DialogAction(tr('online.back_lobby'), () => Navigator.of(context).maybePop(), primary: true)],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return GameScaffold(
      title: tr('game.ludo.title'),
      tint: const Color(0xFFE53935),
      body: g == null
          ? const Center(child: CircularProgressIndicator(color: Pal.gold))
          : LudoTable(
              game: g,
              canAct: _myTurn,
              rollSeq: _rollSeq,
              secondsLeft: _secondsLeft,
              onRoll: () => _send(LudoAction.roll(g.turn)),
              onToken: (i) => _send(LudoAction.move(g.turn, i)),
              status: g.last.lostTurn ? tr('ludo.three_sixes') : (_myTurn ? null : tr('ludo.waiting_for', {'name': g.seats[g.turn].name})),
            ),
    );
  }
}
