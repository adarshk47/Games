import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/levels.dart';
import 'logic/maze.dart';
import 'maze_escape_screen.dart';
import 'progress.dart';

/// Labyrinth mode: swipe the explorer through a perfect maze to the exit.
class LabyrinthGame extends StatefulWidget {
  const LabyrinthGame({super.key, required this.level, this.tier = MazeTier.easy});
  final int level;
  final MazeTier tier;

  @override
  State<LabyrinthGame> createState() => _LabyrinthGameState();
}

class _LabyrinthGameState extends State<LabyrinthGame> with TickerProviderStateMixin {
  late LabLevel cfg;
  late Maze maze;
  late int optimal;
  late int limit;
  late int _cur;
  final ValueNotifier<Offset> _pos = ValueNotifier(Offset.zero);
  late final AnimationController _stepCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 95));
  late final AnimationController _hintCtl = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  int moves = 0;
  int torchesLeft = 0;
  int torchesUsed = 0;
  final Set<int> _seen = {};
  final Set<int> _visited = {};
  final Set<int> _deadEnds = {};
  final List<int> _trail = [];
  List<int> _hintPath = const [];
  bool _walking = false;
  bool _done = false;
  Offset _acc = Offset.zero;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    cfg = LabLevel.of(widget.tier, widget.level);
    maze = Maze.generate(cfg.seed, cfg.size, cfg.size);
    optimal = maze.optimalMoves;
    limit = cfg.moveLimit(optimal);
    _cur = maze.start;
    _pos.value = Offset(maze.xOf(_cur).toDouble(), maze.yOf(_cur).toDouble());
    moves = 0;
    torchesLeft = cfg.torches;
    torchesUsed = 0;
    _seen.clear();
    _visited
      ..clear()
      ..add(_cur);
    _deadEnds.clear();
    _trail
      ..clear()
      ..add(_cur);
    _hintPath = const [];
    _walking = false;
    _done = false;
    _hintCtl.reset();
    _markSeen();
  }

  @override
  void dispose() {
    _stepCtl.dispose();
    _hintCtl.dispose();
    _pos.dispose();
    super.dispose();
  }

  void _markSeen() {
    if (cfg.fogRadius == 0) return;
    final px = maze.xOf(_cur), py = maze.yOf(_cur);
    final r = cfg.fogRadius;
    for (var y = py - r; y <= py + r; y++) {
      for (var x = px - r; x <= px + r; x++) {
        if (x < 0 || y < 0 || x >= maze.w || y >= maze.h) continue;
        final dx = x - px, dy = y - py;
        if (sqrt(dx * dx + dy * dy) <= r + 0.3) _seen.add(maze.idx(x, y));
      }
    }
  }

  void _restart() {
    setState(_setup);
  }

  Future<void> _slide(int dir) async {
    if (_walking || _done) return;
    if (!maze.canMove(_cur, dir)) {
      AppAudio.haptic();
      return;
    }
    var steps = <int>[];
    var c = _cur;
    var d = dir;
    while (steps.length < 1000) {
      c = maze.neighbour(c, d);
      steps.add(c);
      if (c == maze.exit || maze.openings(c) != 2) break;
      final back = opposite(d);
      d = [0, 1, 2, 3].firstWhere((k) => k != back && maze.canMove(c, k));
    }
    if (limit > 0 && steps.length > limit - moves) steps = steps.sublist(0, limit - moves);
    _walking = true;
    var stepNo = 0;
    for (final next in steps) {
      if (stepNo++ % 2 == 0) AppAudio.play(Sound.slide, volume: 0.5);
      final from = Offset(maze.xOf(_cur).toDouble(), maze.yOf(_cur).toDouble());
      final to = Offset(maze.xOf(next).toDouble(), maze.yOf(next).toDouble());
      void l() => _pos.value = Offset.lerp(from, to, _stepCtl.value)!;
      _stepCtl.addListener(l);
      await _stepCtl.forward(from: 0);
      _stepCtl.removeListener(l);
      if (!mounted) return;
      _cur = next;
      _pos.value = to;
      moves++;
      _visited.add(next);
      _trail.add(next);
      if (_trail.length > 600) _trail.removeRange(0, 100);
      _markSeen();
      setState(() {});
    }
    _walking = false;
    if (maze.isDeadEnd(_cur)) {
      _deadEnds.add(_cur);
      AppAudio.play(Sound.fail, volume: 0.5);
      AppAudio.haptic();
    }
    if (_cur == maze.exit) {
      _win();
    } else if (limit > 0 && moves >= limit) {
      _lose();
    } else {
      setState(() {});
    }
  }

  void _useTorch() {
    if (_done || torchesLeft <= 0 || _hintCtl.isAnimating) return;
    AppAudio.play(Sound.pop);
    setState(() {
      torchesLeft--;
      torchesUsed++;
      _hintPath = maze.solve(from: _cur);
    });
    _hintCtl.forward(from: 0);
  }

  Future<void> _win() async {
    _done = true;
    final stars = labStars(moves, optimal, torchesUsed: torchesUsed);
    MazeProgress.save(widget.tier, widget.level, stars);
    Rewards.onLevelComplete('maze_escape', 'labyrinth-${widget.tier.name}-L${widget.level}', stars: stars);
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final hasNext = widget.level < kLevelCount;
    showPremiumDialog(
      context,
      title: 'Bahar nikal gaye!',
      emoji: '🚪',
      stars: stars,
      message: 'Escaped in $moves moves (best possible: $optimal).',
      actions: [
        DialogAction('Levels', () => Navigator.of(context).maybePop()),
        DialogAction('Replay', _restart),
        if (hasNext) DialogAction('Next', () => openMazeLevel(context, widget.tier, widget.level + 1, replace: true), primary: true),
      ],
    );
  }

  Future<void> _lose() async {
    _done = true;
    AppAudio.play(Sound.fail);
    AppAudio.haptic(true);
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    showPremiumDialog(
      context,
      title: 'Moves khatam!',
      emoji: '😵',
      color: Pal.danger,
      message: 'You ran out of the $limit moves allowed. Try a smarter route.',
      actions: [
        DialogAction('Levels', () => Navigator.of(context).maybePop()),
        DialogAction('Retry', _restart, primary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Labyrinth ${widget.tier.label} ${widget.level}',
      tint: const Color(0xFF7C5CFF),
      actions: [
        BarAction(icon: Icons.flashlight_on_rounded, tooltip: 'Torch', onTap: torchesLeft > 0 && !_done ? _useTorch : null),
        BarAction(icon: Icons.refresh_rounded, tooltip: 'Restart', onTap: _restart),
      ],
      body: Column(children: [
        _hud(),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: LayoutBuilder(builder: (context, c) {
                final side = min(c.maxWidth, c.maxHeight);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) {
                    _acc = Offset.zero;
                    _fired = false;
                  },
                  onPanUpdate: (u) {
                    if (_fired) return;
                    _acc += u.delta;
                    if (_acc.distance > 22) {
                      _fired = true;
                      final dir = _acc.dx.abs() > _acc.dy.abs() ? (_acc.dx > 0 ? 1 : 3) : (_acc.dy > 0 ? 2 : 0);
                      _slide(dir);
                    }
                  },
                  child: Container(
                    width: side,
                    height: side,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C5CFF).withValues(alpha: 0.35), blurRadius: 30, spreadRadius: -6)],
                    ),
                    child: CustomPaint(
                      painter: _MazePainter(this),
                    ),
                  ),
                ).animate().fadeIn(duration: 300.ms);
              }),
            ),
          ),
        ),
        _dpad(),
      ]),
    );
  }


  Widget _hud() {
    Widget chip(String t, {Color color = Pal.text}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
          child: Text(t, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        );
    final nearLimit = limit > 0 && limit - moves <= 8;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
        chip('Moves $moves${limit > 0 ? ' / $limit' : ''}', color: nearLimit ? Pal.danger : Pal.text),
        chip('🔦 $torchesLeft'),
        chip('${cfg.size}x${cfg.size}'),
        if (cfg.fogRadius > 0) chip('🌫️ Fog', color: Pal.textDim),
        if (_deadEnds.isNotEmpty) chip('✖ ${_deadEnds.length} dead ends', color: Pal.danger),
      ]),
    );
  }

  Widget _dpad() {
    Widget b(IconData i, int d) => Padding(
          padding: const EdgeInsets.all(3),
          child: GlassCard(
            blur: 0,
            radius: 16,
            padding: const EdgeInsets.all(10),
            onTap: () => _slide(d),
            child: Icon(i, color: Pal.text, size: 26),
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        b(Icons.keyboard_arrow_up_rounded, 0),
        Row(mainAxisSize: MainAxisSize.min, children: [
          b(Icons.keyboard_arrow_left_rounded, 3),
          b(Icons.keyboard_arrow_down_rounded, 2),
          b(Icons.keyboard_arrow_right_rounded, 1),
        ]),
      ]),
    );
  }
}

class _MazePainter extends CustomPainter {
  _MazePainter(this.s) : super(repaint: Listenable.merge([s._pos, s._hintCtl]));
  final _LabyrinthGameState s;

  static final Map<String, TextPainter> _tp = {};

  static void _emoji(Canvas canvas, String t, Offset c, double size) {
    final key = '$t${size.round()}';
    final p = _tp.putIfAbsent(key, () {
      final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: size)),
        textDirection: TextDirection.ltr,
      )..layout();
      return tp;
    });
    p.paint(canvas, c - Offset(p.width / 2, p.height / 2));
  }

  double get _hintOpacity {
    final t = s._hintCtl.value;
    if (!s._hintCtl.isAnimating && t == 0) return 0;
    return min(1.0, min(t / 0.08, (1 - t) / 0.15)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = s.maze;
    final cs = size.width / m.w;
    final fog = s.cfg.fogRadius;
    final pos = s._pos.value;
    final hint = _hintOpacity;
    final hintSet = hint > 0 ? s._hintPath.toSet() : const <int>{};

    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)), Paint()..color = const Color(0xFF100B2E));
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20)));

    final wall = Paint()
      ..strokeWidth = max(2.0, cs * 0.09)
      ..strokeCap = StrokeCap.round;
    final fill = Paint();
    final dr = max(1.5, cs * 0.07);

    for (var i = 0; i < m.cellCount; i++) {
      final x = m.xOf(i), y = m.yOf(i);
      var b = 1.0;
      if (fog > 0) {
        final dist = sqrt(pow(x - pos.dx, 2) + pow(y - pos.dy, 2));
        final vis = ((fog + 0.8 - dist) / 1.2).clamp(0.0, 1.0);
        b = max(vis, s._seen.contains(i) ? 0.42 : 0.0);
      }
      if (hint > 0 && hintSet.contains(i)) b = max(b, 0.9 * hint);
      if (b < 0.03) continue;
      final rect = Rect.fromLTWH(x * cs, y * cs, cs, cs);
      fill.color = const Color(0xFF2B2268).withValues(alpha: b);
      canvas.drawRect(rect, fill);
      if (s._visited.contains(i)) {
        fill.color = Pal.goldDeep.withValues(alpha: 0.16 * b);
        canvas.drawRect(rect, fill);
      }
      wall.color = const Color(0xFFB8A8FF).withValues(alpha: b);
      final a = rect.topLeft, bb = rect.topRight, c = rect.bottomRight, d = rect.bottomLeft;
      if (!m.canMove(i, 0)) canvas.drawLine(a, bb, wall);
      if (!m.canMove(i, 1)) canvas.drawLine(bb, c, wall);
      if (!m.canMove(i, 2)) canvas.drawLine(d, c, wall);
      if (!m.canMove(i, 3)) canvas.drawLine(a, d, wall);
      if (s._deadEnds.contains(i)) {
        final cc = rect.center;
        final k = cs * 0.2;
        final p = Paint()
          ..color = Pal.danger.withValues(alpha: b)
          ..strokeWidth = dr * 1.4
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(cc + Offset(-k, -k), cc + Offset(k, k), p);
        canvas.drawLine(cc + Offset(-k, k), cc + Offset(k, -k), p);
      }
      if (i == m.start) {
        canvas.drawCircle(rect.center, cs * 0.3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = dr
              ..color = Pal.success.withValues(alpha: 0.7 * b));
      }
      if (i == m.exit && b > 0.3) _emoji(canvas, '🚪', rect.center, cs * 0.7);
    }

    // Trail.
    if (s._trail.length > 1) {
      final path = Path();
      for (var k = 0; k < s._trail.length; k++) {
        final c = s._trail[k];
        final o = Offset((m.xOf(c) + 0.5) * cs, (m.yOf(c) + 0.5) * cs);
        k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cs * 0.1
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = Pal.gold.withValues(alpha: 0.4));
    }

    // Torch hint route.
    if (hint > 0 && s._hintPath.length > 1) {
      final path = Path();
      for (var k = 0; k < s._hintPath.length; k++) {
        final c = s._hintPath[k];
        final o = Offset((m.xOf(c) + 0.5) * cs, (m.yOf(c) + 0.5) * cs);
        k == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cs * 0.3
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.25)
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = Pal.success.withValues(alpha: 0.7 * hint));
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cs * 0.1
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round
            ..color = Colors.white.withValues(alpha: 0.9 * hint));
    }

    // Player.
    final pc = Offset((pos.dx + 0.5) * cs, (pos.dy + 0.5) * cs);
    if (fog > 0) {
      canvas.drawCircle(
          pc,
          cs * (fog + 0.8),
          Paint()
            ..shader = RadialGradient(colors: [Pal.gold.withValues(alpha: 0.16), Colors.transparent])
                .createShader(Rect.fromCircle(center: pc, radius: cs * (fog + 0.8))));
    }
    canvas.drawCircle(
        pc,
        cs * 0.4,
        Paint()
          ..color = Pal.gold.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.2));
    canvas.drawCircle(pc, cs * 0.34, Paint()..shader = Pal.accent(Pal.goldDeep).createShader(Rect.fromCircle(center: pc, radius: cs * 0.34)));
    _emoji(canvas, '🧍', pc, cs * 0.5);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MazePainter old) => true;
}
