import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/tile_match_logic.dart';
import 'progress.dart';
import 'tile_art.dart';

const _kFreeUndos = 1;
const _kFreeShuffles = 1;
const _kFlightMs = 280;
const _kBurstMs = 320;

/// A tile flying from the board into the tray.
class _Flight {
  _Flight(this.serial, this.tile, this.icon, this.from, this.to, this.s0, this.s1);
  final int serial, tile, icon;
  final Offset from, to;
  final double s0, s1;
}

/// One Tile Match level.
class TileMatchGame extends StatefulWidget {
  const TileMatchGame({super.key, required this.tier, required this.level});
  final TmTier tier;
  final int level;

  @override
  State<TileMatchGame> createState() => _TileMatchGameState();
}

class _TileMatchGameState extends State<TileMatchGame> {
  late int _level;
  late TmGame _g;
  final _rootKey = GlobalKey();
  final _boardKey = GlobalKey();
  final _trayKey = GlobalKey();
  final List<_Flight> _flights = [];
  final Set<int> _inFlight = {};
  final Map<int, int> _popIn = {};
  List<int> _shown = [];
  Set<int> _burst = {};
  int _burstSerial = 0;
  int _serial = 0;
  int _epoch = 0;
  int _shuffleSerial = 0;
  int _undos = 0;
  int _shuffles = 0;
  int _continues = 0;
  bool _busy = false;
  bool _won = false;
  String? _toast;
  int _toastSerial = 0;
  int _shake = -1;
  int _shakeSerial = 0;
  TmBoardMetrics? _m;
  double _slot = 40;

  TmTier get _tier => widget.tier;

  @override
  void initState() {
    super.initState();
    _start(widget.level.clamp(1, kTmLevels));
  }

  /// Starts (or restarts) [level]; a bought level uses up one play.
  void _start(int level) {
    LevelGate.onStart(TmProgress.prefix(_tier), TmProgress.unlocked(_tier), level);
    _load(level);
  }

  void _load(int level) {
    _level = level;
    TmProgress.setCurrent(_tier, level);
    _g = TmGame(tmGenerate(_tier, level));
    _epoch++;
    _flights.clear();
    _inFlight.clear();
    _popIn.clear();
    _shown = [];
    _burst = {};
    _shuffleSerial = 0;
    _undos = 0;
    _shuffles = 0;
    _continues = 0;
    _busy = false;
    _won = false;
    _toast = null;
    _shake = -1;
  }

  Future<void> _replay(int level) async {
    if (!TmProgress.canPlay(_tier, level)) {
      final ok = await LevelGate.buy(context,
          prefix: TmProgress.prefix(_tier), freeUpTo: TmProgress.unlocked(_tier), level: level);
      if (!mounted) return;
      if (!ok) {
        Navigator.of(context).maybePop();
        return;
      }
    }
    AppAudio.play(Sound.tap);
    setState(() => _start(level));
  }

  /// Runs [f] after [ms] if the same level attempt is still on screen.
  void _later(int ms, VoidCallback f) {
    final e = _epoch;
    Future.delayed(Duration(milliseconds: ms), () {
      if (mounted && e == _epoch) f();
    });
  }

  void _flash(String text) {
    final s = ++_toastSerial;
    setState(() => _toast = text);
    _later(1500, () {
      if (_toastSerial == s) setState(() => _toast = null);
    });
  }

  // ---- geometry -----------------------------------------------------------

  Offset? _toRoot(GlobalKey k, Offset local) {
    final box = k.currentContext?.findRenderObject();
    final root = _rootKey.currentContext?.findRenderObject();
    if (box is! RenderBox || root is! RenderBox || !box.attached || !root.attached) return null;
    return root.globalToLocal(box.localToGlobal(local));
  }

  double get _trayTile => _slot - 6;
  Offset _slotOrigin(int i) => Offset(i * _slot + 3, 3);

  // ---- play ---------------------------------------------------------------

  void _tap(int id) {
    if (_busy || _won || _g.over || !_g.onBoard.contains(id)) return;
    if (!_g.isFree(id)) {
      AppAudio.play(Sound.fail);
      AppAudio.haptic();
      setState(() {
        _shake = id;
        _shakeSerial++;
      });
      _flash(tr('tile_match.covered'));
      return;
    }
    final m = _m;
    final from = m == null ? null : _toRoot(_boardKey, m.origin(_g.level.tiles[id]));
    final mv = _g.tap(id)!;
    final to = _toRoot(_trayKey, _slotOrigin(mv.index));
    AppAudio.play(Sound.pop);
    AppAudio.haptic();
    setState(() {
      _popIn.remove(id);
      if (from != null && to != null && m != null) {
        _inFlight.add(id);
        _flights.add(_Flight(++_serial, id, _g.icons[id], from, to, m.tileSize, _trayTile));
      }
      _shown = mv.cleared.isEmpty ? [..._g.tray] : mv.preClear;
    });
    if (mv.cleared.isNotEmpty) {
      _busy = true;
      final cleared = mv.cleared.toSet();
      _later(_kFlightMs + 20, () {
        AppAudio.play(Sound.success);
        AppAudio.haptic(true);
        setState(() {
          _burst = cleared;
          _burstSerial++;
        });
      });
      _later(_kFlightMs + _kBurstMs + 40, () {
        setState(() {
          _burst = {};
          _shown = [..._g.tray];
          _busy = false;
        });
        if (_g.won) _onWin();
      });
    } else if (_g.lost) {
      _busy = true;
      _later(_kFlightMs + 200, _onLost);
    }
  }

  void _land(_Flight f) {
    if (!mounted) return;
    setState(() {
      _flights.remove(f);
      if (!_flights.any((o) => o.tile == f.tile)) _inFlight.remove(f.tile);
    });
  }

  void _onWin() {
    _won = true;
    final stars = tmStars(helpers: _undos + _shuffles, continues: _continues);
    TmProgress.complete(_tier, _level, stars);
    Rewards.onLevelComplete('tile_match', '${_tier.id}-L$_level', stars: stars);
    _later(500, () => _showWin(stars));
  }

  void _showWin(int stars) {
    final last = _level >= kTmLevels;
    showPremiumDialog(
      context,
      title: tr('common.level_complete'),
      message: [
        tr('tile_match.win_msg', {'moves': _g.moves}),
        if (last) tr('tile_match.tier_done'),
      ].join('\n'),
      emoji: '🀄',
      color: tmAccent,
      stars: stars,
      actions: [
        DialogAction(tr('common.replay'), () => _replay(_level)),
        if (last)
          DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop(), primary: true)
        else
          DialogAction(tr('common.next_level'), () => _replay(_level + 1), primary: true),
      ],
    );
  }

  Future<void> _onLost() async {
    AppAudio.play(Sound.fail);
    AppAudio.haptic(true);
    final paid = await showContinueOffer(context, OfferKind.extraLife);
    if (!mounted) return;
    if (paid) {
      AppAudio.play(Sound.success);
      setState(() {
        final back = _g.returnLast(3);
        for (final t in back) {
          _popIn[t] = ++_serial;
        }
        _shown = [..._g.tray];
        _continues++;
        _busy = false;
      });
      _flash(tr('tile_match.returned'));
      return;
    }
    showPremiumDialog(
      context,
      title: tr('tile_match.tray_full'),
      message: tr('tile_match.tray_full_msg'),
      emoji: '🧺',
      color: Pal.danger,
      actions: [
        DialogAction(tr('common.menu'), () => Navigator.of(context).maybePop()),
        DialogAction(tr('common.try_again'), () => _replay(_level), primary: true),
      ],
    );
  }

  Future<bool> _payIfNeeded(int used, int free, OfferKind kind) async {
    if (used < free) return true;
    _busy = true;
    final paid = await showContinueOffer(context, kind);
    _busy = false;
    return paid && mounted;
  }

  Future<void> _undo() async {
    if (_busy || _won || !_g.canUndo || _g.lost) return;
    if (!await _payIfNeeded(_undos, _kFreeUndos, OfferKind.undo)) return;
    if (!_g.canUndo) return;
    AppAudio.play(Sound.pop);
    setState(() {
      final t = _g.undo();
      if (t != null) _popIn[t] = ++_serial;
      _shown = [..._g.tray];
      _undos++;
    });
  }

  Future<void> _shuffle() async {
    if (_busy || _won || _g.over || _g.onBoard.length < 2) return;
    if (!await _payIfNeeded(_shuffles, _kFreeShuffles, OfferKind.hint)) return;
    AppAudio.play(Sound.slide);
    AppAudio.haptic();
    setState(() {
      _g.shuffle(TmRng(_level * 7919 + _g.moves * 31 + _shuffles * 101 + 17));
      _shuffles++;
      _shuffleSerial++;
    });
    _flash(tr('tile_match.shuffled'));
  }

  // ---- UI -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final freeUndo = math.max(0, _kFreeUndos - _undos);
    final freeShuffle = math.max(0, _kFreeShuffles - _shuffles);
    final plays = TmProgress.playsLeft(_tier, _level);
    final idle = !_busy && !_won && !_g.over;
    return GameScaffold(
      title: tr('tile_match.title'),
      tint: tmAccent,
      body: Stack(
        key: _rootKey,
        children: [
          Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    flex: 3,
                    child: _Pill(
                      icon: Icons.grid_view_rounded,
                      label: '${tmTierName(_tier)} · ${tr('common.level_n', {'n': _level})}',
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: _Pill(icon: Icons.layers_rounded, label: tr('tile_match.tiles_left', {'n': _g.tilesLeft})),
                  ),
                  if (plays > 0) ...[
                    const SizedBox(width: 6),
                    Flexible(
                      flex: 2,
                      child: _Pill(icon: Icons.lock_open_rounded, label: tr('common.skip.plays_left', {'n': plays})),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(child: _board()),
            _trayRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _Booster(
                    key: const ValueKey('tm_undo'),
                    icon: Icons.undo_rounded,
                    label: tr('common.undo'),
                    badge: freeUndo > 0 ? '$freeUndo' : _coin,
                    color: const Color(0xFF4DA8FF),
                    onTap: idle && _g.canUndo ? _undo : null,
                  ),
                  _Booster(
                    key: const ValueKey('tm_shuffle'),
                    icon: Icons.shuffle_rounded,
                    label: tr('tile_match.shuffle'),
                    badge: freeShuffle > 0 ? '$freeShuffle' : _coin,
                    color: const Color(0xFFB794FF),
                    onTap: idle ? _shuffle : null,
                  ),
                  _Booster(
                    key: const ValueKey('tm_restart'),
                    icon: Icons.refresh_rounded,
                    label: tr('common.restart'),
                    color: tmAccentHot,
                    onTap: () => _replay(_level),
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
              bottom: 150,
              left: 24,
              right: 24,
              child: IgnorePointer(
                child: Center(
                  child: GlassCard(
                    blur: 0,
                    radius: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    gradient: LinearGradient(colors: [
                      tmAccentHot.withValues(alpha: 0.9),
                      const Color(0xFF065F46).withValues(alpha: 0.92),
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
      duration: const Duration(milliseconds: _kFlightMs),
      onEnd: () => _land(f),
      builder: (_, v, _) {
        final e = Curves.easeInOutCubic.transform(v);
        final pos = Offset.lerp(f.from, f.to, e)! - Offset(0, math.sin(math.pi * e) * 46);
        // Pops up a little first, then shrinks into the slot.
        final s = (f.s0 + (f.s1 - f.s0) * e) * (1 + 0.18 * math.sin(math.pi * math.min(1.0, v * 1.6)));
        return Positioned(
          left: pos.dx,
          top: pos.dy,
          child: Transform.rotate(
            angle: math.sin(math.pi * e) * 0.18,
            child: TileView(icon: f.icon, size: s),
          ),
        );
      },
    );
  }

  Widget _board() {
    final lv = _g.level;
    return LayoutBuilder(builder: (context, c) {
      final unit = math.min(30.0, TmBoardMetrics.unitFor(lv, Size(c.maxWidth - 16, c.maxHeight - 12)));
      final m = TmBoardMetrics(lv, math.max(6.0, unit));
      _m = m;
      return Center(
        child: SizedBox(
          key: _boardKey,
          width: m.width,
          height: m.height,
          child: Stack(clipBehavior: Clip.none, children: [
            for (final t in lv.tiles)
              if (_g.onBoard.contains(t.id)) _tileAt(t, m),
          ]),
        ),
      );
    });
  }

  Widget _tileAt(TmTile t, TmBoardMetrics m) {
    final o = m.origin(t);
    final free = _g.isFree(t.id);
    Widget tile = TileView(icon: _g.icons[t.id], size: m.tileSize, covered: !free);
    if (_shake == t.id) {
      tile = tile.animate(key: ValueKey('shake$_shakeSerial')).shake(hz: 6, rotation: 0.06, duration: 380.ms);
    }
    final pop = _popIn[t.id];
    if (pop != null) {
      tile = tile
          .animate(key: ValueKey('pop$pop'))
          .scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 600.ms)
          .fadeIn(duration: 150.ms);
    } else if (_shuffleSerial > 0) {
      tile = tile
          .animate(key: ValueKey('shuf$_shuffleSerial'), delay: ((t.x + t.y) * 12).ms)
          .flipH(begin: 0.5, end: 0, duration: 300.ms)
          .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 380.ms);
    } else if (_g.moves == 0 && _epoch > 0) {
      tile = tile
          .animate(key: ValueKey('in$_epoch'), delay: (t.z * 90 + (t.x + t.y) * 6).ms)
          .fadeIn(duration: 220.ms)
          .moveY(begin: -m.unit, end: 0, duration: 320.ms, curve: Curves.easeOutBack);
    }
    return Positioned(
      key: ValueKey('tmp${t.id}-$_epoch'),
      left: o.dx,
      top: o.dy,
      width: m.tileSize,
      height: m.tileSize + m.depth,
      child: GestureDetector(
        key: ValueKey('tm_tile_${t.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _tap(t.id),
        child: tile,
      ),
    );
  }

  Widget _trayRow() {
    final cap = _g.capacity;
    final danger = _g.tray.length >= cap - 2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: LayoutBuilder(builder: (context, c) {
        _slot = math.min(50.0, (c.maxWidth - 20) / cap);
        final h = _slot + _trayTile * kTmDepth + 2;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF7A4E2D), Color(0xFF4A2C17)],
            ),
            border: Border.all(color: danger ? Pal.danger : const Color(0xFFD6A46E).withValues(alpha: 0.6), width: danger ? 2 : 1.2),
            boxShadow: [
              if (danger) BoxShadow(color: Pal.danger.withValues(alpha: 0.5), blurRadius: 16),
              const BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5)),
            ],
          ),
          child: Center(
            child: SizedBox(
              key: _trayKey,
              width: _slot * cap,
              height: h,
              child: Stack(clipBehavior: Clip.none, children: [
                for (var i = 0; i < cap; i++)
                  Positioned(
                    left: i * _slot + 2,
                    top: 2,
                    width: _slot - 4,
                    height: _slot - 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(_slot * 0.2),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF2B180B), Color(0xFF3D2412)],
                        ),
                        border: Border.all(color: Colors.black.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                for (var i = 0; i < _shown.length; i++) _trayTileAt(i, _shown[i]),
                if (_burst.isNotEmpty) _burstView(),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _trayTileAt(int i, int id) {
    final o = _slotOrigin(i);
    Widget tile = TileView(icon: _g.icons[id], size: _trayTile, glow: _burst.contains(id) ? Pal.gold : null);
    if (_burst.contains(id)) {
      tile = tile
          .animate(key: ValueKey('b$_burstSerial-$id'))
          .scale(begin: const Offset(1, 1), end: const Offset(1.25, 1.25), duration: 120.ms, curve: Curves.easeOut)
          .then()
          .scale(begin: const Offset(1, 1), end: const Offset(0.1, 0.1), duration: 180.ms, curve: Curves.easeIn)
          .fadeOut(duration: 180.ms);
    }
    return AnimatedPositioned(
      key: ValueKey('tray$id'),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      left: o.dx,
      top: o.dy,
      child: Opacity(opacity: _inFlight.contains(id) ? 0 : 1, child: tile),
    );
  }

  Widget _burstView() {
    final idx = [for (var i = 0; i < _shown.length; i++) if (_burst.contains(_shown[i])) i];
    if (idx.isEmpty) return const SizedBox.shrink();
    final mid = idx[idx.length ~/ 2];
    final c = _slotOrigin(mid) + Offset(_trayTile / 2, _trayTile / 2);
    final color = tmIcon(_g.icons[_shown[mid]]).$2;
    return Positioned(
      left: c.dx,
      top: c.dy,
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: Stack(clipBehavior: Clip.none, children: [
          for (var k = 0; k < 12; k++)
            Positioned(
              left: -4,
              top: -4,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: k.isEven ? BoxShape.circle : BoxShape.rectangle,
                  color: k % 3 == 0 ? Pal.gold : (k % 3 == 1 ? color : Colors.white),
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              )
                  .animate(key: ValueKey('p$_burstSerial-$k'))
                  .move(
                    begin: Offset.zero,
                    end: Offset(math.cos(k * math.pi / 6) * _slot * 1.5, math.sin(k * math.pi / 6) * _slot * 1.1),
                    duration: _kBurstMs.ms,
                    curve: Curves.easeOutCubic,
                  )
                  .fadeOut(delay: 120.ms, duration: 200.ms),
            ),
        ]),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 0,
      radius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      onTap: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: tmAccent),
        const SizedBox(width: 6),
        Flexible(
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
    );
  }
}

const _coin = '\u{1FA99}';

/// Round glossy booster button with a badge (free uses left, or a coin).
class _Booster extends StatelessWidget {
  const _Booster({super.key, required this.icon, required this.label, required this.color, this.badge, this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final String? badge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    final body = SizedBox(
      width: 96,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: off ? const LinearGradient(colors: [Color(0xFF55507A), Color(0xFF3C3860)]) : Pal.accent(color),
              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 1.5),
              boxShadow: off ? null : [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 4))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          if (badge != null)
            Positioned(
              right: -6,
              top: -4,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: badge == _coin ? const Color(0xFF2A1F63) : Pal.danger,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
                ),
                child: Text(badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(color: off ? Pal.textDim : Pal.text, fontSize: 11.5, fontWeight: FontWeight.w700)),
      ]),
    );
    return Opacity(opacity: off ? 0.55 : 1, child: off ? body : Pressable(onTap: onTap!, child: body));
  }
}
