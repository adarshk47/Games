import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/screw_jam_logic.dart';
import 'progress.dart';
import 'screw_art.dart';

const _kFreeHints = 2;
const _boxW = 92.0, _boxH = 54.0;

/// A screw flying across the screen (unscrew -> box/tray, tray -> box).
class _Flight {
  _Flight(this.serial, this.screw, this.from, this.to, this.color, this.delayMs, this.durMs, this.spin, this.r0, this.r1);
  final int serial, screw;
  final Offset from, to;
  final Color color;
  final int delayMs, durMs;
  final bool spin;
  final double r0, r1;
}

/// A full toolbox leaving its slot.
class _Ghost {
  _Ghost(this.serial, this.slot, this.color, this.screws, this.appearMs, this.leaveMs);
  final int serial, slot;
  final int color;
  final List<int> screws;
  final int appearMs, leaveMs;
}

/// A plate falling off the board.
class _Fall {
  _Fall(this.serial, this.plate, this.dir);
  final int serial;
  final SjPlate plate;
  final double dir;
}

/// One Screw Jam level.
class ScrewJamGame extends StatefulWidget {
  const ScrewJamGame({super.key, required this.tier, required this.level});
  final SjTier tier;
  final int level;

  @override
  State<ScrewJamGame> createState() => _ScrewJamGameState();
}

class _ScrewJamGameState extends State<ScrewJamGame> {
  late int _level;
  late SjGame _g;
  final _rootKey = GlobalKey();
  final _boardKey = GlobalKey();
  final _slotKeys = [for (var i = 0; i < kSjSlots; i++) GlobalKey()];
  final List<GlobalKey> _trayKeys = [];
  final List<_Flight> _flights = [];
  final List<_Ghost> _ghosts = [];
  final List<_Fall> _falls = [];
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

  SjTier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    final l = widget.level.clamp(1, kSjLevels);
    _load(SjProgress.canPlay(_tier, l) ? l : SjProgress.unlocked(_tier));
    SjProgress.start(_tier, _level);
  }

  void _load(int level) {
    _level = level;
    SjProgress.setCurrent(_tier, level);
    _g = SjGame(sjGenerate(_tier, level));
    _epoch++;
    _flights.clear();
    _ghosts.clear();
    _falls.clear();
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
    if (!SjProgress.canPlay(_tier, _level)) {
      _playsOver();
      return;
    }
    AppAudio.play(Sound.tap);
    SjProgress.start(_tier, _level);
    setState(() => _load(_level));
  }

  void _playsOver() {
    AppAudio.play(Sound.fail);
    showPremiumDialog(
      context,
      title: tr('common.skip.title', {'n': _level}),
      message: tr('screw_jam.plays_over'),
      emoji: '🔒',
      color: Pal.gold,
      actions: [DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop(), primary: true)],
    );
  }

  void _next() {
    setState(() => _load(_level + 1));
    SjProgress.start(_tier, _level);
  }

  /// Runs [f] after [ms] if the same level attempt is still on screen.
  void _later(int ms, VoidCallback f) {
    final e = _epoch;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && e == _epoch) f();
    });
  }

  GlobalKey _trayKey(int i) {
    while (_trayKeys.length <= i) {
      _trayKeys.add(GlobalKey());
    }
    return _trayKeys[i];
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

  Offset? _screwPos(int id) {
    final s = _g.level.screws[id];
    return _toRoot(_boardKey, Offset((s.c + 0.5) * _cell, (s.r + 0.5) * _cell));
  }

  Offset? _boxHole(int slot, int i) {
    final k = _slotKeys[slot];
    final size = _sizeOf(k);
    if (size == null || i < 0) return null;
    return _toRoot(k, Offset(size.width * sjBoxHoleX[i.clamp(0, 2)], size.height * sjBoxHoleY));
  }

  Offset? _trayHole(int i) {
    final k = _trayKey(i);
    final size = _sizeOf(k);
    if (size == null) return null;
    return _toRoot(k, size.center(Offset.zero));
  }

  double get _boardR => PlatePainter.screwRadius(_cell);
  double get _boxR => _boxH * 0.2;
  double get _trayR {
    final s = _sizeOf(_trayKey(0));
    return s == null ? 14 : s.width * 0.42;
  }

  // ---- play ---------------------------------------------------------------

  void _flash(String text) {
    final s = ++_toastSerial;
    setState(() => _toast = text);
    _later(1500, () {
      if (_toastSerial == s) setState(() => _toast = null);
    });
  }

  void _tap(int id) {
    if (_busy || _won || _g.over || _g.removed.contains(id)) return;
    if (!_g.canTap(id)) {
      AppAudio.play(Sound.fail);
      AppAudio.haptic();
      setState(() {
        _shake = id;
        _shakeSerial++;
      });
      _flash(tr('screw_jam.blocked'));
      return;
    }
    final from = _screwPos(id);
    final trayBefore = [for (var i = 0; i < _g.trayCapacity; i++) _trayHole(i)];
    final m = _g.tap(id)!;
    AppAudio.play(Sound.pop);
    AppAudio.haptic();
    setState(() {
      _hint = null;
      final screws = _g.level.screws;
      // Which box (by queue index) ended up holding a screw, per completion.
      List<int> screwsOfArrival(int slot, int k) {
        for (var j = k + 1; j < m.completed.length; j++) {
          if (m.completed[j].$1 == slot) return m.completed[j].$4;
        }
        return _g.slots[slot]?.screws ?? const [];
      }

      int? qiOfArrival(int slot, int k) {
        for (var j = k + 1; j < m.completed.length; j++) {
          if (m.completed[j].$1 == slot) return m.completed[j].$3;
        }
        return _g.slots[slot]?.queueIndex;
      }

      // Main flight.
      Offset? to;
      double r1;
      if (m.boxSlot != null) {
        final slot = m.boxSlot!;
        final k = m.completed.indexWhere((c) => c.$4.contains(id));
        final list = k >= 0 ? m.completed[k].$4 : _g.slots[slot]!.screws;
        to = _boxHole(slot, list.indexOf(id));
        r1 = _boxR;
      } else {
        to = _trayHole(m.trayIndex);
        r1 = _trayR;
      }
      _fly(id, from, to, sjColor(screws[id].color), 0, 620, true, _boardR, r1);

      // Boxes leaving / arriving.
      for (var k = 0; k < m.completed.length; k++) {
        final (slot, color, _, inside) = m.completed[k];
        final prev = m.completed.sublist(0, k).lastIndexWhere((c) => c.$1 == slot);
        final appear = prev < 0 ? 0 : 700 + prev * 700;
        final leave = 640 + k * 700;
        _ghosts.add(_Ghost(++_serial, slot, color, inside, appear, leave));
        final gs = _serial;
        _later(leave + 450, () => setState(() => _ghosts.removeWhere((g) => g.serial == gs)));
        final qi = qiOfArrival(slot, k);
        if (qi != null) _arrivalDelay[qi] = 700 + k * 700;
        _later(leave, () => AppAudio.play(Sound.success));
      }
      for (final (t, ti, slot, k) in m.fromTray) {
        final list = screwsOfArrival(slot, k);
        _fly(t, ti >= 0 && ti < trayBefore.length ? trayBefore[ti] : null, _boxHole(slot, list.indexOf(t)),
            sjColor(screws[t].color), 900 + k * 700, 380, false, _trayR, _boxR);
      }

      // Plates falling.
      for (final p in m.fallen) {
        final f = _Fall(++_serial, _g.level.plates[p], p.isEven ? 1 : -1);
        _falls.add(f);
        _later(1500, () => setState(() => _falls.remove(f)));
        _later(250, () => AppAudio.play(Sound.slide));
      }
    });
    if (_g.won) {
      _onWin();
    } else if (_g.lost) {
      _onLost();
    }
  }

  void _fly(int screw, Offset? from, Offset? to, Color color, int delay, int dur, bool spin, double r0, double r1) {
    if (from == null || to == null) return;
    _inFlight.add(screw);
    _flights.add(_Flight(++_serial, screw, from, to, color, delay, dur, spin, r0, r1));
  }

  void _land(_Flight f) {
    if (!mounted) return;
    setState(() {
      _flights.remove(f);
      if (!_flights.any((o) => o.screw == f.screw)) _inFlight.remove(f.screw);
    });
  }

  void _onWin() {
    _won = true;
    final stars = sjStars(peakTray: _g.peakTray, trayCapacity: _g.level.trayCapacity, continues: _continues);
    SjProgress.complete(_tier, _level, stars);
    Rewards.onLevelComplete('screw_jam', '${_tier.id}-L$_level', stars: stars);
    _later(1100, () => _showWin(stars));
  }

  void _showWin(int stars) {
    final last = _level >= kSjLevels;
    showPremiumDialog(
      context,
      title: tr('common.level_complete'),
      message: [
        tr('screw_jam.win_msg', {'moves': _g.moves}),
        if (last) tr('screw_jam.tier_done'),
      ].join('\n'),
      emoji: '🔩',
      color: sjAccentHot,
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

  void _onLost() {
    _busy = true;
    AppAudio.play(Sound.fail);
    AppAudio.haptic();
    _later(750, () async {
      if (_g.canAddSlot) {
        final paid = await showContinueOffer(context, OfferKind.extraLife);
        if (!mounted) return;
        if (paid) {
          AppAudio.play(Sound.success);
          setState(() {
            _g.addTraySlot();
            _continues++;
            _busy = false;
          });
          return;
        }
      }
      if (!mounted) return;
      showPremiumDialog(
        context,
        title: tr('screw_jam.tray_full'),
        message: tr('screw_jam.tray_full_msg'),
        emoji: '🧰',
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
    setState(() => _hint = sjHint(_g, maxNodes: 4000));
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final freeHints = math.max(0, _kFreeHints - _hintsUsed);
    return GameScaffold(
      title: tr('screw_jam.title'),
      tint: sjAccent,
      body: Stack(
        key: _rootKey,
        children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  _Pill(
                    icon: Icons.grid_view_rounded,
                    label: '${sjTierName(_tier)} · ${tr('common.level_n', {'n': _level})}',
                    onTap: () => Navigator.of(context).maybePop(),
                  ),
                  _Pill(icon: Icons.inventory_2_rounded, label: tr('screw_jam.boxes_left', {'n': _g.boxesLeft})),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _boxesRow(),
            Expanded(child: _board()),
            _trayRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 8,
                children: [
                  _Pill(icon: Icons.refresh_rounded, label: tr('common.restart'), onTap: _restart, big: true),
                  _Pill(
                    icon: Icons.lightbulb_rounded,
                    label: freeHints > 0
                        ? '${tr('common.hint')} · ${tr('screw_jam.free_n', {'n': freeHints})}'
                        : tr('common.hint'),
                    trailing: freeHints > 0 ? null : '🪙',
                    onTap: _g.over || _won ? null : _useHint,
                    big: true,
                  ),
                ],
              ),
            ),
          ]),
          Positioned.fill(
            child: IgnorePointer(
              child: Stack(clipBehavior: Clip.none, children: [for (final f in _flights) _flightView(f)]),
            ),
          ),
          if (_toast != null)
            Positioned(
              bottom: 140,
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

  Widget _flightView(_Flight f) {
    return TweenAnimationBuilder<double>(
      key: ValueKey('fl${f.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: f.delayMs + f.durMs),
      onEnd: () => _land(f),
      builder: (_, v, _) {
        final total = (f.delayMs + f.durMs).toDouble();
        final ms = v * total;
        var pos = f.from;
        var r = f.r0;
        var angle = 0.0;
        if (ms >= f.delayMs) {
          final t = ((ms - f.delayMs) / f.durMs).clamp(0.0, 1.0);
          if (f.spin) {
            final lift = f.r0 * 1.2;
            if (t < 0.35) {
              final p = Curves.easeOut.transform(t / 0.35);
              pos = f.from - Offset(0, lift * p);
              r = f.r0 * (1 + 0.3 * p);
              angle = -p * math.pi * 4;
            } else {
              final q = (t - 0.35) / 0.65;
              final e = Curves.easeInOutCubic.transform(q);
              final start = f.from - Offset(0, lift);
              pos = Offset.lerp(start, f.to, e)! - Offset(0, math.sin(math.pi * e) * 40);
              r = f.r0 * 1.3 + (f.r1 - f.r0 * 1.3) * e;
              angle = -math.pi * 4 - e * math.pi * 2;
            }
          } else {
            final e = Curves.easeInOut.transform(t);
            pos = Offset.lerp(f.from, f.to, e)! - Offset(0, math.sin(math.pi * e) * 24);
            r = f.r0 + (f.r1 - f.r0) * e;
            angle = e * math.pi;
          }
        }
        final size = r * 2 / 0.92;
        return Positioned(
          left: pos.dx - size / 2,
          top: pos.dy - size / 2,
          width: size,
          height: size,
          child: ScrewIcon(color: f.color, size: size, angle: angle),
        );
      },
    );
  }

  List<Color?> _filled(List<int> screws) => [
        for (var i = 0; i < kSjBoxSize; i++)
          i < screws.length && !_inFlight.contains(screws[i]) ? sjColor(_g.level.screws[screws[i]].color) : null,
      ];

  Widget _boxView(int color, List<int> screws) => CustomPaint(
        size: const Size(_boxW, _boxH),
        painter: ToolboxPainter(color: sjColor(color), filled: _filled(screws)),
      );

  Widget _boxesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < kSjSlots; i++) ...[
          if (i > 0) const SizedBox(width: 18),
          SizedBox(
            key: _slotKeys[i],
            width: _boxW,
            height: _boxH,
            child: Stack(clipBehavior: Clip.none, children: [
              if (_g.slots[i] == null)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Pal.glassBorder),
                      color: Colors.white.withValues(alpha: 0.04),
                    ),
                    child: const Icon(Icons.check_rounded, color: Pal.success),
                  ),
                )
              else
                _boxView(_g.slots[i]!.color, _g.slots[i]!.screws)
                    .animate(key: ValueKey('box${_g.slots[i]!.queueIndex}-$_epoch'))
                    .fadeIn(delay: (_arrivalDelay[_g.slots[i]!.queueIndex] ?? 0).ms, duration: 250.ms)
                    .slideX(
                        delay: (_arrivalDelay[_g.slots[i]!.queueIndex] ?? 0).ms,
                        begin: 1.4,
                        end: 0,
                        duration: 380.ms,
                        curve: Curves.easeOutBack),
              for (final g in _ghosts)
                if (g.slot == i)
                  _boxView(g.color, g.screws)
                      .animate(key: ValueKey('ghost${g.serial}'))
                      .fadeIn(delay: g.appearMs.ms, duration: (g.appearMs == 0 ? 1 : 200).ms)
                      .then(delay: math.max(0, g.leaveMs - g.appearMs).ms)
                      .scale(begin: const Offset(1, 1), end: const Offset(1.12, 1.12), duration: 120.ms)
                      .then()
                      .moveY(begin: 0, end: -70, duration: 320.ms, curve: Curves.easeIn)
                      .fadeOut(duration: 320.ms),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _board() {
    final lv = _g.level;
    return LayoutBuilder(builder: (context, c) {
      final cell = math.min(56.0, math.min((c.maxWidth - 28) / (lv.cols + 0.5), (c.maxHeight - 12) / (lv.rows + 0.5)));
      _cell = math.max(8.0, cell);
      final cs = _cell;
      final w = lv.cols * cs, h = lv.rows * cs;
      return Center(
        child: CustomPaint(
          painter: BoardPainter(cs),
          child: Padding(
            padding: EdgeInsets.all(cs * 0.25),
            child: SizedBox(
              key: _boardKey,
              width: w,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                for (final p in lv.plates)
                  if (!_g.fallen.contains(p.id)) _plateAt(p, cs),
                for (final f in _falls) _fallingPlate(f, cs, h),
                for (final s in lv.screws)
                  if (!_g.removed.contains(s.id)) _hitTarget(s, cs),
              ]),
            ),
          ),
        ),
      );
    });
  }

  Widget _plateView(SjPlate p, double cs) {
    final ids = _g.level.plateScrews[p.id];
    return CustomPaint(
      painter: PlatePainter(
        plate: p,
        cell: cs,
        screws: [for (final i in ids) _g.level.screws[i]],
        removed: {for (final i in ids) if (_g.removed.contains(i)) i},
      ),
    );
  }

  Widget _plateAt(SjPlate p, double cs) {
    final b = p.bounds;
    return Positioned(
      key: ValueKey('plate${p.id}-$_epoch'),
      left: b.c * cs,
      top: b.r * cs,
      width: b.w * cs,
      height: b.h * cs,
      child: IgnorePointer(child: _plateView(p, cs)),
    );
  }

  Widget _fallingPlate(_Fall f, double cs, double boardH) {
    final b = f.plate.bounds;
    return Positioned(
      key: ValueKey('fall${f.serial}'),
      left: b.c * cs,
      top: b.r * cs,
      width: b.w * cs,
      height: b.h * cs,
      child: IgnorePointer(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1250),
          builder: (_, v, child) {
            // Short wobble on the last hinge, then a gravity drop with spin.
            const hold = 0.22;
            if (v < hold) {
              final w = math.sin(v / hold * math.pi * 3) * 0.05 * f.dir;
              return Transform.rotate(angle: w, child: child);
            }
            final t = (v - hold) / (1 - hold);
            final dy = t * t * (boardH + 200);
            final dx = f.dir * t * cs * 1.5;
            return Opacity(
              opacity: (1.0 - ((t - 0.55) / 0.45).clamp(0.0, 1.0)).toDouble(),
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.rotate(angle: f.dir * t * 1.1, child: Transform.scale(scale: 1 + t * 0.15, child: child)),
              ),
            );
          },
          child: _plateView(f.plate, cs),
        ),
      ),
    );
  }

  Widget _hitTarget(SjScrew s, double cs) {
    final hinted = _hint == s.id;
    final shaking = _shake == s.id;
    return Positioned(
      left: s.c * cs,
      top: s.r * cs,
      width: cs,
      height: cs,
      child: GestureDetector(
        key: ValueKey('sj_screw_${s.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(s.id),
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
                  .scale(begin: const Offset(0.85, 0.85), end: const Offset(1.2, 1.2), duration: 550.ms),
            ),
          if (shaking)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Pal.danger, width: 2.5),
                ),
              )
                  .animate(key: ValueKey('shake$_shakeSerial'))
                  .shake(hz: 6, duration: 400.ms)
                  .then()
                  .fadeOut(duration: 250.ms),
            ),
        ]),
      ),
    );
  }

  Widget _trayRow() {
    final cap = _g.trayCapacity;
    final danger = _g.tray.length >= cap - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF555B70), Color(0xFF2E3242)],
          ),
          border: Border.all(color: danger ? Pal.danger : Colors.white.withValues(alpha: 0.25), width: danger ? 2 : 1),
          boxShadow: [
            if (danger) BoxShadow(color: Pal.danger.withValues(alpha: 0.5), blurRadius: 16),
            const BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Row(children: [
          const Icon(Icons.handyman_rounded, color: Pal.textDim, size: 18),
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 56),
            child: Text(
              '${tr('screw_jam.tray')} ${_g.tray.length}/$cap',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: danger ? Pal.danger : Pal.textDim, fontSize: 11, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final s = math.min(34.0, c.maxWidth / cap);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < cap; i++)
                    SizedBox(
                      key: _trayKey(i),
                      width: s,
                      height: 34,
                      child: Center(
                        child: Container(
                          width: s * 0.84,
                          height: s * 0.84,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(0.3, 0.4),
                              colors: [Color(0xFF2A2420), Color(0xFF0D0A08)],
                            ),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                          ),
                          child: i < _g.tray.length && !_inFlight.contains(_g.tray[i])
                              ? ScrewIcon(color: sjColor(_g.level.screws[_g.tray[i]].color), size: s * 0.84)
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
        padding: EdgeInsets.symmetric(horizontal: big ? 16 : 12, vertical: big ? 11 : 7),
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: big ? 20 : 16, color: off ? Pal.textDim : sjAccentHot),
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
