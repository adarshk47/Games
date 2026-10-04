import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/economy/continue_offer.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mb_tiers.dart';
import 'logic/number_logic.dart';
import 'mb_widgets.dart';

enum _Phase { setup, show, input, feedback }

class NumberMemoryScreen extends StatefulWidget {
  const NumberMemoryScreen({super.key});
  @override
  State<NumberMemoryScreen> createState() => _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends State<NumberMemoryScreen> {
  static final _teal = Pal.accents[3];
  _Phase phase = _Phase.setup;
  Tier tier = Tier.medium;
  NumberTierParams get params => numberTierParams[tier]!;
  int maxLives = 3;
  int lives = 3;
  int level = 1; // current round (digits = startDigits + level - 1)
  int reached = 0; // rounds cleared
  String number = '';
  String answer = '';
  bool lastOk = true;
  int token = 0;
  bool continueUsed = false; // extra-life offer shown this run

  @override
  void dispose() {
    token++;
    super.dispose();
  }

  void _begin(Tier t) {
    tier = t;
    maxLives = params.lives;
    lives = params.lives;
    level = 1;
    reached = 0;
    continueUsed = false;
    _show();
  }

  Future<void> _show() async {
    final my = ++token;
    number = generateNumber(digitsForLevel(level, params.startDigits));
    answer = '';
    setState(() => phase = _Phase.show);
    await Future.delayed(params.displayFor(number.length));
    if (!mounted || my != token) return;
    setState(() => phase = _Phase.input);
  }

  void _key(String k) {
    if (phase != _Phase.input) return;
    AppAudio.play(Sound.tap);
    AppAudio.haptic();
    setState(() {
      if (k == '<') {
        if (answer.isNotEmpty) answer = answer.substring(0, answer.length - 1);
      } else if (answer.length < number.length + 2) {
        answer += k;
      }
    });
  }

  Future<void> _submit() async {
    if (phase != _Phase.input || answer.isEmpty) return;
    final ok = isCorrectAnswer(number, answer);
    setState(() {
      lastOk = ok;
      phase = _Phase.feedback;
      if (ok) {
        reached = level;
      } else {
        lives--;
      }
    });
    if (ok) {
      AppAudio.play(Sound.success);
      AppAudio.haptic();
    } else {
      AppAudio.play(Sound.fail);
      AppAudio.haptic(true);
    }
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (ok) {
      level++;
      _show();
    } else if (lives <= 0) {
      if (!continueUsed) {
        continueUsed = true;
        final paid = await showContinueOffer(context, OfferKind.extraLife);
        if (!mounted) return;
        if (paid) {
          setState(() => lives = 1);
          _show();
          return;
        }
      }
      await _gameOver();
    } else {
      _show(); // same length, new number
    }
  }

  Future<void> _gameOver() async {
    final key = numberBestKeyFor(tier);
    final prevBest = Storage.getInt(key);
    final newBest = Storage.setBest(key, reached);
    Rewards.onGameEnd('memory_boost', score: Storage.getInt(key));
    const milestones = {5: 1, 7: 2, 9: 3, 12: 3};
    milestones.forEach((n, st) {
      if (reached >= n && prevBest < n) {
        Rewards.onLevelComplete('memory_boost', numberRewardKey(tier, n), stars: st);
      }
    });
    final choice = await showResultDialog(
      context,
      title: 'Game over',
      emoji: '🔢',
      color: _teal,
      message:
          'Rounds cleared: $reached\n${newBest && reached > 0 ? 'New best!' : 'Best: ${Storage.getInt(numberBestKeyFor(tier))}'}',
    );
    if (!mounted) return;
    if (choice == DialogChoice.retry) {
      _begin(tier);
    } else {
      setState(() => phase = _Phase.setup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: phase == _Phase.setup ? 'Number Memory' : 'Number - ${tier.label}',
      tint: mbTint,
      onBack: phase == _Phase.setup
          ? null
          : () {
              token++;
              setState(() => phase = _Phase.setup);
            },
      body: phase == _Phase.setup ? _setup() : _play(),
    );
  }

  Widget _setup() {
    String sec(Tier t) => '${(numberTierParams[t]!.displayFor(numberTierParams[t]!.startDigits).inMilliseconds / 1000).toStringAsFixed(1)}s';
    return TierChooser(
      game: 'number',
      heading: 'Memorize the number, then type it. Each round adds a digit. Pick a difficulty.',
      descriptions: {
        for (final t in Tier.values)
          t: 'Starts at ${numberTierParams[t]!.startDigits} digit${numberTierParams[t]!.startDigits > 1 ? 's' : ''}, '
              '${sec(t)} to look, ${numberTierParams[t]!.lives} ${numberTierParams[t]!.lives > 1 ? 'lives' : 'life'}.',
      },
      bestText: (t) => 'Best round ${Storage.getInt(numberBestKeyFor(t))}',
      onSelect: _begin,
    );
  }

  Widget _digits(String text, {Color color = Colors.white, Color glow = const Color(0xFFB794FF)}) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text,
          style: TextStyle(
            color: color,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            shadows: [
              Shadow(color: glow.withValues(alpha: 0.9), blurRadius: 24),
              Shadow(color: glow.withValues(alpha: 0.5), blurRadius: 48),
            ],
          )),
    );
  }

  Widget _play() {
    Widget center;
    switch (phase) {
      case _Phase.show:
        final d = params.displayFor(number.length);
        center = SizedBox(
          width: 280,
          height: 280,
          child: TweenAnimationBuilder<double>(
            key: ValueKey(number + token.toString()),
            tween: Tween(begin: 1, end: 0),
            duration: d,
            builder: (c, v, child) => CustomPaint(
              painter: _RingPainter(v, Color.lerp(Pal.danger, _teal, v)!),
              child: child,
            ),
            child: Padding(padding: const EdgeInsets.all(34), child: Center(child: _digits(number))),
          ),
        );
      case _Phase.input:
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('What was the number?', style: TextStyle(color: Pal.textDim, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          GlassCard(
            blur: 0,
            radius: 24,
            glow: _teal,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: _digits(answer.isEmpty ? '_' : answer, glow: _teal),
          ),
        ]);
      case _Phase.feedback:
        final col = lastOk ? Pal.success : Pal.danger;
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(lastOk ? Icons.check_circle_rounded : Icons.cancel_rounded, size: 72, color: col, shadows: [
            Shadow(color: col.withValues(alpha: 0.8), blurRadius: 30),
          ]).animate().scale(begin: const Offset(0.3, 0.3), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 600.ms),
          const SizedBox(height: 10),
          Text(lastOk ? 'Correct!' : 'It was $number',
              style: TextStyle(color: col, fontSize: 24, fontWeight: FontWeight.w900)),
          if (!lastOk) Text('You typed $answer', style: const TextStyle(color: Pal.textDim, fontSize: 15)),
        ]);
      case _Phase.setup:
        center = const SizedBox();
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(14),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          StatChip(Icons.layers_rounded, 'Round $level'),
          GlassCard(
            blur: 0,
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(children: [
              for (var i = 0; i < maxLives; i++)
                Icon(i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: Pal.danger, size: 19),
            ]),
          ),
          StatChip(Icons.emoji_events_rounded, 'Best ${Storage.getInt(numberBestKeyFor(tier))}', color: Pal.gold),
        ]),
      ),
      Expanded(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: KeyedSubtree(key: ValueKey('$phase$level$lives'), child: center),
          ),
        ),
      ),
      _keypad(),
    ]);
  }

  Widget _keypad() {
    final enabled = phase == _Phase.input;
    Widget key(String label, {VoidCallback? onTap, Widget? child, Color? color}) {
      final c = color ?? const Color(0xFF7C5CFF);
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Opacity(
            opacity: enabled ? 1 : 0.4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? (onTap ?? () => _key(label)) : null,
              child: _GlossyKey(
                color: c,
                child: child ??
                    Text(label, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ),
      );
    }

    Widget row(List<Widget> c) => Row(children: c);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          key('<', child: const Icon(Icons.backspace_rounded, color: Colors.white), color: Pal.danger),
          key('0'),
          key('OK', onTap: _submit, child: const Icon(Icons.check_rounded, color: Colors.white, size: 30), color: const Color(0xFF22C58B)),
        ]),
      ]),
    );
  }
}

class _GlossyKey extends StatefulWidget {
  const _GlossyKey({required this.child, required this.color});
  final Widget child;
  final Color color;
  @override
  State<_GlossyKey> createState() => _GlossyKeyState();
}

class _GlossyKeyState extends State<_GlossyKey> {
  bool down = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.color;
    return Listener(
      onPointerDown: (_) => setState(() => down = true),
      onPointerUp: (_) => setState(() => down = false),
      onPointerCancel: (_) => setState(() => down = false),
      child: AnimatedScale(
        scale: down ? 0.93 : 1,
        duration: const Duration(milliseconds: 90),
        child: Container(
          height: 58,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(c, Colors.white, 0.3)!.withValues(alpha: 0.75), c.withValues(alpha: 0.45)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: c.withValues(alpha: down ? 0.7 : 0.3), blurRadius: down ? 16 : 8, offset: const Offset(0, 3))],
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.v, this.color);
  final double v; // 1 -> 0
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final center = s.center(Offset.zero);
    final r = s.shortestSide / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = Colors.white.withValues(alpha: 0.1),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * v,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.v != v || old.color != color;
}
