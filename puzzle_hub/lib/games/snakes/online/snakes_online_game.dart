import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio.dart';
import '../../../core/cloud/online_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/rewards.dart';
import '../../../core/storage.dart';
import '../../../core/ui/ui.dart';
import '../../ludo/logic/ludo_logic.dart';
import '../../ludo/online/ludo_online_service.dart';
import '../logic/snakes_logic.dart';
import '../snakes_screen.dart';

/// A live online Saanp-Seedhi game. It uses the same Firestore game
/// documents as online Ludo (every log entry is a roll: 100 + seat).
class SnakesOnlineGameScreen extends StatefulWidget {
  const SnakesOnlineGameScreen({super.key, required this.gameId});
  final String gameId;

  @override
  State<SnakesOnlineGameScreen> createState() => _SnakesOnlineGameScreenState();
}

class _SnakesOnlineGameScreenState extends State<SnakesOnlineGameScreen> {
  StreamSubscription<LudoOnlineGame?>? _sub;
  LudoOnlineGame? _doc;
  SnakesGame? _g;
  int _rollSeq = 0;
  bool _sending = false, _ended = false;
  Timer? _tick;

  String? get _me => OnlineService.I.uid;
  bool get _myTurn => _g != null && !_g!.over && _doc!.players[_g!.turn] == _me && !_sending;

  SnakesGame _build(LudoOnlineGame d) {
    final cols = ludoColours(d.players.length);
    return SnakesGame.replay(
      seats: [for (var i = 0; i < d.players.length; i++) LudoSeat(cols[i], d.players[i] == _me ? SeatKind.human : SeatKind.remote, name: d.names[i], uid: d.players[i])],
      seed: d.seed,
      rolls: [for (final v in d.log) if (v >= 100) v - 100],
    );
  }

  @override
  void initState() {
    super.initState();
    _sub = LudoOnline.I.watch(widget.gameId).listen(_onDoc, onError: (e) => debugPrint('snakes online: $e'));
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
      if (g.log.length > before) _rollSeq++;
    });
    if (g.log.length > before && before > 0) {
      final e = g.last;
      AppAudio.play(e.ladder ? Sound.success : (e.snake ? Sound.fail : Sound.dice));
    }
    if (g.over) _finish(g);
  }

  int get _secondsLeft {
    final t = _doc?.updatedAt;
    if (t == null) return LudoOnline.turnTime.inSeconds;
    return (LudoOnline.turnTime - DateTime.now().difference(t)).inSeconds.clamp(0, LudoOnline.turnTime.inSeconds);
  }

  Future<void> _roll([int? seat]) async {
    final d = _doc, g = _g;
    if (d == null || g == null || _sending || g.over) return;
    final s = seat ?? g.turn;
    final copy = _build(d);
    if (!copy.roll(s)) return;
    setState(() => _sending = true);
    await LudoOnline.I.act(d.id, d.log.length, LudoAction.roll(s), endWinner: copy.over ? d.players[copy.winner!] : null);
    if (mounted) setState(() => _sending = false);
  }

  /// Rolls for a player who has been silent for 30 s (the next player's phone).
  void _maybeCover() {
    final g = _g, d = _doc;
    if (g == null || d == null || g.over || _sending || _myTurn || _secondsLeft > 0) return;
    if (d.players[(g.turn + 1) % g.seats.length] != _me) return;
    _roll(g.turn);
  }

  void _finish(SnakesGame g) {
    if (_ended) return;
    _ended = true;
    final iWon = _doc!.players[g.winner!] == _me;
    final key = 'snakes.online.done.${widget.gameId}';
    if (!Storage.getBool(key)) {
      Storage.setBool(key, true);
      if (iWon) {
        Rewards.onLevelComplete('snakes', 'online-${widget.gameId}', stars: 3, score: 200 * (g.seats.length - 1), tier: 'online');
      } else {
        Rewards.onGameEnd('snakes', score: 0, won: false, tier: 'online');
      }
      unawaited(OnlineService.I.recordResult(won: iWon, lost: !iWon));
    }
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: iWon ? tr('online.you_won') : tr('ludo.winner', {'name': g.seats[g.winner!].name}),
        emoji: iWon ? '🏆' : '🐍',
        actions: [DialogAction(tr('online.back_lobby'), () => Navigator.of(context).maybePop(), primary: true)],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = _g;
    return GameScaffold(
      title: tr('game.snakes.title'),
      tint: const Color(0xFF43A047),
      body: g == null
          ? const Center(child: CircularProgressIndicator(color: Pal.gold))
          : SnakesTable(game: g, canRoll: _myTurn, onRoll: _roll, rollSeq: _rollSeq, secondsLeft: _secondsLeft),
    );
  }
}
