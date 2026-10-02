import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/audio.dart';
import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/card_deck.dart';
import 'logic/mb_tiers.dart';
import 'mb_widgets.dart';

class CardMatchScreen extends StatefulWidget {
  const CardMatchScreen({super.key});
  @override
  State<CardMatchScreen> createState() => _CardMatchScreenState();
}

class _CardMatchScreenState extends State<CardMatchScreen> {
  Tier? _tier;
  int? _level;

  @override
  Widget build(BuildContext context) {
    final t = _tier;
    final lv = _level;
    return GameScaffold(
      tint: mbTint,
      title: t == null
          ? 'Card Match'
          : lv == null
              ? 'Card Match - ${t.label}'
              : '${t.label} - Level ${lv + 1} (${cardTierParams[t]!.levels[lv].label})',
      onBack: t == null ? null : () => setState(() => lv == null ? _tier = null : _level = null),
      body: t == null
          ? TierChooser(
              game: 'card',
              heading: 'Flip pairs of cards and find every match. Pick a difficulty.',
              descriptions: const {
                Tier.easy: '2x2 to 4x4. Mismatches stay visible a long time.',
                Tier.medium: '2x2 to 6x6. Balanced flip-back time.',
                Tier.hard: '3x4 to 5x6. Cards flip back fast.',
                Tier.extreme: '5x6 and 6x6. Short peek, very fast flip-back, time limit.',
              },
              bestText: (t) => 'Stars ${_tierStars(t)}/${cardTierParams[t]!.levels.length * 3}',
              onSelect: (t) => setState(() => _tier = t),
            )
          : lv == null
              ? _picker(t)
              : _CardBoard(
                  key: ValueKey('${t.key}$lv'),
                  tier: t,
                  level: lv,
                  onExit: () => setState(() => _level = null),
                  onNext: (l) => setState(() => _level = l),
                ),
    );
  }

  int _tierStars(Tier t) {
    var n = 0;
    for (var i = 0; i < cardTierParams[t]!.levels.length; i++) {
      n += Storage.getInt(cardStarsKey(t, i));
    }
    return n;
  }

  Widget _picker(Tier tier) {
    final levels = cardTierParams[tier]!.levels;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: levels.length,
      itemBuilder: (c, i) {
        final stars = Storage.getInt(cardStarsKey(tier, i));
        final moves = Storage.getInt(cardMovesKey(tier, i));
        final col = tierColor(tier);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GlassCard(
            blur: 0,
            radius: 24,
            glow: stars > 0 ? col : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [col.withValues(alpha: 0.26), col.withValues(alpha: 0.05)],
            ),
            onTap: () => setState(() => _level = i),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: Pal.accent(col),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
                ),
                child: Text('${i + 1}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${levels[i].label} grid',
                      style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 2),
                  Text(moves == 0 ? 'Not played yet' : 'Best: $moves moves',
                      style: const TextStyle(color: Pal.textDim, fontSize: 13)),
                ]),
              ),
              StarRow(stars: stars, size: 22),
            ]),
          ).animate(delay: (70 * i).ms).fadeIn(duration: 350.ms).slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
        );
      },
    );
  }
}

class _CardBoard extends StatefulWidget {
  final Tier tier;
  final int level;
  final VoidCallback onExit;
  final ValueChanged<int> onNext;
  const _CardBoard({super.key, required this.tier, required this.level, required this.onExit, required this.onNext});
  @override
  State<_CardBoard> createState() => _CardBoardState();
}

class _CardBoardState extends State<_CardBoard> {
  late final CardTierParams params = cardTierParams[widget.tier]!;
  late final CardLevel lv = params.levels[widget.level];
  late final int? limit = params.timeLimit(widget.level);
  int gen = 0;
  bool over = false;
  late List<int> deck;
  final Set<int> up = {};
  final Set<int> matched = {};
  int? first;
  bool busy = false;
  int moves = 0;
  int seconds = 0;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    deck = generateDeck(lv.pairs);
    up.clear();
    matched.clear();
    first = null;
    busy = false;
    moves = 0;
    seconds = 0;
    timer?.cancel();
    over = false;
    final my = ++gen;
    if (params.peekMs > 0) {
      busy = true;
      up.addAll(List.generate(deck.length, (i) => i));
      Future.delayed(Duration(milliseconds: params.peekMs), () {
        if (!mounted || my != gen) return;
        setState(() {
          up.clear();
          busy = false;
        });
        _startTimer();
      });
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => seconds++);
      if (limit != null && seconds >= limit! && !over) _timeUp();
    });
  }

  Future<void> _timeUp() async {
    over = true;
    timer?.cancel();
    gen++;
    AppAudio.play(Sound.fail);
    AppAudio.haptic(true);
    Rewards.onGameEnd('memory_boost', score: _tierStarTotal());
    final choice = await showResultDialog(
      context,
      title: "Time is up!",
      emoji: '⏰',
      color: Pal.danger,
      message: '${matched.length ~/ 2}/${lv.pairs} pairs found',
    );
    if (!mounted) return;
    if (choice == DialogChoice.retry) {
      setState(_start);
    } else {
      widget.onExit();
    }
  }

  int _tierStarTotal() {
    var n = 0;
    for (var i = 0; i < params.levels.length; i++) {
      n += Storage.getInt(cardStarsKey(widget.tier, i));
    }
    return n;
  }

  @override
  void dispose() {
    gen++;
    timer?.cancel();
    super.dispose();
  }

  Future<void> _tap(int i) async {
    if (busy || over || up.contains(i) || matched.contains(i)) return;
    AppAudio.play(Sound.flip);
    AppAudio.haptic();
    setState(() => up.add(i));
    if (first == null) {
      first = i;
      return;
    }
    final a = first!;
    first = null;
    setState(() => moves++);
    if (isMatch(deck, a, i)) {
      busy = true;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted || over) return;
      AppAudio.play(Sound.success);
      AppAudio.haptic();
      setState(() {
        up.removeAll([a, i]);
        matched.addAll([a, i]);
        busy = false;
      });
      if (matched.length == deck.length) _won();
    } else {
      busy = true;
      final soundAt = params.flipBackMs < 500 ? params.flipBackMs ~/ 2 : 380;
      await Future.delayed(Duration(milliseconds: soundAt));
      if (!mounted || over) return;
      AppAudio.play(Sound.fail, volume: 0.35);
      await Future.delayed(Duration(milliseconds: params.flipBackMs - soundAt));
      if (!mounted || over) return;
      setState(() {
        up.removeAll([a, i]);
        busy = false;
      });
    }
  }

  Future<void> _won() async {
    timer?.cancel();
    over = true;
    AppAudio.haptic(true);
    final stars = starsFor(moves, lv.pairs);
    Storage.setBest(cardStarsKey(widget.tier, widget.level), stars);
    Rewards.onLevelComplete('memory_boost', cardRewardKey(widget.tier, widget.level),
        stars: stars, score: _tierStarTotal());
    final prev = Storage.getInt(cardMovesKey(widget.tier, widget.level));
    final newBest = prev == 0 || moves < prev;
    if (newBest) Storage.setInt(cardMovesKey(widget.tier, widget.level), moves);
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final hasNext = widget.level + 1 < params.levels.length;
    final choice = await showResultDialog(
      context,
      title: 'Level complete!',
      emoji: '🏆',
      stars: stars,
      message: '$moves moves  -  ${fmtTime(seconds)}${newBest ? '\nNew best!' : ''}',
      retryLabel: 'Replay',
      extraLabel: hasNext ? 'Next level' : null,
    );
    if (!mounted) return;
    switch (choice) {
      case DialogChoice.retry:
        setState(_start);
      case DialogChoice.extra:
        widget.onNext(widget.level + 1);
      case DialogChoice.menu:
        widget.onExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          StatChip(Icons.touch_app_rounded, '$moves moves'),
          StatChip(Icons.timer_rounded, fmtTime(limit == null ? seconds : (limit! - seconds).clamp(0, limit!)),
              color: limit != null && limit! - seconds <= 10 ? Pal.danger : Pal.gold),
          StatChip(Icons.check_circle_rounded, '${matched.length ~/ 2}/${lv.pairs}', color: Pal.success),
        ]),
      ),
      Expanded(
        child: LayoutBuilder(builder: (c, box) {
          const gap = 8.0;
          final w = (box.maxWidth - 24 - gap * (lv.cols - 1)) / lv.cols;
          final h = (box.maxHeight - 24 - gap * (lv.rows - 1)) / lv.rows;
          final size = w < h ? w : h;
          return Center(
            child: SizedBox(
              width: size * lv.cols + gap * (lv.cols - 1),
              height: size * lv.rows + gap * (lv.rows - 1),
              child: GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                clipBehavior: Clip.none,
                crossAxisCount: lv.cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < deck.length; i++)
                    _FlipCard(
                      emoji: cardEmojis[deck[i]],
                      faceUp: up.contains(i) || matched.contains(i),
                      matched: matched.contains(i),
                      fontSize: size * 0.5,
                      onTap: () => _tap(i),
                    ).animate(delay: (25 * i).ms).fadeIn(duration: 300.ms).scale(
                        begin: const Offset(0.7, 0.7), end: const Offset(1, 1), curve: Curves.easeOutBack),
                ],
              ),
            ),
          );
        }),
      ),
      const SizedBox(height: 12),
    ]);
  }
}

class _FlipCard extends StatelessWidget {
  final String emoji;
  final bool faceUp, matched;
  final double fontSize;
  final VoidCallback onTap;
  const _FlipCard({
    required this.emoji,
    required this.faceUp,
    required this.matched,
    required this.fontSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return GestureDetector(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, fit: StackFit.expand, children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: faceUp ? 1.0 : 0.0),
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeInOutCubic,
          builder: (c, v, _) {
            final showFront = v > 0.5;
            final lift = 1 - (2 * v - 1).abs(); // peaks mid-flip
            return Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0012)
                ..rotateY(v * pi)
                ..scaleByDouble(1 + 0.08 * lift, 1 + 0.08 * lift, 1, 1),
              child: showFront
                  ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(pi), child: _front(radius))
                  : _back(radius),
            );
          },
        ),
        if (matched)
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Pal.success, width: 3),
                boxShadow: [BoxShadow(color: Pal.success.withValues(alpha: 0.8), blurRadius: 24, spreadRadius: 4)],
              ),
            ),
          )
              .animate()
              .scale(begin: const Offset(1, 1), end: const Offset(1.45, 1.45), duration: 520.ms, curve: Curves.easeOut)
              .fadeOut(duration: 520.ms),
      ]),
    );
  }

  Widget _back(BorderRadius radius) {
    const c = Color(0xFF7C5CFF);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: Pal.accent(c),
        border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [BoxShadow(color: c.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: CustomPaint(
          painter: _BackPainter(),
          child: Center(
            child: Icon(Icons.psychology_rounded, color: Colors.white.withValues(alpha: 0.85), size: fontSize * 0.9),
          ),
        ),
      ),
    );
  }

  Widget _front(BorderRadius radius) {
    final col = matched ? Pal.success : Pal.gold;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: matched
              ? [const Color(0xFF1F6B4A), const Color(0xFF123F33)]
              : [const Color(0xFF3A2D7A), const Color(0xFF1E1650)],
        ),
        border: Border.all(color: col.withValues(alpha: matched ? 0.9 : 0.5), width: 1.5),
        boxShadow: [BoxShadow(color: col.withValues(alpha: matched ? 0.5 : 0.25), blurRadius: matched ? 16 : 8)],
      ),
      child: Center(child: Text(emoji, style: TextStyle(fontSize: fontSize))),
    );
  }
}

class _BackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final line = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..strokeWidth = 1;
    final step = s.shortestSide / 4;
    for (double d = -s.height; d < s.width; d += step) {
      canvas.drawLine(Offset(d, 0), Offset(d + s.height, s.height), line);
      canvas.drawLine(Offset(d + s.height, 0), Offset(d, s.height), line);
    }
    final top = Rect.fromLTWH(0, 0, s.width, s.height * 0.5);
    canvas.drawRect(
      top,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0)],
        ).createShader(top),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
