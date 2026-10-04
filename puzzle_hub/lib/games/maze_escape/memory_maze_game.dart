import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/levels.dart';
import 'logic/maze.dart';
import 'maze_escape_screen.dart';
import 'progress.dart';

/// Memory Maze: study the maze, then walk it in the dark from memory.
class MemoryMazeGame extends StatefulWidget {
  const MemoryMazeGame({super.key, required this.level, this.tier = MazeTier.easy});
  final int level;
  final MazeTier tier;

  @override
  State<MemoryMazeGame> createState() => _MemoryMazeGameState();
}

class _MemoryMazeGameState extends State<MemoryMazeGame> with TickerProviderStateMixin {
  static const int _fadeMs = 700;
  static const int _peekInMs = 200;
  static const int _peekOutMs = 400;

  late MemLevel cfg;
  late Maze maze;
  late int _cur;
  final ValueNotifier<Offset> _pos = ValueNotifier(Offset.zero);
  late final AnimationController _stepCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
  late final AnimationController _previewCtl = AnimationController(vsync: this)..addListener(_onPreviewTick);
  late final AnimationController _peekCtl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: _peekInMs + MemLevel.peekMs + _peekOutMs));
  late final AnimationController _bumpCtl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  final Stopwatch _soundWatch = Stopwatch()..start();

  int moves = 0;
  int bumps = 0;
  int peeksLeft = 0;
  int peeksUsed = 0;
  int _bumpCell = -1;
  int _bumpDir = -1;
  final Set<int> _visited = {};
  bool _started = false;
  bool _walking = false;
  bool _done = false;
  Offset _acc = Offset.zero;
  bool _fired = false;
  int _attempt = 0;

  /// Bumps allowed (0 = unlimited); grows when the player buys a continue.
  int maxBumps = 0;
  int continuesUsed = 0;
  static const maxContinues = 2;

  int get _totalPreviewMs => cfg.previewMs + _fadeMs;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    cfg = MemLevel.of(widget.tier, widget.level);
    maze = Maze.generate(cfg.seed, cfg.size, cfg.size);
    _cur = maze.start;
    _pos.value = Offset(maze.xOf(_cur).toDouble(), maze.yOf(_cur).toDouble());
    moves = 0;
    bumps = 0;
    peeksLeft = cfg.peeks;
    peeksUsed = 0;
    maxBumps = cfg.maxBumps;
    continuesUsed = 0;
    _attempt++;
    _bumpCell = -1;
    _bumpDir = -1;
    _visited
      ..clear()
      ..add(_cur);
    _started = false;
    _walking = false;
    _done = false;
    _peekCtl.reset();
    _bumpCtl.reset();
    _previewCtl
      ..duration = Duration(milliseconds: _totalPreviewMs)
      ..forward(from: 0);
  }

  @override
  void dispose() {
    _stepCtl.dispose();
    _previewCtl.dispose();
    _peekCtl.dispose();
    _bumpCtl.dispose();
    _pos.dispose();
    super.dispose();
  }

  double get _elapsedPreviewMs => _previewCtl.value * _totalPreviewMs;

  void _onPreviewTick() {
    if (_started || _elapsedPreviewMs < cfg.previewMs) return;
    _started = true;
    AppAudio.play(Sound.tap);
    if (mounted) setState(() {});
  }

  /// Skip the rest of the preview (walls fade out immediately).
  void _ready() {
    if (_started) return;
    _previewCtl.value = cfg.previewMs / _totalPreviewMs;
    _previewCtl.forward();
  }

  /// 0..1 opacity of the full map (preview or peek).
  double get mapOpacity {
    final e = _elapsedPreviewMs;
    final preview = e < cfg.previewMs ? 1.0 : ((_totalPreviewMs - e) / _fadeMs).clamp(0.0, 1.0);
    var peek = 0.0;
    if (_peekCtl.isAnimating) {
      final ms = _peekCtl.value * (_peekInMs + MemLevel.peekMs + _peekOutMs);
      final total = _peekInMs + MemLevel.peekMs + _peekOutMs;
      peek = min(1.0, min(ms / _peekInMs, (total - ms) / _peekOutMs)).clamp(0.0, 1.0);
    }
    return max(preview, peek);
  }

  void _restart() => setState(_setup);

  Future<void> _step(int dir) async {
    if (!_started || _walking || _done) return;
    if (!maze.canMove(_cur, dir)) {
      _bump(dir);
      return;
    }
    final next = maze.neighbour(_cur, dir);
    if (_soundWatch.elapsedMilliseconds > 110) {
      AppAudio.play(Sound.slide, volume: 0.5);
      _soundWatch.reset();
    }
    _walking = true;
    final from = Offset(maze.xOf(_cur).toDouble(), maze.yOf(_cur).toDouble());
    final to = Offset(maze.xOf(next).toDouble(), maze.yOf(next).toDouble());
    void l() => _pos.value = Offset.lerp(from, to, _stepCtl.value)!;
    _stepCtl.addListener(l);
    await _stepCtl.forward(from: 0);
    _stepCtl.removeListener(l);
    if (!mounted) return;
    _walking = false;
    _cur = next;
    _pos.value = to;
    moves++;
    _visited.add(next);
    if (_cur == maze.exit) {
      _win();
    } else {
      setState(() {});
    }
  }

  void _bump(int dir) {
    AppAudio.play(Sound.fail, volume: 0.6);
    AppAudio.haptic(true);
    setState(() {
      bumps++;
      _bumpCell = _cur;
      _bumpDir = dir;
    });
    _bumpCtl.forward(from: 0);
    if (maxBumps > 0 && bumps >= maxBumps) _lose();
  }

  Future<void> _peek() async {
    if (!_started || _done || _peekCtl.isAnimating) return;
    if (peeksLeft <= 0) {
      final a = _attempt;
      final ok = await showContinueOffer(context, OfferKind.hint);
      if (!ok || !mounted || a != _attempt || _done) return;
      peeksLeft++;
    }
    AppAudio.play(Sound.pop);
    setState(() {
      peeksLeft--;
      peeksUsed++;
    });
    _peekCtl.forward(from: 0);
  }

  Future<void> _win() async {
    _done = true;
    final stars = memStars(bumps, peeksUsed);
    MazeProgress.save(widget.tier, widget.level, stars, mode: MazeMode.memory);
    Rewards.onLevelComplete('maze_escape', 'memory-${widget.tier.name}-L${widget.level}', stars: stars);
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    final hasNext = widget.level < kLevelCount;
    showPremiumDialog(
      context,
      title: tr('maze_escape.mem_win_title'),
      emoji: '🧠',
      stars: stars,
      message: peeksUsed > 0
          ? tr('maze_escape.mem_win_msg_peeks', {'moves': moves, 'bumps': bumps, 'peeks': peeksUsed})
          : tr('maze_escape.mem_win_msg', {'moves': moves, 'bumps': bumps}),
      actions: [
        DialogAction(tr('common.levels'), () => Navigator.of(context).maybePop()),
        DialogAction(tr('common.replay'), _restart),
        if (hasNext)
          DialogAction(tr('common.next_level'), () => openMazeLevel(context, widget.tier, widget.level + 1, replace: true, mode: MazeMode.memory),
              primary: true),
      ],
    );
  }

  Future<void> _lose() async {
    _done = true;
    setState(() {});
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    if (continuesUsed < maxContinues) {
      final a = _attempt;
      final ok = await showContinueOffer(context, OfferKind.extraLife);
      if (!mounted || a != _attempt) return;
      if (ok) {
        setState(() {
          continuesUsed++;
          maxBumps += 3;
          _done = false;
        });
        return;
      }
    }
    if (!mounted) return;
    showPremiumDialog(
      context,
      title: tr('maze_escape.mem_lose_title'),
      emoji: '💥',
      color: Pal.danger,
      message: tr('maze_escape.mem_lose_msg', {'n': maxBumps}),
      actions: [
        DialogAction(tr('common.levels'), () => Navigator.of(context).maybePop()),
        DialogAction(tr('common.retry'), _restart, primary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('maze_escape.mem_title', {'tier': mazeTierLabel(widget.tier), 'n': widget.level}),
      tint: kMemColor,
      actions: [
        BarAction(icon: Icons.refresh_rounded, tooltip: tr('common.restart'), onTap: _restart),
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
                      _step(_acc.dx.abs() > _acc.dy.abs() ? (_acc.dx > 0 ? 1 : 3) : (_acc.dy > 0 ? 2 : 0));
                    }
                  },
                  child: SizedBox(
                    width: side,
                    height: side,
                    child: Stack(children: [
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: kMemColor.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: -6)],
                          ),
                          child: CustomPaint(painter: _MemPainter(this)),
                        ),
                      ),
                      if (!_started) Positioned.fill(child: _previewOverlay()),
                    ]),
                  ),
                ).animate().fadeIn(duration: 300.ms);
              }),
            ),
          ),
        ),
        _controls(),
      ]),
    );
  }

  Widget _previewOverlay() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          AnimatedBuilder(
            animation: _previewCtl,
            builder: (context, _) {
              final left = max(0.0, cfg.previewMs - _elapsedPreviewMs);
              return Container(
                width: 58,
                height: 58,
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.55)),
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(
                    child: CircularProgressIndicator(
                      value: left / cfg.previewMs,
                      strokeWidth: 4,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation(kMemColor),
                    ),
                  ),
                  Text('${(left / 1000).ceil()}',
                      style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
                ]),
              );
            },
          ),
          const SizedBox(width: 10),
          GlassCard(
            key: const ValueKey('mem-ready'),
            blur: 0,
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            gradient: Pal.accent(kMemColor),
            onTap: _ready,
            child: Text(tr('maze_escape.ready'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ]),
      ),
    ).animate().fadeIn(duration: 250.ms);
  }

  Widget _hud() {
    Widget chip(String t, {Color color = Pal.text}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
          child: Text(t, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 13)),
        );
    final bumpTxt = maxBumps > 0
        ? tr('maze_escape.bumps_max', {'n': bumps, 'max': maxBumps})
        : tr('maze_escape.bumps', {'n': bumps});
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
        chip(_started ? tr('maze_escape.hud_moves', {'n': moves}) : tr('maze_escape.memorise'), color: _started ? Pal.text : kMemColor),
        chip(bumpTxt, color: bumps > 0 ? Pal.danger : Pal.text),
        chip('${cfg.size}x${cfg.size}'),
      ]),
    );
  }

  Widget _controls() {
    Widget b(IconData i, int d) => Padding(
          padding: const EdgeInsets.all(3),
          child: GlassCard(
            blur: 0,
            radius: 16,
            padding: const EdgeInsets.all(10),
            onTap: () => _step(d),
            child: Icon(i, color: Pal.text, size: 26),
          ),
        );
    // Stays tappable when out of free peeks (offers a paid one).
    final canPeek = _started && !_done;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Opacity(
          opacity: canPeek ? 1 : 0.4,
          child: GlassCard(
            key: const ValueKey('mem-peek'),
            blur: 0,
            radius: 18,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            glow: canPeek ? kMemColor : null,
            onTap: _peek,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.visibility_rounded, color: Pal.text, size: 24),
              const SizedBox(height: 2),
              Text(tr('maze_escape.peek', {'n': peeksLeft}), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(width: 18),
        Column(mainAxisSize: MainAxisSize.min, children: [
          b(Icons.keyboard_arrow_up_rounded, 0),
          Row(mainAxisSize: MainAxisSize.min, children: [
            b(Icons.keyboard_arrow_left_rounded, 3),
            b(Icons.keyboard_arrow_down_rounded, 2),
            b(Icons.keyboard_arrow_right_rounded, 1),
          ]),
        ]),
      ]),
    );
  }
}

class _MemPainter extends CustomPainter {
  _MemPainter(this.s) : super(repaint: Listenable.merge([s._pos, s._previewCtl, s._peekCtl, s._bumpCtl]));
  final _MemoryMazeGameState s;

  static final Map<String, TextPainter> _tp = {};

  static void _emoji(Canvas canvas, String t, Offset c, double size) {
    final key = '$t${size.round()}';
    final p = _tp.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: size)),
        textDirection: TextDirection.ltr,
      )..layout();
    });
    p.paint(canvas, c - Offset(p.width / 2, p.height / 2));
  }

  static void _wallLine(Canvas canvas, Rect r, int dir, Paint p) {
    switch (dir) {
      case 0:
        canvas.drawLine(r.topLeft, r.topRight, p);
      case 1:
        canvas.drawLine(r.topRight, r.bottomRight, p);
      case 2:
        canvas.drawLine(r.bottomLeft, r.bottomRight, p);
      default:
        canvas.drawLine(r.topLeft, r.bottomLeft, p);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final m = s.maze;
    final cs = size.width / m.w;
    final pos = s._pos.value;
    final map = s.mapOpacity;
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(20));

    canvas.drawRRect(rr, Paint()..color = const Color(0xFF060914));
    canvas.save();
    canvas.clipRRect(rr);

    final wall = Paint()
      ..strokeWidth = max(2.0, cs * 0.09)
      ..strokeCap = StrokeCap.round;
    final fill = Paint();
    final dr = max(1.5, cs * 0.07);

    for (var i = 0; i < m.cellCount; i++) {
      final rect = Rect.fromLTWH(m.xOf(i) * cs, m.yOf(i) * cs, cs, cs);
      final visited = s._visited.contains(i);
      final floor = max(map, visited ? 0.3 : 0.0);
      if (floor > 0.02) {
        fill.color = const Color(0xFF173253).withValues(alpha: floor);
        canvas.drawRect(rect, fill);
      }
      if (visited) {
        fill.color = kMemColor.withValues(alpha: 0.12);
        canvas.drawRect(rect, fill);
      }
      if (map > 0.02) {
        wall.color = const Color(0xFF9FE6FF).withValues(alpha: map);
        for (var d = 0; d < 4; d++) {
          if (!m.canMove(i, d)) _wallLine(canvas, rect, d, wall);
        }
      }
      if (i == m.start) {
        canvas.drawCircle(rect.center, cs * 0.3,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = dr
              ..color = Pal.success.withValues(alpha: max(0.35, 0.7 * map)));
      }
    }

    // Faint outer frame so the bounds stay readable in the dark.
    canvas.drawRect(
        (Offset.zero & size).deflate(1),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF9FE6FF).withValues(alpha: 0.18));

    // Bump flash: the walls around the player light up, the bumped one red.
    final flash = s._bumpCtl.isAnimating ? 1 - s._bumpCtl.value : 0.0;
    if (flash > 0 && s._bumpCell >= 0) {
      final c = s._bumpCell;
      final rect = Rect.fromLTWH(m.xOf(c) * cs, m.yOf(c) * cs, cs, cs);
      final p = Paint()
        ..strokeWidth = max(2.0, cs * 0.09)
        ..strokeCap = StrokeCap.round;
      for (var d = 0; d < 4; d++) {
        if (m.canMove(c, d) || d == s._bumpDir) continue;
        p.color = const Color(0xFF9FE6FF).withValues(alpha: 0.7 * flash);
        _wallLine(canvas, rect, d, p);
      }
      final glow = Paint()
        ..strokeWidth = max(4.0, cs * 0.22)
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.12)
        ..color = Pal.danger.withValues(alpha: 0.8 * flash);
      _wallLine(canvas, rect, s._bumpDir, glow);
      p.color = Pal.danger.withValues(alpha: flash);
      p.strokeWidth = max(2.5, cs * 0.12);
      _wallLine(canvas, rect, s._bumpDir, p);
    }

    // Exit: always visible so the goal is known.
    final er = Rect.fromLTWH(m.xOf(m.exit) * cs, m.yOf(m.exit) * cs, cs, cs);
    canvas.drawCircle(
        er.center,
        cs * 0.45,
        Paint()
          ..color = Pal.gold.withValues(alpha: 0.3)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.25));
    _emoji(canvas, '🚪', er.center, cs * 0.62);

    // Player.
    final pc = Offset((pos.dx + 0.5) * cs, (pos.dy + 0.5) * cs);
    canvas.drawCircle(
        pc,
        cs * 0.42,
        Paint()
          ..color = kMemColor.withValues(alpha: 0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cs * 0.2));
    canvas.drawCircle(pc, cs * 0.32, Paint()..shader = Pal.accent(kMemColor).createShader(Rect.fromCircle(center: pc, radius: cs * 0.32)));
    _emoji(canvas, '🧍', pc, cs * 0.46);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MemPainter old) => true;
}
