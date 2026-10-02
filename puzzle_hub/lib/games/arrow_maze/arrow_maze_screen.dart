import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/arrow_maze_logic.dart';
import 'progress.dart';

const _tint = Color(0xFF7C9CFF);

Color _tierColor(MazeTier t) => switch (t) {
      MazeTier.easy => const Color(0xFF4ADE80),
      MazeTier.medium => const Color(0xFF7C9CFF),
      MazeTier.hard => const Color(0xFFFFB347),
      MazeTier.extreme => const Color(0xFFFF5C7A),
    };

IconData _tierIcon(MazeTier t) => switch (t) {
      MazeTier.easy => Icons.spa_rounded,
      MazeTier.medium => Icons.bolt_rounded,
      MazeTier.hard => Icons.local_fire_department_rounded,
      MazeTier.extreme => Icons.whatshot_rounded,
    };

/// Difficulty selection (entry point of the game).
class ArrowMazeScreen extends StatefulWidget {
  const ArrowMazeScreen({super.key});

  @override
  State<ArrowMazeScreen> createState() => _ArrowMazeScreenState();
}

class _ArrowMazeScreenState extends State<ArrowMazeScreen> {
  Future<void> _open(MazeTier tier) async {
    ArrowMazeProgress.setLastTier(tier);
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => _LevelGridPage(tier: tier),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final last = ArrowMazeProgress.lastTier;
    return GameScaffold(
      title: 'Arrow Maze',
      tint: _tint,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Text('Choose your challenge',
                style: TextStyle(
                    color: Pal.textDim,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
          for (var i = 0; i < MazeTier.values.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _TierCard(
                tier: MazeTier.values[i],
                isLast: MazeTier.values[i] == last,
                onTap: () => _open(MazeTier.values[i]),
              )
                  .animate(delay: (i * 90).ms)
                  .fadeIn(duration: 380.ms)
                  .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard(
      {required this.tier, required this.isLast, required this.onTap});
  final MazeTier tier;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    final done = ArrowMazeProgress.completed(tier);
    final frac = done / tier.count;
    return GlassCard(
      onTap: onTap,
      glow: color,
      radius: 26,
      padding: const EdgeInsets.all(18),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: isLast ? 0.38 : 0.28),
          color.withValues(alpha: 0.06),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: Pal.accent(color),
              boxShadow: [
                BoxShadow(
                    color: color.withValues(alpha: 0.6),
                    blurRadius: 20,
                    spreadRadius: -2)
              ],
            ),
            child: Icon(_tierIcon(tier), color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(tier.label,
                      style: const TextStyle(
                          color: Pal.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w900)),
                  if (isLast) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                        border:
                            Border.all(color: color.withValues(alpha: 0.7)),
                      ),
                      child: const Text('LAST PLAYED',
                          style: TextStyle(
                              color: Pal.text,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6)),
                    ),
                  ],
                ]),
                const SizedBox(height: 2),
                Text(tier.blurb,
                    style: const TextStyle(color: Pal.textDim, fontSize: 13)),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: frac,
                    minHeight: 7,
                    backgroundColor: Colors.white.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 6),
                Text('$done / ${tier.count} levels',
                    style: const TextStyle(
                        color: Pal.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Pal.textDim),
        ],
      ),
    );
  }
}

class _LevelGridPage extends StatefulWidget {
  const _LevelGridPage({required this.tier});
  final MazeTier tier;

  @override
  State<_LevelGridPage> createState() => _LevelGridPageState();
}

class _LevelGridPageState extends State<_LevelGridPage> {
  MazeTier get tier => widget.tier;

  Future<void> _open(int level) async {
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, _, _) => ArrowMazeGamePage(tier: tier, level: level),
        transitionsBuilder: (_, a, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: a, curve: Curves.easeOut),
          child: child,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final color = _tierColor(tier);
    return GameScaffold(
      title: 'Arrow Maze - ${tier.label}',
      tint: color,
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 90, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: tier.count,
        itemBuilder: (context, i) {
          final level = i + 1;
          final unlocked = ArrowMazeProgress.isUnlocked(tier, level);
          final done = ArrowMazeProgress.isDone(tier, level);
          return _LevelTile(
            level: level,
            color: color,
            unlocked: unlocked,
            done: done,
            stars: ArrowMazeProgress.stars(tier, level),
            onTap: () => _open(level),
          )
              .animate(delay: (math.min(i, 24) * 30).ms)
              .fadeIn(duration: 350.ms)
              .scale(
                  begin: const Offset(0.7, 0.7),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 450.ms);
        },
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile(
      {required this.level,
      required this.color,
      required this.unlocked,
      required this.done,
      required this.stars,
      required this.onTap});
  final int level, stars;
  final Color color;
  final bool unlocked, done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Gradient gradient = unlocked
        ? (done
            ? Pal.accent(color)
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  color.withValues(alpha: 0.38),
                  color.withValues(alpha: 0.12),
                ],
              ))
        : const LinearGradient(colors: [Color(0x14FFFFFF), Color(0x08FFFFFF)]);
    final tile = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient,
        border: Border.all(
            color: unlocked
                ? Colors.white.withValues(alpha: 0.4)
                : Pal.glassBorder),
        boxShadow: unlocked
            ? [
                BoxShadow(
                    color: color.withValues(alpha: done ? 0.5 : 0.28),
                    blurRadius: done ? 18 : 12,
                    spreadRadius: -2)
              ]
            : null,
      ),
      child: Center(
        child: unlocked
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$level',
                      style: const TextStyle(
                          color: Pal.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 2),
                  if (done)
                    StarRow(stars: stars, size: 15)
                  else
                    const SizedBox(height: 15),
                ],
              )
            : const Icon(Icons.lock_rounded, color: Pal.textDim, size: 24),
      ),
    );
    return unlocked
        ? Pressable(onTap: onTap, child: tile)
        : Opacity(opacity: 0.7, child: tile);
  }
}

class _Fx {
  _Fx(this.id, this.slide, this.startMs, this.durMs, this.travel);
  final int id;
  final bool slide; // false = shake
  final int startMs, durMs;
  final double travel; // slide distance in cells
}

class ArrowMazeGamePage extends StatefulWidget {
  const ArrowMazeGamePage({super.key, required this.tier, required this.level});
  final MazeTier tier;
  final int level;

  @override
  State<ArrowMazeGamePage> createState() => _ArrowMazeGamePageState();
}

class _ArrowMazeGamePageState extends State<ArrowMazeGamePage>
    with SingleTickerProviderStateMixin {
  late final MazeTier tier = widget.tier;
  int get maxLives => tier.lives;
  late int level = widget.level;
  late ArrowMazeBoard board;
  final Stopwatch _clock = Stopwatch()..start();
  final List<_Fx> _fx = [];
  late final AnimationController _tick = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1000));
  int lives = 3;
  int hintsLeft = 0;
  int moves = 0;
  int? hinted;
  bool over = false;
  int version = 0;
  int loadId = 0;

  @override
  void initState() {
    super.initState();
    _tick.addListener(_onTick);
    _load();
  }

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  void _load() {
    board = ArrowMazeLevels.generate(tier, level);
    _fx.clear();
    lives = maxLives;
    hintsLeft = tier.hints;
    moves = 0;
    hinted = null;
    over = false;
    version++;
    loadId++;
  }

  void _onTick() {
    final now = _clock.elapsedMilliseconds;
    final before = _fx.length;
    final expired = _fx.where((f) => now - f.startMs >= f.durMs).toList();
    if (expired.isNotEmpty) {
      _fx.removeWhere(expired.contains);
    }
    if (_fx.length != before) {
      setState(() => version++);
    }
    if (_fx.isEmpty && hinted == null) {
      _tick.stop();
    }
  }

  void _kick() {
    if (!_tick.isAnimating) _tick.repeat();
  }

  void _tap(int id) {
    if (over) return;
    final res = board.tap(id);
    if (res == null) return;
    final now = _clock.elapsedMilliseconds;
    setState(() {
      hinted = null;
      if (res) {
        moves++;
        final s = board.snakes[id];
        final travel = _bodyLen(s) + board.rayCells(s).length + 1.0;
        final dur = (300 + travel * 38).clamp(380, 1100).round();
        _fx.add(_Fx(id, true, now, dur, travel));
        AppAudio.play(Sound.slide);
      } else {
        lives--;
        AppAudio.play(Sound.fail);
        AppAudio.haptic(true);
        _fx.removeWhere((f) => f.id == id);
        _fx.add(_Fx(id, false, now, 460, 0));
      }
      version++;
    });
    _kick();
    if (board.isCleared) {
      over = true;
      final stars = _stars;
      ArrowMazeProgress.complete(tier, level, stars);
      Rewards.onLevelComplete('arrow_maze', '${tier.key}-L$level',
          stars: stars);
      Future.delayed(const Duration(milliseconds: 900), _showWin);
    } else if (lives <= 0) {
      over = true;
      AppAudio.play(Sound.fail);
      Future.delayed(const Duration(milliseconds: 650), _showLose);
    }
  }

  void _hint() {
    if (over) return;
    if (hintsLeft <= 0) {
      AppAudio.haptic();
      return;
    }
    final h = board.hint();
    if (h != null) {
      hintsLeft--;
      AppAudio.play(Sound.pop);
    }
    setState(() {
      hinted = h?.id;
      version++;
    });
    if (h != null) _kick();
  }

  void _undo() {
    if (over) return;
    final id = board.undo();
    if (id == null) return;
    setState(() {
      _fx.removeWhere((f) => f.id == id);
      if (moves > 0) moves--;
      hinted = null;
      version++;
    });
  }

  int get _stars => (3 - (maxLives - lives)).clamp(1, 3);

  void _showWin() {
    if (!mounted) return;
    final hasNext = level < tier.count;
    final stars = _stars;
    showPremiumDialog(
      context,
      title: 'Maze cleared!',
      message: 'Lives left: $lives  |  Moves: $moves',
      emoji: '🎉✨',
      stars: stars,
      color: _tierColor(tier),
      actions: [
        DialogAction('Levels', () => Navigator.pop(context)),
        DialogAction('Replay', () => setState(_load)),
        if (hasNext)
          DialogAction('Next level', () {
            setState(() {
              level++;
              _load();
            });
          }, primary: true),
      ],
    );
  }

  void _showLose() {
    if (!mounted) return;
    showPremiumDialog(
      context,
      title: 'Out of lives',
      message: 'Those arrows were blocked. Try again!',
      emoji: '💔',
      color: Pal.danger,
      actions: [
        DialogAction('Levels', () => Navigator.pop(context)),
        DialogAction('Retry', () => setState(_load), primary: true),
      ],
    );
  }

  int? _hit(Offset p, double cell) {
    // p is in board coordinates (pixels); grid is offset by half a cell.
    final gx = p.dx / cell - 0.5, gy = p.dy / cell - 0.5;
    final c0 = gx.floor(), r0 = gy.floor();
    int? best;
    var bestD = 0.75 * 0.75;
    for (var r = r0 - 1; r <= r0 + 2; r++) {
      for (var c = c0 - 1; c <= c0 + 2; c++) {
        if (r < 0 || r >= board.rows || c < 0 || c >= board.cols) continue;
        final id = board.snakeAtCell(r * board.cols + c);
        if (id == null) continue;
        final dx = gx - (c + 0.5), dy = gy - (r + 0.5);
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          bestD = d;
          best = id;
        }
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final hidden = <int>{for (final f in _fx) f.id, ?hinted};
    return GameScaffold(
      title: '${tier.label} - Level $level',
      tint: _tierColor(tier),
      actions: [
        BarAction(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onTap: over || board.history.isEmpty ? null : _undo),
        BarAction(
            icon: Icons.lightbulb_rounded,
            tooltip: 'Hint ($hintsLeft left)',
            onTap: over || hintsLeft <= 0 ? null : _hint),
        BarAction(
            icon: Icons.refresh_rounded,
            tooltip: 'Restart',
            onTap: () => setState(_load)),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: GlassCard(
              blur: 0,
              radius: 20,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(children: [
                    for (var i = 0; i < maxLives; i++)
                      _Heart(alive: i < lives),
                  ]),
                  Text('Hints $hintsLeft  |  Moves $moves  |  Left ${board.remaining}',
                      style: const TextStyle(
                          color: Pal.text,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(builder: (context, box) {
                final cell = math.min(box.maxWidth / (board.cols + 1),
                    box.maxHeight / (board.rows + 1));
                final w = cell * (board.cols + 1);
                final h = cell * (board.rows + 1);
                final boardW = Center(
                  child: GestureDetector(
                    onTapUp: (d) {
                      final id = _hit(d.localPosition, cell);
                      if (id != null) _tap(id);
                    },
                    child: SizedBox(
                      key: ValueKey('board_${level}_$loadId'),
                      width: w,
                      height: h,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF1B1840), Color(0xFF0E0B26)],
                            ),
                            border: Border.all(color: Pal.glassBorder),
                          ),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RepaintBoundary(
                                  child: CustomPaint(
                                    painter: _StaticPainter(
                                        board: board,
                                        hidden: hidden,
                                        version: version),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _FxPainter(
                                    board: board,
                                    fx: _fx,
                                    hinted: hinted,
                                    clock: _clock,
                                    repaint: _tick,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
                return InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: SizedBox(
                      width: box.maxWidth,
                      height: box.maxHeight,
                      child: boardW),
                )
                    .animate(key: ValueKey('anim_${level}_$loadId'))
                    .fadeIn(duration: 350.ms);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _Heart extends StatelessWidget {
  const _Heart({required this.alive});
  final bool alive;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.elasticOut,
      transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
      child: Padding(
        key: ValueKey(alive),
        padding: const EdgeInsets.only(right: 4),
        child: alive
            ? DecoratedBox(
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [
                  BoxShadow(
                      color: Pal.danger.withValues(alpha: 0.5), blurRadius: 12)
                ]),
                child: const Icon(Icons.favorite_rounded,
                    color: Pal.danger, size: 26),
              )
            : const Icon(Icons.heart_broken_rounded,
                color: Pal.textDim, size: 26),
      ),
    );
  }
}

// ---------------------------------------------------------------- painting

double _bodyLen(Snake s) => (s.length - 1).toDouble();

Color _colorOf(int id) => Pal.accents[(id * 3 + id ~/ 8) % Pal.accents.length];

/// Polyline of the snake body (tail -> head) in cell units (cell centers).
List<Offset> _bodyPoints(Snake s, int cols) => [
      for (final i in s.cells) Offset(i % cols + 0.5, i ~/ cols + 0.5),
    ];

/// Part of a polyline between arc-lengths [a] and [b].
List<Offset> _slice(List<Offset> pts, double a, double b) {
  final out = <Offset>[];
  var acc = 0.0;
  for (var i = 0; i < pts.length - 1; i++) {
    final p = pts[i], q = pts[i + 1];
    final len = (q - p).distance;
    final s0 = acc, s1 = acc + len;
    acc = s1;
    if (s1 <= a || s0 >= b) continue;
    final from = math.max(a, s0), to = math.min(b, s1);
    final u = (q - p) / len;
    final pa = p + u * (from - s0), pb = p + u * (to - s0);
    if (out.isEmpty) out.add(pa);
    out.add(pb);
  }
  return out;
}

void _drawSnake(Canvas canvas, List<Offset> pts, double cell, Color color,
    {double glow = 0.28, Color? glowColor, double glowWidth = 0.55}) {
  if (pts.length < 2) return;
  final path = Path()..moveTo(pts.first.dx * cell, pts.first.dy * cell);
  for (var i = 1; i < pts.length; i++) {
    path.lineTo(pts[i].dx * cell, pts[i].dy * cell);
  }
  final head = pts.last * cell;
  final dir = (pts.last - pts[pts.length - 2]);
  final u = dir / dir.distance;
  final nrm = Offset(-u.dy, u.dx);
  final tip = head + u * (cell * 0.5);
  final base = head - u * (cell * 0.02);
  final arrow = Path()
    ..moveTo(tip.dx, tip.dy)
    ..lineTo(base.dx + nrm.dx * cell * 0.3, base.dy + nrm.dy * cell * 0.3)
    ..lineTo(base.dx - nrm.dx * cell * 0.3, base.dy - nrm.dy * cell * 0.3)
    ..close();

  Paint stroke(double w, Color c) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = c;

  if (glow > 0) {
    final gc = glowColor ?? color;
    final gp = stroke(cell * glowWidth, gc.withValues(alpha: glow))
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.28);
    canvas.drawPath(path, gp);
    canvas.drawPath(
        arrow,
        Paint()
          ..color = gc.withValues(alpha: glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, cell * 0.28));
  }
  canvas.drawPath(path, stroke(cell * 0.2, color));
  canvas.drawPath(
      path, stroke(cell * 0.07, Colors.white.withValues(alpha: 0.45)));
  canvas.drawPath(arrow, Paint()..color = color);
  canvas.drawPath(
      arrow,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cell * 0.05
        ..color = Colors.white.withValues(alpha: 0.4));
}

class _StaticPainter extends CustomPainter {
  _StaticPainter(
      {required this.board, required this.hidden, required this.version});
  final ArrowMazeBoard board;
  final Set<int> hidden;
  final int version;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / (board.cols + 1);
    canvas.save();
    canvas.translate(cell * 0.5, cell * 0.5);
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.07);
    for (var r = 0; r < board.rows; r++) {
      for (var c = 0; c < board.cols; c++) {
        canvas.drawCircle(
            Offset((c + 0.5) * cell, (r + 0.5) * cell), cell * 0.05, dot);
      }
    }
    final glow = board.snakes.length < 60;
    for (final s in board.snakes) {
      if (board.removed.contains(s.id) || hidden.contains(s.id)) continue;
      _drawSnake(canvas, _bodyPoints(s, board.cols), cell, _colorOf(s.id),
          glow: glow ? 0.22 : 0);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StaticPainter old) =>
      old.version != version || old.board != board;
}

class _FxPainter extends CustomPainter {
  _FxPainter(
      {required this.board,
      required this.fx,
      required this.hinted,
      required this.clock,
      required Listenable repaint})
      : super(repaint: repaint);
  final ArrowMazeBoard board;
  final List<_Fx> fx;
  final int? hinted;
  final Stopwatch clock;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / (board.cols + 1);
    final now = clock.elapsedMilliseconds;
    canvas.save();
    canvas.translate(cell * 0.5, cell * 0.5);
    canvas.clipRect(Rect.fromLTWH(-cell * 0.5, -cell * 0.5, size.width, size.height));
    for (final f in fx) {
      final s = board.snakes[f.id];
      final t = ((now - f.startMs) / f.durMs).clamp(0.0, 1.0);
      final body = _bodyPoints(s, board.cols);
      final color = _colorOf(s.id);
      if (f.slide) {
        final d = Curves.easeInQuad.transform(t) * f.travel;
        final ext = [
          ...body,
          body.last +
              Offset(s.dir.dc.toDouble(), s.dir.dr.toDouble()) *
                  (board.rayCells(s).length + 3.0),
        ];
        _drawSnake(canvas, _slice(ext, d, d + _bodyLen(s)), cell, color,
            glow: 0.35 * (1 - t));
      } else {
        final dx = math.sin(t * math.pi * 7) * (1 - t) * 0.16;
        final shifted = [for (final p in body) p + Offset(dx, 0)];
        _drawSnake(canvas, shifted, cell,
            Color.lerp(color, Pal.danger, (1 - t) * 0.9)!,
            glow: 0.5 * (1 - t), glowColor: Pal.danger);
      }
    }
    final h = hinted;
    if (h != null && !fx.any((f) => f.id == h) && !board.removed.contains(h)) {
      final s = board.snakes[h];
      final pulse = (math.sin(now / 160) + 1) / 2;
      _drawSnake(canvas, _bodyPoints(s, board.cols), cell, Pal.gold,
          glow: 0.35 + pulse * 0.5,
          glowColor: Pal.gold,
          glowWidth: 0.6 + pulse * 0.5);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FxPainter old) => true;
}
