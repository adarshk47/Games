import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'hexa_art.dart';
import 'logic/hexa_sort_logic.dart';
import 'progress.dart';

const _kFreeRefresh = 1;
const _kMaxContinues = 3;
const _gapMs = 70, _flyMs = 300, _dropMs = 280;

/// A tile flying between two stacks.
class _Flight {
  _Flight(this.serial, this.color, this.from, this.to, this.delayMs);
  final int serial, color, delayMs;
  final Offset from, to;
}

/// A clear / revive burst on a cell.
class _Burst {
  _Burst(this.serial, this.cell, this.color, this.count);
  final int serial, cell, count;
  final Color color;
}

/// One Hexa Sort level.
class HexaSortGame extends StatefulWidget {
  const HexaSortGame({super.key, required this.tier, required this.level, this.custom});
  final HsTier tier;
  final int level;

  /// Hand-made level used instead of the generated one (tests / tutorial).
  final HsLevel? custom;

  @override
  State<HexaSortGame> createState() => _HexaSortGameState();
}

class _HexaSortGameState extends State<HexaSortGame> {
  late int _level;
  late HsGame _g;
  late List<List<int>> _display;
  final _rootKey = GlobalKey();
  final _boardKey = GlobalKey();
  final List<_Flight> _flights = [];
  final List<_Burst> _bursts = [];
  final Map<int, int> _drops = {};
  HsGeometry? _geo;
  int? _selected;
  int _shownCleared = 0;
  int _serial = 0;
  int _epoch = 0;
  int _offerSerial = 0;
  int _refreshUsed = 0;
  bool _busy = false;
  bool _won = false;
  String? _toast;
  bool _toastGood = false;
  int _toastSerial = 0;
  int? _dragOffer;
  Offset? _dragPos;
  int? _hover;

  HsTier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    _load(widget.level);
  }

  HsLevel _levelData(int n) =>
      widget.custom != null && widget.custom!.number == n ? widget.custom! : hsGenerate(_tier, n);

  void _load(int level) {
    _level = level.clamp(1, kHsLevels);
    HsProgress.setCurrent(_tier, _level);
    HsProgress.onStart(_tier, _level);
    _g = HsGame(_levelData(_level));
    _display = [for (final s in _g.stacks) List<int>.of(s)];
    _epoch++;
    _flights.clear();
    _bursts.clear();
    _drops.clear();
    _selected = 0;
    _shownCleared = 0;
    _refreshUsed = 0;
    _busy = false;
    _won = false;
    _toast = null;
    _dragOffer = null;
    _dragPos = null;
    _hover = null;
    _offerSerial++;
  }

  /// Opens [level] if it may be played (offering the skip purchase if not).
  Future<void> _open(int level) async {
    if (!HsProgress.canPlay(_tier, level)) {
      final bought = await LevelGate.buy(context,
          prefix: HsProgress.prefix(_tier), freeUpTo: HsProgress.unlocked(_tier), level: level);
      if (!mounted) return;
      if (!bought) {
        Navigator.of(context).maybePop();
        return;
      }
    }
    AppAudio.play(Sound.tap);
    setState(() => _load(level));
  }

  void _restart() => _open(_level);

  void _later(int ms, VoidCallback f) {
    final e = _epoch;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && e == _epoch) f();
    });
  }

  void _flash(String text, {bool good = false}) {
    final s = ++_toastSerial;
    setState(() {
      _toast = text;
      _toastGood = good;
    });
    _later(1400, () {
      if (_toastSerial == s) setState(() => _toast = null);
    });
  }

  int? _firstOffer() {
    for (var i = 0; i < kHsOffers; i++) {
      if (_g.offers[i] != null) return i;
    }
    return null;
  }

  // ---- play ---------------------------------------------------------------

  void _selectOffer(int i) {
    if (_busy || _g.over || _g.offers[i] == null) return;
    AppAudio.play(Sound.tap, volume: 0.6);
    setState(() => _selected = i);
  }

  void _tapCell(int cell) {
    if (_busy || _won || _g.over) return;
    final o = _selected ?? _firstOffer();
    if (o == null) return;
    _place(o, cell);
  }

  void _place(int offer, int cell) {
    if (_busy || _g.over) return;
    if (_g.board.blocked.contains(cell)) {
      AppAudio.play(Sound.fail);
      _flash(tr('hexa_sort.blocked'));
      return;
    }
    if (!_g.board.isOpen(cell)) return;
    if (_g.stacks[cell].isNotEmpty) {
      AppAudio.play(Sound.fail);
      _flash(tr('hexa_sort.occupied'));
      return;
    }
    final m = _g.place(offer, cell);
    if (m == null) return;
    AppAudio.play(Sound.pop);
    AppAudio.haptic();
    setState(() {
      _busy = true;
      _display[cell] = List<int>.of(m.stack);
      _drops[cell] = ++_serial;
      _selected = _firstOffer();
      if (m.dealt) _offerSerial++;
    });
    _later(_dropMs, () {
      _play(m.steps, 0, () {
        if (m.clears >= 2) _flash(tr('hexa_sort.combo', {'n': m.clears}), good: true);
        _settle();
      });
    });
  }

  void _play(List<HsStep> steps, int i, VoidCallback done) {
    final geo = _geo;
    if (i >= steps.length || geo == null) {
      done();
      return;
    }
    final s = steps[i];
    if (s.kind == HsStepKind.transfer) {
      final srcN = _display[s.from].length;
      final dstN = _display[s.to].length;
      final finalN = dstN + s.count;
      final from = geo.center(s.from), to = geo.center(s.to);
      setState(() {
        for (var j = 0; j < s.count; j++) {
          _flights.add(_Flight(++_serial, s.color, hsLayer(from, geo.r, srcN - 1 - j, srcN),
              hsLayer(to, geo.r, dstN + j, finalN), j * _gapMs));
        }
        _display[s.from].removeRange(math.max(0, srcN - s.count), srcN);
      });
      AppAudio.play(Sound.slide, volume: 0.7);
      for (var j = 0; j < s.count; j++) {
        _later(j * _gapMs + _flyMs, () => setState(() => _display[s.to].add(s.color)));
      }
      _later((s.count - 1) * _gapMs + _flyMs + 60, () => _play(steps, i + 1, done));
    } else {
      setState(() {
        final d = _display[s.from];
        d.removeRange(math.max(0, d.length - s.count), d.length);
        _shownCleared += s.count;
        _bursts.add(_Burst(++_serial, s.from, hsColor(s.color), s.count));
      });
      final serial = _serial;
      AppAudio.play(Sound.success);
      AppAudio.haptic();
      _later(950, () => setState(() => _bursts.removeWhere((b) => b.serial == serial)));
      _later(450, () => _play(steps, i + 1, done));
    }
  }

  void _settle() {
    setState(() {
      _display = [for (final s in _g.stacks) List<int>.of(s)];
      _shownCleared = _g.cleared;
      _flights.clear();
      _busy = false;
    });
    if (_g.won) {
      _onWin();
    } else if (_g.lost) {
      _onLost();
    }
  }

  void _onWin() {
    _won = true;
    _busy = true;
    final stars = hsStars(fill: _g.fill, continues: _g.continues);
    HsProgress.complete(_tier, _level, stars);
    Rewards.onLevelComplete('hexa_sort', '${_tier.id}-L$_level', stars: stars);
    _later(900, () => _showWin(stars));
  }

  void _showWin(int stars) {
    final last = _level >= kHsLevels;
    showPremiumDialog(
      context,
      title: tr('common.level_complete'),
      message: [
        tr('hexa_sort.win_msg', {'n': _g.cleared, 'moves': _g.moves}),
        if (last) tr('hexa_sort.tier_done'),
      ].join('\n'),
      emoji: '🍯',
      color: hsAccentHot,
      stars: stars,
      actions: [
        DialogAction(tr('common.replay'), _restart),
        if (last)
          DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop(), primary: true)
        else
          DialogAction(tr('common.next_level'), () => _open(_level + 1), primary: true),
      ],
    );
  }

  void _onLost() {
    _busy = true;
    AppAudio.play(Sound.fail);
    AppAudio.haptic();
    _later(700, () async {
      if (_g.continues < _kMaxContinues) {
        final paid = await showContinueOffer(context, OfferKind.extraLife);
        if (!mounted) return;
        if (paid) {
          _revive();
          return;
        }
      }
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: tr('hexa_sort.board_full'),
        message: tr('hexa_sort.board_full_msg', {'n': _g.cleared, 'total': _g.level.goal}),
        emoji: '⬢',
        color: Pal.danger,
        actions: [
          DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop()),
          DialogAction(tr('common.try_again'), _restart, primary: true),
        ],
      );
    });
  }

  void _revive() {
    final before = [for (final s in _g.stacks) List<int>.of(s)];
    final cells = _g.revive();
    AppAudio.play(Sound.success);
    setState(() {
      for (final c in cells) {
        final s = before[c];
        _bursts.add(_Burst(++_serial, c, s.isEmpty ? Colors.white : hsColor(s.last), 0));
      }
      _display = [for (final s in _g.stacks) List<int>.of(s)];
      _busy = false;
    });
    final serial = _serial;
    _later(950, () => setState(() => _bursts.removeWhere((b) => b.serial <= serial)));
    _flash(tr('hexa_sort.revived'), good: true);
  }

  Future<void> _refresh() async {
    if (_busy || _g.over) return;
    if (_refreshUsed >= _kFreeRefresh) {
      _busy = true;
      final paid = await showContinueOffer(context, OfferKind.hint);
      _busy = false;
      if (!mounted || !paid || _g.over) return;
    } else {
      _refreshUsed++;
    }
    AppAudio.play(Sound.coin);
    setState(() {
      _g.refreshOffers();
      _selected = 0;
      _offerSerial++;
    });
  }

  // ---- drag -----------------------------------------------------------------

  Offset? _boardLocal(Offset global) {
    final box = _boardKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.globalToLocal(global);
  }

  Offset? _rootLocal(Offset global) {
    final box = _rootKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.globalToLocal(global);
  }

  double get _dragLift => (_geo?.r ?? 24) * 1.4;

  int? _dropCell(Offset global) {
    final geo = _geo;
    final p = _boardLocal(global - Offset(0, _dragLift));
    if (geo == null || p == null) return null;
    final c = geo.cellAt(p);
    return c != null && _g.board.isOpen(c) && _g.stacks[c].isEmpty ? c : null;
  }

  void _dragStart(int i, Offset global) {
    if (_busy || _g.over || _g.offers[i] == null) return;
    setState(() {
      _selected = i;
      _dragOffer = i;
      _dragPos = global;
      _hover = _dropCell(global);
    });
  }

  void _dragUpdate(Offset global) {
    if (_dragOffer == null) return;
    setState(() {
      _dragPos = global;
      _hover = _dropCell(global);
    });
  }

  void _dragEnd() {
    final o = _dragOffer, c = _hover;
    setState(() {
      _dragOffer = null;
      _dragPos = null;
      _hover = null;
    });
    if (o != null && c != null) _place(o, c);
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final freeRefresh = math.max(0, _kFreeRefresh - _refreshUsed);
    final off = _g.over || _won;
    return GameScaffold(
      title: tr('hexa_sort.title'),
      tint: hsAccent,
      body: Stack(
        key: _rootKey,
        children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Row(children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 130),
                  child: _Pill(
                    icon: Icons.grid_view_rounded,
                    label: '${hsTierName(_tier)} · $_level',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _goalBar()),
              ]),
            ),
            Expanded(child: _board()),
            _offersRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _Pill(icon: Icons.refresh_rounded, label: tr('common.restart'), onTap: _restart, big: true),
                  _Pill(
                    icon: Icons.autorenew_rounded,
                    label: freeRefresh > 0
                        ? '${tr('hexa_sort.refresh')} · ${tr('hexa_sort.free_n', {'n': freeRefresh})}'
                        : tr('hexa_sort.refresh'),
                    trailing: freeRefresh > 0 ? null : '🪙',
                    onTap: off ? null : _refresh,
                    big: true,
                  ),
                ],
              ),
            ),
          ]),
          if (_dragOffer != null && _dragPos != null) _dragGhost(),
          if (_toast != null)
            Positioned(
              bottom: 150,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: GlassCard(
                    blur: 0,
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    gradient: LinearGradient(
                      colors: _toastGood
                          ? [hsAccentHot.withValues(alpha: 0.9), const Color(0xFF9B3FD0).withValues(alpha: 0.9)]
                          : [Pal.danger.withValues(alpha: 0.85), const Color(0xFF8A2340).withValues(alpha: 0.9)],
                    ),
                    child: Text(_toast!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                )
                    .animate(key: ValueKey(_toastSerial))
                    .fadeIn(duration: 150.ms)
                    .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack),
              ),
            ),
        ],
      ),
    );
  }

  Widget _goalBar() {
    final goal = _g.level.goal;
    final frac = (_shownCleared / goal).clamp(0.0, 1.0);
    return GlassCard(
      blur: 0,
      radius: 18,
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 7),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          const Icon(Icons.hexagon_rounded, size: 14, color: hsAccentHot),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tr('hexa_sort.goal', {'n': math.min(_shownCleared, goal), 'total': goal}),
              key: const ValueKey('hs_goal'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
          Text(tr('hexa_sort.moves', {'n': _g.moves}),
              style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700, fontSize: 11)),
        ]),
        const SizedBox(height: 5),
        TweenAnimationBuilder<double>(
          tween: Tween(end: frac),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (_, v, _) => Container(
            height: 7,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: const LinearGradient(colors: [Color(0xFFFFB86B), hsAccentHot, Color(0xFFB06BFF)]),
                  boxShadow: [BoxShadow(color: hsAccentHot.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _board() {
    final b = _g.board;
    return LayoutBuilder(builder: (context, c) {
      final r = math.max(8.0, math.min(46.0, HsGeometry.fit(b, c.maxWidth - 20, c.maxHeight - 10)));
      final geo = HsGeometry(b, r);
      _geo = geo;
      final empty = {for (final i in b.openCells) if (_display[i].isEmpty) i};
      final showTargets = !_busy && !_g.over && (_selected != null || _dragOffer != null);
      final cells = b.allCells.toList();
      return Center(
        child: SizedBox(
          key: _boardKey,
          width: geo.width,
          height: geo.height,
          child: Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: CustomPaint(
                painter: HsBoardPainter(
                  geo: geo,
                  empty: empty,
                  highlight: _hover,
                  targets: showTargets ? empty : const {},
                ),
              ),
            ),
            for (final i in cells)
              if (_display[i].isNotEmpty) _cellStack(i, geo),
            for (final i in cells) _hitTarget(i, geo),
            for (final bu in _bursts) _burstView(bu, geo),
            Positioned.fill(
              child: IgnorePointer(
                child: Stack(clipBehavior: Clip.none, children: [for (final f in _flights) _flightView(f, geo)]),
              ),
            ),
          ]),
        ),
      );
    });
  }

  Widget _cellStack(int i, HsGeometry geo) {
    final c = geo.center(i);
    final r = geo.r;
    Widget w = CustomPaint(painter: HsStackPainter(tiles: List<int>.of(_display[i]), r: r));
    final drop = _drops[i];
    if (drop != null) {
      w = w
          .animate(key: ValueKey('drop$drop'))
          .moveY(begin: -r * 1.6, end: 0, duration: _dropMs.ms, curve: Curves.easeOutBack)
          .fadeIn(duration: 120.ms);
    }
    return Positioned(
      key: ValueKey('stack$i-$_epoch'),
      left: c.dx - r,
      top: c.dy - r,
      width: r * 2,
      height: r * 2,
      child: IgnorePointer(child: w),
    );
  }

  Widget _hitTarget(int i, HsGeometry geo) {
    final c = geo.center(i);
    final r = geo.r;
    return Positioned(
      left: c.dx - r * 0.85,
      top: c.dy - r * 0.85,
      width: r * 1.7,
      height: r * 1.7,
      child: GestureDetector(
        key: ValueKey('hs_cell_$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tapCell(i),
      ),
    );
  }

  Widget _burstView(_Burst b, HsGeometry geo) {
    final c = geo.center(b.cell);
    final r = geo.r;
    return Positioned(
      key: ValueKey('burst${b.serial}'),
      left: c.dx - r * 3,
      top: c.dy - r * 3.5,
      width: r * 6,
      height: r * 6,
      child: IgnorePointer(
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 750),
            builder: (_, v, _) => CustomPaint(size: Size(r * 6, r * 6), painter: HsBurstPainter(b.color, v, r)),
          ),
          if (b.count > 0)
            Text('+${b.count}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: math.max(14, r * 0.8),
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: b.color, blurRadius: 10), const Shadow(color: Colors.black54, blurRadius: 4)],
                    ))
                .animate()
                .scale(begin: const Offset(0.4, 0.4), end: const Offset(1.2, 1.2), duration: 300.ms, curve: Curves.easeOutBack)
                .then()
                .moveY(begin: 0, end: -r * 1.2, duration: 500.ms)
                .fadeOut(duration: 500.ms),
        ]),
      ),
    );
  }

  Widget _flightView(_Flight f, HsGeometry geo) {
    final r = geo.r;
    final total = f.delayMs + _flyMs;
    final d = f.to - f.from;
    final len = d.distance == 0 ? 1.0 : d.distance;
    final nx = d.dx / len, ny = d.dy / len;
    return TweenAnimationBuilder<double>(
      key: ValueKey('fl${f.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      onEnd: () {
        if (mounted) setState(() => _flights.remove(f));
      },
      builder: (_, v, _) {
        final ms = v * total;
        var pos = f.from;
        var angle = 0.0;
        if (ms >= f.delayMs) {
          final t = ((ms - f.delayMs) / _flyMs).clamp(0.0, 1.0);
          final e = Curves.easeInOut.transform(t);
          pos = Offset.lerp(f.from, f.to, e)! - Offset(0, math.sin(math.pi * e) * (r * 1.1 + len * 0.15));
          angle = math.pi * e;
        }
        return Positioned(
          left: pos.dx - r,
          top: pos.dy - r,
          width: r * 2,
          height: r * 2,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0015)
              ..rotateY(angle * nx)
              ..rotateX(-angle * ny),
            child: CustomPaint(painter: HsTilePainter(hsColor(f.color), r)),
          ),
        );
      },
    );
  }

  Widget _offersRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: GlassCard(
        blur: 0,
        radius: 24,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: SizedBox(
          height: 92,
          child: Row(children: [
            for (var i = 0; i < kHsOffers; i++) Expanded(child: _offerSlot(i)),
          ]),
        ),
      ),
    );
  }

  Widget _offerSlot(int i) {
    final tiles = _g.offers[i];
    return LayoutBuilder(builder: (context, c) {
      final r = math.min(26.0, math.min(c.maxWidth / 2.4, c.maxHeight / 3.4));
      if (tiles == null) {
        return Center(
          child: CustomPaint(
            size: Size(r * 2, r * 2),
            painter: _EmptySlotPainter(r),
          ),
        );
      }
      final selected = _selected == i && !_g.over;
      final dragging = _dragOffer == i;
      final stack = CustomPaint(
        size: Size(r * 2.2, c.maxHeight - 8),
        painter: HsStackPainter(tiles: tiles, r: r, glow: selected ? tiles.last : null),
      );
      return GestureDetector(
        key: ValueKey('hs_offer_$i'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _selectOffer(i),
        onPanStart: (d) => _dragStart(i, d.globalPosition),
        onPanUpdate: (d) => _dragUpdate(d.globalPosition),
        onPanEnd: (_) => _dragEnd(),
        onPanCancel: _dragEnd,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 120),
            opacity: dragging ? 0.25 : 1,
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              offset: Offset(0, selected ? -0.06 : 0),
              child: stack,
            ),
          ),
        ).animate(key: ValueKey('offer$i-$_offerSerial')).fadeIn(duration: 220.ms, delay: (i * 70).ms).scale(
            begin: const Offset(0.5, 0.5),
            end: const Offset(1, 1),
            duration: 380.ms,
            delay: (i * 70).ms,
            curve: Curves.easeOutBack),
      );
    });
  }

  Widget _dragGhost() {
    final tiles = _g.offers[_dragOffer!];
    final p = _rootLocal(_dragPos!);
    if (tiles == null || p == null) return const SizedBox.shrink();
    final r = _geo?.r ?? 24;
    final h = r * 2 + hsThickness(r, tiles.length) * tiles.length;
    final base = p - Offset(0, _dragLift);
    return Positioned(
      left: base.dx - r * 1.1,
      top: base.dy + r - h,
      width: r * 2.2,
      height: h,
      child: IgnorePointer(
        child: CustomPaint(painter: HsStackPainter(tiles: tiles, r: r, glow: tiles.last)),
      ),
    );
  }
}

class _EmptySlotPainter extends CustomPainter {
  _EmptySlotPainter(this.r);
  final double r;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      hexPath(size.center(Offset.zero), r * 0.85, squash: 0.82),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  @override
  bool shouldRepaint(_EmptySlotPainter old) => old.r != r;
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap, this.big = false, this.trailing});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool big;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null && big;
    return Opacity(
      opacity: off ? 0.5 : 1,
      child: GlassCard(
        blur: 0,
        radius: 30,
        padding: EdgeInsets.symmetric(horizontal: big ? 16 : 10, vertical: big ? 11 : 9),
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: big ? 20 : 16, color: off ? Pal.textDim : hsAccentHot),
          const SizedBox(width: 6),
          Flexible(
            child: Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: off ? Pal.textDim : Pal.text, fontWeight: FontWeight.w700, fontSize: big ? 14 : 13)),
          ),
          if (trailing != null) ...[const SizedBox(width: 4), Text(trailing!, style: const TextStyle(fontSize: 13))],
        ]),
      ),
    );
  }
}
