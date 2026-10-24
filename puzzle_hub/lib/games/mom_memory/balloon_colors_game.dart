import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'mm_common.dart';

enum _Phase { intro, show, ask, result }

/// Gubbaaron ke rang – a row of coloured balloons floats up for a few
/// seconds; then gentle questions ask which colour balloon number N had.
/// No timer while answering, three questions a round.
class BalloonColorsGame extends StatefulWidget {
  const BalloonColorsGame({super.key, this.random});
  final math.Random? random;

  static const maxLevel = 9;
  static const questions = 3;

  /// Balloons in [level] (3 → 7).
  static int count(int level) => 3 + level ~/ 2;

  /// How long the balloons stay (ms): calm and long, a bit shorter later.
  static int showMs(int level) => 5200 - level * 250;

  static const colors = [Mm.rose, Mm.sky, Mm.mint, Mm.butter, Mm.lavender, Mm.peach];

  @override
  State<BalloonColorsGame> createState() => _BalloonColorsGameState();
}

class _BalloonColorsGameState extends State<BalloonColorsGame> with SingleTickerProviderStateMixin {
  late final math.Random _r = widget.random ?? math.Random();
  late int _level = Storage.getInt('mom.balloon.level').clamp(0, BalloonColorsGame.maxLevel);
  _Phase _phase = _Phase.intro;
  List<int> _balloons = [];
  List<int> _asks = [];
  int _q = 0, _correct = 0, _stars = 0;
  int? _picked;
  late final AnimationController _bar = AnimationController(vsync: this);

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _begin() {
    final n = BalloonColorsGame.count(_level);
    _balloons = [for (var i = 0; i < n; i++) _r.nextInt(BalloonColorsGame.colors.length)];
    _asks = (List.generate(n, (i) => i)..shuffle(_r)).take(BalloonColorsGame.questions).toList();
    _q = 0;
    _correct = 0;
    _picked = null;
    setState(() => _phase = _Phase.show);
    _bar.duration = Duration(milliseconds: BalloonColorsGame.showMs(_level));
    _bar.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.show) setState(() => _phase = _Phase.ask);
    });
  }

  void _answer(int c) {
    if (_picked != null) return;
    softTap();
    final right = _balloons[_asks[_q]] == c;
    if (right) _correct++;
    setState(() => _picked = c);
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (_q + 1 < _asks.length) {
        setState(() {
          _q++;
          _picked = null;
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    _stars = _correct;
    Storage.setBest('mom.balloon.stars.$_level', _stars);
    Storage.setBest('mom.balloon.best', _correct);
    if (_stars >= 2 && _level < BalloonColorsGame.maxLevel) {
      Storage.setBest('mom.balloon.level', _level + 1);
    }
    recordPlay();
    Rewards.onLevelComplete('mom_memory', 'balloon-L${_level + 1}', stars: _stars);
    setState(() => _phase = _Phase.result);
  }

  Widget _balloon(int i, {bool hidden = false, bool highlight = false}) {
    final c = BalloonColorsGame.colors[_balloons[i]];
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 44,
        height: 56,
        decoration: BoxDecoration(
          color: hidden ? Colors.white.withValues(alpha: 0.12) : c,
          borderRadius: const BorderRadius.all(Radius.elliptical(44, 56)),
          border: Border.all(color: highlight ? Pal.gold : Colors.white.withValues(alpha: 0.5), width: highlight ? 3 : 1.5),
          boxShadow: hidden ? null : [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 10)],
        ),
        alignment: Alignment.center,
        child: Text(hidden ? '?' : '', style: const TextStyle(color: Colors.white70, fontSize: 20, fontWeight: FontWeight.w900)),
      ),
      Container(width: 1.5, height: 18, color: Colors.white54),
      Text('${i + 1}', style: TextStyle(color: highlight ? Pal.gold : Pal.textDim, fontWeight: FontWeight.w900)),
    ]);
  }

  Widget _row({required bool hidden, int? highlight}) => Wrap(
        alignment: WrapAlignment.center,
        spacing: 10,
        runSpacing: 14,
        children: [for (var i = 0; i < _balloons.length; i++) _balloon(i, hidden: hidden, highlight: highlight == i)],
      );

  Widget _play() {
    if (_phase == _Phase.show) {
      return Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(tr('mom_memory.balloon_watch'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        MmBar(animation: _bar),
        Expanded(child: Center(child: _row(hidden: false).animate().fadeIn(duration: 400.ms).slideY(begin: 0.3, end: 0))),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PremiumButton(
            label: tr('mom_memory.memorized'),
            compact: true,
            color: Mm.lavender,
            onTap: () {
              _bar.stop();
              setState(() => _phase = _Phase.ask);
            },
          ),
        ),
      ]);
    }
    final idx = _asks[_q];
    final right = _balloons[idx];
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(
          tr('mom_memory.balloon_ask', {'n': idx + 1, 'q': _q + 1, 'total': _asks.length}),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      Expanded(child: Center(child: _row(hidden: true, highlight: idx))),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
          for (var c = 0; c < BalloonColorsGame.colors.length; c++)
            GestureDetector(
              key: ValueKey('balloon_color_$c'),
              onTap: () => _answer(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: BalloonColorsGame.colors[c],
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _picked == null
                        ? Colors.white54
                        : (c == right ? const Color(0xFF22C55E) : (c == _picked ? const Color(0xFFEF4444) : Colors.white24)),
                    width: _picked != null && (c == right || c == _picked) ? 4 : 2,
                  ),
                ),
                child: _picked != null && c == right ? const Icon(Icons.check_rounded, color: Mm.ink) : null,
              ),
            ),
        ]),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) => MmPage(
        title: tr('mom_memory.balloon_title'),
        body: Column(children: [
          Expanded(
            child: switch (_phase) {
              _Phase.intro => MmIntro(
                  emoji: '🎈',
                  level: _level,
                  unlocked: Storage.getInt('mom.balloon.level'),
                  maxLevel: BalloonColorsGame.maxLevel,
                  text: tr('mom_memory.balloon_intro'),
                  onLevel: (i) => setState(() => _level = i),
                  onStart: _begin,
                ),
              _Phase.result => Column(children: [
                  Expanded(child: Center(child: _row(hidden: false))),
                  SizedBox(
                    height: 250,
                    child: MmResult(
                      title: tr('mom_memory.balloon_result', {'n': _correct, 'total': _asks.length}),
                      stars: _stars,
                      message: _correct == _asks.length ? pick(praise) : tr('mom_memory.good_try'),
                      onAgain: _begin,
                      onNext: _level < BalloonColorsGame.maxLevel
                          ? () {
                              setState(() => _level++);
                              _begin();
                            }
                          : null,
                    ),
                  ),
                ]),
              _ => _play(),
            },
          ),
          const MmFootnote(),
        ]),
      );
}
