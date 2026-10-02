import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'logic/fork_path.dart';
import 'logic/levels.dart';
import 'maze_escape_screen.dart';
import 'progress.dart';

const _kGreen = Color(0xFF1FB589);
const _optionEmoji = ['🚪', '🛤️', '🌲', '⛰️', '🕳️'];

/// Fork Path mode: a chain of junctions, only one trail is right at each.
class ForkGame extends StatefulWidget {
  const ForkGame({super.key, required this.level});
  final int level;

  @override
  State<ForkGame> createState() => _ForkGameState();
}

class _ForkGameState extends State<ForkGame> with SingleTickerProviderStateMixin {
  late ForkLevel cfg;
  late ForkPath path;
  late final AnimationController _go = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  int fork = 0;
  late List<Set<int>> tried;
  int wrong = 0;
  int lanternsLeft = 0;
  bool usedHint = false;
  bool _busy = false;
  bool _done = false;
  int? _selected;
  int? _deadEnd;
  int? _hintOpt;
  Timer? _hintTimer;
  String? _banner;
  Color _bannerColor = Pal.danger;
  Offset _target = Offset.zero;
  Size _scene = Size.zero;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  void _setup() {
    cfg = ForkLevel.of(widget.level);
    path = ForkPath.generate(cfg.seed, cfg.forks, cfg.options);
    fork = 0;
    tried = List.generate(cfg.forks, (_) => <int>{});
    wrong = 0;
    lanternsLeft = cfg.lanterns;
    usedHint = false;
    _busy = false;
    _done = false;
    _selected = null;
    _deadEnd = null;
    _hintOpt = null;
    _banner = null;
    _go.value = 0;
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _go.dispose();
    super.dispose();
  }

  Offset _home(Size s) => Offset(s.width * 0.5, s.height * 0.86);

  Offset _optPos(int i, int n, Size s) {
    final t = (i + 0.5) / n;
    return Offset(s.width * (0.1 + 0.8 * t), s.height * (0.3 + 0.14 * (1 - sin(pi * t))));
  }

  void _say(String? t, [Color c = Pal.danger]) {
    _banner = t;
    _bannerColor = c;
  }

  Future<void> _choose(int i) async {
    if (_busy || _done || tried[fork].contains(i)) return;
    _busy = true;
    setState(() {
      _selected = i;
      _hintOpt = null;
      _target = _optPos(i, cfg.options, _scene);
    });
    await _go.forward(from: 0);
    if (!mounted) return;
    if (path.isCorrect(fork, i)) {
      HapticFeedback.selectionClick();
      setState(() => _say('Sahi raasta!', Pal.success));
      await Future<void>.delayed(const Duration(milliseconds: 550));
      if (!mounted) return;
      if (fork + 1 >= cfg.forks) {
        setState(() {
          fork++;
          _say(null);
        });
        _win();
        return;
      }
      setState(() {
        fork++;
        _selected = null;
        _say(null);
        _go.value = 0;
      });
      _busy = false;
    } else {
      tried[fork].add(i);
      wrong++;
      HapticFeedback.mediumImpact();
      setState(() {
        _deadEnd = i;
        _say('Dead end!  Wapas jao...');
      });
      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;
      await _go.reverse();
      if (!mounted) return;
      if (cfg.resetOnWrong && fork > 0) {
        setState(() {
          _deadEnd = null;
          _selected = null;
          _say('Wapas shuru se... yaad rakhna!', Pal.gold);
        });
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted) return;
        setState(() {
          fork = 0;
          _say(null);
        });
      } else {
        setState(() {
          _deadEnd = null;
          _selected = null;
          _say(null);
        });
      }
      _busy = false;
    }
  }

  void _lantern() {
    if (_busy || _done || lanternsLeft <= 0) return;
    setState(() {
      lanternsLeft--;
      usedHint = true;
      _hintOpt = path.correct[fork];
    });
    _hintTimer?.cancel();
    _hintTimer = Timer(const Duration(milliseconds: 2800), () {
      if (mounted) setState(() => _hintOpt = null);
    });
  }

  void _restart() => setState(_setup);

  Future<void> _win() async {
    _done = true;
    final stars = forkStars(wrong, cfg.forks, usedHint: usedHint);
    MazeProgress.save(MazeMode.fork, widget.level, stars);
    Rewards.onLevelComplete('maze_escape', 'fork-L${widget.level}', stars: stars);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    showPremiumDialog(
      context,
      title: 'Jungle se bahar!',
      emoji: '🏁',
      stars: stars,
      message: wrong == 0 ? 'Not a single wrong turn.' : 'You took $wrong wrong turn${wrong == 1 ? '' : 's'}.',
      actions: [
        DialogAction('Levels', () => Navigator.of(context).maybePop()),
        DialogAction('Replay', _restart),
        if (widget.level < kLevelCount)
          DialogAction('Next', () => openMazeLevel(context, MazeMode.fork, widget.level + 1, replace: true), primary: true),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: 'Fork Path ${widget.level}',
      tint: _kGreen,
      actions: [
        BarAction(icon: Icons.flashlight_on_rounded, tooltip: 'Lantern', onTap: lanternsLeft > 0 && !_busy && !_done ? _lantern : null),
        BarAction(icon: Icons.refresh_rounded, tooltip: 'Restart', onTap: _restart),
      ],
      body: Column(children: [
        _chain(),
        _chips(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF0E2A35), Color(0xFF14463A), Color(0xFF0C2A22)],
                  ),
                  border: Border.all(color: Pal.glassBorder),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: LayoutBuilder(builder: (context, c) {
                  _scene = Size(c.maxWidth, c.maxHeight);
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 520),
                    switchInCurve: Curves.easeOut,
                    transitionBuilder: (child, a) =>
                        FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 1.12, end: 1.0).animate(a), child: child)),
                    child: KeyedSubtree(key: ValueKey(fork), child: _sceneFor(_scene)),
                  );
                }),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _chain() {
    Widget node(int i) {
      final done = i < fork;
      final cur = i == fork && !_done;
      return AnimatedContainer(
        duration: 300.ms,
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: done ? Pal.success.withValues(alpha: 0.9) : Colors.black.withValues(alpha: 0.3),
          border: Border.all(color: cur ? Pal.gold : Pal.glassBorder, width: cur ? 2.5 : 1),
          boxShadow: cur ? [BoxShadow(color: Pal.gold.withValues(alpha: 0.5), blurRadius: 10)] : null,
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
            : Text('${i + 1}', style: TextStyle(color: cur ? Pal.gold : Pal.textDim, fontSize: 12, fontWeight: FontWeight.w800)),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: Row(children: [
        for (var i = 0; i < cfg.forks; i++) ...[
          node(i),
          if (i < cfg.forks - 1)
            Expanded(child: Container(height: 2, color: i < fork ? Pal.success.withValues(alpha: 0.7) : Pal.glassBorder)),
        ],
        const SizedBox(width: 6),
        const Text('🏁', style: TextStyle(fontSize: 20)),
      ]),
    );
  }

  Widget _chips() {
    Widget chip(String t, {Color color = Pal.text}) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(20)),
          child: Text(t, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [
        chip('Fork ${min(fork + 1, cfg.forks)} / ${cfg.forks}'),
        chip('Wrong turns $wrong', color: wrong > 0 ? Pal.danger : Pal.text),
        chip('🔦 $lanternsLeft'),
        if (cfg.resetOnWrong) chip('Wrong turn = back to start', color: Pal.gold),
      ]),
    );
  }

  Widget _sceneFor(Size s) {
    final home = _home(s);
    final n = cfg.options;
    final f = min(fork, cfg.forks - 1);
    final sz = min(78.0, s.width * 0.8 / n - 8);
    final positions = [for (var i = 0; i < n; i++) _optPos(i, n, s)];
    return Stack(clipBehavior: Clip.hardEdge, children: [
      Positioned.fill(
        child: CustomPaint(painter: _ForestPainter(seed: cfg.seed + f * 31, home: home, options: positions, tried: tried[f], deadEnd: _deadEnd, hint: _hintOpt)),
      ),
      for (var i = 0; i < n; i++) _option(i, positions[i], sz, f),
      // Player.
      AnimatedBuilder(
        animation: _go,
        builder: (context, _) {
          final t = Curves.easeInOut.transform(_go.value);
          final p = Offset.lerp(home, _target, _selected == null ? 0 : t)!;
          return Positioned(left: p.dx - 24, top: p.dy - 24, child: const _Walker());
        },
      ),
      if (_done)
        Positioned.fill(
            child: const Center(child: Text('🏁', style: TextStyle(fontSize: 90)))
                .animate()
                .scale(begin: const Offset(0.2, 0.2), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 800.ms)),
      Positioned(
        top: 12,
        left: 0,
        right: 0,
        child: Center(
          child: AnimatedSwitcher(
            duration: 250.ms,
            child: _banner == null
                ? const SizedBox(key: ValueKey('none'), height: 44)
                : Container(
                    key: ValueKey(_banner),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _bannerColor.withValues(alpha: 0.8)),
                    ),
                    child: Text(_banner!, style: TextStyle(color: _bannerColor, fontWeight: FontWeight.w900, fontSize: 16)),
                  ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.4, end: 0),
          ),
        ),
      ),
      if (!_busy && !_done)
        Positioned(
          left: 0,
          right: 0,
          bottom: 6,
          child: Text(
            tried[f].isEmpty ? 'Which trail leads out?' : 'Crossed-out trails are dead ends.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Pal.textDim, fontSize: 12.5),
          ),
        ),
    ]);
  }

  Widget _option(int i, Offset p, double sz, int f) {
    final isTried = tried[f].contains(i);
    final isDead = _deadEnd == i && f == fork;
    final isHint = _hintOpt == i;
    final emoji = isDead ? '🧱' : _optionEmoji[(i + f) % _optionEmoji.length];
    final glow = isHint ? Pal.success : (isDead ? Pal.danger : _kGreen);
    return Positioned(
      left: p.dx - sz / 2,
      top: p.dy - sz / 2,
      child: Opacity(
        opacity: isTried && !isDead ? 0.5 : 1,
        child: Pressable(
          onTap: () => _choose(i),
          child: Container(
            width: sz,
            height: sz,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.06)],
              ),
              border: Border.all(color: isHint ? Pal.success : Pal.glassBorder, width: isHint ? 3 : 1.5),
              boxShadow: [BoxShadow(color: glow.withValues(alpha: isHint ? 0.8 : 0.3), blurRadius: isHint ? 26 : 14, spreadRadius: isHint ? 2 : 0)],
            ),
            child: Stack(alignment: Alignment.center, children: [
              Text(emoji, style: TextStyle(fontSize: sz * 0.52)),
              if (isTried)
                Icon(Icons.close_rounded, size: sz * 0.9, color: Pal.danger.withValues(alpha: 0.9))
                    .animate()
                    .scale(begin: const Offset(1.8, 1.8), end: const Offset(1, 1), duration: 300.ms, curve: Curves.easeOutBack),
            ]),
          ),
        ),
      ),
    );
  }
}

class _Walker extends StatelessWidget {
  const _Walker();

  @override
  Widget build(BuildContext context) => Container(
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: Pal.accent(Pal.goldDeep),
          boxShadow: [BoxShadow(color: Pal.gold.withValues(alpha: 0.5), blurRadius: 16)],
        ),
        child: const Text('🧍', style: TextStyle(fontSize: 26)),
      );
}

class _ForestPainter extends CustomPainter {
  _ForestPainter({required this.seed, required this.home, required this.options, required this.tried, this.deadEnd, this.hint});
  final int seed;
  final Offset home;
  final List<Offset> options;
  final Set<int> tried;
  final int? deadEnd;
  final int? hint;

  @override
  void paint(Canvas canvas, Size size) {
    // Trails from the junction to every option.
    for (var i = 0; i < options.length; i++) {
      final o = options[i];
      final p = Path()
        ..moveTo(home.dx, home.dy)
        ..quadraticBezierTo(home.dx, (home.dy + o.dy) / 2, o.dx, o.dy);
      final dead = tried.contains(i);
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 22
            ..strokeCap = StrokeCap.round
            ..color = (dead ? const Color(0xFF4A2B38) : const Color(0xFF6B5030)).withValues(alpha: 0.65));
      canvas.drawPath(
          p,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = (i == hint ? Pal.success : Colors.white).withValues(alpha: i == hint ? 0.9 : 0.18));
    }
    canvas.drawCircle(home, 34, Paint()..color = const Color(0xFF6B5030).withValues(alpha: 0.7));
    // Trees around the edges, seeded per fork.
    final rnd = Random(seed);
    for (var k = 0; k < 22; k++) {
      final x = rnd.nextDouble() * size.width;
      final y = rnd.nextDouble() * size.height;
      final fs = 24 + rnd.nextDouble() * 22;
      final tree = rnd.nextBool() ? '🌲' : '🌳';
      // Keep the middle band (trails + doors) clear.
      var near = (Offset(x, y) - home).distance < 70;
      for (final o in options) {
        if ((Offset(x, y) - o).distance < 62) near = true;
      }
      final nearTrail = (x - home.dx).abs() < 26 && y > size.height * 0.4;
      if (near || nearTrail) continue;
      final tp = TextPainter(text: TextSpan(text: tree, style: TextStyle(fontSize: fs)), textDirection: TextDirection.ltr)..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ForestPainter old) => old.tried.length != tried.length || old.hint != hint || old.deadEnd != deadEnd || old.seed != seed || old.home != home;
}
