import 'dart:math' as math;

import '../../core/share/score_share.dart';
import 'package:flutter/material.dart';

import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/ui/ui.dart';
import 'brain_tests.dart';
import 'logic/brain_age_logic.dart';

const _accent = Color(0xFFB794FF);

const _testIcons = {
  BrainTest.reaction: '⚡',
  BrainTest.memory: '🔢',
  BrainTest.math: '➕',
  BrainTest.stroop: '🎨',
  BrainTest.pattern: '🧩',
  BrainTest.order: '🔟',
  BrainTest.grid: '🟦',
};

String _unit(BrainTest t, double v) => switch (t) {
      BrainTest.reaction => '${v.round()} ms',
      BrainTest.order => '${v.toStringAsFixed(1)} s',
      BrainTest.grid => tr('brain.unit.squares', {'n': v.round()}),
      BrainTest.memory => tr('brain.unit.digits', {'n': v.round()}),
      _ => tr('brain.unit.correct', {'n': v % 1 == 0 ? v.round() : v.toStringAsFixed(1)}),
    };

/// Brain Age: pick your age group, take 5 quick tests (reaction, memory,
/// mental math, colour-word focus, patterns) and see how your brain compares
/// with your age group. Every test ends with a tip that teaches a technique.
class BrainAgeScreen extends StatefulWidget {
  const BrainAgeScreen({super.key});

  @override
  State<BrainAgeScreen> createState() => _BrainAgeScreenState();
}

class _BrainAgeScreenState extends State<BrainAgeScreen> {
  bool _changing = false;

  Future<void> _run(List<BrainTest> tests) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BrainRunScreen(tests: tests, group: BrainStore.group!)));
    if (mounted) setState(() {});
  }

  Widget _groupPicker() => ListView(padding: const EdgeInsets.all(16), children: [
        Text(tr('brain.pick_age'), style: const TextStyle(color: Pal.text, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text(tr('brain.pick_age_text'), style: const TextStyle(color: Pal.textDim, height: 1.4)),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.6,
          children: [
            for (final g in AgeGroup.values)
              Pressable(
                key: ValueKey('age_${g.name}'),
                onTap: () async {
                  await BrainStore.setGroup(g);
                  if (mounted) setState(() => _changing = false);
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: Pal.accent(_accent),
                    border: Border.all(color: BrainStore.group == g ? Pal.gold : Colors.white24, width: BrainStore.group == g ? 2 : 1),
                  ),
                  child: Text(tr('brain.years', {'g': g.label}), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                ),
              ),
          ],
        ),
      ]);

  /// "Best 280 ms (first 340 ms)" once practice made a difference.
  static String? _improved(BrainTest t, double best) {
    final first = BrainStore.firstOf(t);
    if (first == null || first == best) return null;
    return tr('brain.improved', {'v': _unit(t, best), 'first': _unit(t, first)});
  }

  Widget _history(List<BrainResult> h) {
    final full = h.where((r) => r.isFull).toList();
    if (full.isEmpty) return const SizedBox();
    final last = full.sublist(math.max(0, full.length - 10));
    return GlassCard(
      blur: 0,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(tr('brain.progress'), style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w800, fontSize: 13)),
        const SizedBox(height: 10),
        SizedBox(
          height: 90,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final r in last)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    FittedBox(child: Text(r.brainGroup.label, style: const TextStyle(color: Pal.text, fontSize: 11, fontWeight: FontWeight.w800))),
                    const SizedBox(height: 2),
                    Container(
                      // Younger brain age = taller bar.
                      height: 10 + 60 * ((85 - r.brainAge) / 70).clamp(0.0, 1.0),
                      decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: Pal.accent(_accent)),
                    ),
                  ]),
                ),
              ),
          ]),
        ),
      ]),
    );
  }

  Widget _home(AgeGroup g) {
    final h = BrainStore.history();
    final best = BrainStore.best();
    final lastFull = h.lastWhere((r) => r.isFull, orElse: () => BrainResult(group: g, scores: const {}, at: DateTime(0)));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 6, 16, 24), children: [
      Text(tr('brain.intro'), style: const TextStyle(color: Pal.textDim, height: 1.4)),
      const SizedBox(height: 12),
      GlassCard(
        glow: _accent,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(children: [
          const Text('🧠', style: TextStyle(fontSize: 36)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('brain.your_group', {'g': g.label}), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
              Text(
                lastFull.scores.isEmpty ? tr('brain.not_yet') : tr('brain.last', {'n': lastFull.brainGroup.label}),
                style: const TextStyle(color: Pal.gold, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              if (best != null) Text(tr('brain.best', {'n': AgeGroup.of(best).label}), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
            ]),
          ),
          TextButton(
            key: const ValueKey('brain_change_age'),
            onPressed: () => setState(() => _changing = true),
            child: Text(tr('brain.change'), style: const TextStyle(color: Pal.gold)),
          ),
        ]),
      ),
      const SizedBox(height: 14),
      PremiumButton(
        key: const ValueKey('brain_start'),
        label: tr('brain.start_full'),
        icon: Icons.psychology_rounded,
        color: _accent,
        onTap: () => _run(BrainTest.values),
      ),
      const SizedBox(height: 6),
      Text(tr('brain.full_time'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
      const SizedBox(height: 14),
      _history(h),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(tr('brain.practice'), style: const TextStyle(color: Pal.textDim, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Text(tr('brain.practice_text'), style: const TextStyle(color: Pal.textDim, fontSize: 12, height: 1.4)),
      ),
      if (BrainStore.weakest() case final w?)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PremiumButton(
            key: const ValueKey('brain_train_weakest'),
            label: tr('brain.train_weakest', {'test': tr('brain.test.${w.name}')}),
            icon: Icons.fitness_center_rounded,
            compact: true,
            onTap: () => _run([w]),
          ),
        ),
      for (final t in BrainTest.values)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Pressable(
            key: ValueKey('practice_${t.name}'),
            onTap: () => _run([t]),
            child: GlassCard(
              blur: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(children: [
                Text(_testIcons[t]!, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('brain.test.${t.name}'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                    Text(tr('brain.measures.${t.name}'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
                    if (BrainStore.bestOf(t) case final b?)
                      Text(
                        _improved(t, b) ?? tr('brain.your_best', {'v': _unit(t, b)}),
                        style: const TextStyle(color: Pal.gold, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                  ]),
                ),
                const Icon(Icons.play_arrow_rounded, color: Pal.gold),
              ]),
            ),
          ),
        ),
      const SizedBox(height: 10),
      Text(tr('brain.disclaimer'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 11, height: 1.4)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final g = BrainStore.group;
    return GameScaffold(
      title: tr('game.brain_age.title'),
      tint: _accent,
      body: g == null || _changing ? _groupPicker() : _home(g),
    );
  }
}

/// Runs [tests] one after another: intro, the test, then a result + tip
/// card; after the last one the Brain Age result.
class BrainRunScreen extends StatefulWidget {
  const BrainRunScreen({super.key, required this.tests, required this.group});
  final List<BrainTest> tests;
  final AgeGroup group;

  @override
  State<BrainRunScreen> createState() => _BrainRunScreenState();
}

enum _Phase { intro, test, tip, result }

class _BrainRunScreenState extends State<BrainRunScreen> {
  int _i = 0;
  _Phase _phase = _Phase.intro;
  final Map<BrainTest, double> _scores = {};
  final _rnd = math.Random();
  late int _tip = _rnd.nextInt(3);
  bool _saved = false;

  BrainTest get _t => widget.tests[_i];
  bool get _full => widget.tests.length == BrainTest.values.length;
  BrainResult get _result => BrainResult(group: widget.group, scores: _scores, at: DateTime.now());

  void _done(double score) {
    if (!mounted || _phase != _Phase.test) return;
    setState(() {
      _scores[_t] = score;
      _phase = _Phase.tip;
      _tip = _rnd.nextInt(3);
    });
  }

  void _next() {
    if (_i + 1 < widget.tests.length) {
      setState(() {
        _i++;
        _phase = _Phase.intro;
      });
      return;
    }
    setState(() => _phase = _Phase.result);
    _save();
  }

  void _save() {
    if (_saved) return;
    _saved = true;
    final r = _result;
    BrainStore.add(r);
    if (_full) {
      Rewards.onGameEnd('brain_age', score: r.percentile * 10, won: r.youngerOrSame);
    }
  }

  Widget _testWidget() => switch (_t) {
        BrainTest.reaction => ReactionTest(onDone: _done),
        BrainTest.memory => MemoryTest(onDone: _done),
        BrainTest.math => MathTest(onDone: _done),
        BrainTest.stroop => StroopTest(onDone: _done),
        BrainTest.pattern => PatternTest(onDone: _done),
        BrainTest.order => OrderTest(onDone: _done),
        BrainTest.grid => GridTest(onDone: _done),
      };

  Widget _card({required String emoji, required String title, required List<Widget> children, required String button, required VoidCallback onTap, Key? key}) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        const SizedBox(height: 12),
        Center(child: Text(emoji, style: const TextStyle(fontSize: 64))),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontSize: 24, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        ...children,
        const SizedBox(height: 22),
        PremiumButton(key: key, label: button, color: _accent, icon: Icons.arrow_forward_rounded, onTap: onTap),
      ]);

  Widget _intro() => _card(
        key: const ValueKey('brain_go'),
        emoji: _testIcons[_t]!,
        title: tr('brain.test.${_t.name}'),
        children: [
          if (widget.tests.length > 1)
            Text(tr('brain.step', {'n': _i + 1, 'total': widget.tests.length}), textAlign: TextAlign.center, style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          GlassCard(
            blur: 0,
            padding: const EdgeInsets.all(16),
            child: Text(tr('brain.how.${_t.name}'), style: const TextStyle(color: Pal.text, fontSize: 15, height: 1.5)),
          ),
        ],
        button: tr('brain.go'),
        onTap: () => setState(() => _phase = _Phase.test),
      );

  Widget _tipCard() {
    final r = _result;
    final v = _scores[_t]!;
    return _card(
      key: const ValueKey('brain_next'),
      emoji: _testIcons[_t]!,
      title: _unit(_t, v),
      children: [
        Text(tr('brain.test_age', {'n': r.groupOf(_t).label}), textAlign: TextAlign.center, style: const TextStyle(color: Pal.gold, fontSize: 18, fontWeight: FontWeight.w900)),
        Text(tr('brain.beats', {'p': r.percentileOf(_t), 'g': widget.group.label}), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim)),
        const SizedBox(height: 14),
        GlassCard(
          blur: 0,
          glow: _accent,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('brain.learn'), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(tr('brain.tip.${_t.name}.$_tip'), style: const TextStyle(color: Pal.text, height: 1.5)),
          ]),
        ),
      ],
      button: _i + 1 < widget.tests.length ? tr('brain.next_test') : tr('brain.see_result'),
      onTap: _next,
    );
  }

  Widget _resultView() {
    final r = _result;
    final younger = _full ? r.youngerOrSame : r.groupOf(widget.tests.first).index <= widget.group.index;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const SizedBox(height: 8),
      Center(child: Text(younger ? '🧠✨' : '🧠', style: const TextStyle(fontSize: 60))),
      Text(tr(_full ? 'brain.result_title' : 'brain.result_title_one'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w800)),
      Text(
        tr('brain.age_value', {'n': (_full ? r.brainGroup : r.groupOf(widget.tests.first)).label}),
        key: const ValueKey('brain_result_age'),
        textAlign: TextAlign.center,
        style: const TextStyle(color: Pal.gold, fontSize: 44, fontWeight: FontWeight.w900),
      ),
      Text(tr('brain.beats', {'p': r.percentile, 'g': widget.group.label}), textAlign: TextAlign.center, style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(tr(younger ? 'brain.verdict_good' : 'brain.verdict_train'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, height: 1.4)),
      const SizedBox(height: 16),
      for (final t in widget.tests)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: GlassCard(
            blur: 0,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Text(_testIcons[t]!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('brain.test.${t.name}'), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800)),
                  Text(_unit(t, _scores[t] ?? 0), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
                ]),
              ),
              Text(tr('brain.age_short', {'n': r.groupOf(t).label}), style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900)),
            ]),
          ),
        ),
      const SizedBox(height: 16),
      if (!_full)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PremiumButton(
            key: const ValueKey('brain_again'),
            label: tr('brain.again'),
            icon: Icons.replay_rounded,
            compact: true,
            onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => BrainRunScreen(tests: widget.tests, group: widget.group))),
          ),
        ),
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PremiumButton(
          key: const ValueKey('brain_share'),
          label: tr('share.challenge'),
          icon: Icons.share_rounded,
          compact: true,
          onTap: () => ScoreShare.show(
            context,
            game: tr('game.brain_age.title'),
            emoji: '🧠',
            value: tr('brain.age_value', {'n': (_full ? r.brainGroup : r.groupOf(widget.tests.first)).label}),
            label: tr(_full ? 'brain.result_title' : 'brain.result_title_one'),
            color: _accent,
            extra: tr('brain.beats', {'p': r.percentile, 'g': widget.group.label}),
          ),
        ),
      ),
      PremiumButton(key: const ValueKey('brain_done'), label: tr('brain.done'), color: _accent, icon: Icons.check_rounded, onTap: () => Navigator.of(context).pop()),
      const SizedBox(height: 10),
      Text(tr('brain.disclaimer'), textAlign: TextAlign.center, style: const TextStyle(color: Pal.textDim, fontSize: 11, height: 1.4)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      title: tr('game.brain_age.title'),
      tint: _accent,
      body: switch (_phase) {
        _Phase.intro => _intro(),
        _Phase.test => KeyedSubtree(key: ValueKey('test_${_t.name}'), child: _testWidget()),
        _Phase.tip => _tipCard(),
        _Phase.result => _resultView(),
      },
    );
  }
}
