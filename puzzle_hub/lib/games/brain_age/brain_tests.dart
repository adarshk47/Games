import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/ui/ui.dart';
import 'logic/brain_age_logic.dart';

/// Every test calls [onDone] once with its raw score (see [BrainNorms]).
typedef ScoreCallback = void Function(double score);

/// Clock for timed tests (overridable in widget tests).
@visibleForTesting
Duration Function(BrainTest t) brainTestDuration = (t) => switch (t) {
      BrainTest.math => const Duration(seconds: 45),
      BrainTest.stroop => const Duration(seconds: 30),
      BrainTest.pattern => const Duration(seconds: 60),
      _ => Duration.zero,
    };

Widget _bigText(String s, {Color color = Pal.text, double size = 30}) =>
    Text(s, textAlign: TextAlign.center, style: TextStyle(color: color, fontSize: size, fontWeight: FontWeight.w900));

/// Countdown bar shown on timed tests.
class _TimeBar extends StatelessWidget {
  const _TimeBar(this.left, this.total);
  final Duration left, total;

  @override
  Widget build(BuildContext context) {
    final f = total.inMilliseconds == 0 ? 0.0 : left.inMilliseconds / total.inMilliseconds;
    return Column(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: f.clamp(0.0, 1.0),
          minHeight: 10,
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          color: f < 0.2 ? const Color(0xFFFF4D5E) : Pal.gold,
        ),
      ),
      const SizedBox(height: 6),
      Text('${(left.inMilliseconds / 1000).ceil()} s', style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w800)),
    ]);
  }
}

/// Base for the timed multiple-choice tests (math, stroop, pattern).
abstract class _TimedState<T extends StatefulWidget> extends State<T> {
  BrainTest get test;
  ScoreCallback get onDone;

  late final Duration total = brainTestDuration(test);
  late Duration left = total;
  Timer? _timer;
  final _watch = Stopwatch();
  int correct = 0, wrong = 0;
  bool finished = false;
  int? flash; // index of the last tapped choice
  bool flashOk = false;

  @override
  void initState() {
    super.initState();
    _watch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      final l = total - _watch.elapsed;
      if (l <= Duration.zero) {
        finish();
      } else if (mounted) {
        setState(() => left = l);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void finish() {
    if (finished) return;
    finished = true;
    _timer?.cancel();
    onDone(math.max(0, correct - wrong * 0.5).toDouble());
  }

  void answer(int index, bool ok) {
    if (finished) return;
    if (ok) {
      correct++;
      AppAudio.play(Sound.pop, volume: 0.5);
    } else {
      wrong++;
      AppAudio.play(Sound.fail, volume: 0.4);
      AppAudio.haptic();
    }
    setState(() {
      flash = index;
      flashOk = ok;
      next();
    });
  }

  void next();

  Widget choiceGrid(List<String> labels, int answerIndex, {List<Color>? colors}) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.2,
        children: [
          for (var i = 0; i < labels.length; i++)
            Pressable(
              key: ValueKey('choice_$i'),
              onTap: () => answer(i, i == answerIndex),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  color: colors?[i] ?? Colors.white.withValues(alpha: 0.10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                ),
                child: Text(labels[i],
                    style: TextStyle(
                      color: colors == null ? Pal.text : Colors.white,
                      fontSize: colors == null ? 26 : 18,
                      fontWeight: FontWeight.w900,
                      shadows: colors == null ? null : const [Shadow(color: Colors.black54, blurRadius: 4)],
                    )),
              ),
            ),
        ],
      );

  Widget frame(Widget question, Widget choices) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(children: [
          _TimeBar(left, total),
          const SizedBox(height: 8),
          Text(tr('brain.score_live', {'n': correct}), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
          Expanded(child: Center(child: question)),
          choices,
        ]),
      );
}

// ---------------------------------------------------------------- reaction

/// Tap as soon as the panel turns green; median of 5 tries (ms).
class ReactionTest extends StatefulWidget {
  const ReactionTest({super.key, required this.onDone, this.tries = 5, this.random});
  final ScoreCallback onDone;
  final int tries;
  final math.Random? random;

  @override
  State<ReactionTest> createState() => _ReactionTestState();
}

class _ReactionTestState extends State<ReactionTest> {
  late final math.Random _r = widget.random ?? math.Random();
  final List<int> _times = [];
  final _watch = Stopwatch();
  Timer? _wait;
  bool _green = false, _early = false;
  int? _last;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _wait?.cancel();
    super.dispose();
  }

  void _arm() {
    _green = false;
    _wait?.cancel();
    _wait = Timer(Duration(milliseconds: 1200 + _r.nextInt(2300)), () {
      if (!mounted) return;
      setState(() => _green = true);
      _watch
        ..reset()
        ..start();
    });
  }

  void _tap() {
    if (!_green) {
      AppAudio.play(Sound.fail, volume: 0.4);
      setState(() {
        _early = true;
        _last = null;
      });
      _arm();
      return;
    }
    final ms = _watch.elapsedMilliseconds;
    _times.add(ms);
    AppAudio.play(Sound.pop);
    setState(() {
      _early = false;
      _last = ms;
    });
    if (_times.length >= widget.tries) {
      _green = false;
      final s = [..._times]..sort();
      widget.onDone(s[s.length ~/ 2].toDouble());
    } else {
      _arm();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _green ? const Color(0xFF22C55E) : const Color(0xFFB91C1C);
    return GestureDetector(
      key: const ValueKey('reaction_pad'),
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _tap(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 60),
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), color: c, boxShadow: [BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 30)]),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _bigText(_green ? tr('brain.reaction.tap') : tr('brain.reaction.wait'), color: Colors.white, size: 34),
            const SizedBox(height: 12),
            if (_early) _bigText(tr('brain.reaction.early'), color: Colors.white70, size: 16),
            if (_last != null) _bigText('$_last ms', color: Colors.white, size: 22),
            const SizedBox(height: 8),
            Text(tr('brain.reaction.count', {'n': _times.length, 'total': widget.tries}),
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- memory

/// Digits are shown one by one; type them back. Each correct round adds a
/// digit; two mistakes end the test. Score = longest correct length.
class MemoryTest extends StatefulWidget {
  const MemoryTest({super.key, required this.onDone, this.random, this.digitMs = 800});
  final ScoreCallback onDone;
  final math.Random? random;
  final int digitMs;

  @override
  State<MemoryTest> createState() => _MemoryTestState();
}

class _MemoryTestState extends State<MemoryTest> {
  late final math.Random _r = widget.random ?? math.Random();
  int _len = 3, _best = 0, _misses = 0;
  String _digits = '';
  String _typed = '';
  int _showing = -1; // index of the digit on screen, -1 = typing
  Timer? _t;
  String? _feedback;

  @override
  void initState() {
    super.initState();
    _round();
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _round() {
    _digits = List.generate(_len, (i) => '${(i == 0 ? 1 : 0) + _r.nextInt(i == 0 ? 9 : 10)}').join();
    _typed = '';
    _showing = 0;
    _t?.cancel();
    _t = Timer.periodic(Duration(milliseconds: widget.digitMs), (t) {
      if (!mounted) return;
      setState(() {
        _showing++;
        if (_showing >= _digits.length) {
          _showing = -1;
          t.cancel();
        }
      });
    });
    setState(() {});
  }

  void _key(String k) {
    if (_showing != -1) return;
    setState(() {
      _feedback = null;
      if (k == '⌫') {
        if (_typed.isNotEmpty) _typed = _typed.substring(0, _typed.length - 1);
        return;
      }
      _typed += k;
    });
    if (_typed.length < _digits.length) return;
    final ok = _typed == _digits;
    AppAudio.play(ok ? Sound.pop : Sound.fail, volume: ok ? 1 : 0.5);
    setState(() {
      if (ok) {
        _best = _len;
        _len++;
        _feedback = tr('brain.memory.right');
      } else {
        _misses++;
        _feedback = tr('brain.memory.wrong', {'n': _digits});
      }
      _showing = -2; // pause: no typing until the next round
    });
    if (_misses >= 2 || _len > 14) {
      widget.onDone(_best.toDouble());
      return;
    }
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) _round();
    });
  }

  @override
  Widget build(BuildContext context) {
    final showing = _showing >= 0;
    final paused = _showing == -2;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(children: [
        Text(tr('brain.memory.length', {'n': _len}), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
        Expanded(
          child: Center(
            child: showing
                ? _bigText(_digits[_showing], size: 84)
                : Column(mainAxisSize: MainAxisSize.min, children: [
                    _bigText(_typed.isEmpty ? '?' : _typed, size: 40),
                    if (_feedback != null) ...[const SizedBox(height: 10), Text(_feedback!, style: const TextStyle(color: Pal.textDim))],
                  ]),
          ),
        ),
        Opacity(
          opacity: showing || paused ? 0.3 : 1,
          child: GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.9,
            children: [
              for (final k in ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
                k.isEmpty
                    ? const SizedBox()
                    : Pressable(
                        key: ValueKey('key_$k'),
                        onTap: () => _key(k),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: Colors.white.withValues(alpha: 0.1)),
                          child: Text(k, style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
                        ),
                      ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------- math

class MathTest extends StatefulWidget {
  const MathTest({super.key, required this.onDone, this.random});
  final ScoreCallback onDone;
  final math.Random? random;

  @override
  State<MathTest> createState() => _MathTestState();
}

class _MathTestState extends _TimedState<MathTest> {
  @override
  BrainTest get test => BrainTest.math;
  @override
  ScoreCallback get onDone => widget.onDone;

  late final math.Random _r = widget.random ?? math.Random();
  late MathQ _q = MathQ.make(_r, 0);

  @override
  void next() => _q = MathQ.make(_r, correct);

  @override
  Widget build(BuildContext context) => frame(
        _bigText('${_q.text} = ?', size: 44),
        choiceGrid([for (final c in _q.choices) '$c'], _q.choices.indexOf(_q.answer)),
      );
}

// ---------------------------------------------------------------- stroop

class StroopTest extends StatefulWidget {
  const StroopTest({super.key, required this.onDone, this.random});
  final ScoreCallback onDone;
  final math.Random? random;

  static const colors = [Color(0xFFEF4444), Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFFACC15)];
  static const names = ['red', 'blue', 'green', 'yellow'];

  @override
  State<StroopTest> createState() => _StroopTestState();
}

class _StroopTestState extends _TimedState<StroopTest> {
  @override
  BrainTest get test => BrainTest.stroop;
  @override
  ScoreCallback get onDone => widget.onDone;

  late final math.Random _r = widget.random ?? math.Random();
  int _word = 0, _ink = 1;
  List<int> _order = [0, 1, 2, 3];

  @override
  void initState() {
    super.initState();
    next();
  }

  @override
  void next() {
    _word = _r.nextInt(4);
    // Mostly mismatched (that is the hard part), sometimes the same.
    _ink = _r.nextInt(4) == 0 ? _word : (_word + 1 + _r.nextInt(3)) % 4;
    _order = [0, 1, 2, 3]..shuffle(_r);
  }

  @override
  Widget build(BuildContext context) => frame(
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('brain.stroop.ask'), style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _bigText(tr('brain.color.${StroopTest.names[_word]}'), color: StroopTest.colors[_ink], size: 54),
        ]),
        choiceGrid(
          [for (final i in _order) tr('brain.color.${StroopTest.names[i]}')],
          _order.indexOf(_ink),
          colors: [for (final i in _order) StroopTest.colors[i].withValues(alpha: 0.85)],
        ),
      );
}

// ---------------------------------------------------------------- pattern

class PatternTest extends StatefulWidget {
  const PatternTest({super.key, required this.onDone, this.random});
  final ScoreCallback onDone;
  final math.Random? random;

  @override
  State<PatternTest> createState() => _PatternTestState();
}

class _PatternTestState extends _TimedState<PatternTest> {
  @override
  BrainTest get test => BrainTest.pattern;
  @override
  ScoreCallback get onDone => widget.onDone;

  late final math.Random _r = widget.random ?? math.Random();
  late PatternQ _q = PatternQ.make(_r, 0);

  @override
  void next() => _q = PatternQ.make(_r, correct);

  @override
  Widget build(BuildContext context) => frame(
        Column(mainAxisSize: MainAxisSize.min, children: [
          Text(tr('brain.pattern.ask'), style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          FittedBox(child: _bigText('${_q.shown.join(', ')}, ?', size: 34)),
        ]),
        choiceGrid([for (final c in _q.choices) '$c'], _q.choices.indexOf(_q.answer)),
      );
}
