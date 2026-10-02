import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_extra_logic.dart';
import 'mm_common.dart';

enum _Phase { intro, show, tap, result }

/// Kahan tha? - cute emoji appear in cells, vanish, tap where they were.
class WhereWasItGame extends StatefulWidget {
  const WhereWasItGame({super.key});
  @override
  State<WhereWasItGame> createState() => _WhereWasItGameState();
}

class _WhereWasItGameState extends State<WhereWasItGame>
    with SingleTickerProviderStateMixin {
  late int _level = Storage.getInt('mom.where.level').clamp(0, whereMaxLevel);
  _Phase _phase = _Phase.intro;
  late Map<int, int> _round;
  late final AnimationController _bar = AnimationController(vsync: this);
  final Set<int> _tapped = {};
  int _stars = 0;

  @override
  void dispose() {
    _bar.dispose();
    super.dispose();
  }

  void _begin() {
    _round = buildWhereRound(_level, math.Random());
    _tapped.clear();
    setState(() => _phase = _Phase.show);
    _bar.duration = Duration(milliseconds: whereShowMs(_level));
    _bar.forward(from: 0).whenComplete(() {
      if (mounted && _phase == _Phase.show) setState(() => _phase = _Phase.tap);
    });
  }

  void _toggle(int cell) {
    softTap();
    setState(() {
      if (!_tapped.remove(cell)) _tapped.add(cell);
    });
  }

  void _submit() {
    final r = scoreWhere(_tapped, _round.keys);
    _stars = whereStars(r.correct, r.wrong, _round.length);
    Storage.setBest('mom.where.stars.$_level', _stars);
    if (_stars >= 2 && _level < whereMaxLevel) {
      Storage.setBest('mom.where.level', _level + 1);
    }
    recordPlay();
    Rewards.onLevelComplete(
      'mom_memory',
      'where-L${_level + 1}',
      stars: _stars,
    );
    setState(() => _phase = _Phase.result);
  }

  @override
  Widget build(BuildContext context) => MmPage(
    title: 'Kahan tha?',
    body: Column(
      children: [
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: KeyedSubtree(
              key: ValueKey(
                _phase == _Phase.intro
                    ? 'intro'
                    : (_phase == _Phase.result ? 'result' : 'play'),
              ),
              child: switch (_phase) {
                _Phase.intro => MmIntro(
                  emoji: '🔍',
                  level: _level,
                  unlocked: Storage.getInt('mom.where.level'),
                  maxLevel: whereMaxLevel,
                  text: 'Pyaare emoji kuch der dikhenge, phir chhup jayenge.\nYaad kijiye woh kahan the.',
                  onLevel: (i) => setState(() => _level = i),
                  onStart: _begin,
                ),
                _Phase.result => _result(),
                _ => _play(),
              },
            ),
          ),
        ),
        const MmFootnote(),
      ],
    ),
  );

  Widget _grid(Widget Function(int cell) cell) {
    final n = whereSize(_level);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: n,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [for (var c = 0; c < n * n; c++) cell(c)],
          ),
        ),
      ),
    );
  }

  Widget _play() {
    final showing = _phase == _Phase.show;
    final need = _round.length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Text(
            showing
                ? 'Dhyaan se dekhiye'
                : 'Kahan the? Chuniye (${_tapped.length}/$need)',
            style: const TextStyle(
              color: Pal.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (showing) MmBar(animation: _bar) else const SizedBox(height: 22),
        Expanded(
          child: _grid((c) {
            if (showing) {
              final e = _round[c];
              return PastelTile(
                color: Mm.pads[c % Mm.pads.length],
                dim: e == null,
                child: e == null
                    ? const SizedBox.shrink()
                    : Text(whereEmojis[e], style: const TextStyle(fontSize: 34))
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .scale(
                            begin: const Offset(0.6, 0.6),
                            curve: Curves.easeOutBack,
                          ),
              );
            }
            final on = _tapped.contains(c);
            return Pressable(
              onTap: () => _toggle(c),
              child: PastelTile(
                color: on ? Mm.rose : Mm.lavender,
                selected: on,
                dim: !on,
                child: on
                    ? const Text('💗', style: TextStyle(fontSize: 26))
                    : const SizedBox.shrink(),
              ),
            );
          }),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: showing
              ? PremiumButton(
                  label: 'Yaad ho gaya',
                  compact: true,
                  color: Mm.lavender,
                  onTap: () {
                    _bar.stop();
                    setState(() => _phase = _Phase.tap);
                  },
                )
              : PremiumButton(
                  label: 'Ho gaya',
                  icon: Icons.check_rounded,
                  color: Mm.rose,
                  onTap: _tapped.isEmpty ? null : _submit,
                ),
        ),
      ],
    );
  }

  Widget _result() {
    final r = scoreWhere(_tapped, _round.keys);
    final total = _round.length;
    return Column(
      children: [
        Expanded(
          child: _grid((c) {
            final e = _round[c];
            final hit = _tapped.contains(c);
            return PastelTile(
              color: e != null ? Mm.mint : Mm.pads[c % Mm.pads.length],
              dim: e == null,
              selected: e != null && hit,
              child: e != null
                  ? Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          whereEmojis[e],
                          style: const TextStyle(fontSize: 32),
                        ),
                        Positioned(
                          top: 4,
                          right: 6,
                          child: Text(
                            hit ? '✅' : '💭',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    )
                  : (hit
                        ? const Text('🌫️', style: TextStyle(fontSize: 20))
                        : const SizedBox.shrink()),
            );
          }),
        ),
        SizedBox(
          height: 250,
          child: MmResult(
            title: '${r.correct}/$total sahi jagah',
            stars: _stars,
            message: r.correct == total
                ? pick(praise)
                : 'Bahut achha prayas! Aaram se phir koshish kijiye.',
            onAgain: _begin,
            onNext: _level < whereMaxLevel
                ? () {
                    setState(() => _level++);
                    _begin();
                  }
                : null,
          ),
        ),
      ],
    );
  }
}
