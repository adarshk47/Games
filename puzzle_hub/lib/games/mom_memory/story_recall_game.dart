import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_extra_logic.dart';
import 'mm_common.dart';

enum _Phase { intro, read, ask, result }

/// Kahani yaad karo - read a short warm story, then answer 3 questions.
class StoryRecallGame extends StatefulWidget {
  const StoryRecallGame({super.key});
  @override
  State<StoryRecallGame> createState() => _StoryRecallGameState();
}

class _StoryRecallGameState extends State<StoryRecallGame>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.intro;
  final _rng = math.Random();
  int? _story;
  late final AnimationController _bar = AnimationController(
    vsync: this,
    duration: const Duration(seconds: storyReadSeconds),
  );
  int _q = 0;
  int _correct = 0;
  int? _chosen;
  int _stars = 0;

  MmStory get _s => stories[_story!];

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _begin() {
    _story = nextStoryIndex(_story, _rng);
    _q = 0;
    _correct = 0;
    _chosen = null;
    setState(() => _phase = _Phase.read);
    _bar.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.read) _toAsk();
    });
  }

  void _toAsk() {
    _bar.stop();
    setState(() => _phase = _Phase.ask);
  }

  Future<void> _answer(int i) async {
    if (_chosen != null) return;
    softTap();
    setState(() => _chosen = i);
    if (i == _s.questions[_q].answer) _correct++;
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    if (_q + 1 < _s.questions.length) {
      setState(() {
        _q++;
        _chosen = null;
      });
    } else {
      _stars = storyStars(_correct);
      Storage.setBest('mom.story.best', _correct);
      Storage.setInt(
        'mom.story.played',
        Storage.getInt('mom.story.played') + 1,
      );
      recordPlay();
      Rewards.onLevelComplete(
        'mom_memory',
        'story-L${_story! + 1}',
        stars: _stars,
      );
      setState(() => _phase = _Phase.result);
    }
  }

  @override
  Widget build(BuildContext context) => MmPage(
    title: 'Kahani yaad karo',
    body: Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey(_phase == _Phase.ask ? 'ask$_q' : _phase),
              child: switch (_phase) {
                _Phase.intro => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('📖', style: TextStyle(fontSize: 72)),
                        const SizedBox(height: 14),
                        const Text(
                          'Ek chhoti kahani',
                          style: TextStyle(
                            color: Pal.text,
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Kahani aaram se padhiye, phir 3 aasaan sawaal honge.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Pal.textDim,
                            fontSize: 15,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        PremiumButton(
                          label: 'Shuru karein',
                          icon: Icons.favorite_rounded,
                          color: Mm.rose,
                          onTap: _begin,
                        ),
                      ],
                    ),
                  ),
                ),
                _Phase.read => _read(),
                _Phase.ask => _ask(),
                _Phase.result => MmResult(
                  title: '$_correct/${_s.questions.length} sahi',
                  stars: _stars,
                  message: _correct == _s.questions.length ? pick(praise) : 'Bahut achha prayas! Nayi kahani ke saath phir koshish kijiye.',
                  onAgain: _begin,
                  onNext: _begin,
                ),
              },
            ),
          ),
        ),
        const MmFootnote(),
      ],
    ),
  );

  Widget _read() => Column(
    children: [
      MmBar(animation: _bar),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
          child: GlassCard(
            blur: 0,
            radius: 24,
            glow: Mm.lavender,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(_s.emoji, style: const TextStyle(fontSize: 48)),
                const SizedBox(height: 6),
                Text(
                  _s.title,
                  style: const TextStyle(
                    color: Pal.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _s.lines.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      _s.lines[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Pal.text,
                        fontSize: 17,
                        height: 1.45,
                      ),
                    ).animate(delay: (i * 500).ms).fadeIn(duration: 500.ms),
                  ),
              ],
            ),
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: PremiumButton(
          label: 'Padh liya',
          compact: true,
          color: Mm.lavender,
          onTap: _toAsk,
        ),
      ),
    ],
  );

  Widget _ask() {
    final q = _s.questions[_q];
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
          child: Text(
            'Sawaal ${_q + 1}/${_s.questions.length}',
            style: const TextStyle(color: Pal.textDim, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
          child: Text(
            q.q,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Pal.text,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            children: [
              for (var i = 0; i < q.options.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    height: 60,
                    child: Pressable(
                      onTap: () => _answer(i),
                      child: PastelTile(
                        color: _chosen != null && i == q.answer
                            ? Mm.mint
                            : Mm.pads[(i + 1) % Mm.pads.length],
                        dim: _chosen != null && i != q.answer,
                        selected:
                            _chosen != null && (i == q.answer || i == _chosen),
                        child: Text(
                          q.options[i],
                          style: const TextStyle(
                            color: Mm.ink,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (_chosen != null)
                Center(
                  child: Text(
                    _chosen == q.answer
                        ? pick(praise)
                        : 'Koi baat nahi, sahi jawab: ${q.options[q.answer]}',
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
