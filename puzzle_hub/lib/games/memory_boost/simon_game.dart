import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mb_tiers.dart';
import 'logic/simon_logic.dart';
import 'mb_widgets.dart';

enum _Phase { idle, watching, input, over }

class SimonScreen extends StatefulWidget {
  const SimonScreen({super.key});
  @override
  State<SimonScreen> createState() => _SimonScreenState();
}

class _SimonScreenState extends State<SimonScreen> {
  Tier? tier;

  @override
  Widget build(BuildContext context) {
    final t = tier;
    if (t != null) {
      return _SimonGame(key: ValueKey(t), tier: t, onBack: () => setState(() => tier = null));
    }
    return GameScaffold(
      title: 'Simon Sequence',
      tint: mbTint,
      body: TierChooser(
        game: 'simon',
        heading: 'Watch the growing light pattern and repeat it. Pick a difficulty.',
        descriptions: const {
          Tier.easy: 'Slow lights, 4 pads, one forgiven mistake.',
          Tier.medium: 'Classic speed, 4 pads.',
          Tier.hard: 'Fast lights, 4 pads.',
          Tier.extreme: 'Blazing speed with 6 pads.',
        },
        bestText: (t) => 'Best streak ${Storage.getInt(simonBestKeyFor(t))}',
        onSelect: (t) => setState(() => tier = t),
      ),
    );
  }
}

class _SimonGame extends StatefulWidget {
  final Tier tier;
  final VoidCallback onBack;
  const _SimonGame({super.key, required this.tier, required this.onBack});
  @override
  State<_SimonGame> createState() => _SimonGameState();
}

class _SimonGameState extends State<_SimonGame> {
  static const _colors = [
    Color(0xFFFF4D6D),
    Color(0xFF2EE6A8),
    Color(0xFF4DA8FF),
    Color(0xFFFFD369),
    Color(0xFFB794FF),
    Color(0xFFFF9F43),
  ];
  static const _icons = [
    Icons.favorite_rounded,
    Icons.eco_rounded,
    Icons.water_drop_rounded,
    Icons.star_rounded,
    Icons.diamond_rounded,
    Icons.local_fire_department_rounded,
  ];
  late final SimonTierParams params = simonTierParams[widget.tier]!;
  late final SimonLogic logic = SimonLogic(pads: params.pads);
  late int chancesLeft = params.chances;
  String get bestKey => simonBestKeyFor(widget.tier);
  _Phase phase = _Phase.idle;
  int lit = -1;
  int pulse = 0; // bumps on every light-up to retrigger the ripple
  int lastPad = -1;
  int round = 0; // bumps to cancel stale playback loops

  @override
  void dispose() {
    round++;
    super.dispose();
  }

  Future<void> _startGame() async {
    logic.reset();
    chancesLeft = params.chances;
    await _nextRound();
  }

  Future<void> _nextRound() async {
    final my = ++round;
    logic.addStep();
    await _playback(my);
  }

  Future<void> _playback(int my) async {
    setState(() => phase = _Phase.watching);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted || my != round) return;
    final ms = SimonLogic.stepMillis(logic.length, base: params.baseMs, min: params.minMs, decay: params.decayMs);
    for (final p in List<int>.from(logic.sequence)) {
      if (!mounted || my != round) return;
      setState(() {
        lit = p;
        lastPad = p;
        pulse++;
      });
      AppAudio.play(Sound.pop);
      AppAudio.haptic();
      await Future.delayed(Duration(milliseconds: ms));
      if (!mounted || my != round) return;
      setState(() => lit = -1);
      await Future.delayed(Duration(milliseconds: (ms * 0.4).round()));
    }
    if (!mounted || my != round) return;
    setState(() => phase = _Phase.input);
  }

  Future<void> _tap(int pad) async {
    if (phase != _Phase.input) return;
    final res = logic.input(pad);
    if (res != SequenceResult.wrong) {
      AppAudio.play(Sound.pop);
      AppAudio.haptic();
    }
    setState(() {
      lit = pad;
      lastPad = pad;
      pulse++;
    });
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted && phase != _Phase.watching) setState(() => lit = -1);
    });
    if (res == SequenceResult.wrong) {
      if (chancesLeft > 1) {
        chancesLeft--;
        AppAudio.play(Sound.fail);
        AppAudio.haptic(true);
        logic.restartInput();
        setState(() => phase = _Phase.watching);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) _playback(++round);
        return;
      }
      await _gameOver();
    } else if (res == SequenceResult.complete) {
      setState(() => phase = _Phase.watching);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _nextRound();
    }
  }

  Future<void> _gameOver() async {
    AppAudio.play(Sound.fail);
    AppAudio.haptic(true);
    setState(() => phase = _Phase.over);
    final streak = logic.streak;
    final prevBest = Storage.getInt(bestKey);
    final newBest = Storage.setBest(bestKey, streak);
    Rewards.onGameEnd('memory_boost', score: Storage.getInt(bestKey), won: streak >= 5);
    const milestones = {5: 1, 10: 2, 15: 3, 20: 3};
    milestones.forEach((m, st) {
      if (streak >= m && prevBest < m) {
        Rewards.onLevelComplete('memory_boost', simonRewardKey(widget.tier, m), stars: st);
      }
    });
    final choice = await showResultDialog(
      context,
      title: 'Game over',
      emoji: '💡',
      color: Pal.accents[1],
      message: 'Streak: $streak\n${newBest && streak > 0 ? 'New best!' : 'Best: ${Storage.getInt(bestKey)}'}',
    );
    if (!mounted) return;
    if (choice == DialogChoice.retry) {
      _startGame();
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = switch (phase) {
      _Phase.idle => 'Watch the pattern, then repeat it',
      _Phase.watching => 'Watch...',
      _Phase.input => 'Your turn!',
      _Phase.over => 'Game over',
    };
    final statusColor = phase == _Phase.input ? Pal.success : (phase == _Phase.over ? Pal.danger : Pal.textDim);
    return GameScaffold(
      title: 'Simon - ${widget.tier.label}',
      tint: mbTint,
      onBack: widget.onBack,
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            StatChip(Icons.local_fire_department_rounded, 'Streak ${logic.streak}', color: Pal.accents[0]),
            if (params.chances > 1) StatChip(Icons.favorite_rounded, '$chancesLeft', color: Pal.danger),
            StatChip(Icons.emoji_events_rounded, 'Best ${Storage.getInt(bestKey)}', color: Pal.gold),
          ]),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(status,
              key: ValueKey(status),
              style: TextStyle(color: statusColor, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.4)),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: AspectRatio(
                aspectRatio: params.pads == 6 ? 2 / 3 : 1,
                child: LayoutBuilder(builder: (c, box) {
                  final orb = box.maxWidth * 0.3;
                  return Stack(alignment: Alignment.center, children: [
                    Column(children: [
                      for (var r = 0; r < params.pads ~/ 2; r++) ...[
                        if (r > 0) const SizedBox(height: 14),
                        Expanded(
                            child: Row(children: [
                          Expanded(child: _pad(r * 2)),
                          const SizedBox(width: 14),
                          Expanded(child: _pad(r * 2 + 1)),
                        ])),
                      ],
                    ]),
                    if (params.pads == 4) IgnorePointer(child: _orb(orb)),
                  ]);
                }),
              ),
            ),
          ),
        ),
        SizedBox(
          height: 84,
          child: phase == _Phase.idle
              ? Center(
                  child: PremiumButton(label: 'Start', icon: Icons.play_arrow_rounded, onTap: _startGame)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 900.ms),
                )
              : null,
        ),
      ]),
    );
  }

  Widget _orb(double size) {
    final on = lit >= 0;
    final col = on ? _colors[lit] : Pal.bg2;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [Color.lerp(col, Colors.white, 0.25)!, Pal.bg0]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 2),
        boxShadow: [BoxShadow(color: (on ? col : mbTint).withValues(alpha: 0.55), blurRadius: 30, spreadRadius: 2)],
      ),
      alignment: Alignment.center,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${logic.streak}',
            style: TextStyle(color: Colors.white, fontSize: size * 0.4, fontWeight: FontWeight.w900, height: 1)),
        Text('SCORE', style: TextStyle(color: Pal.textDim, fontSize: size * 0.1, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
      ]),
    );
  }

  Widget _pad(int i) {
    final on = lit == i;
    final base = _colors[i];
    final radius = BorderRadius.circular(28);
    return GestureDetector(
      onTapDown: (_) => _tap(i),
      child: AnimatedScale(
        scale: on ? 1.04 : 1,
        duration: const Duration(milliseconds: 120),
        child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: on
                    ? [Color.lerp(base, Colors.white, 0.45)!, base]
                    : [base.withValues(alpha: 0.38), base.withValues(alpha: 0.12)],
              ),
              border: Border.all(color: Colors.white.withValues(alpha: on ? 0.8 : 0.3), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: base.withValues(alpha: on ? 0.85 : 0.18),
                  blurRadius: on ? 36 : 12,
                  spreadRadius: on ? 4 : -2,
                ),
              ],
            ),
            child: Align(
              alignment: Alignment.topLeft,
              child: FractionallySizedBox(
                widthFactor: 0.7,
                heightFactor: 0.35,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.only(topLeft: radius.topLeft, bottomRight: const Radius.circular(40)),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white.withValues(alpha: on ? 0.4 : 0.16), Colors.white.withValues(alpha: 0)],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment(i.isEven ? -0.45 : 0.45, i < 2 ? -0.45 : 0.45),
            child: Icon(_icons[i], color: Colors.white.withValues(alpha: on ? 0.95 : 0.35), size: 30),
          ),
          if (pulse > 0 && lastPad == i)
            IgnorePointer(
              child: DecoratedBox(
                key: ValueKey('ripple$pulse'),
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 3),
                ),
              ).animate().scale(
                  begin: const Offset(1, 1), end: const Offset(1.22, 1.22), duration: 450.ms, curve: Curves.easeOut).fadeOut(duration: 450.ms),
            ),
        ]),
      ),
    );
  }
}
