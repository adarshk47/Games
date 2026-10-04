import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_extra_logic.dart';
import 'mm_common.dart';

enum _Phase { intro, show, ask, result }

/// Jodi Milao - remember word and partner pairs, then match them.
class WordPairsGame extends StatefulWidget {
  const WordPairsGame({super.key});
  @override
  State<WordPairsGame> createState() => _WordPairsGameState();
}

class _WordPairsGameState extends State<WordPairsGame>
    with SingleTickerProviderStateMixin {
  late int _level = Storage.getInt('mom.pairs.level').clamp(0, pairsMaxLevel);
  _Phase _phase = _Phase.intro;
  late PairsRound _round;
  late final AnimationController _bar = AnimationController(vsync: this);
  int _q = 0;
  int _correct = 0;
  int? _chosen; // option position picked on the current question
  int _stars = 0;

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _begin() {
    _round = buildPairsRound(_level, math.Random());
    _q = 0;
    _correct = 0;
    _chosen = null;
    setState(() => _phase = _Phase.show);
    _bar.duration = Duration(seconds: pairsShowSeconds(_level));
    _bar.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.show) _toAsk();
    });
  }

  void _toAsk() {
    _bar.stop();
    setState(() => _phase = _Phase.ask);
  }

  Future<void> _answer(int pos) async {
    if (_chosen != null) return;
    AppAudio.haptic();
    final qn = _round.questions[_q];
    setState(() => _chosen = pos);
    if (pos == qn.answerOption) _correct++;
    AppAudio.play(pos == qn.answerOption ? Sound.success : Sound.pop);
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    if (_q + 1 < _round.questions.length) {
      setState(() {
        _q++;
        _chosen = null;
      });
    } else {
      _finish();
    }
  }

  void _finish() {
    final total = _round.questions.length;
    _stars = pairsStars(_correct, total);
    Storage.setBest('mom.pairs.stars.$_level', _stars);
    if (_stars >= 2 && _level < pairsMaxLevel) {
      Storage.setBest('mom.pairs.level', _level + 1);
    }
    recordPlay();
    Rewards.onLevelComplete(
      'mom_memory',
      'pairs-L${_level + 1}',
      stars: _stars,
    );
    setState(() => _phase = _Phase.result);
  }

  @override
  Widget build(BuildContext context) => MmPage(
    title: tr('mom_memory.pairs_title'),
    body: Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey(_phase == _Phase.ask ? 'ask$_q' : _phase),
              child: switch (_phase) {
                _Phase.intro => MmIntro(
                  emoji: '💞',
                  level: _level,
                  unlocked: Storage.getInt('mom.pairs.level'),
                  maxLevel: pairsMaxLevel,
                  text: tr('mom_memory.pairs_intro', {
                    'n': pairsCount(_level),
                  }),
                  onLevel: (i) => setState(() => _level = i),
                  onStart: _begin,
                ),
                _Phase.show => _show(),
                _Phase.ask => _ask(),
                _Phase.result => MmResult(
                  title: tr('mom_memory.n_correct', {
                    'n': _correct,
                    'total': _round.questions.length,
                  }),
                  stars: _stars,
                  message: _correct == _round.questions.length
                      ? pick(praise)
                      : tr('mom_memory.good_try'),
                  onAgain: _begin,
                  onNext: _level < pairsMaxLevel
                      ? () {
                          setState(() => _level++);
                          _begin();
                        }
                      : null,
                ),
              },
            ),
          ),
        ),
        const MmFootnote(),
      ],
    ),
  );

  Widget _show() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Text(
          tr('mom_memory.remember_pairs'),
          style: const TextStyle(
            color: Pal.text,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      MmBar(animation: _bar),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
          children: [
            for (var i = 0; i < _round.shown.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _pairRow(wordPairs[_round.shown[i]], i)
                    .animate(delay: (i * 120).ms)
                    .fadeIn(duration: 400.ms)
                    .slideX(begin: 0.1, end: 0),
              ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PremiumButton(
          label: tr('mom_memory.memorized'),
          compact: true,
          color: Mm.lavender,
          onTap: _toAsk,
        ),
      ),
    ],
  );

  Widget _pairRow(WordPair p, int i) => SizedBox(
    height: 64,
    child: PastelTile(
      color: Mm.pads[i % Mm.pads.length],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Flexible(
            child: Text(
              p.word,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Mm.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(Icons.favorite_rounded, color: Mm.ink, size: 16),
          ),
          Text(p.partner.emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              p.partner.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Mm.ink.withValues(alpha: 0.75),
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _ask() {
    final qn = _round.questions[_q];
    final w = wordPairs[qn.pairIndex];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            tr('mom_memory.question_n', {
              'n': _q + 1,
              'total': _round.questions.length,
            }),
            style: const TextStyle(color: Pal.textDim, fontSize: 13),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          tr('mom_memory.pairs_q', {'word': w.word}),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Pal.text,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            children: [
              for (var i = 0; i < qn.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 66,
                    child: Pressable(
                      onTap: () => _answer(i),
                      child: PastelTile(
                        color: _chosen != null && i == qn.answerOption
                            ? Mm.mint
                            : Mm.pads[(i + 1) % Mm.pads.length],
                        dim: _chosen != null && i != qn.answerOption,
                        selected:
                            _chosen != null &&
                            (i == qn.answerOption || i == _chosen),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              wordPairs[qn.options[i]].partner.emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              wordPairs[qn.options[i]].partner.name,
                              style: const TextStyle(
                                color: Mm.ink,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_chosen != null)
                Center(
                  child: Text(
                    _chosen == qn.answerOption
                        ? pick(praise)
                        : tr('mom_memory.pairs_wrong', {
                            'word': w.word,
                            'emoji': w.partner.emoji,
                            'partner': w.partner.name,
                          }),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Pal.textDim, fontSize: 14),
                  ).animate().fadeIn(),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
