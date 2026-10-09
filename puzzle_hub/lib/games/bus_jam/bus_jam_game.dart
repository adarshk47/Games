import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'bus_art.dart';
import 'logic/bus_jam_logic.dart';
import 'progress.dart';

const _kFreeHints = 2;

/// A passenger walking across the screen (grid -> bus / waiting, waiting -> bus).
class _Walk {
  _Walk(this.serial, this.id, this.points, this.delayMs, this.durMs, this.s0, this.s1);
  final int serial, id;
  final List<Offset> points;
  final int delayMs, durMs;
  final double s0, s1;
}

/// A full bus leaving the stop.
class _Ghost {
  _Ghost(this.serial, this.bus, this.color, this.riders, this.appearMs, this.leaveMs);
  final int serial, bus, color;
  final List<int> riders;
  final int appearMs, leaveMs;
}

/// One Bus Jam level.
class BusJamGame extends StatefulWidget {
  const BusJamGame({super.key, required this.tier, required this.level});
  final BjTier tier;
  final int level;

  @override
  State<BusJamGame> createState() => _BusJamGameState();
}

class _BusJamGameState extends State<BusJamGame> {
  late int _level;
  late BjGame _g;
  final _rootKey = GlobalKey();
  final _boardKey = GlobalKey();
  final _busKey = GlobalKey();
  final List<GlobalKey> _slotKeys = [];
  final List<_Walk> _walks = [];
  final List<_Ghost> _ghosts = [];
  final Set<int> _inFlight = {};
  final Map<int, int> _arrivalDelay = {};
  int _serial = 0;
  int _epoch = 0;
  int? _hint;
  int _hintsUsed = 0;
  int _continues = 0;
  bool _busy = false;
  bool _won = false;
  String? _toast;
  int _toastSerial = 0;
  int _shake = -1;
  int _shakeSerial = 0;
  double _cell = 30;

  BjTier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    final l = widget.level.clamp(1, kBjLevels);
    _load(BjProgress.canPlay(_tier, l) ? l : BjProgress.unlocked(_tier));
    BjProgress.start(_tier, _level);
  }

  void _load(int level) {
    _level = level;
    BjProgress.setCurrent(_tier, level);
    _g = BjGame(bjGenerate(_tier, level));
    _epoch++;
    _walks.clear();
    _ghosts.clear();
    _inFlight.clear();
    _arrivalDelay.clear();
    _hint = null;
    _hintsUsed = 0;
    _continues = 0;
    _busy = false;
    _won = false;
    _toast = null;
    _shake = -1;
  }

  /// Restart / replay / try again: each one counts as a play of a bought
  /// level; when its plays are used up the level locks again.
  void _restart() {
    if (!BjProgress.canPlay(_tier, _level)) {
      _playsOver();
      return;
    }
    AppAudio.play(Sound.tap);
    BjProgress.start(_tier, _level);
    setState(() => _load(_level));
  }

  void _playsOver() {
    AppAudio.play(Sound.fail);
    showPremiumDialog(
      context,
      title: tr('common.skip.title', {'n': _level}),
      message: tr('bus_jam.plays_over'),
      emoji: '🔒',
      color: Pal.gold,
      actions: [DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop(), primary: true)],
    );
  }

  void _next() {
    setState(() => _load(_level + 1));
    BjProgress.start(_tier, _level);
  }

  /// Runs [f] after [ms] if the same level attempt is still on screen.
  void _later(int ms, VoidCallback f) {
    final e = _epoch;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && e == _epoch) f();
    });
  }

  GlobalKey _slotKey(int i) {
    while (_slotKeys.length <= i) {
      _slotKeys.add(GlobalKey());
    }
    return _slotKeys[i];
  }

  // ---- geometry -----------------------------------------------------------

  Offset? _toRoot(GlobalKey k, Offset local) {
    final box = k.currentContext?.findRenderObject();
    final root = _rootKey.currentContext?.findRenderObject();
    if (box is! RenderBox || root is! RenderBox || !box.attached || !root.attached) return null;
    return root.globalToLocal(box.localToGlobal(local));
  }

  Size? _sizeOf(GlobalKey k) {
    final box = k.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : null;
  }

  Offset? _cellPos(int cell) {
    final lv = _g.level;
    return _toRoot(_boardKey, Offset((lv.colOf(cell) + 0.5) * _cell, (lv.rowOf(cell) + 0.5) * _cell));
  }

  Offset? _slotPos(int i) {
    final k = _slotKey(i);
    final s = _sizeOf(k);
    return s == null ? null : _toRoot(k, s.center(Offset.zero));
  }

  double get _slotSize => (_sizeOf(_slotKey(0))?.height ?? 36) * 0.9;

  Offset? _seatPos(int seat) {
    final s = _sizeOf(_busKey);
    if (s == null) return null;
    return _toRoot(_busKey, Offset(s.width * BusPainter.seatX[seat.clamp(0, 2)], s.height * BusPainter.seatY));
  }

  double get _seatSize => (_sizeOf(_busKey)?.height ?? 60) * 0.4;

  // ---- play ---------------------------------------------------------------

  void _flash(String text) {
    final s = ++_toastSerial;
    setState(() => _toast = text);
    _later(1500, () {
      if (_toastSerial == s) setState(() => _toast = null);
    });
  }

  int _walkMs(List<Offset> pts) {
    var len = 0.0;
    for (var i = 1; i < pts.length; i++) {
      len += (pts[i] - pts[i - 1]).distance;
    }
    return (len / 0.55).clamp(320, 1150).round();
  }

  void _addWalk(int id, List<Offset?> pts, int delay, double s0, double s1, {int? dur}) {
    if (pts.any((p) => p == null)) return;
    final points = pts.cast<Offset>();
    _inFlight.add(id);
    _walks.add(_Walk(++_serial, id, points, delay, dur ?? _walkMs(points), s0, s1));
  }

  void _tap(int id) {
    if (_busy || _won || _g.over || !_g.onGrid(id)) return;
    if (!_g.canTap(id)) {
      AppAudio.play(Sound.fail);
      AppAudio.haptic();
      setState(() {
        _shake = id;
        _shakeSerial++;
      });
      _flash(tr('bus_jam.blocked'));
      return;
    }
    final slotsBefore = [for (var i = 0; i < _g.waiting.length; i++) _slotPos(i)];
    final m = _g.tap(id)!;
    AppAudio.play(Sound.pop);
    AppAudio.haptic();
    var end = 0;
    setState(() {
      _hint = null;
      // Riders of bus [b] as they end up (departed or still at the stop).
      List<int> ridersOf(int b) {
        for (final d in m.departures) {
          if (d.bus == b) return d.riders;
        }
        return _g.seated;
      }

      // Walk out along the BFS path, then to the bus or a waiting spot.
      final pts = <Offset?>[for (final c in m.path) _cellPos(c)];
      final top = pts.last;
      if (top != null) pts.add(top - Offset(0, _cell * 0.9));
      if (m.boarded) {
        pts.add(_seatPos(ridersOf(m.bus).indexOf(id)));
      } else {
        pts.add(_slotPos(m.waitIndex));
      }
      final s1 = m.boarded ? _seatSize : _slotSize;
      _addWalk(id, pts, 0, _cell * 0.95, s1);
      final t = pts.any((p) => p == null) ? 300 : _walkMs(pts.cast<Offset>());
      end = t;

      // Buses leaving and arriving.
      final arrive = <int>[];
      for (var k = 0; k < m.departures.length; k++) {
        final d = m.departures[k];
        final appear = k == 0 ? 0 : arrive[k - 1];
        final leave = k == 0 ? t + 150 : arrive[k - 1] + 850;
        _ghosts.add(_Ghost(++_serial, d.bus, d.color, d.riders, appear, leave));
        final gs = _serial;
        _later(leave + 700, () => setState(() => _ghosts.removeWhere((g) => g.serial == gs)));
        _later(leave, () => AppAudio.play(Sound.success));
        arrive.add(leave + 450);
        _arrivalDelay[d.bus + 1] = leave + 450;
        end = math.max(end, leave + 650);
      }
      for (final a in m.autoBoard) {
        final k = m.departures.indexWhere((d) => d.bus + 1 == a.bus);
        final start = (k >= 0 ? arrive[k] : t) + 120;
        final from = a.fromIndex >= 0 && a.fromIndex < slotsBefore.length ? slotsBefore[a.fromIndex] : null;
        _addWalk(a.id, [from, _seatPos(ridersOf(a.bus).indexOf(a.id))], start, _slotSize, _seatSize, dur: 420);
        end = math.max(end, start + 420);
      }
      if (m.spawned.isNotEmpty) _later(150, () => AppAudio.play(Sound.flip));
    });
    if (_g.won) {
      _onWin(end);
    } else if (_g.lost) {
      _onLost(end);
    }
  }

  void _land(_Walk w) {
    if (!mounted) return;
    setState(() {
      _walks.remove(w);
      if (!_walks.any((o) => o.id == w.id)) _inFlight.remove(w.id);
    });
  }

  void _onWin(int afterMs) {
    _won = true;
    final stars = bjStars(peakWaiting: _g.peakWaiting, capacity: _g.level.waiting, continues: _continues);
    BjProgress.complete(_tier, _level, stars);
    Rewards.onLevelComplete('bus_jam', '${_tier.id}-L$_level', stars: stars);
    _later(afterMs + 400, () {
      AppAudio.play(Sound.win);
      _showWin(stars);
    });
  }

  void _showWin(int stars) {
    final last = _level >= kBjLevels;
    showPremiumDialog(
      context,
      title: tr('common.level_complete'),
      message: [
        tr('bus_jam.win_msg', {'moves': _g.moves}),
        if (last) tr('bus_jam.tier_done'),
      ].join('\n'),
      emoji: '🚌',
      color: bjAccentHot,
      stars: stars,
      actions: [
        DialogAction(tr('common.replay'), _restart),
        if (last)
          DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop(), primary: true)
        else
          DialogAction(tr('common.next_level'), _next, primary: true),
      ],
    );
  }

  void _onLost(int afterMs) {
    _busy = true;
    AppAudio.play(Sound.fail);
    AppAudio.haptic();
    _later(afterMs + 300, () async {
      if (_g.canAddSlot) {
        final paid = await showContinueOffer(context, OfferKind.extraLife);
        if (!mounted) return;
        if (paid) {
          AppAudio.play(Sound.success);
          setState(() {
            _g.addSlot();
            _continues++;
            _busy = false;
          });
          return;
        }
      }
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: tr('bus_jam.wait_full'),
        message: tr('bus_jam.wait_full_msg'),
        emoji: '🪑',
        color: Pal.danger,
        actions: [
          DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop()),
          DialogAction(tr('common.try_again'), _restart, primary: true),
        ],
      );
    });
  }

  Future<void> _useHint() async {
    if (_busy || _won || _g.over) return;
    if (_hintsUsed >= _kFreeHints) {
      _busy = true;
      final paid = await showContinueOffer(context, OfferKind.hint);
      _busy = false;
      if (!mounted || !paid || _g.over) return;
    } else {
      _hintsUsed++;
    }
    AppAudio.play(Sound.pop);
    setState(() => _hint = bjHint(_g));
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final freeHints = math.max(0, _kFreeHints - _hintsUsed);
    return GameScaffold(
      title: tr('bus_jam.title'),
      tint: bjAccent,
      body: Stack(
        key: _rootKey,
        children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: _Pill(
                      icon: Icons.grid_view_rounded,
                      label: '${bjTierName(_tier)} · ${tr('common.level_n', {'n': _level})}',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: _Pill(icon: Icons.directions_bus_rounded, label: tr('bus_jam.buses_left', {'n': _g.busesLeft})),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            _busStop(),
            _waitingRow(),
            Expanded(child: _board()),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: _Pill(icon: Icons.refresh_rounded, label: tr('common.restart'), onTap: _restart, big: true)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: _Pill(
                    icon: Icons.lightbulb_rounded,
                    label: freeHints > 0
                        ? '${tr('common.hint')} · ${tr('bus_jam.free_n', {'n': freeHints})}'
                        : tr('common.hint'),
                    trailing: freeHints > 0 ? null : '🪙',
                      onTap: _g.over || _won ? null : _useHint,
                      big: true,
                    ),
                  ),
                ],
              ),
            ),
          ]),
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(clipBehavior: Clip.none, children: [for (final w in _walks) _walkView(w)]),
            ),
          ),
          if (_toast != null)
            Positioned(
              bottom: 70,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: GlassCard(
                    blur: 0,
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    gradient: LinearGradient(colors: [
                      Pal.danger.withValues(alpha: 0.85),
                      const Color(0xFF8A2340).withValues(alpha: 0.9),
                    ]),
                    child: Text(_toast!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                  ),
                ).animate(key: ValueKey(_toastSerial)).fadeIn(duration: 150.ms).slideY(begin: -0.3, end: 0),
              ),
            ),
        ],
      ),
    );
  }

  Widget _walkView(_Walk w) {
    final pts = w.points;
    final segs = <double>[0];
    for (var i = 1; i < pts.length; i++) {
      segs.add(segs.last + (pts[i] - pts[i - 1]).distance);
    }
    final total = math.max(1.0, segs.last);
    final color = bjColor(_g.colorOf(w.id));
    return TweenAnimationBuilder<double>(
      key: ValueKey('walk${w.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: w.delayMs + w.durMs),
      onEnd: () => _land(w),
      builder: (_, v, _) {
        final ms = v * (w.delayMs + w.durMs);
        final t = ms < w.delayMs ? 0.0 : ((ms - w.delayMs) / w.durMs).clamp(0.0, 1.0);
        final d = Curves.easeInOut.transform(t) * total;
        var i = 1;
        while (i < pts.length - 1 && segs[i] < d) {
          i++;
        }
        final a = pts[i - 1], b = pts[pts.length > 1 ? i : 0];
        final segLen = math.max(0.001, segs[i] - segs[i - 1]);
        final f = ((d - segs[i - 1]) / segLen).clamp(0.0, 1.0);
        final p = Offset.lerp(a, b, f)!;
        final dir = b - a;
        final facing = dir.distance < 0.5 ? 0.0 : math.atan2(dir.dx, -dir.dy);
        final size = w.s0 + (w.s1 - w.s0) * (t * t);
        final hidden = ms < w.delayMs && w.delayMs > 0;
        return Positioned(
          left: p.dx - size / 2,
          top: p.dy - size / 2,
          width: size,
          height: size,
          child: CustomPaint(
            painter: PersonPainter(
              color: color,
              seed: w.id * 7,
              walking: t > 0 && t < 1,
              phase: d / math.max(4, _cell * 0.18),
              facing: hidden ? 0 : facing,
            ),
          ),
        );
      },
    );
  }

  List<Color?> _riderColors(List<int> riders) => [
        for (var i = 0; i < kBjSeats; i++)
          i < riders.length && !_inFlight.contains(riders[i]) ? bjColor(_g.colorOf(riders[i])) : null,
      ];

  Widget _busStop() {
    return LayoutBuilder(builder: (context, c) {
      final bw = math.min(150.0, c.maxWidth * 0.42);
      final bh = bw * 0.5;
      final qw = bw * 0.52;
      final b = _g.busIndex;
      final buses = _g.level.buses;
      return SizedBox(
        height: bh + 18,
        child: Stack(clipBehavior: Clip.none, children: [
          // Road with lane dashes.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bh * 0.5,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3B3F4E), Color(0xFF252833)],
                ),
              ),
              child: CustomPaint(painter: _LanePainter()),
            ),
          ),
          // Bus stop sign.
          Positioned(
            left: 4,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(color: const Color(0xFF2B6BFF), borderRadius: BorderRadius.circular(6)),
              child: const Icon(Icons.directions_bus_filled_rounded, size: 14, color: Colors.white),
            ),
          ),
          // Waiting buses in the queue.
          for (var i = 1; i <= 3 && b + i < buses.length; i++)
            Positioned(
              left: 14 + bw + 12 + (i - 1) * (qw + 8),
              top: bh - qw * 0.5 + 6,
              width: qw,
              height: qw * 0.5,
              child: Opacity(
                opacity: 1 - (i - 1) * 0.22,
                child: CustomPaint(painter: BusPainter(color: bjColor(buses[b + i]), riders: const [null, null, null])),
              ).animate(key: ValueKey('q${b + i}-$_epoch')).fadeIn(duration: 300.ms).slideX(begin: 0.4, end: 0),
            ),
          Positioned(
            left: 14,
            top: 6,
            width: bw,
            height: bh,
            child: Stack(clipBehavior: Clip.none, children: [
              SizedBox(
                key: _busKey,
                width: bw,
                height: bh,
                child: b < buses.length
                    ? CustomPaint(painter: BusPainter(color: bjColor(buses[b]), riders: _riderColors(_g.seated)))
                        .animate(key: ValueKey('bus$b-$_epoch'))
                        .fadeIn(delay: (_arrivalDelay[b] ?? 0).ms, duration: 200.ms)
                        .slideX(
                            delay: (_arrivalDelay[b] ?? 0).ms,
                            begin: 1.6,
                            end: 0,
                            duration: 420.ms,
                            curve: Curves.easeOutBack)
                    : null,
              ),
              for (final g in _ghosts)
                CustomPaint(
                  size: Size(bw, bh),
                  painter: BusPainter(color: bjColor(g.color), riders: _riderColors(g.riders)),
                )
                    .animate(key: ValueKey('ghost${g.serial}'))
                    .fadeIn(delay: g.appearMs.ms, duration: (g.appearMs == 0 ? 1 : 200).ms)
                    .slideX(delay: g.appearMs.ms, begin: g.appearMs == 0 ? 0 : 1.6, end: 0, duration: (g.appearMs == 0 ? 1 : 420).ms)
                    .then(delay: math.max(0, g.leaveMs - g.appearMs - (g.appearMs == 0 ? 1 : 420)).ms)
                    .shakeX(hz: 8, amount: 2, duration: 150.ms)
                    .then()
                    .moveX(begin: 0, end: -bw * 1.6, duration: 450.ms, curve: Curves.easeIn)
                    .fadeOut(duration: 450.ms),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _waitingRow() {
    final cap = _g.capacity;
    final danger = _g.waiting.length >= cap - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF4A5068), Color(0xFF2B2F3F)],
          ),
          border: Border.all(color: danger ? Pal.danger : Colors.white.withValues(alpha: 0.22), width: danger ? 2 : 1),
          boxShadow: [
            if (danger) BoxShadow(color: Pal.danger.withValues(alpha: 0.5), blurRadius: 14),
            const BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.event_seat_rounded, color: Pal.textDim, size: 16),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 60),
            child: Text(
              '${tr('bus_jam.waiting')} ${_g.waiting.length}/$cap',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: danger ? Pal.danger : Pal.textDim, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final s = math.min(38.0, c.maxWidth / cap);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cap; i++)
                    SizedBox(
                      key: _slotKey(i),
                      width: s,
                      height: 38,
                      child: Center(
                        child: Container(
                          width: s * 0.88,
                          height: s * 0.88,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(s * 0.25),
                            color: Colors.black.withValues(alpha: 0.28),
                            border: Border.all(
                                color: i >= _g.level.waiting
                                    ? Pal.gold.withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.16)),
                          ),
                          child: i < _g.waiting.length && !_inFlight.contains(_g.waiting[i])
                              ? PersonIcon(color: bjColor(_g.colorOf(_g.waiting[i])), size: s * 0.86, seed: _g.waiting[i] * 7)
                              : null,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
        ]),
      ),
    );
  }

  Widget _board() {
    final lv = _g.level;
    final open = _g.over ? const <int>{} : _g.removable.toSet();
    return LayoutBuilder(builder: (context, c) {
      final cell = math.min(54.0, math.min((c.maxWidth - 32) / (lv.cols + 0.4), (c.maxHeight - 16) / (lv.rows + 0.4)));
      _cell = math.max(8.0, cell);
      final cs = _cell;
      final pad = cs * 0.2;
      return Center(
        child: CustomPaint(
          painter: PlazaPainter(cols: lv.cols, rows: lv.rows, cell: cs),
          child: Padding(
            padding: EdgeInsets.all(pad),
            child: SizedBox(
              key: _boardKey,
              width: lv.cols * cs,
              height: lv.rows * cs,
              child: Stack(clipBehavior: Clip.none, children: [
                for (final w in lv.walls)
                  Positioned(
                    left: lv.colOf(w) * cs,
                    top: lv.rowOf(w) * cs,
                    width: cs,
                    height: cs,
                    child: IgnorePointer(child: CustomPaint(painter: PlanterPainter(w))),
                  ),
                for (final t in lv.tunnels) _tunnelView(t, cs),
                for (var cell = 0; cell < _g.grid.length; cell++)
                  if (_g.grid[cell] >= 0) _personView(_g.grid[cell], cell, cs, open.contains(_g.grid[cell])),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _tunnelView(BjTunnel t, double cs) {
    final left = _g.tunnelLeft(t.id);
    final next = left > 0 ? bjColor(_g.colorOf(t.queue[t.queue.length - left])) : null;
    return Positioned(
      left: _g.level.colOf(t.cell) * cs,
      top: _g.level.rowOf(t.cell) * cs,
      width: cs,
      height: cs,
      child: IgnorePointer(
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: CustomPaint(painter: TunnelPainter(dir: t.dir, next: next))),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: left > 0 ? const Color(0xFF1B1F2B) : Pal.success,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Text('$left',
                  style: TextStyle(color: Colors.white, fontSize: math.max(8, cs * 0.24), fontWeight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _personView(int id, int cell, double cs, bool free) {
    final lv = _g.level;
    final hinted = _hint == id;
    final shaking = _shake == id;
    return Positioned(
      key: ValueKey('pp$id-$_epoch'),
      left: lv.colOf(cell) * cs,
      top: lv.rowOf(cell) * cs,
      width: cs,
      height: cs,
      child: GestureDetector(
        key: ValueKey('bj_p_$id'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(id),
        child: Stack(clipBehavior: Clip.none, children: [
          if (hinted)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Pal.gold, width: 3),
                  boxShadow: [BoxShadow(color: Pal.gold.withValues(alpha: 0.7), blurRadius: 14, spreadRadius: 2)],
                ),
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.15, 1.15), duration: 550.ms),
            ),
          Positioned.fill(
            child: CustomPaint(painter: PersonPainter(color: bjColor(lv.passengers[id].color), seed: id * 7, dim: !free))
                .animate()
                .scale(begin: const Offset(0.4, 0.4), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOutBack),
          ),
          if (shaking)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Pal.danger, width: 2.5)),
              ).animate(key: ValueKey('shake$_shakeSerial')).shake(hz: 6, duration: 400.ms).then().fadeOut(duration: 250.ms),
            ),
        ]),
      ),
    );
  }
}

class _LanePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..strokeWidth = 2;
    for (var x = 6.0; x < size.width; x += 22) {
      canvas.drawLine(Offset(x, size.height * 0.6), Offset(x + 10, size.height * 0.6), p);
    }
    canvas.drawLine(Offset.zero, Offset(size.width, 0), Paint()
      ..color = const Color(0xFFFFD23F)
      ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_LanePainter old) => false;
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
        padding: EdgeInsets.symmetric(horizontal: big ? 16 : 12, vertical: big ? 10 : 6),
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: big ? 20 : 16, color: off ? Pal.textDim : bjAccentHot),
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
