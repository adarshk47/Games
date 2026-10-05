import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/parking_logic.dart';
import 'parking_painters.dart';

const pjAccent = Color(0xFFFFB020);

/// Storage keys: everything is per tier (`parking_jam.<tier>.<what>`).
String pjKey(PjTier t, String what) => 'parking_jam.${t.id}.$what';

/// Localized tier name.
String pjTierName(PjTier t) => tr('common.tier.${t.id}');

/// Road ring around the lot, in cells.
const _kMargin = 0.7;

class ParkingJamGame extends StatefulWidget {
  const ParkingJamGame({super.key, required this.tier, required this.level, this.custom});
  final PjTier tier;
  final int level;

  /// Test hook: play this exact level instead of the generated one.
  @visibleForTesting
  final PjLevel? custom;

  @override
  State<ParkingJamGame> createState() => _ParkingJamGameState();
}

class _Ghost {
  _Ghost(this.serial, this.v, this.step);
  final int serial;
  final Vehicle v;

  /// +1 / -1 along the vehicle's axis (screen direction).
  final int step;
}

class _ParkingJamGameState extends State<ParkingJamGame> {
  late int _level;
  late int _unlocked;
  late PjLevel _lvl;
  late ParkingState _s;
  final List<ParkingState> _history = [];
  final List<_Ghost> _ghosts = [];
  final Map<int, int> _bumps = {};
  int _serial = 0;
  int _hintsUsed = 0;
  int? _hintId;
  int _extra = 0;
  bool _won = false;
  bool _offerOpen = false;
  String? _banner;
  Timer? _bannerTimer;

  PjTier get _tier => widget.tier;
  int? get _limit => _lvl.moveLimit == null ? null : _lvl.moveLimit! + _extra;
  bool get _outOfMoves => _limit != null && _s.moves >= _limit! && !_s.isSolved;

  @override
  void initState() {
    super.initState();
    _unlocked = Storage.getInt(pjKey(_tier, 'unlocked'), 1);
    _load(widget.level.clamp(1, math.min(_unlocked, kPjLevels)));
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _load(int level) {
    _level = level;
    Storage.setInt(pjKey(_tier, 'level'), level);
    final custom = widget.custom;
    _lvl = custom != null && custom.level == level
        ? PjLevel(
            tier: custom.tier,
            level: custom.level,
            state: custom.state.clone(),
            solution: custom.solution,
            moveLimit: custom.moveLimit)
        : generateLevel(_tier, level);
    _s = _lvl.state;
    _history.clear();
    _ghosts.clear();
    _bumps.clear();
    _hintsUsed = 0;
    _hintId = null;
    _extra = 0;
    _won = false;
    _banner = null;
  }

  void _restart() {
    AppAudio.play(Sound.tap);
    setState(() => _load(_level));
  }

  void _undo() {
    if (_history.isEmpty || _won) return;
    AppAudio.play(Sound.tap);
    setState(() {
      _s = _history.removeLast();
      final ids = {for (final v in _s.vehicles) v.id};
      _ghosts.removeWhere((g) => ids.contains(g.v.id));
      _hintId = null;
    });
  }

  void _showBanner(String text) {
    _bannerTimer?.cancel();
    setState(() => _banner = text);
    _bannerTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  void _drive(int id, int dir) {
    if (_won) return;
    if (_outOfMoves) {
      _askMoreMoves();
      return;
    }
    final before = _s.byId(id)?.copy();
    if (before == null) return;
    final snap = _s.clone();
    final r = _s.move(id, dir);
    setState(() {
      final blocker = r.blocker;
      if (!r.moved) {
        _bumps[id] = ++_serial;
        if (blocker != null && blocker >= 0) _bumps[blocker] = ++_serial;
        AppAudio.play(Sound.fail);
        AppAudio.haptic();
        return;
      }
      _history.add(snap);
      if (_hintId == id) _hintId = null;
      AppAudio.play(Sound.slide);
      if (r.exited) {
        _ghosts.add(_Ghost(++_serial, before, before.facing * dir));
      } else {
        _bumps[id] = ++_serial;
        AppAudio.haptic();
        if (blocker != null && blocker >= 0) {
          Future.delayed(_driveTime(r.distance), () {
            if (mounted && _s.byId(blocker) != null) setState(() => _bumps[blocker] = ++_serial);
          });
        }
      }
    });
    if (_s.isSolved) {
      _onWin();
    } else if (_outOfMoves) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted && _outOfMoves && !_won) _askMoreMoves();
      });
    }
  }

  Future<void> _askMoreMoves() async {
    if (_offerOpen) return;
    _offerOpen = true;
    final paid = await showContinueOffer(context, OfferKind.extraLife);
    _offerOpen = false;
    if (!mounted) return;
    if (paid) {
      AppAudio.play(Sound.success);
      setState(() => _extra += kPjExtraMoves);
      return;
    }
    AppAudio.play(Sound.fail);
    showPremiumDialog(
      context,
      title: tr('parking_jam.out_title'),
      message: tr('parking_jam.out_msg'),
      emoji: '🚧',
      color: Pal.danger,
      actions: [
        DialogAction(tr('common.undo'), _undo),
        DialogAction(tr('common.restart'), _restart, primary: true),
      ],
    );
  }

  Future<void> _hint() async {
    if (_won || _offerOpen) return;
    final h = _s.exitHint();
    if (h == null) {
      AppAudio.play(Sound.fail);
      _showBanner(tr('parking_jam.hint_stuck'));
      return;
    }
    if (_hintsUsed >= kPjFreeHints) {
      _offerOpen = true;
      final paid = await showContinueOffer(context, OfferKind.hint);
      _offerOpen = false;
      if (!mounted || !paid || _won) return;
    } else {
      _hintsUsed++;
    }
    final again = _s.exitHint();
    if (again == null) return;
    AppAudio.play(Sound.pop);
    setState(() => _hintId = again.$1);
  }

  void _onWin() {
    _won = true;
    _hintId = null;
    if (_level >= _unlocked) {
      _unlocked = _level + 1;
      Storage.setInt(pjKey(_tier, 'unlocked'), _unlocked);
    }
    final bkey = pjKey(_tier, 'best.$_level');
    final best = Storage.getInt(bkey);
    if (best == 0 || _s.moves < best) Storage.setInt(bkey, _s.moves);
    final stars = pjStars(_s.moves, _lvl.par);
    final skey = pjKey(_tier, 'stars.$_level');
    if (stars > Storage.getInt(skey)) Storage.setInt(skey, stars);
    Rewards.onLevelComplete('parking_jam', '${_tier.id}-L$_level', stars: stars);
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _showWin(stars);
    });
  }

  void _showWin(int stars) {
    final last = _level >= kPjLevels;
    showPremiumDialog(
      context,
      title: last ? tr('parking_jam.tier_done', {'tier': pjTierName(_tier)}) : tr('parking_jam.level_done'),
      message: tr('parking_jam.solved_msg', {'moves': _s.moves, 'par': _lvl.par}),
      emoji: '🚗',
      color: pjAccent,
      stars: stars,
      actions: [
        DialogAction(tr('common.replay'), _restart),
        if (last)
          DialogAction(tr('common.levels'), () => Navigator.of(context).maybePop(), primary: true)
        else
          DialogAction(tr('common.next_level'), () => setState(() => _load(_level + 1)), primary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final limit = _limit;
    final movesText = limit == null ? '${_s.moves}' : '${_s.moves}/$limit';
    final low = limit != null && limit - _s.moves <= 2;
    final freeHints = kPjFreeHints - _hintsUsed;
    return GameScaffold(
      title: tr('parking_jam.title_tier', {'tier': pjTierName(_tier)}),
      tint: pjAccent,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            _Pill(
                icon: Icons.grid_view_rounded,
                label: tr('common.level_n', {'n': _level}),
                onTap: () => Navigator.of(context).maybePop()),
            _Pill(
                icon: Icons.swap_calls_rounded,
                label: '${tr('common.moves')} $movesText',
                color: low ? Pal.danger : null),
            _Pill(icon: Icons.directions_car_filled_rounded, label: tr('parking_jam.left', {'n': _s.vehicles.length})),
          ]),
        ),
        SizedBox(
          height: 34,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Padding(
                key: ValueKey(_banner ?? (_s.moves == 0 ? 'tip' : '')),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _banner ?? (_s.moves == 0 ? tr('parking_jam.tip') : ''),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: _banner != null ? Pal.gold : Pal.textDim, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
        Expanded(child: _board()),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 14),
          child: Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            _Pill(icon: Icons.undo_rounded, label: tr('common.undo'), onTap: _history.isEmpty || _won ? null : _undo, big: true),
            _Pill(icon: Icons.refresh_rounded, label: tr('common.restart'), onTap: _restart, big: true),
            _Pill(
              icon: freeHints > 0 ? Icons.lightbulb_rounded : Icons.monetization_on_rounded,
              label: freeHints > 0 ? '${tr('common.hint')} ($freeHints)' : tr('common.hint'),
              onTap: _won ? null : _hint,
              big: true,
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _board() {
    return LayoutBuilder(builder: (context, c) {
      final n = _s.size;
      final side = math.max(0.0, math.min(c.maxWidth - 16, c.maxHeight - 4));
      final cell = side / (n + 2 * _kMargin);
      final origin = Offset(_kMargin * cell, _kMargin * cell);
      return Center(
        child: SizedBox(
          key: ValueKey('pj_board_${_tier.id}_$_level'),
          width: side,
          height: side,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: pjAccent.withValues(alpha: 0.18), blurRadius: 30, spreadRadius: -6)],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(children: [
                Positioned.fill(child: CustomPaint(painter: LotPainter(n: n, margin: _kMargin))),
                for (final o in _s.obstacles)
                  Positioned(
                    left: origin.dx + (o % n) * cell,
                    top: origin.dy + (o ~/ n) * cell,
                    width: cell,
                    height: cell,
                    child: const IgnorePointer(child: CustomPaint(painter: ConePainter())),
                  ),
                for (final v in _s.vehicles)
                  _CarView(
                    key: ValueKey('pj_car_${_level}_${v.id}'),
                    v: v,
                    cell: cell,
                    origin: origin,
                    hinted: _hintId == v.id,
                    bump: _bumps[v.id] ?? 0,
                    onDrive: (d) => _drive(v.id, d),
                  ),
                for (final g in _ghosts)
                  _ExitingCar(
                    key: ValueKey('pj_exit_${g.serial}'),
                    v: g.v,
                    step: g.step,
                    cell: cell,
                    origin: origin,
                    n: n,
                    onDone: () {
                      if (mounted) setState(() => _ghosts.remove(g));
                    },
                  ),
              ]),
            ),
          ),
        ),
      ).animate(key: ValueKey('pj_in_$_level')).fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.96, 0.96), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOut);
    });
  }
}

Duration _driveTime(int cells) => Duration(milliseconds: 110 + 55 * cells);

int _turns(Vehicle v) => v.horizontal ? (v.facing > 0 ? 1 : 3) : (v.facing > 0 ? 2 : 0);

Widget _vehicleArt(Vehicle v, {double glow = 0}) => RotatedBox(
      quarterTurns: _turns(v),
      child: CustomPaint(
        painter: VehiclePainter(
          color: pjCarColors[v.color % pjCarColors.length],
          length: v.length,
          variant: v.id,
          glow: glow,
          glowColor: Pal.gold,
        ),
      ),
    );

/// A parked vehicle: drives to its new cell with slight acceleration, shakes
/// on bumps, glows when hinted. Tap = forward, swipe = choose direction.
class _CarView extends StatefulWidget {
  const _CarView({
    super.key,
    required this.v,
    required this.cell,
    required this.origin,
    required this.hinted,
    required this.bump,
    required this.onDrive,
  });
  final Vehicle v;
  final double cell;
  final Offset origin;
  final bool hinted;
  final int bump;
  final void Function(int dir) onDrive;

  @override
  State<_CarView> createState() => _CarViewState();
}

class _CarViewState extends State<_CarView> with TickerProviderStateMixin {
  late final AnimationController _drive = AnimationController(vsync: this, duration: _driveTime(1));
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  late Offset _from, _to;
  bool _pendingShake = false;
  Offset _pan = Offset.zero;

  Offset _pos(Vehicle v) => Offset(v.col.toDouble(), v.row.toDouble());

  @override
  void initState() {
    super.initState();
    _from = _to = _pos(widget.v);
    _drive.addStatusListener((s) {
      if (s == AnimationStatus.completed && _pendingShake) {
        _pendingShake = false;
        _shake.forward(from: 0);
      }
    });
    if (widget.hinted) _pulse.repeat(reverse: true);
  }

  Offset get _current => Offset.lerp(_from, _to, Curves.easeIn.transform(_drive.value))!;

  @override
  void didUpdateWidget(_CarView old) {
    super.didUpdateWidget(old);
    final p = _pos(widget.v);
    if (p != _to) {
      _from = _current;
      _to = p;
      _drive.duration = _driveTime((p - _from).distance.round());
      _drive.forward(from: 0);
    }
    if (widget.bump != old.bump) {
      if (_drive.isAnimating) {
        _pendingShake = true;
      } else {
        _shake.forward(from: 0);
      }
    }
    if (widget.hinted && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.hinted && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _drive.dispose();
    _shake.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _panEnd() {
    final v = widget.v;
    final along = v.horizontal ? _pan.dx : _pan.dy;
    final across = v.horizontal ? _pan.dy : _pan.dx;
    _pan = Offset.zero;
    if (along.abs() < 8 || along.abs() < across.abs() * 0.6) {
      widget.onDrive(1);
      return;
    }
    widget.onDrive(along.sign.toInt() == v.facing ? 1 : -1);
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final cell = widget.cell;
    return AnimatedBuilder(
      animation: Listenable.merge([_drive, _shake, _pulse]),
      builder: (context, child) {
        final cur = _current;
        final t = _shake.value;
        final shake = _shake.isAnimating ? math.sin(t * math.pi * 6) * (1 - t) * cell * 0.1 : 0.0;
        final off = v.horizontal ? Offset(shake, 0) : Offset(0, shake);
        return Positioned(
          left: widget.origin.dx + cur.dx * cell + off.dx,
          top: widget.origin.dy + cur.dy * cell + off.dy,
          width: v.horizontal ? v.length * cell : cell,
          height: v.horizontal ? cell : v.length * cell,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.onDrive(1),
            onPanStart: (_) => _pan = Offset.zero,
            onPanUpdate: (d) => _pan += d.delta,
            onPanEnd: (_) => _panEnd(),
            child: _vehicleArt(v, glow: widget.hinted ? 0.4 + 0.6 * _pulse.value : 0),
          ),
        );
      },
    );
  }
}

/// A vehicle leaving the lot: accelerates off the board and fades.
class _ExitingCar extends StatefulWidget {
  const _ExitingCar({
    super.key,
    required this.v,
    required this.step,
    required this.cell,
    required this.origin,
    required this.n,
    required this.onDone,
  });
  final Vehicle v;
  final int step;
  final double cell;
  final Offset origin;
  final int n;
  final VoidCallback onDone;

  @override
  State<_ExitingCar> createState() => _ExitingCarState();
}

class _ExitingCarState extends State<_ExitingCar> with SingleTickerProviderStateMixin {
  late final double _travel;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    final v = widget.v;
    final start = v.horizontal ? v.col : v.row;
    _travel = widget.step > 0 ? widget.n + _kMargin + 0.4 - start : start + v.length + _kMargin + 0.4;
    _c = AnimationController(vsync: this, duration: Duration(milliseconds: (180 + 45 * _travel).round()))
      ..forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.v;
    final cell = widget.cell;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final d = Curves.easeInQuad.transform(_c.value) * _travel * widget.step * cell;
        return Positioned(
          left: widget.origin.dx + v.col * cell + (v.horizontal ? d : 0),
          top: widget.origin.dy + v.row * cell + (v.horizontal ? 0 : d),
          width: v.horizontal ? v.length * cell : cell,
          height: v.horizontal ? cell : v.length * cell,
          child: IgnorePointer(
            child: Opacity(opacity: (1 - (_c.value - 0.7) / 0.3).clamp(0.0, 1.0), child: child),
          ),
        );
      },
      child: _vehicleArt(v),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap, this.big = false, this.color});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool big;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null && big;
    final c = color ?? pjAccent;
    return Opacity(
      opacity: off ? 0.5 : 1,
      child: GlassCard(
        blur: 0,
        radius: 30,
        padding: EdgeInsets.symmetric(horizontal: big ? 16 : 12, vertical: big ? 11 : 7),
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: big ? 20 : 17, color: off ? Pal.textDim : c),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: off ? Pal.textDim : (color ?? Pal.text), fontWeight: FontWeight.w700, fontSize: big ? 15 : 13)),
        ]),
      ),
    );
  }
}
