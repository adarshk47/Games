import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/ball_sort_logic.dart';

const _kMarkersKey = 'ball_sort.markers';

/// Storage key helpers: everything is per difficulty.
String bsKey(BsDifficulty d, String what) => 'ball_sort.${d.id}.$what';

/// Highest level unlocked in sequence (stored), at least 1.
int bsUnlockedInSequence(BsDifficulty d) => Storage.getInt(bsKey(d, 'unlocked'), 1);

int bsStars(BsDifficulty d, int level) => Storage.getInt(bsKey(d, 'stars.$level'));

/// [LevelGate] prefix, e.g. `ball_sort.easy`.
String bsGatePrefix(BsDifficulty d) => 'ball_sort.${d.id}';

/// Next unbeaten level in sequence: the furthest level that is free to open.
int bsFreeUpTo(BsDifficulty d) => bsUnlockedInSequence(d).clamp(1, kBsLevelCount);

/// Unlocked through progress: up to the next level in sequence, a cleared
/// level, or the level right after a cleared one.
bool bsUnlocked(BsDifficulty d, int level) =>
    level <= bsUnlockedInSequence(d) || bsStars(d, level) > 0 || (level > 1 && bsStars(d, level - 1) > 0);

/// Plays left on a level skipped to with coins (0 for unlocked levels).
int bsPlaysLeft(BsDifficulty d, int level) => bsUnlocked(d, level) ? 0 : LevelGate.playsLeft(bsGatePrefix(d), level);

bool bsCanPlay(BsDifficulty d, int level) => bsUnlocked(d, level) || bsPlaysLeft(d, level) > 0;

/// Counts one play of a bought level (no-op for unlocked levels).
Future<void> bsOnStart(BsDifficulty d, int level) =>
    LevelGate.onStart(bsGatePrefix(d), bsUnlocked(d, level) ? level : bsFreeUpTo(d), level);

/// Makes sure [level] may be played; a locked level must be bought first.
Future<bool> bsEnsurePlayable(BuildContext context, BsDifficulty d, int level) async {
  if (bsCanPlay(d, level)) return true;
  return LevelGate.buy(context, prefix: bsGatePrefix(d), freeUpTo: bsFreeUpTo(d), level: level);
}

/// Localized difficulty name.
String bsTierName(BsDifficulty d) => tr('common.tier.${d.id}');

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
  Color(0xFFF5F5F5), // white
  Color(0xFFD500F9), // magenta
  Color(0xFF26A69A), // teal
  Color(0xFFFFCC80), // peach
  Color(0xFF81D4FA), // sky
  Color(0xFF8B0000), // maroon
  Color(0xFF827717), // olive
  Color(0xFFB39DDB), // lavender
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
  Icons.water_drop,
  Icons.eco,
  Icons.cloud,
  Icons.pentagon,
  Icons.star_border,
  Icons.ac_unit,
  Icons.wb_sunny,
  Icons.park,
];

class BallSortGame extends StatefulWidget {
  const BallSortGame({super.key, required this.difficulty, required this.level});
  final BsDifficulty difficulty;
  final int level;

  @override
  State<BallSortGame> createState() => _BallSortGameState();
}

class _BallSortGameState extends State<BallSortGame> {
  late int _level;
  late bool _markers;
  late BallSortState _state;
  final List<BallSortState> _history = [];
  final List<GlobalKey> _keys = [];
  int? _selected;
  int _lastDest = -1;
  int _lastCount = 0;
  Offset _lastFrom = Offset.zero;
  int _moveSerial = 0;
  bool _won = false;

  BsDifficulty get _diff => widget.difficulty;

  @override
  void initState() {
    super.initState();
    _markers = Storage.getBool(_kMarkersKey, _diff == BsDifficulty.hard || _diff == BsDifficulty.extreme);
    _load(widget.level.clamp(1, kBsLevelCount));
  }

  GlobalKey _keyFor(int i) {
    while (_keys.length <= i) {
      _keys.add(GlobalKey());
    }
    return _keys[i];
  }

  /// Screen-space top-left of a tube, or null if not laid out.
  Offset? _tubePos(int i) {
    final box = _keyFor(i).currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return null;
    return box.localToGlobal(Offset.zero);
  }

  void _load(int level) {
    _level = level;
    bsOnStart(_diff, level);
    Storage.setInt(bsKey(_diff, 'level'), level);
    _state = generateLevel(_diff, level);
    _history.clear();
    _selected = null;
    _lastDest = -1;
    _lastCount = 0;
    _won = false;
  }

  /// Restart / replay: a bought level spends one of its plays; when none are
  /// left the skip offer is shown again, otherwise back to the level grid.
  Future<void> _restart() async {
    AppAudio.play(Sound.tap);
    final ok = await bsEnsurePlayable(context, _diff, _level);
    if (!mounted) return;
    if (!ok) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _load(_level));
  }

  void _undo() {
    if (_history.isEmpty) return;
    AppAudio.play(Sound.tap);
    setState(() {
      _state = _history.removeLast();
      _selected = null;
      _lastDest = -1;
      _won = false;
    });
  }

  bool _offerOpen = false;

  Future<void> _addTube() async {
    if (_state.canAddTube) {
      AppAudio.play(Sound.tap);
      setState(() {
        _history.add(_state.clone());
        _state.addTube();
      });
      return;
    }
    if (!_state.canBuyTube || _offerOpen || _won) return;
    // Free tubes used up: offer an extra tube for coins / an ad.
    _offerOpen = true;
    final paid = await showContinueOffer(context, OfferKind.extraLife);
    _offerOpen = false;
    if (!mounted || !paid || _won) return;
    AppAudio.play(Sound.success);
    setState(() {
      // Bought tubes are permanent for this level: undo must not take them away.
      _state.addPaidTube();
      for (final h in _history) {
        h.addPaidTube();
      }
    });
  }

  void _tap(int i) {
    if (_won) return;
    setState(() {
      final sel = _selected;
      if (sel == null) {
        if (_state.tubes[i].isNotEmpty) {
          _selected = i;
          AppAudio.play(Sound.tap);
        }
      } else if (sel == i) {
        _selected = null;
        AppAudio.play(Sound.tap);
      } else if (_state.canPour(sel, i)) {
        final srcPos = _tubePos(sel);
        final dstPos = _tubePos(i);
        _lastFrom = (srcPos != null && dstPos != null) ? srcPos - dstPos : Offset.zero;
        _history.add(_state.clone());
        _lastCount = _state.pour(sel, i);
        _lastDest = i;
        _moveSerial++;
        _selected = null;
        final dt = _state.tubes[i];
        final done = dt.length == _state.capacity && dt.every((c) => c == dt.first);
        AppAudio.play(done ? Sound.success : Sound.pop);
        if (_state.isSolved) _onWin();
      } else {
        if (_state.tubes[i].isNotEmpty) {
          AppAudio.play(Sound.fail);
          AppAudio.haptic();
        }
        _selected = _state.tubes[i].isNotEmpty ? i : null;
      }
    });
  }

  void _onWin() {
    _won = true;
    LevelGate.onCleared(bsGatePrefix(_diff), _level);
    // Advance the free-in-sequence level past every cleared level (skipped
    // levels that were bought and cleared count too).
    var unlocked = bsUnlockedInSequence(_diff);
    if (_level >= unlocked) {
      if (_level == unlocked) unlocked++;
      while (unlocked <= kBsLevelCount && bsStars(_diff, unlocked) > 0) {
        unlocked++;
      }
      Storage.setInt(bsKey(_diff, 'unlocked'), unlocked);
    }
    final key = bsKey(_diff, 'best.$_level');
    final best = Storage.getInt(key, 0);
    if (best == 0 || _state.moves < best) Storage.setInt(key, _state.moves);
    final stars = starsFor(_diff, _level, _state.moves);
    final skey = bsKey(_diff, 'stars.$_level');
    if (stars > Storage.getInt(skey)) Storage.setInt(skey, stars);
    Rewards.onLevelComplete('ball_sort', '${_diff.id}-L$_level', stars: stars);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _showWin(stars);
    });
  }

  void _showWin(int stars) {
    showPremiumDialog(
      context,
      title: tr('ball_sort.level_done', {'n': _level}),
      message: tr('ball_sort.solved_msg', {'moves': _state.moves, 'par': parMoves(_diff, _level)}),
      emoji: '🧪',
      color: bsAccent,
      stars: stars,
      actions: [
        DialogAction(tr('common.replay'), _restart),
        if (_level < kBsLevelCount)
          DialogAction(tr('common.next_level'), () => setState(() => _load(_level + 1)), primary: true),
      ],
    );
  }

  Widget _tubeAt(int i, double ball) => _TubeView(
        key: _keyFor(i),
        balls: _state.tubes[i],
        capacity: _state.capacity,
        ball: ball,
        selected: _selected == i,
        lifted: _selected == i ? _state.topRun(i) : 0,
        markers: _markers,
        dropCount: _lastDest == i ? _lastCount : 0,
        from: _lastDest == i ? _lastFrom : Offset.zero,
        serial: _moveSerial,
        onTap: () => _tap(i),
      );

  @override
  Widget build(BuildContext context) {
    final n = _state.tubes.length;
    return GameScaffold(
      title: tr('ball_sort.title_tier', {'tier': bsTierName(_diff)}),
      tint: bsAccent,
      actions: [
        BarAction(
          icon: _markers ? Icons.accessibility_new : Icons.accessibility_outlined,
          tooltip: tr('ball_sort.markers'),
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
              _Pill(icon: Icons.grid_view_rounded, label: tr('common.level_n', {'n': _level}), onTap: () => Navigator.of(context).maybePop()),
              const SizedBox(width: 10),
              _Pill(icon: Icons.swap_vert_rounded, label: tr('ball_sort.moves_n', {'n': _state.moves})),
            ]),
          ),
          Expanded(
            child: LayoutBuilder(builder: (context, c) {
              // Choose the layout (tubes per row) giving the biggest balls that
              // still fit the available height; otherwise scroll.
              const minBall = 26.0, maxBall = 52.0;
              final cap = _state.capacity;
              double bestBall = 0;
              var perRow = n;
              for (var pr = n; pr >= 1; pr--) {
                final rows = (n + pr - 1) ~/ pr;
                var b = math.min(maxBall, (c.maxWidth - 16) / pr / 1.5);
                if (b < minBall) continue;
                final perBall = rows * (cap + 0.9) + (rows - 1) * 0.6;
                final byH = (c.maxHeight - 8 - rows * 16) / perBall;
                if (byH < b) b = byH;
                if (b > bestBall) {
                  bestBall = b;
                  perRow = pr;
                }
              }
              if (bestBall < minBall) {
                bestBall = minBall;
                perRow = math.max(1, math.min(n, ((c.maxWidth - 16) / (minBall * 1.5)).floor()));
              }
              final ball = bestBall;
              final spacing = ball * 0.3;
              final runSpacing = ball * 0.6;
              final rowsList = <List<int>>[];
              for (var i = 0; i < n; i += perRow) {
                rowsList.add([for (var j = i; j < math.min(n, i + perRow); j++) j]);
              }
              return Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var r = 0; r < rowsList.length; r++) ...[
                        if (r > 0) SizedBox(height: runSpacing),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var k = 0; k < rowsList[r].length; k++) ...[
                              if (k > 0) SizedBox(width: spacing),
                              _tubeAt(rowsList[r][k], ball),
                            ],
                          ],
                        ),
                      ],
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
                _Pill(icon: Icons.undo_rounded, label: tr('common.undo'), onTap: _history.isEmpty ? null : _undo, big: true),
                _Pill(icon: Icons.refresh_rounded, label: tr('common.restart'), onTap: _restart, big: true),
                _Pill(
                    icon: Icons.add_rounded,
                    label: _state.canAddTube
                        ? tr('ball_sort.tube_n', {'n': kMaxExtraTubes - _state.extraUsed})
                        : tr('ball_sort.tube_buy'),
                    onTap: _state.canAddTube || _state.canBuyTube ? _addTube : null,
                    big: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const bsAccent = Color(0xFF2EE6A8);

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
          Icon(icon, size: big ? 20 : 18, color: off ? Pal.textDim : bsAccent),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: off ? Pal.textDim : Pal.text, fontWeight: FontWeight.w700, fontSize: big ? 15 : 14)),
        ]),
      ),
    );
  }
}

class _TubeView extends StatelessWidget {
  const _TubeView({
    super.key,
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
    final glowColor = solved ? _palette[balls.first % _palette.length] : bsAccent;
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
                      colors: [bsAccent.withValues(alpha: 0.16), Colors.transparent],
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
