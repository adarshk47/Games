import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/focus_common.dart';
import 'logic/focus_difficulty.dart';
import 'logic/odd_logic.dart';
import 'logic/rule_logic.dart';
import 'logic/stroop_logic.dart';

const focusTint = Color(0xFF5EEAD4);

/// Localized tier name (Easy / Medium / Hard / Extreme).
String focusTierName(FocusTier t) => tr('common.tier.${t.name}');

/// Localized name of a Stroop color. Display only: answers are always judged
/// by comparing [StroopColor] ids, never by this text.
String stroopColorName(StroopColor c) => tr('focus_color.color.${c.name}');

class FocusModeInfo {
  const FocusModeInfo(this.mode, this.icon, this.color);
  final FocusMode mode;
  final IconData icon;
  final Color color;

  String get title => tr('focus_color.mode.${mode.name}.title');
  String get blurb => tr('focus_color.mode.${mode.name}.blurb');

  /// Best score for a tier (medium also honours the pre-difficulty legacy key).
  int bestFor(FocusTier t) {
    final v = Storage.getInt(focusBestKey(mode, t));
    return t == FocusTier.medium ? max(v, Storage.getInt('focus.${mode.name}.best')) : v;
  }
}

const focusModes = <FocusModeInfo>[
  FocusModeInfo(FocusMode.stroop, Icons.palette_rounded, Color(0xFFFF6FB5)),
  FocusModeInfo(FocusMode.odd, Icons.grid_view_rounded, Color(0xFF4DA8FF)),
  FocusModeInfo(FocusMode.rule, Icons.rule_rounded, Color(0xFFFFC857)),
];

enum _Phase { countdown, playing, over }

class FocusPlayScreen extends StatefulWidget {
  const FocusPlayScreen({super.key, required this.info, required this.tier});
  final FocusModeInfo info;
  final FocusTier tier;
  @override
  State<FocusPlayScreen> createState() => _FocusPlayScreenState();
}

class _FocusPlayScreenState extends State<FocusPlayScreen> with TickerProviderStateMixin {
  late final AnimationController _t; // elapsed fraction 0..1
  late final AnimationController _shake;
  late final AnimationController _flash;
  final _rng = Random();
  late StroopGenerator _stroopGen;
  late OddGenerator _oddGen;
  late RuleGenerator _ruleGen;
  Timer? _cd;

  FocusModeInfo get info => widget.info;
  FocusTier get tier => widget.tier;
  late final FocusParams _p = focusParams(widget.info.mode, widget.tier);
  String get _bestKey => focusBestKey(info.mode, tier);
  DateTime _lastOk = DateTime.fromMillisecondsSinceEpoch(0);
  _Phase _phase = _Phase.countdown;
  int _count = 3;
  int _score = 0, _streak = 0, _bestStreak = 0, _solved = 0, _wrong = 0, _lives = 3;
  int _burst = 0;
  String _burstText = '';
  Color _flashColor = Pal.success;
  StroopRound? _sr;
  OddRound? _or;
  RuleRound? _rr;
  int _round = 0; // bumps per new round for transitions
  bool _continueUsed = false; // extra-life / extra-time offer shown this run
  bool _offering = false; // continue offer dialog is open

  double get _total => _p.seconds.toDouble();

  @override
  void initState() {
    super.initState();
    _t = AnimationController(vsync: this, duration: Duration(seconds: _p.seconds))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) _finish(timeUp: true);
      });
    _shake = AnimationController(vsync: this, duration: 380.ms);
    _flash = AnimationController(vsync: this, duration: 450.ms);
    _begin();
  }

  @override
  void dispose() {
    _cd?.cancel();
    _t.dispose();
    _shake.dispose();
    _flash.dispose();
    super.dispose();
  }

  void _begin() {
    _cd?.cancel();
    _stroopGen = StroopGenerator(_rng, _p);
    _oddGen = OddGenerator(_rng, _p);
    _ruleGen = RuleGenerator(_rng, _p);
    _t.reset();
    setState(() {
      _phase = _Phase.countdown;
      _count = 3;
      _score = _streak = _bestStreak = _solved = _wrong = 0;
      _lives = _p.lives;
      _burstText = '';
      _continueUsed = false;
      _offering = false;
    });
    AppAudio.play(Sound.tap);
    _cd = Timer.periodic(const Duration(milliseconds: 800), (tm) {
      if (!mounted) return;
      if (_count > 1) {
        AppAudio.play(Sound.tap);
        setState(() => _count--);
      } else {
        tm.cancel();
        _nextRound();
        setState(() => _phase = _Phase.playing);
        _t.forward(from: 0);
      }
    });
  }

  void _nextRound() {
    _round++;
    switch (info.mode) {
      case FocusMode.stroop:
        _sr = _stroopGen.next(_solved);
      case FocusMode.odd:
        _or = _oddGen.next(_solved);
      case FocusMode.rule:
        _rr = _ruleGen.next(_solved);
    }
  }

  void _adjustTime(double seconds) {
    final v = (_t.value + seconds / _total).clamp(0.0, 1.0);
    _t.value = v;
    if (v >= 1) {
      _finish(timeUp: true);
    } else {
      _t.forward();
    }
  }

  void _answer(bool ok) {
    if (_phase != _Phase.playing || _offering) return;
    if (ok) {
      final now = DateTime.now();
      final spammy = now.difference(_lastOk).inMilliseconds < 450;
      _lastOk = now;
      final before = comboMultiplier(_streak);
      _score += info.mode == FocusMode.odd ? 1 : pointsFor(_streak);
      _streak++;
      _solved++;
      if (_streak > _bestStreak) _bestStreak = _streak;
      _flashColor = Pal.success;
      _flash.forward(from: 0);
      final after = comboMultiplier(_streak);
      if (after > before) {
        _burst++;
        _burstText = tr('focus_color.combo', {'n': after});
        AppAudio.play(Sound.coin);
      } else {
        AppAudio.play(spammy ? Sound.pop : Sound.success);
        if (info.mode == FocusMode.stroop && _p.bonusEvery > 0 && _streak % _p.bonusEvery == 0) {
          _burst++;
          _burstText = tr('focus_color.bonus', {'n': _p.bonusSeconds});
          _adjustTime(-_p.bonusSeconds.toDouble());
        }
      }
      AppAudio.haptic();
      _nextRound();
      setState(() {});
    } else {
      AppAudio.play(Sound.fail);
      AppAudio.haptic(true);
      _wrong++;
      _streak = 0;
      _flashColor = Pal.danger;
      _flash.forward(from: 0);
      _shake.forward(from: 0);
      if (_p.lives > 0) _lives--;
      if (info.mode != FocusMode.odd) _nextRound();
      setState(() {});
      if (_p.lives > 0 && _lives <= 0) {
        _finish();
        return;
      }
      if (_p.wrongPenalty > 0) _adjustTime(_p.wrongPenalty);
    }
  }

  Future<void> _finish({bool timeUp = false}) async {
    if (_phase == _Phase.over || _offering) return;
    _t.stop();
    if (timeUp) AppAudio.play(Sound.fail);
    if (!_continueUsed && _phase == _Phase.playing) {
      _continueUsed = true;
      _offering = true;
      final paid = await showContinueOffer(context, OfferKind.extraLife);
      if (!mounted) return;
      _offering = false;
      if (paid) {
        setState(() {
          if (_p.lives > 0 && _lives <= 0) _lives = 1;
        });
        if (timeUp) {
          _adjustTime(-10);
        } else {
          _t.forward();
        }
        return;
      }
    }
    setState(() => _phase = _Phase.over);
    final isBest = Storage.setBest(_bestKey, _score);
    final stars = focusStars(info.mode, tier, _score);
    Rewards.onGameEnd('focus_color', score: _score, won: stars >= 1);
    if (stars >= 1) {
      Rewards.onLevelComplete('focus_color', '${info.mode.name}-${tier.name}-star$stars', stars: stars, score: _score);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final unit = tr(info.mode == FocusMode.odd ? 'focus_color.unit.found' : 'focus_color.unit.pts');
    await showPremiumDialog(
      context,
      title: isBest && _score > 0
          ? tr('focus_color.result.new_best')
          : tr(stars == 0 ? 'focus_color.result.keep_focusing' : 'focus_color.result.time'),
      emoji: isBest && _score > 0 ? '🏆' : (stars == 0 ? '🎯' : '🧠'),
      stars: stars,
      color: info.color,
      message: tr('focus_color.result.message', {
        'score': _score,
        'unit': unit,
        'streak': _bestStreak,
        'wrong': _wrong,
        'tier': focusTierName(tier),
        'best': max(info.bestFor(tier), _score),
      }),
      actions: [
        DialogAction(tr('common.menu'), () {
          if (mounted) Navigator.of(context).maybePop();
        }),
        DialogAction(tr('common.play_again'), () {
          if (mounted) _begin();
        }, primary: true),
      ],
    );
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: '${info.title} - ${focusTierName(tier)}',
      tint: focusTint,
      body: Stack(children: [
        Column(children: [
          _hud(),
          Expanded(
            child: AnimatedBuilder(
              animation: _shake,
              builder: (_, child) {
                final v = _shake.value;
                final dx = sin(v * pi * 7) * 12 * (1 - v);
                return Transform.translate(offset: Offset(dx, 0), child: child);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: _phase == _Phase.countdown ? _countdown() : _body(),
              ),
            ),
          ),
        ]),
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _flash,
              builder: (_, _) => ColoredBox(color: _flashColor.withValues(alpha: 0.22 * (1 - _flash.value))),
            ),
          ),
        ),
        if (_burstText.isNotEmpty)
          Positioned(
            top: 96,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Text(_burstText,
                    style: TextStyle(
                        color: Pal.gold,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Pal.goldDeep.withValues(alpha: 0.9), blurRadius: 18)]))
                    .animate(key: ValueKey(_burst))
                    .scale(begin: const Offset(0.4, 0.4), end: const Offset(1.15, 1.15), curve: Curves.easeOutBack, duration: 350.ms)
                    .then(delay: 450.ms)
                    .fadeOut(duration: 300.ms)
                    .slideY(begin: 0, end: -0.6, duration: 300.ms),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _hud() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(children: [
        Expanded(
            child: _stat(info.mode == FocusMode.odd ? tr('focus_color.hud.found') : tr('common.score').toUpperCase(),
                '$_score', Pal.gold)),
        const SizedBox(width: 10),
        _ring(),
        const SizedBox(width: 10),
        Expanded(
          child: _p.lives > 0
              ? GlassCard(
                  blur: 0,
                  radius: 18,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Column(children: [
                    Text(tr('common.lives').toUpperCase(), style: const TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
                    const SizedBox(height: 2),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < _p.lives; i++)
                        Icon(i < _lives ? Icons.favorite_rounded : Icons.heart_broken_rounded,
                            size: 20, color: i < _lives ? Pal.danger : Pal.textDim),
                    ]),
                  ]),
                )
              : _stat(tr('focus_color.hud.streak'), '$_streak', Pal.success, showCombo: false),
        ),
      ]),
    );
  }

  Widget _stat(String label, String value, Color c, {bool showCombo = true}) => GlassCard(
        blur: 0,
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(children: [
          Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value, key: ValueKey('focus-stat-$label'), style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900)),
          if (comboMultiplier(_streak) > 1 && showCombo)
            Text('x${comboMultiplier(_streak)}', style: const TextStyle(color: Pal.goldDeep, fontSize: 11, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _ring() {
    return SizedBox(
      width: 84,
      height: 84,
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, _) {
          final left = (1 - _t.value) * _total;
          final low = left <= 8 && _phase == _Phase.playing;
          return CustomPaint(
            painter: _RingPainter(1 - _t.value, low ? Pal.danger : info.color),
            child: Center(
              child: Text('${left.ceil()}',
                  style: TextStyle(color: low ? Pal.danger : Pal.text, fontSize: 26, fontWeight: FontWeight.w900)),
            ),
          );
        },
      ),
    );
  }

  Widget _countdown() => Center(
        child: Text(_count.toString(),
                key: ValueKey(_count),
                style: TextStyle(
                    color: info.color,
                    fontSize: 140,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: info.color.withValues(alpha: 0.8), blurRadius: 40)]))
            .animate(key: ValueKey(_count))
            .scale(begin: const Offset(1.6, 1.6), end: const Offset(1, 1), curve: Curves.easeOutBack, duration: 450.ms)
            .fadeIn(duration: 200.ms),
      );

  Widget _body() {
    switch (info.mode) {
      case FocusMode.stroop:
        return _stroopBody();
      case FocusMode.odd:
        return _oddBody();
      case FocusMode.rule:
        return _ruleBody();
    }
  }

  // ---- Stroop
  Widget _stroopBody() {
    final r = _sr;
    if (r == null) return const SizedBox();
    final ink = Color(r.ink.argb);
    return Column(children: [
      Text(tr('focus_color.stroop.prompt'), style: const TextStyle(color: Pal.textDim, fontSize: 15, fontWeight: FontWeight.w600)),
      Expanded(
        child: Center(
          child: GlassCard(
            blur: 0,
            radius: 32,
            glow: ink,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(stroopColorName(r.word),
                  key: const ValueKey('stroop-word'),
                  style: TextStyle(
                      color: ink,
                      fontSize: 56,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      shadows: [Shadow(color: ink.withValues(alpha: 0.5), blurRadius: 18)])),
            )
                .animate(key: ValueKey(_round))
                .scale(begin: const Offset(0.85, 0.85), end: const Offset(1, 1), duration: 160.ms, curve: Curves.easeOut),
          ),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final c in r.options)
            SizedBox(
              width: (MediaQuery.of(context).size.width - 32 - 12) / 2,
              child: Pressable(
                onTap: () => _answer(r.isCorrect(c)),
                child: _glossy(stroopColorName(c), h: r.options.length > 6 ? 50 : 62, font: r.options.length > 6 ? 16 : 18),
              ),
            ),
        ],
      ),
    ]);
  }

  Widget _glossy(String label, {Color base = const Color(0xFF4B3F9E), double h = 62, double font = 18}) => Container(
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color.lerp(base, Colors.white, 0.28)!, base, Color.lerp(base, Colors.black, 0.3)!],
            stops: const [0, 0.5, 1],
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: base.withValues(alpha: 0.5), blurRadius: 14, offset: const Offset(0, 5))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, style: TextStyle(color: Colors.white, fontSize: font, fontWeight: FontWeight.w800, letterSpacing: 1)),
        ),
      );

  // ---- Odd one out
  Widget _oddBody() {
    final r = _or;
    if (r == null) return const SizedBox();
    return LayoutBuilder(builder: (_, box) {
      final side = min(box.maxWidth, box.maxHeight);
      const gap = 8.0;
      final tile = (side - gap * (r.size - 1)) / r.size;
      final base = HSLColor.fromAHSL(1, r.hue, r.saturation, r.baseLightness).toColor();
      final odd = HSLColor.fromAHSL(1, r.hue, r.saturation, r.oddLightness).toColor();
      return Center(
        child: SizedBox(
          width: side,
          height: side,
          child: Column(
            key: ValueKey(_round),
            children: [
              for (var y = 0; y < r.size; y++) ...[
                if (y > 0) const SizedBox(height: gap),
                Row(children: [
                  for (var x = 0; x < r.size; x++) ...[
                    if (x > 0) const SizedBox(width: gap),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (_) => _answer(y * r.size + x == r.oddIndex),
                      child: Container(
                        width: tile,
                        height: tile,
                        decoration: BoxDecoration(
                          color: y * r.size + x == r.oddIndex ? odd : base,
                          borderRadius: BorderRadius.circular(tile > 60 ? 18 : 10),
                        ),
                      ),
                    ),
                  ],
                ]),
              ],
            ],
          ).animate(key: ValueKey(_round)).fadeIn(duration: 140.ms).scale(begin: const Offset(0.96, 0.96), duration: 160.ms),
        ),
      );
    });
  }

  // ---- Match rule
  Widget _ruleBody() {
    final r = _rr;
    if (r == null) return const SizedBox();
    final isColor = r.rule == Rule.sameColor;
    final rc = isColor ? const Color(0xFFFF6FB5) : const Color(0xFF4DA8FF);
    return Column(children: [
      GlassCard(
        blur: 0,
        radius: 22,
        glow: rc,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(isColor ? Icons.palette_rounded : Icons.category_rounded, color: rc),
          const SizedBox(width: 10),
          Text(tr(isColor ? 'focus_color.rule.same_color' : 'focus_color.rule.same_shape'),
              style: TextStyle(color: rc, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        ]),
      ).animate(key: ValueKey('rule$_round${r.rule}')).fadeIn(duration: 120.ms).scale(begin: const Offset(0.9, 0.9), duration: 200.ms),
      Expanded(
        child: Row(key: ValueKey(_round), mainAxisAlignment: MainAxisAlignment.center, children: [
          _symCard(r.a),
          const SizedBox(width: 16),
          _symCard(r.b),
        ]).animate(key: ValueKey(_round)).fadeIn(duration: 120.ms),
      ),
      Row(children: [
        Expanded(
          child: Pressable(onTap: () => _answer(!r.answer), child: _glossy(tr('common.no').toUpperCase(), base: const Color(0xFFD14B6A), h: 70, font: 24)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Pressable(onTap: () => _answer(r.answer), child: _glossy(tr('common.yes').toUpperCase(), base: const Color(0xFF22A06B), h: 70, font: 24)),
        ),
      ]),
    ]);
  }

  Widget _symCard(Sym s) {
    final w = (MediaQuery.of(context).size.width - 32 - 16) / 2;
    final d = min(w, 150.0);
    return GlassCard(
      blur: 0,
      radius: 28,
      padding: EdgeInsets.zero,
      child: SizedBox(
        width: d,
        height: d,
        child: CustomPaint(painter: _ShapePainter(s.shape, Color(ruleColors[s.colorIndex]))),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.frac, this.color);
  final double frac;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 - 6;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawCircle(c, r, track);
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * pi * frac.clamp(0.0, 1.0);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -pi / 2, sweep, false, glow);
    canvas.drawArc(rect, -pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.frac != frac || o.color != color;
}

class _ShapePainter extends CustomPainter {
  _ShapePainter(this.shape, this.color);
  final SymShape shape;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.32;
    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color.lerp(color, Colors.white, 0.3)!, color],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    final path = Path();
    switch (shape) {
      case SymShape.circle:
        path.addOval(Rect.fromCircle(center: c, radius: r));
      case SymShape.square:
        path.addRRect(RRect.fromRectAndRadius(Rect.fromCircle(center: c, radius: r * 0.9), Radius.circular(r * 0.2)));
      case SymShape.triangle:
        path
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 1.05, c.dy + r * 0.8)
          ..lineTo(c.dx - r * 1.05, c.dy + r * 0.8)
          ..close();
      case SymShape.diamond:
        path
          ..moveTo(c.dx, c.dy - r * 1.15)
          ..lineTo(c.dx + r * 0.85, c.dy)
          ..lineTo(c.dx, c.dy + r * 1.15)
          ..lineTo(c.dx - r * 0.85, c.dy)
          ..close();
      case SymShape.star:
        for (var i = 0; i < 10; i++) {
          final rad = i.isEven ? r * 1.1 : r * 0.48;
          final a = -pi / 2 + i * pi / 5;
          final p = Offset(c.dx + cos(a) * rad, c.dy + sin(a) * rad);
          i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
        }
        path.close();
    }
    canvas.drawShadow(path, color, 10, true);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_ShapePainter o) => o.shape != shape || o.color != color;
}
