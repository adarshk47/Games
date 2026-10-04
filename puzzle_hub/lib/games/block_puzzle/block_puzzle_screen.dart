import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/block_logic.dart';

const _tint = Color(0xFFFF6FB5);
const _milestones = [500, 1000, 2500];

String _bestKey(Tier t) => 'block.${t.name}.best';

String _tierLabel(Tier t) => tr('common.tier.${t.name}');

/// Block Puzzle: tier select, then the game.
class BlockPuzzleScreen extends StatefulWidget {
  const BlockPuzzleScreen({super.key});

  @override
  State<BlockPuzzleScreen> createState() => _BlockPuzzleScreenState();
}

class _BlockPuzzleScreenState extends State<BlockPuzzleScreen> {
  Tier? _tier;

  @override
  Widget build(BuildContext context) {
    final t = _tier;
    if (t == null) return _TierMenu(onPick: (x) => setState(() => _tier = x));
    return _BlockGameView(key: ValueKey(t), tier: t, onMenu: () => setState(() => _tier = null));
  }
}

// ---------------------------------------------------------------- menu

class _TierMenu extends StatelessWidget {
  const _TierMenu({required this.onPick});
  final ValueChanged<Tier> onPick;

  static const _icon = {
    Tier.easy: Icons.spa_rounded,
    Tier.medium: Icons.grid_view_rounded,
    Tier.hard: Icons.local_fire_department_rounded,
    Tier.extreme: Icons.bolt_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final last = Storage.getInt('block.tier', 0).clamp(0, Tier.values.length - 1);
    return GameScaffold(
      title: tr('block_puzzle.title'),
      tint: _tint,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(tr('block_puzzle.choose'),
              style: const TextStyle(color: Pal.textDim, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          for (final t in Tier.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Pressable(
                onTap: () {
                  Storage.setInt('block.tier', t.index);
                  AppAudio.play(Sound.tap);
                  onPick(t);
                },
                child: GlassCard(
                  blur: 0,
                  glow: t.index == last ? _tint : null,
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: Pal.accent(Pal.accents[(t.index * 2 + 5) % 8]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(_icon[t], color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(_tierLabel(t), style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
                          if (t.index == last) ...[
                            const SizedBox(width: 8),
                            Text(tr('common.last_played').toUpperCase(),
                                style: const TextStyle(color: _tint, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                          ],
                        ]),
                        const SizedBox(height: 2),
                        Text(tr('block_puzzle.desc.${t.name}'), style: const TextStyle(color: Pal.textDim, fontSize: 13)),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(tr('common.best').toUpperCase(), style: const TextStyle(color: Pal.textDim, fontSize: 10, letterSpacing: 1)),
                      Text('${Storage.getInt(_bestKey(t))}',
                          style: const TextStyle(color: Pal.gold, fontSize: 20, fontWeight: FontWeight.w900)),
                    ]),
                  ]),
                ),
              ),
            ).animate(delay: (t.index * 70).ms).fadeIn().slideX(begin: 0.15, end: 0),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- visuals

class _Block extends StatelessWidget {
  const _Block({required this.color, required this.size});
  final int color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = Pal.accents[color % Pal.accents.length];
    final r = size * 0.24;
    return Padding(
      padding: EdgeInsets.all(size * 0.04),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(c, Colors.white, 0.4)!, c, Color.lerp(c, Colors.black, 0.3)!],
          ),
          borderRadius: BorderRadius.circular(r),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: size > 20 ? 1.2 : 0.8),
          boxShadow: [BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: size * 0.2, offset: Offset(0, size * 0.06))],
        ),
        child: Align(
          alignment: const Alignment(-0.3, -0.6),
          child: FractionallySizedBox(
            widthFactor: 0.55,
            heightFactor: 0.2,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(size),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PieceView extends StatelessWidget {
  const _PieceView({required this.piece, required this.cell});
  final Piece piece;
  final double cell;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: piece.w * cell,
        height: piece.h * cell,
        child: Stack(children: [
          for (final (r, c) in piece.cells)
            Positioned(left: c * cell, top: r * cell, width: cell, height: cell, child: _Block(color: piece.color, size: cell)),
        ]),
      );
}

class _Flash {
  _Flash(this.r, this.c, this.color, this.delay);
  final int r, c, color, delay;
}

class _Pop {
  _Pop(this.text, this.dx, this.dy, this.big);
  final String text;
  final double dx, dy;
  final bool big;
}

// ---------------------------------------------------------------- game

class _BlockGameView extends StatefulWidget {
  const _BlockGameView({super.key, required this.tier, required this.onMenu});
  final Tier tier;
  final VoidCallback onMenu;

  @override
  State<_BlockGameView> createState() => _BlockGameViewState();
}

class _BlockGameViewState extends State<_BlockGameView> {
  static const _pad = 6.0;
  static const _lift = 56.0;

  late BlockGame _g;
  final _boardKey = GlobalKey();
  final _stackKey = GlobalKey();
  final _timers = <Timer>[];
  final _paid = <int>{};
  final _flashes = <_Flash>[];
  final _pops = <_Pop>[];
  int _best = 0;
  bool _ended = false;

  int? _dragSlot;
  Offset _finger = Offset.zero;
  (int, int)? _anchor;
  bool _valid = false;
  double _boardCell = 40;

  Tier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  void _later(Duration d, VoidCallback f) {
    late Timer t;
    t = Timer(d, () {
      _timers.remove(t);
      if (mounted) f();
    });
    _timers.add(t);
  }

  void _newGame() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _g = BlockGame(_tier);
    _best = Storage.getInt(_bestKey(_tier));
    _paid.clear();
    _flashes.clear();
    _pops.clear();
    _ended = false;
    _dragSlot = null;
    _anchor = null;
  }

  // ---- drag handling

  Offset? _boardOrigin() {
    final ro = _boardKey.currentContext?.findRenderObject();
    if (ro is! RenderBox || !ro.attached) return null;
    return ro.localToGlobal(Offset.zero);
  }

  void _start(int slot, Offset global) {
    if (_ended || _g.tray[slot] == null || _dragSlot != null) return;
    AppAudio.haptic();
    setState(() {
      _dragSlot = slot;
      _finger = global;
      _computeAnchor();
    });
  }

  void _move(Offset global) {
    if (_dragSlot == null) return;
    setState(() {
      _finger = global;
      _computeAnchor();
    });
  }

  void _computeAnchor() {
    final p = _g.tray[_dragSlot!];
    final o = _boardOrigin();
    if (p == null || o == null) {
      _anchor = null;
      _valid = false;
      return;
    }
    final tl = Offset(_finger.dx - p.w * _boardCell / 2, _finger.dy - p.h * _boardCell - _lift);
    final c = ((tl.dx - o.dx - _pad) / _boardCell).round();
    final r = ((tl.dy - o.dy - _pad) / _boardCell).round();
    _anchor = (r, c);
    _valid = _g.canPlace(p, r, c);
  }

  void _end({bool cancel = false}) {
    final slot = _dragSlot;
    if (slot == null) return;
    final a = _anchor;
    final ok = !cancel && a != null && _valid;
    setState(() {
      _dragSlot = null;
      _anchor = null;
    });
    if (ok) {
      _commit(slot, a.$1, a.$2);
    } else if (!cancel) {
      AppAudio.play(Sound.fail);
    }
  }

  void _commit(int slot, int r, int c) {
    final p = _g.tray[slot]!;
    final res = _g.place(slot, r, c);
    if (res == null) return;
    AppAudio.haptic(res.lines > 0);
    final combo = res.lines >= 2 || res.streak >= 2;
    AppAudio.play(res.lines == 0 ? Sound.pop : (combo ? Sound.coin : Sound.success));

    final o = _boardOrigin();
    final stackO = (_stackKey.currentContext?.findRenderObject() as RenderBox?)?.localToGlobal(Offset.zero);
    final base = (o != null && stackO != null) ? o - stackO : Offset.zero;
    final px = base.dx + _pad + (c + p.w / 2) * _boardCell;
    final py = base.dy + _pad + (r + p.h / 2) * _boardCell;

    setState(() {
      if (res.lines > 0) {
        final fl = res.cleared.map((e) => _Flash(e.$1, e.$2, e.$3, ((e.$1 - r).abs() + (e.$2 - c).abs()) * 18)).toList();
        _flashes.addAll(fl);
        _later(900.ms, () => setState(() => _flashes.removeWhere(fl.contains)));
      }
      final pops = <_Pop>[_Pop('+${res.gained}', px, py, res.lines > 0)];
      if (res.lines >= 2) {
        pops.add(_Pop(tr('block_puzzle.lines', {'n': res.lines}), px, py - 34, true));
      } else if (res.streak >= 2) {
        pops.add(_Pop(tr('block_puzzle.combo', {'n': res.streak}), px, py - 34, true));
      }
      _pops.addAll(pops);
      _later(1100.ms, () => setState(() => _pops.removeWhere(pops.contains)));
      if (_g.score > _best) {
        _best = _g.score;
        Storage.setInt(_bestKey(_tier), _best);
      }
    });

    for (var i = 0; i < _milestones.length; i++) {
      final m = _milestones[i];
      if (_g.score >= m && _paid.add(m)) {
        Rewards.onLevelComplete('block_puzzle', '${_tier.name}-score$m', stars: i + 1, score: _g.score);
      }
    }
    if (_g.over) _gameOver();
  }

  void _gameOver() {
    if (_ended) return;
    _ended = true;
    Storage.setBest(_bestKey(_tier), _g.score);
    Rewards.onGameEnd('block_puzzle', score: _g.score, won: _g.score >= _tier.winScore);
    AppAudio.play(Sound.fail);
    _later(700.ms, () {
      final score = _g.score;
      showPremiumDialog(
        context,
        title: tr('block_puzzle.no_moves'),
        emoji: score >= _best && score > 0 ? '🏆' : '🧱',
        message: tr('block_puzzle.result', {'score': score, 'best': _best, 'tier': _tierLabel(_tier)}),
        stars: score >= _milestones[2] ? 3 : score >= _milestones[1] ? 2 : score >= _milestones[0] ? 1 : 0,
        color: _tint,
        actions: [
          DialogAction(tr('common.play_again'), () => setState(_newGame), primary: true),
          DialogAction(tr('common.menu'), widget.onMenu),
        ],
      );
    });
  }

  // ---- build

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '${tr('block_puzzle.title')} · ${_tierLabel(_tier)}',
      tint: _tint,
      onBack: widget.onMenu,
      actions: [
        BarAction(icon: Icons.refresh_rounded, tooltip: tr('common.restart'), onTap: () => setState(_newGame)),
      ],
      body: LayoutBuilder(builder: (context, bc) {
        const trayH = 130.0;
        const statsH = 70.0;
        final side = (bc.maxWidth - 24).clamp(120.0, bc.maxHeight - statsH - trayH - 20).toDouble();
        _boardCell = (side - 2 * _pad) / _g.n;
        final slotW = (bc.maxWidth - 24) / 3;
        final trayCell = [_boardCell * 0.6, (slotW - 12) / 5, (trayH - 12) / 5].reduce((a, b) => a < b ? a : b);

        return Stack(key: _stackKey, clipBehavior: Clip.none, children: [
          Column(children: [
            SizedBox(height: statsH, child: _stats()),
            Center(child: _board(side)),
            const Spacer(),
            SizedBox(
              height: trayH,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(children: [
                  for (var i = 0; i < 3; i++) SizedBox(width: slotW, child: _slot(i, trayCell)),
                ]),
              ),
            ),
            const SizedBox(height: 20),
          ]),
          if (_dragSlot != null && _g.tray[_dragSlot!] != null) _dragOverlay(_g.tray[_dragSlot!]!),
          for (final p in _pops) _popup(p),
        ]);
      }),
    );
  }

  Widget _stats() {
    Widget box(String label, String value, Color color, {Key? key}) => GlassCard(
          blur: 0,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w700)),
            Text(value, key: key, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900)),
          ]),
        );
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      box(tr('common.score').toUpperCase(), '${_g.score}', Pal.text, key: const ValueKey('score')),
      const SizedBox(width: 14),
      box(tr('common.best').toUpperCase(), '$_best', Pal.gold, key: const ValueKey('best')),
    ]);
  }

  Widget _board(double side) {
    final n = _g.n;
    final cell = _boardCell;
    final dp = _dragSlot == null ? null : _g.tray[_dragSlot!];
    final ghost = <int>{};
    if (dp != null && _anchor != null && _valid) {
      for (final (dr, dc) in dp.cells) {
        ghost.add((_anchor!.$1 + dr) * n + _anchor!.$2 + dc);
      }
    }
    // Lines that would complete with the ghost, highlighted.
    final hi = <int>{};
    if (ghost.isNotEmpty) {
      bool full(int Function(int) idx) => List.generate(n, idx).every((k) => _g.grid[k ~/ n][k % n] != -1 || ghost.contains(k));
      for (var i = 0; i < n; i++) {
        if (full((j) => i * n + j)) hi.addAll(List.generate(n, (j) => i * n + j));
        if (full((j) => j * n + i)) hi.addAll(List.generate(n, (j) => j * n + i));
      }
    }
    final ghostColor = dp == null ? Colors.white : Pal.accents[dp.color % 8];

    return Container(
      key: _boardKey,
      width: side,
      height: side,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.14), Colors.white.withValues(alpha: 0.05)],
        ),
        border: Border.all(color: Pal.glassBorder),
        boxShadow: [BoxShadow(color: _tint.withValues(alpha: 0.18), blurRadius: 30, spreadRadius: -6)],
      ),
      child: Stack(children: [
        for (var r = 0; r < n; r++)
          for (var c = 0; c < n; c++)
            Positioned(
              left: _pad + c * cell,
              top: _pad + r * cell,
              width: cell,
              height: cell,
              child: Padding(
                padding: EdgeInsets.all(cell * 0.04),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: ghost.contains(r * n + c)
                        ? ghostColor.withValues(alpha: 0.55)
                        : hi.contains(r * n + c)
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(cell * 0.22),
                    border: ghost.contains(r * n + c) ? Border.all(color: Colors.white.withValues(alpha: 0.8), width: 1.5) : null,
                  ),
                ),
              ),
            ),
        for (var r = 0; r < n; r++)
          for (var c = 0; c < n; c++)
            if (_g.grid[r][c] != -1)
              Positioned(
                key: ValueKey('cell-$r-$c-${_g.grid[r][c]}'),
                left: _pad + c * cell,
                top: _pad + r * cell,
                width: cell,
                height: cell,
                child: _Block(color: _g.grid[r][c], size: cell).animate().scaleXY(begin: 0.6, end: 1, duration: 180.ms, curve: Curves.easeOutBack),
              ),
        for (final f in _flashes)
          Positioned(
            left: _pad + f.c * cell,
            top: _pad + f.r * cell,
            width: cell,
            height: cell,
            child: IgnorePointer(
              child: Stack(children: [
                _Block(color: f.color, size: cell),
                Padding(
                  padding: EdgeInsets.all(cell * 0.04),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(cell * 0.22)),
                  ),
                ),
              ]),
            )
                .animate(delay: f.delay.ms)
                .scaleXY(begin: 1, end: 1.35, duration: 380.ms, curve: Curves.easeOut)
                .fadeOut(duration: 380.ms)
                .rotate(begin: 0, end: (f.r + f.c).isEven ? 0.08 : -0.08, duration: 380.ms),
          ),
      ]),
    );
  }

  Widget _slot(int i, double trayCell) {
    final p = _g.tray[i];
    final dragging = _dragSlot == i;
    final stuck = p != null && !_g.fitsAnywhere(p);
    return Listener(
      key: ValueKey('slot-$i'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) => _start(i, e.position),
      onPointerMove: (e) => _move(e.position),
      onPointerUp: (_) => _end(),
      onPointerCancel: (_) => _end(cancel: true),
      child: Center(
        child: p == null
            ? const SizedBox.shrink()
            : AnimatedOpacity(
                duration: 150.ms,
                opacity: dragging ? 0.2 : (stuck ? 0.4 : 1),
                child: _PieceView(piece: p, cell: trayCell)
                    .animate(key: ValueKey(p))
                    .scaleXY(begin: 0.5, end: 1, duration: 320.ms, curve: Curves.easeOutBack)
                    .fadeIn(duration: 200.ms),
              ),
      ),
    );
  }

  Widget _dragOverlay(Piece p) {
    final so = (_stackKey.currentContext?.findRenderObject() as RenderBox?)?.globalToLocal(_finger);
    if (so == null) return const SizedBox.shrink();
    final pw = p.w * _boardCell, ph = p.h * _boardCell;
    return Positioned(
      left: so.dx - pw / 2,
      top: so.dy - ph - _lift,
      child: IgnorePointer(
        child: Opacity(opacity: _valid ? 0.95 : 0.7, child: _PieceView(piece: p, cell: _boardCell)),
      ),
    );
  }

  Widget _popup(_Pop p) => Positioned(
        left: p.dx - 80,
        top: p.dy - 18,
        width: 160,
        child: IgnorePointer(
          child: Text(
            p.text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: p.big ? Pal.gold : Pal.text,
              fontSize: p.big ? 26 : 20,
              fontWeight: FontWeight.w900,
              shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
              decoration: TextDecoration.none,
            ),
          ).animate().scaleXY(begin: 0.4, end: 1.1, duration: 250.ms, curve: Curves.easeOutBack).moveY(begin: 0, end: -50, duration: 1000.ms).fadeOut(delay: 600.ms, duration: 400.ms),
        ),
      );
}
