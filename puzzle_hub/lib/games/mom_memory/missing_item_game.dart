import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_extra_logic.dart';
import 'mm_common.dart';

enum _Phase { intro, show, pick, result }

/// Kya gaya? - one of the items disappears behind a curtain; which one?
class MissingItemGame extends StatefulWidget {
  const MissingItemGame({super.key});
  @override
  State<MissingItemGame> createState() => _MissingItemGameState();
}

class _MissingItemGameState extends State<MissingItemGame>
    with SingleTickerProviderStateMixin {
  late int _level = Storage.getInt('mom.missing.level')
      .clamp(0, missingMaxLevel);
  _Phase _phase = _Phase.intro;
  late MissingRound _round;
  late final AnimationController _bar = AnimationController(vsync: this);
  bool _curtain = false; // curtain down
  bool _revealed = false; // hidden slot shown as "?"
  int _tries = 0;
  final Set<int> _wrong = {};
  int _stars = 0;
  bool _solved = false;

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _begin() {
    _round = buildMissingRound(_level, math.Random());
    _curtain = false;
    _revealed = false;
    _tries = 0;
    _solved = false;
    _wrong.clear();
    setState(() => _phase = _Phase.show);
    _bar.duration = Duration(seconds: missingShowSeconds(_level));
    _bar.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.show) _cover();
    });
  }

  Future<void> _cover() async {
    _bar.stop();
    setState(() {
      _phase = _Phase.pick;
      _curtain = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (!mounted) return;
    setState(() {
      _curtain = false;
      _revealed = true;
    });
  }

  Future<void> _choose(int poolIdx) async {
    if (!_revealed || _solved || _wrong.contains(poolIdx)) return;
    AppAudio.haptic();
    _tries++;
    if (poolIdx == _round.answer) {
      AppAudio.play(Sound.success);
      _solved = true;
      _stars = triesToStars(_tries);
      setState(() {});
      Storage.setBest('mom.missing.stars.$_level', _stars);
      if (_level < missingMaxLevel) {
        Storage.setBest('mom.missing.level', _level + 1);
      }
      recordPlay();
      Rewards.onLevelComplete(
        'mom_memory',
        'missing-L${_level + 1}',
        stars: _stars,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted) setState(() => _phase = _Phase.result);
    } else {
      AppAudio.play(Sound.pop);
      setState(() => _wrong.add(poolIdx));
    }
  }

  @override
  Widget build(BuildContext context) => MmPage(
    title: 'Kya gaya?',
    body: Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey(
                _phase == _Phase.show || _phase == _Phase.pick
                    ? 'play'
                    : _phase,
              ),
              child: switch (_phase) {
                _Phase.intro => MmIntro(
                  emoji: '🪄',
                  level: _level,
                  unlocked: Storage.getInt('mom.missing.level'),
                  maxLevel: missingMaxLevel,
                  text:
                      '${missingCount(_level)} cheezein dekhiye. Ek chhup jayegi.\nBataiye kaunsi gayi? Aaram se.',
                  onLevel: (i) => setState(() => _level = i),
                  onStart: _begin,
                ),
                _Phase.result => MmResult(
                  title: pick(praise),
                  stars: _stars,
                  message: _tries <= 1
                      ? 'Pehli baar mein sahi!'
                      : 'Aapne dhyaan se dhoondh liya.',
                  onAgain: _begin,
                  onNext: _level < missingMaxLevel
                      ? () {
                          setState(() => _level++);
                          _begin();
                        }
                      : null,
                ),
                _ => _play(),
              },
            ),
          ),
        ),
        const MmFootnote(),
      ],
    ),
  );

  Widget _tile(int poolIdx, int i, {double size = 36}) {
    final t = missingPool[poolIdx];
    return PastelTile(
      color: Mm.pads[i % Mm.pads.length],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(t.emoji, style: TextStyle(fontSize: size)),
          Text(
            t.hi,
            style: const TextStyle(
              color: Mm.ink,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _play() {
    final showing = _phase == _Phase.show;
    final cols = _round.items.length <= 4 ? 2 : 3;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            showing
                ? 'Ye cheezein yaad kijiye'
                : (_revealed
                      ? (_solved ? 'Bilkul sahi!' : 'Kaunsi cheez chali gayi?')
                      : 'Parda gir raha hai...'),
            style: const TextStyle(
              color: Pal.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showing) MmBar(animation: _bar) else const SizedBox(height: 22),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Stack(
                    children: [
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: cols,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        children: [
                          for (var i = 0; i < _round.items.length; i++)
                            (_revealed && i == _round.hiddenIndex && !_solved)
                                ? const PastelTile(
                                        color: Mm.lavender,
                                        dim: true,
                                        child: Text(
                                          '❓',
                                          style: TextStyle(fontSize: 34),
                                        ),
                                      )
                                      .animate(
                                        onPlay: (c) => c.repeat(reverse: true),
                                      )
                                      .fade(
                                        begin: 0.6,
                                        end: 1,
                                        duration: 1200.ms,
                                      )
                                : _tile(_round.items[i], i),
                        ],
                      ),
                      Positioned.fill(
                        child: IgnorePointer(
                          child: AnimatedSlide(
                            duration: const Duration(milliseconds: 650),
                            curve: Curves.easeInOut,
                            offset: _curtain
                                ? Offset.zero
                                : const Offset(0, -1.05),
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Mm.lavender,
                                    Mm.rose.withValues(alpha: 0.9),
                                  ],
                                ),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                '🎀',
                                style: TextStyle(fontSize: 48),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        if (!showing)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: AnimatedOpacity(
              opacity: _revealed ? 1 : 0,
              duration: const Duration(milliseconds: 300),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  for (var i = 0; i < _round.options.length; i++)
                    SizedBox(
                      width: 78,
                      height: 82,
                      child: Pressable(
                        onTap: () => _choose(_round.options[i]),
                        child: Opacity(
                          opacity: _wrong.contains(_round.options[i])
                              ? 0.35
                              : 1,
                          child: PastelTile(
                            color: Mm.pads[(i + 2) % Mm.pads.length],
                            selected:
                                _solved && _round.options[i] == _round.answer,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  missingPool[_round.options[i]].emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                                Text(
                                  missingPool[_round.options[i]].hi,
                                  style: const TextStyle(
                                    color: Mm.ink,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: PremiumButton(
              label: 'Yaad ho gaya',
              compact: true,
              color: Mm.lavender,
              onTap: _cover,
            ),
          ),
        if (!showing && _wrong.isNotEmpty && !_solved)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              pick(gentle),
              style: const TextStyle(color: Pal.textDim, fontSize: 13),
            ),
          ),
      ],
    );
  }
}
