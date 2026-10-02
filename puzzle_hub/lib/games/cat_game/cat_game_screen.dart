import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/cat_logic.dart';

const _skins = ['🐱', '😺', '😸', '🐈'];
const _skinStars = [0, 6, 15, 30];
const _tint = Color(0xFFFFC857);
const _pink = Color(0xFFFF8FAB);

int _starsOf(int level) => Storage.getInt('cat_game.stars.$level');
int _totalStars() {
  var t = 0;
  for (var i = 0; i < CatLevels.count; i++) {
    t += _starsOf(i);
  }
  return t;
}

class CatGameScreen extends StatefulWidget {
  const CatGameScreen({super.key});

  @override
  State<CatGameScreen> createState() => _CatGameScreenState();
}

class _CatGameScreenState extends State<CatGameScreen> {
  Future<void> _openSkins() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _SkinSheet(),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final total = _totalStars();
    final skin = Storage.getInt('cat_game.skin').clamp(0, _skins.length - 1);
    return GameScaffold(
      title: 'Cat & Fish',
      tint: _tint,
      actions: [
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            radius: 16,
            blur: 0,
            onTap: _openSkins,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_skins[skin], style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Icon(Icons.star_rounded, size: 18, color: Pal.gold),
              const SizedBox(width: 2),
              Text('$total',
                  style: const TextStyle(
                      color: Pal.text, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ],
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 96, mainAxisSpacing: 12, crossAxisSpacing: 12),
        itemCount: CatLevels.count,
        itemBuilder: (_, i) {
          final s = _starsOf(i);
          final done = s > 0;
          return GlassCard(
            padding: EdgeInsets.zero,
            radius: 20,
            blur: 0,
            glow: done ? _tint : null,
            gradient: done
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _tint.withValues(alpha: 0.55),
                      _pink.withValues(alpha: 0.25)
                    ])
                : null,
            onTap: () async {
              await Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => _LevelScreen(index: i)));
              if (mounted) setState(() {});
            },
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('${i + 1}',
                  style: const TextStyle(
                      color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              StarRow(stars: s, size: 14),
            ]),
          )
              .animate(delay: (math.min(i, 24) * 30).ms)
              .fadeIn(duration: 320.ms)
              .scale(
                  begin: const Offset(0.8, 0.8),
                  end: const Offset(1, 1),
                  curve: Curves.easeOutBack,
                  duration: 380.ms);
        },
      ),
    );
  }
}

class _SkinSheet extends StatefulWidget {
  const _SkinSheet();

  @override
  State<_SkinSheet> createState() => _SkinSheetState();
}

class _SkinSheetState extends State<_SkinSheet> {
  @override
  Widget build(BuildContext context) {
    final total = _totalStars();
    final cur = Storage.getInt('cat_game.skin');
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GlassCard(
          blur: 0,
          radius: 32,
          glow: _tint,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2A1F63).withValues(alpha: 0.97),
              const Color(0xFF140E38).withValues(alpha: 0.97)
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                    color: Pal.glassBorder,
                    borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Text('Cat skins',
                  style: TextStyle(
                      color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(width: 12),
              const Icon(Icons.star_rounded, color: Pal.gold, size: 20),
              Text('$total',
                  style: const TextStyle(
                      color: Pal.gold, fontSize: 18, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 18),
            Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
              for (var i = 0; i < _skins.length; i++) _card(i, total, cur),
            ]),
            const SizedBox(height: 20),
            PremiumButton(
                label: 'Done',
                compact: true,
                onTap: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }

  Widget _card(int i, int total, int cur) {
    final unlocked = total >= _skinStars[i];
    final selected = cur == i && unlocked;
    return Opacity(
      opacity: unlocked ? 1 : 0.6,
      child: GlassCard(
        blur: 0,
        radius: 22,
        glow: selected ? Pal.success : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        gradient: selected
            ? LinearGradient(colors: [
                Pal.success.withValues(alpha: 0.35),
                Pal.success.withValues(alpha: 0.1)
              ])
            : null,
        onTap: unlocked
            ? () {
                Storage.setInt('cat_game.skin', i);
                setState(() {});
              }
            : () {},
        child: SizedBox(
          width: 68,
          child: Column(children: [
            Text(unlocked ? _skins[i] : '🔒', style: const TextStyle(fontSize: 38)),
            const SizedBox(height: 6),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: Pal.success, size: 18)
            else
              Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.star_rounded, size: 14, color: Pal.gold),
                Text('${_skinStars[i]}',
                    style: const TextStyle(
                        color: Pal.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ]),
          ]),
        ),
      ),
    );
  }
}

class _LevelScreen extends StatefulWidget {
  const _LevelScreen({required this.index});
  final int index;

  @override
  State<_LevelScreen> createState() => _LevelScreenState();
}

class _LevelScreenState extends State<_LevelScreen>
    with TickerProviderStateMixin {
  late int index = widget.index;
  late CatLevel level;
  late int cat;
  final List<int> history = [];
  final List<(int, Dir)> trail = [];
  int moves = 0;
  bool busy = false;
  bool dead = false;
  Offset _dragStart = Offset.zero;
  Duration _anim = Duration.zero;
  Dir _lastDir = Dir.right;
  late final AnimationController _slideFx =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  late final AnimationController _burst =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
        ..repeat();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _slideFx.dispose();
    _burst.dispose();
    _loop.dispose();
    super.dispose();
  }

  void _load() {
    level = CatLevels.level(index);
    cat = level.start;
    history.clear();
    trail.clear();
    moves = 0;
    busy = false;
    dead = false;
    _anim = Duration.zero;
    _burst.value = 0;
  }

  Future<void> _move(Dir d) async {
    if (busy) return;
    final res = level.slide(cat, d);
    if (res.outcome == SlideOutcome.blocked) return;
    busy = true;
    final from = cat;
    setState(() {
      _anim = Duration(milliseconds: 90 * res.path.length + 60);
      _lastDir = d;
      cat = res.end;
      for (final p in [from, ...res.path.take(res.path.length - 1)]) {
        trail.add((p, d));
      }
    });
    _slideFx.duration = _anim;
    _slideFx.forward(from: 0);
    await Future<void>.delayed(_anim + const Duration(milliseconds: 80));
    if (!mounted) return;
    if (res.outcome == SlideOutcome.dog) {
      setState(() => dead = true);
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      setState(() {
        _anim = const Duration(milliseconds: 200);
        cat = from;
        dead = false;
        busy = false;
        trail.removeRange(trail.length - res.path.length, trail.length);
      });
      return;
    }
    setState(() {
      history.add(from);
      moves++;
      busy = res.outcome == SlideOutcome.fish;
    });
    if (res.outcome == SlideOutcome.fish) _win();
  }

  void _undo() {
    if (busy || history.isEmpty) return;
    setState(() {
      _anim = const Duration(milliseconds: 200);
      final prev = history.removeLast();
      // Drop trail entries belonging to the undone move.
      final w = level.width;
      final steps = ((cat ~/ w - prev ~/ w).abs() + (cat % w - prev % w).abs());
      final n = math.min(steps, trail.length);
      trail.removeRange(trail.length - n, trail.length);
      cat = prev;
      moves--;
    });
  }

  void _restart() => setState(_load);

  Future<void> _win() async {
    final par = level.optimal!;
    final stars = starsFor(moves, par);
    final before = _totalStars();
    Storage.setBest('cat_game.stars.$index', stars);
    final after = _totalStars();
    final unlocked = [
      for (var i = 0; i < _skins.length; i++)
        if (before < _skinStars[i] && after >= _skinStars[i]) _skins[i]
    ];
    final next = index + 1 < CatLevels.count;
    _burst.forward(from: 0);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    var action = 'menu';
    await showPremiumDialog(
      context,
      title: 'Yum!',
      emoji: '🐟',
      stars: stars,
      color: _tint,
      message: 'Caught the fish in $moves moves (par $par).'
          '${unlocked.isEmpty ? '' : '\nNew skin unlocked: ${unlocked.join(' ')}'}',
      actions: [
        DialogAction('Levels', () => action = 'menu'),
        DialogAction('Retry', () => action = 'retry'),
        if (next) DialogAction('Next', () => action = 'next', primary: true),
      ],
    );
    if (!mounted) return;
    if (action == 'next') {
      index++;
      _restart();
    } else if (action == 'retry') {
      _restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Widget _chip(IconData icon, String label, Color c) => GlassCard(
        blur: 0,
        radius: 18,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Pal.text, fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final skin = _skins[Storage.getInt('cat_game.skin').clamp(0, 3)];
    final par = level.optimal ?? 0;
    return GameScaffold(
      title: 'Level ${index + 1}',
      tint: _tint,
      actions: [
        BarAction(
            icon: Icons.undo_rounded,
            tooltip: 'Undo',
            onTap: history.isEmpty || busy ? null : _undo),
        BarAction(icon: Icons.refresh_rounded, tooltip: 'Restart', onTap: _restart),
      ],
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _chip(Icons.pets_rounded, 'Moves $moves', _pink),
            const SizedBox(width: 12),
            _chip(Icons.flag_rounded, 'Par $par', Pal.gold),
          ]),
        ),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: level.width / level.height,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GlassCard(
                  blur: 0,
                  radius: 26,
                  glow: _tint,
                  padding: const EdgeInsets.all(8),
                  child: LayoutBuilder(builder: (context, box) {
                    final cw = box.maxWidth / level.width;
                    final ch = box.maxHeight / level.height;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) => _dragStart = d.localPosition,
                      onPanUpdate: (d) {
                        final delta = d.localPosition - _dragStart;
                        if (delta.distance > 24) {
                          _dragStart = d.localPosition;
                          if (delta.dx.abs() > delta.dy.abs()) {
                            _move(delta.dx > 0 ? Dir.right : Dir.left);
                          } else {
                            _move(delta.dy > 0 ? Dir.down : Dir.up);
                          }
                        }
                      },
                      child: Stack(clipBehavior: Clip.none, children: [
                        for (var i = 0; i < level.cells.length; i++)
                          Positioned(
                            left: (i % level.width) * cw,
                            top: (i ~/ level.width) * ch,
                            width: cw,
                            height: ch,
                            child: _tile(i, cw),
                          ),
                        for (final t in trail) _paw(t, cw, ch),
                        AnimatedPositioned(
                          duration: _anim,
                          curve: Curves.easeOut,
                          left: (cat % level.width) * cw,
                          top: (cat ~/ level.width) * ch,
                          width: cw,
                          height: ch,
                          child: _catSprite(dead ? '😵' : skin, cw),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: AnimatedBuilder(
                              animation: _burst,
                              builder: (_, _) => _burst.value == 0
                                  ? const SizedBox.shrink()
                                  : CustomPaint(
                                      painter: _BurstPainter(
                                          _burst.value,
                                          Offset(
                                              (level.fish % level.width + 0.5) * cw,
                                              (level.fish ~/ level.width + 0.5) * ch),
                                          cw)),
                            ),
                          ),
                        ),
                      ]),
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: Text('Swipe to slide. Avoid the dogs!',
              style: TextStyle(color: Pal.textDim, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _paw((int, Dir) t, double cw, double ch) {
    final i = t.$1;
    final angle = switch (t.$2) {
      Dir.up => 0.0,
      Dir.right => math.pi / 2,
      Dir.down => math.pi,
      Dir.left => -math.pi / 2,
    };
    return Positioned(
      left: (i % level.width) * cw,
      top: (i ~/ level.width) * ch,
      width: cw,
      height: ch,
      child: IgnorePointer(
        child: Center(
          child: Transform.rotate(
            angle: angle,
            child: Text('🐾',
                style: TextStyle(
                    fontSize: cw * 0.32, color: Colors.white.withValues(alpha: 0.5))),
          ),
        ),
      ),
    );
  }

  Widget _catSprite(String face, double cw) {
    final horizontal = _lastDir == Dir.left || _lastDir == Dir.right;
    return AnimatedBuilder(
      animation: _slideFx,
      builder: (_, child) {
        final k = math.sin(_slideFx.value * math.pi);
        final along = 1 + 0.28 * k;
        final across = 1 - 0.16 * k;
        return Transform.scale(
          scaleX: horizontal ? along : across,
          scaleY: horizontal ? across : along,
          child: child,
        );
      },
      child: Stack(alignment: Alignment.center, children: [
        Positioned(
          bottom: cw * 0.1,
          child: Container(
            width: cw * 0.55,
            height: cw * 0.12,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(cw),
              color: Colors.black.withValues(alpha: 0.35),
            ),
          ),
        ),
        Text(face, style: TextStyle(fontSize: cw * 0.66)),
      ]),
    );
  }

  Widget _shadowed(String e, double size, {double lift = 0.06}) => Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: size * 0.12,
            child: Container(
              width: size * 0.5,
              height: size * 0.1,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(size),
                color: Colors.black.withValues(alpha: 0.32),
              ),
            ),
          ),
          Transform.translate(
              offset: Offset(0, -size * lift),
              child: Text(e, style: TextStyle(fontSize: size * 0.56))),
        ],
      );

  Widget _tile(int i, double size) {
    final dark = (i % level.width + i ~/ level.width) % 2 == 0;
    Widget? content;
    switch (level.cells[i]) {
      case Cell.wall:
        content = _shadowed('📦', size);
      case Cell.yarn:
        content = _shadowed('🧶', size);
      case Cell.dog:
        content = _shadowed('🐶', size);
      case Cell.empty:
        break;
    }
    if (i == level.fish) {
      content = AnimatedBuilder(
        animation: _loop,
        builder: (_, _) {
          final t = math.sin(_loop.value * 2 * math.pi);
          return Stack(alignment: Alignment.center, children: [
            Container(
              width: size * 0.7,
              height: size * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: const Color(0xFF4DA8FF)
                          .withValues(alpha: 0.35 + 0.2 * t),
                      blurRadius: 14 + 6 * t)
                ],
              ),
            ),
            Transform.translate(
                offset: Offset(0, -size * 0.05 * t),
                child: Text('🐟', style: TextStyle(fontSize: size * 0.56))),
          ]);
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.all(1.5),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.18),
          color: Colors.white.withValues(alpha: dark ? 0.1 : 0.04),
        ),
        child: content == null ? null : Center(child: content),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.center, this.cell);
  final double t;
  final Offset center;
  final double cell;

  @override
  void paint(Canvas canvas, Size size) {
    const n = 14;
    final eased = Curves.easeOutCubic.transform(t);
    final fade = (1 - t).clamp(0.0, 1.0);
    for (var i = 0; i < n; i++) {
      final a = i / n * 2 * math.pi + (i.isEven ? 0.1 : 0);
      final r = cell * (0.3 + (i.isEven ? 1.5 : 1.0) * eased);
      final p = center + Offset(math.cos(a), math.sin(a)) * r;
      final c = i % 3 == 0 ? Pal.gold : (i % 3 == 1 ? _pink : Colors.white);
      _star(canvas, p, cell * (i.isEven ? 0.16 : 0.1) * (1 - 0.5 * t),
          Paint()..color = c.withValues(alpha: fade));
    }
    canvas.drawCircle(
        center,
        cell * (0.3 + 1.2 * eased),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Pal.gold.withValues(alpha: fade * 0.6));
  }

  void _star(Canvas canvas, Offset c, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final rad = i.isEven ? r : r * 0.35;
      final a = i * math.pi / 4 - math.pi / 2;
      final p = c + Offset(math.cos(a), math.sin(a)) * rad;
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t || old.center != center;
}
