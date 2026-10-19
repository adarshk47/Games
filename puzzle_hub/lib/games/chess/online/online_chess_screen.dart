import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/audio.dart';
import '../../../core/cloud/online_service.dart';
import '../../../core/i18n/i18n.dart';
import '../../../core/rewards.dart';
import '../../../core/storage.dart';
import '../../../core/ui/ui.dart';
import '../logic/chess_engine.dart';
import '../logic/chess_game.dart';
import '../widgets/chess_board.dart';

/// A live chess game against another signed-in player. Moves come from the
/// shared Firestore game document; I can only move on my turn.
class OnlineChessScreen extends StatefulWidget {
  const OnlineChessScreen({super.key, required this.gameId});
  final String gameId;

  @override
  State<OnlineChessScreen> createState() => _OnlineChessScreenState();
}

class _OnlineChessScreenState extends State<OnlineChessScreen> {
  StreamSubscription<OnlineGame?>? _sub;
  OnlineGame? _doc;
  ChessGame _game = ChessGame();
  int? _selected;
  int? _anim;
  int _animSeq = 0;
  bool _sending = false;
  bool _shownEnd = false;
  Timer? _tick;

  String? get _me => OnlineService.I.uid;
  bool get _white => _doc?.white == _me;
  bool get _myTurn => _doc != null && !_doc!.over && !_game.over && !_sending && _game.whiteToMove == _white;

  @override
  void initState() {
    super.initState();
    _sub = OnlineService.I.watchGame(widget.gameId).listen(_onDoc, onError: (e) => debugPrint('online game: $e'));
    // Re-check "opponent left" every 15 s.
    _tick = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _onDoc(OnlineGame? d) {
    if (!mounted || d == null) return;
    final before = _game.moves.length;
    // Replay: normally just the opponent's new move; rebuild if out of sync.
    var g = _game;
    final known = [for (final m in g.moves) moveUci(m)];
    final prefixOk = d.moves.length >= known.length && List.generate(known.length, (i) => d.moves[i] == known[i]).every((x) => x);
    if (!prefixOk) g = ChessGame();
    for (var i = g.moves.length; i < d.moves.length; i++) {
      if (!g.playUci(d.moves[i])) break;
    }
    final newMove = g.moves.length > before && g.moves.isNotEmpty;
    setState(() {
      _doc = d;
      _game = g;
      if (newMove) {
        _anim = g.moves.last;
        _animSeq++;
        _selected = null;
      }
    });
    if (newMove && before > 0) AppAudio.play(Sound.pop);
    if (d.over) _onOver(d);
  }

  // ---------------------------------------------------------------- input

  void _onSquare(int sq) {
    if (!_myTurn) return;
    final sel = _selected;
    if (sel != null && _game.movesFrom(sel).any((m) => moveTo(m) == sq)) {
      _tryMove(sel, sq);
      return;
    }
    final p = _game.pos.board[sq];
    if (p != 0 && (p > 0) == _white && sq != sel) {
      AppAudio.haptic();
      setState(() => _selected = sq);
    } else {
      setState(() => _selected = null);
    }
  }

  bool _canDrag(int sq) {
    if (!_myTurn) return false;
    final p = _game.pos.board[sq];
    if (p == 0 || (p > 0) != _white) return false;
    setState(() => _selected = sq);
    return true;
  }

  void _onDrop(int from, int to) {
    if (!_myTurn) return;
    if (_game.movesFrom(from).any((m) => moveTo(m) == to)) {
      _tryMove(from, to);
    } else {
      setState(() => _selected = null);
    }
  }

  Future<void> _tryMove(int from, int to) async {
    final cands = [for (final m in _game.movesFrom(from)) if (moveTo(m) == to) m];
    if (cands.isEmpty) return;
    var m = cands.first;
    if (cands.length > 1) {
      final promo = await _pickPromotion();
      if (!mounted || promo == null || !_myTurn) return;
      m = cands.firstWhere((c) => movePromo(c) == promo);
    }
    final d = _doc!;
    final g = ChessGame();
    for (final u in d.moves) {
      g.playUci(u);
    }
    if (!g.play(m)) return;
    String? result, reason;
    if (g.over) {
      result = switch (g.result) { ChessResult.whiteWins => 'white', ChessResult.blackWins => 'black', _ => 'draw' };
      reason = g.reason.name;
    }
    setState(() {
      _sending = true;
      _game = g;
      _selected = null;
      _anim = m;
      _animSeq++;
    });
    AppAudio.play(Sound.pop);
    final ok = await OnlineService.I.sendMove(d, moveUci(m), result: result, reason: reason);
    if (!mounted) return;
    setState(() => _sending = false);
    if (!ok) {
      // Not accepted (network / out of sync): go back to the shared state.
      _snack(tr('online.err.network'));
      _game = ChessGame();
      _onDoc(_doc);
    }
  }

  Future<int?> _pickPromotion() => showDialog<int>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF241A4F),
          title: Text(tr('chess.promote'), style: const TextStyle(color: Pal.text)),
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            for (final t in const [pQueen, pRook, pBishop, pKnight])
              InkWell(
                key: ValueKey('promo$t'),
                onTap: () => Navigator.of(ctx).pop(t),
                child: Padding(padding: const EdgeInsets.all(4), child: PieceGlyph(_white ? t : -t, size: 48)),
              ),
          ]),
        ),
      );

  // ---------------------------------------------------------------- end

  bool get _opponentGone {
    final d = _doc;
    if (d == null || d.over || _myTurn || _sending) return false;
    final t = d.updatedAt;
    return t != null && DateTime.now().difference(t) > OnlineService.abandonAfter;
  }

  Future<void> _resign() async {
    final d = _doc;
    if (d == null || d.over) return;
    var yes = false;
    await showPremiumDialog(
      context,
      title: tr('online.resign_q'),
      emoji: '🏳️',
      dismissible: true,
      actions: [
        DialogAction(tr('online.resign'), () => yes = true, primary: true),
        DialogAction(tr('common.cancel'), () {}),
      ],
    );
    if (!yes) return;
    await OnlineService.I.end(d, _white ? 'black' : 'white', 'resign');
  }

  Future<void> _claim() async {
    final d = _doc;
    if (d == null) return;
    await OnlineService.I.end(d, _white ? 'white' : 'black', 'abandoned');
  }

  void _onOver(OnlineGame d) {
    if (_shownEnd) return;
    _shownEnd = true;
    final won = d.result == (_white ? 'white' : 'black');
    final draw = d.result == 'draw';
    // Rewards once per game, even if the screen is opened again.
    final key = 'online.done.${d.id}';
    if (!Storage.getBool(key)) {
      Storage.setBool(key, true);
      if (won) {
        Rewards.onLevelComplete('chess', 'online-${d.id}', stars: 3, score: 400, tier: 'online');
      } else {
        Rewards.onGameEnd('chess', score: draw ? 100 : 0, won: false, tier: 'online');
      }
      unawaited(OnlineService.I.recordResult(won: won, lost: !won && !draw));
    }
    final why = tr('online.reason.${d.reason ?? 'checkmate'}', const {}, d.reason ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: tr(won ? 'online.you_won' : (draw ? 'online.draw' : 'online.you_lost')),
        message: why,
        emoji: won ? '🏆' : (draw ? '🤝' : '😔'),
        actions: [
          DialogAction(tr('online.back_lobby'), () => Navigator.of(context).maybePop(), primary: true),
          DialogAction(tr('online.see_board'), () {}),
        ],
      );
    });
  }

  void _snack(String m) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 2)));

  // ---------------------------------------------------------------- ui

  Widget _player(String name, bool white, bool toMove) => GlassCard(
        blur: 0,
        glow: toMove ? Pal.gold : null,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(children: [
          PieceGlyph(white ? pKing : -pKing, size: 26),
          const SizedBox(width: 8),
          Expanded(
            child: Text('@$name', overflow: TextOverflow.ellipsis, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
          ),
          if (toMove)
            Text(tr('online.to_move'), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800, fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final d = _doc;
    return GameScaffold(
      title: tr('online.title'),
      tint: Pal.gold,
      actions: [
        if (d != null && !d.over)
          IconButton(
            key: const ValueKey('online_resign'),
            tooltip: tr('online.resign'),
            icon: const Icon(Icons.flag_rounded, color: Pal.text),
            onPressed: _resign,
          ),
      ],
      body: d == null
          ? const Center(child: CircularProgressIndicator(color: Pal.gold))
          : Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: Column(children: [
                _player(_white ? d.blackName : d.whiteName, !_white, !d.over && _game.whiteToMove != _white),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: ChessBoardView(
                        board: _game.pos.board,
                        flipped: !_white,
                        selected: _selected,
                        targets: _selected == null ? const [] : [for (final m in _game.movesFrom(_selected!)) moveTo(m)],
                        lastMove: _game.lastMove,
                        animMove: _anim,
                        animSeq: _animSeq,
                        checkSquare: _game.inCheck ? (_game.whiteToMove ? _game.pos.whiteKing : _game.pos.blackKing) : null,
                        onTapSquare: _onSquare,
                        onDrop: _onDrop,
                        canDrag: _canDrag,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _player(_white ? d.whiteName : d.blackName, _white, !d.over && _game.whiteToMove == _white),
                const SizedBox(height: 8),
                if (d.over)
                  Text(tr(d.result == 'draw' ? 'online.draw' : (d.result == (_white ? 'white' : 'black') ? 'online.you_won' : 'online.you_lost')),
                      style: const TextStyle(color: Pal.gold, fontSize: 16, fontWeight: FontWeight.w900))
                else if (_opponentGone)
                  PremiumButton(key: const ValueKey('online_claim'), label: tr('online.claim'), icon: Icons.emoji_events_rounded, onTap: _claim, compact: true)
                else
                  Text(tr(_myTurn || _sending ? 'online.your_turn' : 'online.their_turn'),
                      style: const TextStyle(color: Pal.textDim, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
            ),
    );
  }
}
