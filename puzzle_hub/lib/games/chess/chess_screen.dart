import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/chess_ai.dart';
import 'logic/chess_engine.dart';
import 'logic/chess_game.dart';
import 'logic/chess_positions.dart';
import 'widgets/chess_board.dart';

const _tint = Color(0xFFC08A4E);

enum ChessMode { cpu, pvp }

const _levelIcons = <ChessLevel, IconData>{
  ChessLevel.easy: Icons.spa_rounded,
  ChessLevel.medium: Icons.local_fire_department_rounded,
  ChessLevel.hard: Icons.bolt_rounded,
  ChessLevel.extreme: Icons.whatshot_rounded,
};

String _levelLabel(ChessLevel l) => tr('common.tier.${l.name}');

String _tcLabel(TimeControl tc) =>
    tc.increment == 0 ? tr('chess.min', {'n': tc.minutes}) : tr('chess.min_inc', {'n': tc.minutes, 's': tc.increment});

class ChessScreen extends StatefulWidget {
  const ChessScreen({super.key});

  @override
  State<ChessScreen> createState() => _ChessScreenState();
}

class _ChessScreenState extends State<ChessScreen> {
  // ---- menu choices (remembered)
  ChessMode _mode = ChessMode.cpu;
  ChessLevel _level = ChessLevel.easy;
  TimeControl _tc = const TimeControl(3);
  int _colorPref = 0; // 0 white, 1 black, 2 random
  bool _autoRotate = true;
  bool _midStart = false; // start from a curated middlegame position

  // ---- game state
  ChessGame? _game;
  late ChessClock _clock;
  bool _playerWhite = true;
  MidgamePosition? _midPos; // null = standard start
  bool _startWhite = true; // side to move in the start position
  int _startFullmove = 1;
  bool _thinking = false;
  int _searchGen = 0;
  int? _selected;
  int? _animMove;
  int _animSeq = 0;
  int _freeUndos = 1;
  bool _manualFlip = false;
  bool _clockRunning = false;
  bool _finished = false;
  Timer? _ticker;
  Timer? _endTimer;
  final Stopwatch _sw = Stopwatch();
  int _lastTick = 0;

  @override
  void initState() {
    super.initState();
    _mode = ChessMode.values[Storage.getInt('chess.pref.mode').clamp(0, 1)];
    _level = ChessLevel.values[Storage.getInt('chess.pref.level').clamp(0, 3)];
    _tc = TimeControl.all[Storage.getInt('chess.pref.tc', 1).clamp(0, TimeControl.all.length - 1)];
    _colorPref = Storage.getInt('chess.pref.color').clamp(0, 2);
    _autoRotate = Storage.getBool('chess.pref.rotate', true);
    _midStart = Storage.getInt('chess.pref.start').clamp(0, 1) == 1;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _endTimer?.cancel();
    _searchGen++;
    super.dispose();
  }

  void _savePrefs() {
    Storage.setInt('chess.pref.mode', _mode.index);
    Storage.setInt('chess.pref.level', _level.index);
    Storage.setInt('chess.pref.tc', TimeControl.all.indexOf(_tc));
    Storage.setInt('chess.pref.color', _colorPref);
    Storage.setBool('chess.pref.rotate', _autoRotate);
    Storage.setInt('chess.pref.start', _midStart ? 1 : 0);
  }

  // ---------------------------------------------------------------- stats

  String _statKey(String kind) =>
      _mode == ChessMode.cpu ? 'chess.cpu.${_level.name}.${_tc.id}.$kind' : 'chess.pvp.${_tc.id}.$kind';

  void _bump(String kind) => Storage.setInt(_statKey(kind), Storage.getInt(_statKey(kind)) + 1);

  // ---------------------------------------------------------------- game flow

  bool get _cpu => _mode == ChessMode.cpu;

  bool get _flipped {
    final g = _game;
    if (g == null) return false;
    final base = _cpu ? !_playerWhite : (_autoRotate && !g.whiteToMove);
    return base != _manualFlip;
  }

  bool get _humanTurn {
    final g = _game;
    if (g == null || g.over || _finished) return false;
    return !_cpu || g.whiteToMove == _playerWhite;
  }

  void _start() {
    _savePrefs();
    _ticker?.cancel();
    _endTimer?.cancel();
    _searchGen++;
    final mid = _midStart ? randomMidgame() : null;
    setState(() {
      _midPos = mid;
      _game = mid == null ? ChessGame() : ChessGame(mid.fen);
      _startWhite = _game!.whiteToMove;
      _startFullmove = _game!.pos.fullmove;
      _clock = ChessClock(_tc);
      _playerWhite = _colorPref == 2 ? math.Random().nextBool() : _colorPref == 0;
      _thinking = false;
      _selected = null;
      _animMove = null;
      _freeUndos = 1;
      _manualFlip = false;
      _clockRunning = false;
      _finished = false;
    });
    _sw
      ..reset()
      ..start();
    _lastTick = 0;
    _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
    // The computer opens when it has the side to move (e.g. player is black).
    if (_cpu && _game!.whiteToMove != _playerWhite) _aiMove();
  }

  void _menu() {
    _ticker?.cancel();
    _endTimer?.cancel();
    _searchGen++;
    setState(() {
      _game = null;
      _thinking = false;
    });
  }

  /// Charges elapsed time to the side to move.
  void _flushClock() {
    final now = _sw.elapsedMilliseconds;
    final dt = now - _lastTick;
    _lastTick = now;
    final g = _game;
    if (g == null || g.over || !_clockRunning) return;
    if (_clock.consume(g.whiteToMove, dt)) {
      g.flag(g.whiteToMove);
      AppAudio.play(Sound.fail);
      _finish();
    }
  }

  void _tick() {
    if (!mounted || _game == null || _finished) return;
    setState(_flushClock);
  }

  void _onSquare(int sq) {
    final g = _game;
    if (g == null || !_humanTurn) return;
    final sel = _selected;
    if (sel != null && g.movesFrom(sel).any((m) => moveTo(m) == sq)) {
      _tryMove(sel, sq);
      return;
    }
    final p = g.pos.board[sq];
    if (p != 0 && (p > 0) == g.whiteToMove && sq != sel) {
      AppAudio.haptic();
      setState(() => _selected = sq);
    } else {
      if (sel != null && sel != sq) AppAudio.play(Sound.fail, volume: 0.4);
      setState(() => _selected = null);
    }
  }

  bool _canDrag(int sq) {
    final g = _game;
    if (g == null || !_humanTurn) return false;
    final p = g.pos.board[sq];
    if (p == 0 || (p > 0) != g.whiteToMove) return false;
    setState(() => _selected = sq);
    return true;
  }

  void _onDrop(int from, int to) {
    final g = _game;
    if (g == null || !_humanTurn) return;
    if (g.movesFrom(from).any((m) => moveTo(m) == to)) {
      _tryMove(from, to, animate: false);
    } else {
      AppAudio.play(Sound.fail, volume: 0.4);
      setState(() => _selected = null);
    }
  }

  Future<void> _tryMove(int from, int to, {bool animate = true}) async {
    final g = _game!;
    final cands = [for (final m in g.movesFrom(from)) if (moveTo(m) == to) m];
    if (cands.isEmpty) return;
    var m = cands.first;
    if (cands.length > 1) {
      final promo = await _pickPromotion(g.whiteToMove);
      if (!mounted || promo == null || _game != g || !_humanTurn) {
        setState(() => _selected = null);
        return;
      }
      m = cands.firstWhere((c) => movePromo(c) == promo);
    }
    _commit(m, animate: animate);
  }

  void _commit(int m, {bool animate = true}) {
    final g = _game!;
    _flushClock();
    if (g.over) return;
    final moverWhite = g.whiteToMove;
    final capture = g.pos.board[moveTo(m)] != 0 || moveFlags(m) & mfEnPassant != 0;
    if (!g.play(m)) return;
    if (_clockRunning) {
      _clock.moved(moverWhite);
    } else {
      _clockRunning = true; // clocks start after the first move
    }
    _lastTick = _sw.elapsedMilliseconds;
    if (!g.over) {
      if (g.inCheck) {
        AppAudio.play(Sound.success, volume: 0.6);
        AppAudio.haptic(true);
      } else if (capture) {
        AppAudio.play(Sound.pop);
      } else {
        AppAudio.play(Sound.tap);
      }
    }
    setState(() {
      _selected = null;
      _animMove = animate ? m : null;
      _animSeq++;
    });
    if (g.over) {
      _finish();
    } else if (_cpu && g.whiteToMove != _playerWhite) {
      _aiMove();
    }
  }

  Future<void> _aiMove() async {
    final g = _game;
    if (g == null || g.over) return;
    final gen = ++_searchGen;
    setState(() => _thinking = true);
    final cfg = AiConfig.levels[_level]!;
    final left = _clock.msFor(g.whiteToMove);
    final budget = math.min(cfg.timeMs, math.max(150, left ~/ 30 + _clock.control.incMs ~/ 2));
    final req = chessSearchRequest(g.pos, g.hashHistory, cfg, timeMs: budget, seed: DateTime.now().microsecondsSinceEpoch & 0xFFFFFF);
    String uci;
    try {
      final results = await Future.wait([
        compute(chessSearchEntry, req),
        Future<String>.delayed(const Duration(milliseconds: 350), () => ''),
      ]);
      uci = results.first;
    } catch (_) {
      // Fallback (e.g. isolates unavailable): quick search on this thread.
      uci = chessSearchEntry({...req, 'depth': 2, 'time': 200});
    }
    if (!mounted || gen != _searchGen || _game != g || g.over || _finished) return;
    final m = g.pos.findUci(uci) ?? (g.legal.isNotEmpty ? g.legal.first : null);
    setState(() => _thinking = false);
    if (m != null) _commit(m);
  }

  // ---------------------------------------------------------------- actions

  bool get _canUndo {
    final g = _game;
    if (g == null || !_cpu || g.over || _thinking || !_humanTurn) return false;
    // Need the player's own move + the reply, and never undo past the start.
    return g.moves.length >= (_playerWhite == _startWhite ? 2 : 3);
  }

  Future<void> _undo() async {
    if (!_canUndo) return;
    if (_freeUndos > 0) {
      _freeUndos--;
    } else {
      final ok = await showContinueOffer(context, OfferKind.undo);
      if (!ok || !mounted || !_canUndo) return;
    }
    setState(() {
      _game!.undo(2);
      _selected = null;
      _animMove = null;
    });
    AppAudio.play(Sound.slide);
  }

  void _resign() {
    final g = _game;
    if (g == null || g.over) return;
    showPremiumDialog(
      context,
      title: tr('chess.resign_q'),
      emoji: '🏳️',
      color: Pal.danger,
      dismissible: true,
      actions: [
        DialogAction(tr('chess.resign'), () {
          if (_game != g || g.over) return;
          g.resign(_cpu ? _playerWhite : g.whiteToMove);
          _finish();
        }, primary: true),
        DialogAction(tr('common.cancel'), () {}),
      ],
    );
  }

  void _offerDraw() {
    final g = _game;
    if (g == null || g.over || g.moves.isEmpty) return;
    if (_cpu) {
      final aiEval = (g.whiteToMove == _playerWhite ? -1 : 1) * evaluate(g.pos);
      final accept = aiEval < -150 || (aiEval.abs() <= 60 && g.moves.length >= 60);
      if (accept) {
        g.agreeDraw();
        _finish();
      } else {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Pal.bg2,
            content: Text(tr('chess.draw_declined'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
          ));
      }
      return;
    }
    final side = tr(g.whiteToMove ? 'chess.white' : 'chess.black');
    showPremiumDialog(
      context,
      title: tr('chess.offer_draw'),
      message: tr('chess.draw_offer_q', {'side': side}),
      emoji: '🤝',
      color: Pal.textDim,
      actions: [
        DialogAction(tr('chess.accept'), () {
          if (_game != g || g.over) return;
          g.agreeDraw();
          _finish();
        }, primary: true),
        DialogAction(tr('chess.decline'), () {}),
      ],
    );
  }

  void _back() {
    final g = _game;
    if (g == null) {
      Navigator.of(context).maybePop();
      return;
    }
    if (g.over || _finished || g.moves.isEmpty) {
      _menu();
      return;
    }
    showPremiumDialog(
      context,
      title: tr('chess.leave_q'),
      message: _cpu ? tr('chess.leave_msg') : null,
      emoji: '🚪',
      color: Pal.danger,
      dismissible: true,
      actions: [
        DialogAction(tr('chess.leave'), () {
          if (_game != g) return;
          if (!g.over) {
            g.resign(_cpu ? _playerWhite : g.whiteToMove);
            _record(g);
          }
          _menu();
        }, primary: true),
        DialogAction(tr('common.cancel'), () {}),
      ],
    );
  }

  Future<int?> _pickPromotion(bool white) {
    return showGeneralDialog<int>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'promote',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, a, _, child) =>
          ScaleTransition(scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack), child: child),
      pageBuilder: (ctx, _, _) => Center(
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            glow: Pal.gold,
            radius: 26,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(tr('chess.promote'), style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Row(mainAxisSize: MainAxisSize.min, children: [
                for (final t in const [pQueen, pRook, pBishop, pKnight])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Pressable(
                      key: ValueKey('promo$t'),
                      onTap: () => Navigator.of(ctx).pop(t),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6C690),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Pal.gold, width: 1.5),
                        ),
                        child: PieceGlyph(white ? t : -t, size: 58),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- result

  /// Stats + rewards. Returns whether the human (vs computer) won.
  bool _record(ChessGame g) {
    final r = g.result;
    if (_cpu) {
      final won = (r == ChessResult.whiteWins) == _playerWhite && r != ChessResult.draw;
      final lost = r != ChessResult.draw && !won;
      _bump(won ? 'w' : (lost ? 'l' : 'd'));
      final tierScore = const [100, 200, 400, 800][_level.index];
      if (won) {
        final ck = 'chess.wincount.${_level.name}.${_tc.id}';
        final n = Storage.getInt(ck) + 1;
        Storage.setInt(ck, n);
        final stars = switch (_level) { ChessLevel.easy => 1, ChessLevel.medium => 2, _ => 3 };
        Rewards.onLevelComplete('chess', '${_level.name}-${_tc.id}-win-$n', stars: stars, score: tierScore);
      } else {
        Rewards.onGameEnd('chess', score: r == ChessResult.draw ? tierScore ~/ 4 : 0, won: false);
      }
      return won;
    }
    _bump(switch (r) { ChessResult.whiteWins => 'w', ChessResult.blackWins => 'l', _ => 'd' });
    Rewards.onGameEnd('chess', score: g.moves.length, won: false);
    return false;
  }

  void _finish() {
    final g = _game;
    if (g == null || _finished || !g.over) return;
    _finished = true;
    _ticker?.cancel();
    _searchGen++;
    _thinking = false;
    final won = _record(g);
    final r = g.result;
    final draw = r == ChessResult.draw;
    if (!won) AppAudio.play(draw ? Sound.pop : Sound.fail);
    final String title;
    final String emoji;
    Color color;
    if (_cpu) {
      title = won ? tr('common.you_win') : (draw ? tr('chess.draw_title') : tr('chess.lose_title'));
      emoji = won ? '🏆' : (draw ? '🤝' : '😔');
      color = won ? Pal.gold : (draw ? Pal.textDim : Pal.danger);
    } else {
      title = draw ? tr('chess.draw_title') : tr(r == ChessResult.whiteWins ? 'chess.white_wins' : 'chess.black_wins');
      emoji = draw ? '🤝' : '👑';
      color = draw ? Pal.textDim : Pal.gold;
    }
    final reasonKey = switch (g.reason) {
      EndReason.checkmate => 'chess.r.checkmate',
      EndReason.stalemate => 'chess.r.stalemate',
      EndReason.repetition => 'chess.r.repetition',
      EndReason.fiftyMove => 'chess.r.fifty',
      EndReason.insufficient => 'chess.r.insufficient',
      EndReason.timeout => 'chess.r.timeout',
      EndReason.timeoutMaterial => 'chess.r.timeout_material',
      EndReason.resign => 'chess.r.resign',
      EndReason.agreement => 'chess.r.agreement',
      EndReason.none => 'chess.draw_title',
    };
    final message = '${tr(reasonKey)}\n${tr('chess.moves_n', {'n': (g.moves.length + 1) ~/ 2})}';
    setState(() {});
    _endTimer?.cancel();
    _endTimer = Timer(const Duration(milliseconds: 700), () {
      if (!mounted || _game != g) return;
      showPremiumDialog(
        context,
        title: title,
        emoji: emoji,
        message: message,
        stars: _cpu && won ? switch (_level) { ChessLevel.easy => 1, ChessLevel.medium => 2, _ => 3 } : null,
        color: color,
        actions: [
          DialogAction(tr('common.play_again'), _start, primary: true),
          DialogAction(tr('common.menu'), _menu),
          DialogAction(tr('common.close'), () {}),
        ],
      );
    });
  }

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final inGame = _game != null;
    return GameScaffold(
      title: inGame ? '${tr('chess.title')} · ${_tc.label}' : tr('chess.title'),
      tint: _tint,
      onBack: _back,
      actions: inGame
          ? [BarAction(icon: Icons.refresh_rounded, tooltip: tr('common.restart'), onTap: (_game!.over || _game!.moves.isEmpty) ? _start : null)]
          : null,
      body: inGame ? _gameBody() : _menuBody(),
    );
  }

  // ---------------------------------------------------------------- menu

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(title, style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      );

  Widget _menuBody() {
    final w = Storage.getInt(_statKey('w')), l = Storage.getInt(_statKey('l')), d = Storage.getInt(_statKey('d'));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
      children: [
        Text(tr('chess.intro'), style: const TextStyle(color: Pal.textDim, fontSize: 14, height: 1.4)),
        _section(tr('chess.mode')),
        Row(children: [
          Expanded(child: _modeCard(ChessMode.cpu, Icons.smart_toy_rounded, tr('chess.vs_cpu'))),
          const SizedBox(width: 10),
          Expanded(child: _modeCard(ChessMode.pvp, Icons.people_alt_rounded, tr('chess.two_players'))),
        ]),
        if (_cpu) ...[
          _section(tr('chess.difficulty')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final lv in ChessLevel.values)
              _Choice(
                key: ValueKey('level_${lv.name}'),
                label: _levelLabel(lv),
                icon: _levelIcons[lv],
                selected: _level == lv,
                color: Pal.accents[lv.index * 2 % Pal.accents.length],
                onTap: () => setState(() => _level = lv),
              ),
          ]),
          _section(tr('chess.play_as')),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final (i, k) in const ['chess.white', 'chess.black', 'chess.random'].indexed)
              _Choice(
                label: tr(k),
                leading: i == 2 ? const Text('🎲', style: TextStyle(fontSize: 16)) : PieceGlyph(i == 0 ? pKing : -pKing, size: 22),
                selected: _colorPref == i,
                color: _tint,
                onTap: () => setState(() => _colorPref = i),
              ),
          ]),
        ] else ...[
          const SizedBox(height: 10),
          GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(children: [
              const Icon(Icons.screen_rotation_rounded, color: Pal.gold, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(tr('chess.auto_rotate'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700))),
              Switch(value: _autoRotate, activeThumbColor: Pal.gold, onChanged: (v) => setState(() => _autoRotate = v)),
            ]),
          ),
        ],
        _section(tr('chess.time_control')),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.35,
          children: [for (final tc in TimeControl.all) _tcTile(tc)],
        ),
        _section(tr('chess.start_pos')),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _Choice(
            key: const ValueKey('start_std'),
            label: tr('chess.start_standard'),
            icon: Icons.grid_on_rounded,
            selected: !_midStart,
            color: _tint,
            onTap: () => setState(() => _midStart = false),
          ),
          _Choice(
            key: const ValueKey('start_mid'),
            label: tr('chess.start_mid'),
            icon: Icons.shuffle_rounded,
            selected: _midStart,
            color: _tint,
            onTap: () => setState(() => _midStart = true),
          ),
        ]),
        if (_midStart)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(tr('chess.mid_hint'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.35)),
          ),
        const SizedBox(height: 16),
        GlassCard(
          blur: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            const Icon(Icons.emoji_events_rounded, color: Pal.gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _cpu ? tr('chess.stats', {'w': w, 'l': l, 'd': d}) : tr('chess.stats_pvp', {'w': w, 'b': l, 'd': d}),
                style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        Center(
          child: PremiumButton(
            key: const ValueKey('startGame'),
            label: tr('chess.start'),
            icon: Icons.play_arrow_rounded,
            onTap: _start,
          ),
        ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),
      ],
    );
  }

  Widget _modeCard(ChessMode m, IconData icon, String label) {
    final sel = _mode == m;
    return Pressable(
      key: ValueKey('mode_${m.name}'),
      onTap: () => setState(() => _mode = m),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: sel ? Pal.accent(_tint) : const LinearGradient(colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)]),
          border: Border.all(color: sel ? Pal.gold : Pal.glassBorder, width: sel ? 1.5 : 1),
          boxShadow: sel ? [BoxShadow(color: _tint.withValues(alpha: 0.45), blurRadius: 16)] : null,
        ),
        child: Column(children: [
          Icon(icon, color: Colors.white, size: 30),
          const SizedBox(height: 6),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }

  Widget _tcTile(TimeControl tc) {
    final sel = _tc == tc;
    return Pressable(
      key: ValueKey('tc_${tc.id}'),
      onTap: () => setState(() => _tc = tc),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: sel ? Pal.accent(Pal.goldDeep) : const LinearGradient(colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)]),
          border: Border.all(color: sel ? Pal.gold : Pal.glassBorder),
        ),
        padding: const EdgeInsets.all(6),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(tc.label, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            Text(_tcLabel(tc), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- game UI

  Widget _gameBody() {
    final g = _game!;
    final flipped = _flipped;
    final topWhite = flipped; // white sits at the top when the board is flipped
    final checkSq = g.inCheck ? (g.whiteToMove ? g.pos.whiteKing : g.pos.blackKing) : null;
    final mid = _midPos;
    return Column(children: [
      if (mid != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.auto_stories_rounded, color: Pal.gold, size: 15),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                '${tr('chess.start_mid')} · ${mid.name}',
                key: const ValueKey('midLabel'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Pal.gold, fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ]),
        ),
      Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 4), child: _playerPanel(topWhite)),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ChessBoardView(
            board: List<int>.of(g.pos.board),
            flipped: flipped,
            selected: _selected,
            targets: _selected == null ? const [] : [for (final m in g.movesFrom(_selected!)) moveTo(m)],
            lastMove: g.lastMove,
            animMove: _animMove,
            animSeq: _animSeq,
            checkSquare: checkSq,
            onTapSquare: _onSquare,
            onDrop: _onDrop,
            canDrag: _canDrag,
          ),
        ),
      ),
      Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 2), child: _playerPanel(!topWhite)),
      _history(g),
      _controls(g),
    ]);
  }

  Widget _playerPanel(bool white) {
    final g = _game!;
    final toMove = g.whiteToMove == white && !g.over;
    final isAi = _cpu && white != _playerWhite;
    final name = _cpu ? (isAi ? '${tr('chess.computer')} · ${_levelLabel(_level)}' : tr('chess.you')) : tr(white ? 'chess.white' : 'chess.black');
    String? status;
    if (toMove) {
      if (isAi && _thinking) {
        status = tr('chess.thinking');
      } else if (g.inCheck) {
        status = tr('chess.check');
      } else if (!isAi) {
        status = _cpu ? tr('chess.your_turn') : tr(white ? 'chess.turn_white' : 'chess.turn_black');
      }
    }
    // Pieces this side has captured = opponent's missing pieces.
    final caps = g.captured(!white);
    final diff = g.materialDiff() * (white ? 1 : -1);
    return GlassCard(
      blur: 0,
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      gradient: toMove
          ? LinearGradient(colors: [_tint.withValues(alpha: 0.35), _tint.withValues(alpha: 0.12)])
          : null,
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: white ? const Color(0xFFF3E7CF) : const Color(0xFF2A2536),
            border: Border.all(color: toMove ? Pal.gold : Pal.glassBorder, width: 2),
          ),
          alignment: Alignment.center,
          child: isAi
              ? Icon(Icons.smart_toy_rounded, size: 20, color: white ? const Color(0xFF2A2536) : const Color(0xFFF3E7CF))
              : PieceGlyph(white ? pKing : -pKing, size: 24),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Flexible(
                child: Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 14)),
              ),
              if (status != null) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(status,
                      key: ValueKey('status_$white'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: g.inCheck ? Pal.danger : Pal.gold, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ]),
            SizedBox(
              height: 16,
              child: Row(children: [
                Flexible(
                  child: ClipRect(
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (final t in caps.reversed) Align(widthFactor: 0.62, child: PieceGlyph(white ? -t : t, size: 16)),
                    ]),
                  ),
                ),
                if (diff > 0) Text(' +$diff', style: const TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w800)),
              ]),
            ),
          ]),
        ),
        _clockChip(white, toMove),
      ]),
    );
  }

  Widget _clockChip(bool white, bool active) {
    final ms = _clock.msFor(white);
    final low = _clock.low(white);
    final running = active && _clockRunning && !_finished;
    final bg = running ? (low ? Pal.danger : Pal.gold) : Colors.black.withValues(alpha: 0.35);
    Widget chip = Container(
      key: ValueKey('clock_$white'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: low ? Pal.danger : Pal.glassBorder),
        boxShadow: running ? [BoxShadow(color: bg.withValues(alpha: 0.5), blurRadius: 12)] : null,
      ),
      child: Text(
        ChessClock.format(ms),
        style: TextStyle(
          color: running ? const Color(0xFF1B1245) : (low ? Pal.danger : Pal.text),
          fontSize: 18,
          fontWeight: FontWeight.w900,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
    if (running && low) {
      chip = chip
          .animate(key: ValueKey('pulse_$white'), onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.08, 1.08), duration: 450.ms)
          .fade(begin: 1, end: 0.75, duration: 450.ms);
    }
    return chip;
  }

  Widget _history(ChessGame g) {
    // A position with black to move starts the list with "N. ... move".
    final pad = _startWhite ? 0 : 1;
    final rows = (g.sans.length + pad + 1) ~/ 2;
    return SizedBox(
      height: 30,
      child: g.sans.isEmpty
          ? Center(child: Text(tr('chess.no_moves'), style: const TextStyle(color: Pal.textDim, fontSize: 12)))
          : ListView.builder(
              key: const ValueKey('history'),
              scrollDirection: Axis.horizontal,
              reverse: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: rows,
              itemBuilder: (_, i) {
                final n = rows - 1 - i;
                final wi = n * 2 - pad, bi = n * 2 + 1 - pad;
                final w = wi >= 0 ? g.sans[wi] : '...';
                final b = bi < g.sans.length ? g.sans[bi] : '';
                final last = n == rows - 1;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: last ? _tint.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${_startFullmove + n}. $w $b',
                        style: const TextStyle(color: Pal.text, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                );
              },
            ),
    );
  }

  Widget _controls(ChessGame g) {
    final live = !g.over && !_finished;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 2, 12, 10),
      child: Row(children: [
        if (_cpu)
          Expanded(
            child: _ctrl(
              const ValueKey('undoBtn'),
              Icons.undo_rounded,
              _freeUndos > 0 ? tr('chess.undo_free') : tr('common.undo'),
              _canUndo ? _undo : null,
            ),
          ),
        Expanded(child: _ctrl(const ValueKey('drawBtn'), Icons.handshake_rounded, tr('chess.offer_draw'), live && g.moves.isNotEmpty ? _offerDraw : null)),
        Expanded(child: _ctrl(const ValueKey('resignBtn'), Icons.flag_rounded, tr('chess.resign'), live ? _resign : null)),
        Expanded(child: _ctrl(const ValueKey('flipBtn'), Icons.swap_vert_rounded, tr('chess.flip'), () => setState(() => _manualFlip = !_manualFlip))),
      ]),
    );
  }

  Widget _ctrl(Key key, IconData icon, String label, VoidCallback? onTap) {
    final body = Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.08),
            border: Border.all(color: Pal.glassBorder),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Pal.text, size: 20),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Pal.textDim, fontSize: 10, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
    return onTap == null ? KeyedSubtree(key: key, child: body) : Pressable(key: key, onTap: onTap, child: body);
  }
}

class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.label, required this.selected, required this.onTap, required this.color, this.icon, this.leading});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color color;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: selected ? Pal.accent(color) : const LinearGradient(colors: [Color(0x26FFFFFF), Color(0x0DFFFFFF)]),
          border: Border.all(color: selected ? Colors.white.withValues(alpha: 0.6) : Pal.glassBorder),
          boxShadow: selected ? [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12)] : null,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          if (icon != null) ...[Icon(icon, size: 17, color: Colors.white), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
        ]),
      ),
    );
  }
}
