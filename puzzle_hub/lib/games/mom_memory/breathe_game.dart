import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_logic.dart';
import 'mm_common.dart';

enum _Step { choose, breathe, quiz, done }

class BreatheGame extends StatefulWidget {
  const BreatheGame({super.key});
  @override
  State<BreatheGame> createState() => _BreatheGameState();
}

class _BreatheGameState extends State<BreatheGame> with SingleTickerProviderStateMixin {
  final _rng = math.Random();
  _Step _step = _Step.choose;
  int _minutes = 1;
  int _colorIdx = 0;
  List<int> _options = [];
  int? _answer;
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _start(int minutes) {
    _minutes = minutes;
    _colorIdx = _rng.nextInt(breathColors.length);
    _c.duration = Duration(seconds: minutes * 60);
    setState(() => _step = _Step.breathe);
    _c.forward(from: 0).whenComplete(() {
      if (!mounted || _step != _Step.breathe) return;
      _options = colorOptions(_colorIdx, _rng);
      setState(() => _step = _Step.quiz);
    });
  }

  void _stopEarly() {
    _c.stop();
    setState(() => _step = _Step.choose);
  }

  void _answerQ(int idx) {
    softTap();
    Storage.setInt('mom.breath.sessions', Storage.getInt('mom.breath.sessions') + 1);
    Storage.setInt('mom.breath.minutes', Storage.getInt('mom.breath.minutes') + _minutes);
    recordPlay();
    setState(() {
      _answer = idx;
      _step = _Step.done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MmPage(
      title: 'Breathe & Focus',
      body: Column(children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            child: KeyedSubtree(key: ValueKey(_step), child: _content()),
          ),
        ),
        const MmFootnote(),
      ]),
    );
  }

  Widget _content() {
    switch (_step) {
      case _Step.choose:
        return _choose();
      case _Step.breathe:
        return _breathe();
      case _Step.quiz:
        return _quiz();
      case _Step.done:
        return _done();
    }
  }

  Widget _choose() {
    final sessions = Storage.getInt('mom.breath.sessions');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🌬️', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 12),
          const Text('Gehri saans, shaant mann',
              style: TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Saans andar 4, rokein 4, bahar 6.\nBas circle ke saath saath chaliye.',
              textAlign: TextAlign.center, style: TextStyle(color: Pal.textDim, fontSize: 15, height: 1.45)),
          const SizedBox(height: 24),
          Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
            for (final m in [1, 2, 3]) PremiumButton(label: '$m min', color: Mm.pads[m], onTap: () => _start(m)),
          ]),
          const SizedBox(height: 22),
          Text('Ab tak $sessions session', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }

  Widget _breathe() {
    final col = Color(breathColors[_colorIdx].argb);
    return GestureDetector(
      onLongPress: _stopEarly,
      child: Column(children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, _) {
              final secs = _c.value * _minutes * 60;
              final b = breathAt(secs);
              final remaining = (_minutes * 60 - secs).ceil();
              final (label, left) = switch (b.phase) {
                BreathPhase.inhale => ('Saans andar...', (inhaleSec * (1 - b.progress)).ceil()),
                BreathPhase.hold => ('Aaram se rokein', (holdSec * (1 - b.progress)).ceil()),
                BreathPhase.exhale => ('Dheere se bahar...', (exhaleSec * (1 - b.progress)).ceil()),
              };
              final scale = Curves.easeInOut.transform(breathScale(secs));
              return Stack(alignment: Alignment.center, children: [
                RepaintBoundary(child: CustomPaint(size: Size.infinite, painter: _BreathPainter(scale, col))),
                Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(label, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('$left', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 34, fontWeight: FontWeight.w300)),
                ]),
                Positioned(
                  bottom: 8,
                  child: Text('${remaining ~/ 60}:${(remaining % 60).toString().padLeft(2, '0')}',
                      style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700)),
                ),
              ]);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PremiumButton(label: 'Rukein', compact: true, color: const Color(0xFF6F63B8), onTap: _stopEarly),
        ),
      ]),
    );
  }

  Widget _quiz() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Bahut badhiya! 🌸', style: TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('Ek chhota sa sawaal:\nKaunsa rang dikha tha?',
                textAlign: TextAlign.center, style: TextStyle(color: Pal.textDim, fontSize: 17, height: 1.45)),
            const SizedBox(height: 26),
            Wrap(spacing: 16, runSpacing: 16, alignment: WrapAlignment.center, children: [
              for (final o in _options)
                Pressable(
                  onTap: () => _answerQ(o),
                  child: Column(children: [
                    Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(breathColors[o].argb),
                        border: Border.all(color: Colors.white54, width: 2),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(breathColors[o].name, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ]),
        ),
      );

  Widget _done() {
    final ok = _answer == _colorIdx;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ok ? '🌷' : '🌼', style: const TextStyle(fontSize: 64)).animate().scale(curve: Curves.easeOutBack, duration: 600.ms),
          const SizedBox(height: 12),
          Text(ok ? 'Bilkul sahi! ${breathColors[_colorIdx].name} tha.' : 'Koi baat nahi, ${breathColors[_colorIdx].name} tha.',
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text('Aapne $_minutes min shaanti se bitaye. Shukriya!',
              textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 15)),
          const SizedBox(height: 24),
          PremiumButton(label: 'Phir se', color: Mm.rose, onTap: () => setState(() => _step = _Step.choose)),
        ]),
      ),
    );
  }
}

class _BreathPainter extends CustomPainter {
  _BreathPainter(this.t, this.color);
  final double t; // 0..1
  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final maxR = math.min(s.width, s.height) * 0.42;
    final r = maxR * (0.45 + 0.55 * t);
    // soft outer halos
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(c, r + i * 14 * (0.5 + t), Paint()..color = color.withValues(alpha: 0.07 * (4 - i) * (0.6 + t * 0.4)));
    }
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(colors: [
          Color.lerp(color, Colors.white, 0.45)!.withValues(alpha: 0.95),
          color.withValues(alpha: 0.75),
        ]).createShader(Rect.fromCircle(center: c, radius: r)),
    );
    canvas.drawCircle(c, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white.withValues(alpha: 0.5));
  }

  @override
  bool shouldRepaint(_BreathPainter o) => o.t != t || o.color != color;
}
