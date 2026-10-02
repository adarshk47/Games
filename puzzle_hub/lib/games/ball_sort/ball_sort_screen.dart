import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/ball_sort_logic.dart';

const _kLevelKey = 'ball_sort.level';
const _kUnlockedKey = 'ball_sort.unlocked';
const _kMarkersKey = 'ball_sort.markers';

const _palette = <Color>[
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFF8E24AA), // purple
  Color(0xFFFB8C00), // orange
  Color(0xFF00ACC1), // cyan
  Color(0xFFEC407A), // pink
  Color(0xFF6D4C41), // brown
  Color(0xFF9E9E9E), // grey
  Color(0xFF7CB342), // lime
  Color(0xFF1A237E), // navy
];

const _shapes = <IconData>[
  Icons.circle,
  Icons.change_history,
  Icons.square,
  Icons.star,
  Icons.favorite,
  Icons.diamond,
  Icons.hexagon,
  Icons.add,
  Icons.close,
  Icons.remove,
  Icons.bolt,
  Icons.crop_square,
];

class BallSortScreen extends StatefulWidget {
  const BallSortScreen({super.key});

  @override
  State<BallSortScreen> createState() => _BallSortScreenState();
}

class _BallSortScreenState extends State<BallSortScreen> {
  late int _level;
  late int _unlocked;
  late bool _markers;
  late BallSortState _state;
  final List<BallSortState> _history = [];
  int? _selected;
  int _lastDest = -1;
  int _lastSrc = -1;
  int _lastCount = 0;
  int _moveSerial = 0;
  bool _won = false;

  @override
  void initState() {
    super.initState();
    _unlocked = Storage.getInt(_kUnlockedKey, 1);
    _level = Storage.getInt(_kLevelKey, 1).clamp(1, _unlocked);
    _markers = Storage.getBool(_kMarkersKey);
    _load(_level);
  }

  void _load(int level) {
    _level = level;
    Storage.setInt(_kLevelKey, level);
    _state = generateLevel(level);
    _history.clear();
    _selected = null;
    _lastDest = -1;
    _won = false;
  }

  void _restart() => setState(() => _load(_level));

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      _state = _history.removeLast();
      _selected = null;
      _lastDest = -1;
      _won = false;
    });
  }

  void _addTube() {
    if (!_state.canAddTube) return;
    setState(() {
      _history.add(_state.clone());
      _state.addTube();
    });
  }

  void _tap(int i) {
    if (_won) return;
    setState(() {
      final sel = _selected;
      if (sel == null) {
        if (_state.tubes[i].isNotEmpty) _selected = i;
      } else if (sel == i) {
        _selected = null;
      } else if (_state.canPour(sel, i)) {
        _history.add(_state.clone());
        _lastCount = _state.pour(sel, i);
        _lastDest = i;
        _lastSrc = sel;
        _moveSerial++;
        _selected = null;
        if (_state.isSolved) _onWin();
      } else {
        _selected = _state.tubes[i].isNotEmpty ? i : null;
      }
    });
  }

  void _onWin() {
    _won = true;
    if (_level >= _unlocked) {
      _unlocked = _level + 1;
      Storage.setInt(_kUnlockedKey, _unlocked);
    }
    final key = 'ball_sort.best_moves.$_level';
    final best = Storage.getInt(key, 0);
    if (best == 0 || _state.moves < best) Storage.setInt(key, _state.moves);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showWin();
    });
  }

  void _showWin() {
    showPremiumDialog(
      context,
      title: 'Level $_level complete!',
      message: 'Solved in ${_state.moves} moves.',
      emoji: '🧪',
      color: _accent,
      actions: [
        DialogAction('Replay', _restart),
        DialogAction('Next level', () => setState(() => _load(_level + 1)), primary: true),
      ],
    );
  }

  void _showLevels() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
            child: GlassCard(
              radius: 28,
              blur: 0,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [const Color(0xFF2A1F63).withValues(alpha: 0.97), const Color(0xFF140E38).withValues(alpha: 0.97)],
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Select level', style: TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 68, mainAxisSpacing: 10, crossAxisSpacing: 10),
                    itemCount: _unlocked + 9,
                    itemBuilder: (_, i) {
                      final lv = i + 1;
                      return _LevelTile(
                        level: lv,
                        locked: lv > _unlocked,
                        done: lv < _unlocked,
                        current: lv == _level,
                        onTap: () {
                          Navigator.pop(ctx);
                          setState(() => _load(lv));
                        },
                      );
                    },
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _state.tubes.length;
    return GameScaffold(
      title: 'Ball Sort',
      tint: _accent,
      actions: [
        BarAction(
          icon: _markers ? Icons.accessibility_new : Icons.accessibility_outlined,
          tooltip: 'Shape markers',
          onTap: () {
            setState(() => _markers = !_markers);
            Storage.setBool(_kMarkersKey, _markers);
          },
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _Pill(icon: Icons.grid_view_rounded, label: 'Level $_level', onTap: _showLevels),
              const SizedBox(width: 10),
              _Pill(icon: Icons.swap_vert_rounded, label: 'Moves ${_state.moves}'),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              final perRow = n <= 6 ? n : (n + 1) ~/ 2;
              final ball = ((c.maxWidth - 16) / perRow / 1.35).clamp(24.0, 52.0);
              final spacing = ball * 0.3;
              final tubeW = ball * 1.2;
              final tubeH = ball * _state.capacity + 12 + ball * 0.9 + 4;
              final runSpacing = ball * 0.6;
              return Center(
                child: SingleChildScrollView(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: spacing,
                    runSpacing: runSpacing,
                    children: [
                      for (var i = 0; i < n; i++)
                        _TubeView(
                          balls: _state.tubes[i],
                          capacity: _state.capacity,
                          ball: ball,
                          selected: _selected == i,
                          lifted: _selected == i ? _state.topRun(i) : 0,
                          markers: _markers,
                          dropCount: _lastDest == i ? _lastCount : 0,
                          from: _lastDest == i && _lastSrc >= 0
                              ? Offset(((_lastSrc % perRow) - (i % perRow)) * (tubeW + spacing),
                                  ((_lastSrc ~/ perRow) - (i ~/ perRow)) * (tubeH + runSpacing))
                              : Offset.zero,
                          serial: _moveSerial,
                          onTap: () => _tap(i),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pill(icon: Icons.undo_rounded, label: 'Undo', onTap: _history.isEmpty ? null : _undo, big: true),
                _Pill(icon: Icons.refresh_rounded, label: 'Restart', onTap: _restart, big: true),
                _Pill(
                    icon: Icons.add_rounded,
                    label: 'Tube (${kMaxExtraTubes - _state.extraUsed})',
                    onTap: _state.canAddTube ? _addTube : null,
                    big: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _accent = Color(0xFF2EE6A8);

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, this.onTap, this.big = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final off = onTap == null && big;
    return Opacity(
      opacity: off ? 0.5 : 1,
      child: GlassCard(
        blur: 0,
        radius: 30,
        padding: EdgeInsets.symmetric(horizontal: big ? 18 : 14, vertical: big ? 12 : 8),
        onTap: onTap,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: big ? 20 : 18, color: off ? Pal.textDim : _accent),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: off ? Pal.textDim : Pal.text, fontWeight: FontWeight.w700, fontSize: big ? 15 : 14)),
        ]),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile(
      {required this.level, required this.locked, required this.done, required this.current, required this.onTap});
  final int level;
  final bool locked, done, current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: locked
            ? const LinearGradient(colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)])
            : current
                ? Pal.accent(_accent)
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_accent.withValues(alpha: 0.28), _accent.withValues(alpha: 0.08)]),
        border: Border.all(color: current ? Colors.white.withValues(alpha: 0.7) : Pal.glassBorder),
        boxShadow: locked
            ? null
            : [BoxShadow(color: _accent.withValues(alpha: current ? 0.55 : 0.2), blurRadius: current ? 16 : 8, spreadRadius: -2)],
      ),
      child: locked
          ? const Icon(Icons.lock_rounded, size: 18, color: Pal.textDim)
          : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('$level',
                  style: TextStyle(color: current ? Colors.white : Pal.text, fontWeight: FontWeight.w800, fontSize: 18)),
              if (done) const Icon(Icons.check_circle_rounded, size: 14, color: Pal.success),
            ]),
    );
    return locked ? tile : Pressable(onTap: onTap, child: tile);
  }
}

class _TubeView extends StatelessWidget {
  const _TubeView({
    required this.balls,
    required this.capacity,
    required this.ball,
    required this.selected,
    required this.lifted,
    required this.markers,
    required this.dropCount,
    required this.from,
    required this.serial,
    required this.onTap,
  });

  final List<int> balls;
  final int capacity;
  final double ball;
  final bool selected;
  final int lifted;
  final bool markers;
  final int dropCount;
  final Offset from;
  final int serial;
  final VoidCallback onTap;

  bool get _solved => balls.length == capacity && balls.every((b) => b == balls.first);

  @override
  Widget build(BuildContext context) {
    final w = ball * 1.2;
    final lift = ball * 0.9;
    final h = ball * capacity + 12;
    final solved = _solved;
    final glowColor = solved ? _palette[balls.first % _palette.length] : _accent;
    final glowOn = selected || solved;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: w,
        height: h + lift + 4,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Glass tube body.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: h,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.04),
                      Colors.white.withValues(alpha: 0.10),
                    ],
                  ),
                  border: Border.all(
                      color: glowOn ? glowColor.withValues(alpha: 0.9) : Colors.white.withValues(alpha: 0.35),
                      width: glowOn ? 2 : 1.5),
                  borderRadius: BorderRadius.vertical(top: const Radius.circular(8), bottom: Radius.circular(w / 2)),
                  boxShadow: [
                    if (glowOn) BoxShadow(color: glowColor.withValues(alpha: 0.55), blurRadius: 20, spreadRadius: 1),
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4)),
                  ],
                ),
              ),
            ),
            // Inner glow at the base.
            Positioned(
              left: 3,
              right: 3,
              bottom: 3,
              height: h * 0.4,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(w / 2)),
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [_accent.withValues(alpha: 0.16), Colors.transparent],
                    ),
                  ),
                ),
              ),
            ),
            for (var i = 0; i < balls.length; i++)
              AnimatedPositioned(
                key: ValueKey('b$i'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                left: (w - ball) / 2,
                bottom: 6 + i * ball + (i >= balls.length - lifted ? lift : 0),
                width: ball,
                height: ball,
                child: i >= balls.length - dropCount
                    ? _PourBall(
                        key: ValueKey('d$serial-$i'),
                        from: from,
                        lift: lift,
                        order: i - (balls.length - dropCount),
                        child: _BallView(color: balls[i], size: ball, marker: markers),
                      )
                    : _BallView(color: balls[i], size: ball, marker: markers),
              ),
            // Rim highlight and reflection.
            Positioned(
              left: -2,
              right: -2,
              bottom: h - 5,
              height: 8,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.white.withValues(alpha: 0.28),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1),
                  ),
                ),
              ),
            ),
            Positioned(
              left: w * 0.16,
              bottom: 12,
              width: w * 0.12,
              height: h - 28,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white.withValues(alpha: 0.5), Colors.white.withValues(alpha: 0.0)],
                    ),
                  ),
                ),
              ),
            ),
            if (solved)
              Positioned.fill(
                child: IgnorePointer(
                  child: Stack(clipBehavior: Clip.none, children: [
                    for (var k = 0; k < 3; k++)
                      Positioned(
                        left: w * (0.1 + 0.35 * k),
                        top: lift + h * (0.1 + 0.3 * k),
                        child: Icon(Icons.auto_awesome, size: ball * 0.3, color: Colors.white)
                            .animate(onPlay: (c) => c.repeat(), delay: (k * 400).ms)
                            .fadeIn(duration: 350.ms)
                            .scale(begin: const Offset(0.3, 0.3), end: const Offset(1.1, 1.1), duration: 700.ms)
                            .then()
                            .fadeOut(duration: 600.ms),
                      ),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Arcs a ball from the source tube into place, then squashes on landing.
class _PourBall extends StatelessWidget {
  const _PourBall({super.key, required this.from, required this.lift, required this.order, required this.child});
  final Offset from;
  final double lift;
  final int order;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final delay = (order * 0.14).clamp(0.0, 0.5);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + order * 60),
      builder: (_, raw, _) {
        final t = ((raw - delay) / (1 - delay)).clamp(0.0, 1.0);
        final e = Curves.easeInOut.transform(t);
        final arc = math.sin(math.pi * e) * lift * 1.6;
        final dx = from.dx * (1 - e);
        final dy = from.dy * (1 - e) - lift * (1 - e) - arc;
        // Squash in the last 25% of the flight.
        final sq = t > 0.75 ? math.sin((t - 0.75) / 0.25 * math.pi) * 0.18 : 0.0;
        return Opacity(
          opacity: (t * 6).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(dx, dy),
            child: Transform(
              alignment: Alignment.bottomCenter,
              transform: Matrix4.diagonal3Values(1 + sq * 0.6, 1 - sq, 1),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _BallView extends StatelessWidget {
  const _BallView({required this.color, required this.size, required this.marker});
  final int color;
  final double size;
  final bool marker;

  @override
  Widget build(BuildContext context) {
    final base = _palette[color % _palette.length];
    return Padding(
      padding: const EdgeInsets.all(2),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            center: const Alignment(-0.35, -0.4),
            radius: 0.95,
            colors: [
              Color.lerp(base, Colors.white, 0.55)!,
              base,
              Color.lerp(base, Colors.black, 0.55)!,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(color: base.withValues(alpha: 0.45), blurRadius: 6, spreadRadius: -1),
            const BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(1, 3)),
          ],
        ),
        child: Stack(children: [
          Positioned(
            left: size * 0.2,
            top: size * 0.12,
            width: size * 0.3,
            height: size * 0.18,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                gradient: RadialGradient(colors: [
                  Colors.white.withValues(alpha: 0.9),
                  Colors.white.withValues(alpha: 0.0),
                ]),
              ),
            ),
          ),
          if (marker)
            Center(
              child: Icon(_shapes[color % _shapes.length],
                  size: size * 0.42, color: base.computeLuminance() > 0.5 ? Colors.black87 : Colors.white),
            ),
        ]),
      ),
    );
  }
}
