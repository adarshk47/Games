import 'dart:async';
import 'dart:math' show pi;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/storage.dart';
import 'logic/card_deck.dart';
import 'mb_widgets.dart';

String cardStarsKey(int level) => 'memory.cards.stars.$level';
String cardMovesKey(int level) => 'memory.cards.moves.$level';

class CardMatchScreen extends StatefulWidget {
  const CardMatchScreen({super.key});
  @override
  State<CardMatchScreen> createState() => _CardMatchScreenState();
}

class _CardMatchScreenState extends State<CardMatchScreen> {
  int? _level;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_level == null ? 'Card Match' : 'Level ${_level! + 1} (${cardLevels[_level!].label})'),
        leading: _level == null ? null : BackButton(onPressed: () => setState(() => _level = null)),
      ),
      body: _level == null
          ? _picker()
          : _CardBoard(
              key: ValueKey(_level),
              level: _level!,
              onExit: () => setState(() => _level = null),
              onNext: (l) => setState(() => _level = l),
            ),
    );
  }

  Widget _picker() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: cardLevels.length,
      itemBuilder: (c, i) {
        final stars = Storage.getInt(cardStarsKey(i));
        final moves = Storage.getInt(cardMovesKey(i));
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${i + 1}')),
            title: Text('${cardLevels[i].label} grid'),
            subtitle: Text(moves == 0 ? 'Not played yet' : 'Best: $moves moves'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var s = 1; s <= 3; s++)
                Icon(s <= stars ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber),
            ]),
            onTap: () => setState(() => _level = i),
          ),
        );
      },
    );
  }
}

class _CardBoard extends StatefulWidget {
  final int level;
  final VoidCallback onExit;
  final ValueChanged<int> onNext;
  const _CardBoard({super.key, required this.level, required this.onExit, required this.onNext});
  @override
  State<_CardBoard> createState() => _CardBoardState();
}

class _CardBoardState extends State<_CardBoard> {
  late final CardLevel lv = cardLevels[widget.level];
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
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => seconds++);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  Future<void> _tap(int i) async {
    if (busy || up.contains(i) || matched.contains(i)) return;
    HapticFeedback.selectionClick();
    setState(() => up.add(i));
    if (first == null) {
      first = i;
      return;
    }
    final a = first!;
    first = null;
    setState(() => moves++);
    if (isMatch(deck, a, i)) {
      HapticFeedback.lightImpact();
      busy = true;
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        up.removeAll([a, i]);
        matched.addAll([a, i]);
        busy = false;
      });
      if (matched.length == deck.length) _won();
    } else {
      busy = true;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      setState(() {
        up.removeAll([a, i]);
        busy = false;
      });
    }
  }

  Future<void> _won() async {
    timer?.cancel();
    HapticFeedback.heavyImpact();
    final stars = starsFor(moves, lv.pairs);
    Storage.setBest(cardStarsKey(widget.level), stars);
    final prev = Storage.getInt(cardMovesKey(widget.level));
    final newBest = prev == 0 || moves < prev;
    if (newBest) Storage.setInt(cardMovesKey(widget.level), moves);
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    final hasNext = widget.level + 1 < cardLevels.length;
    final choice = await showResultDialog(
      context,
      title: 'Level complete!',
      retryLabel: 'Replay',
      extraLabel: hasNext ? 'Next level' : null,
      body: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (var s = 1; s <= 3; s++)
            Icon(s <= stars ? Icons.star_rounded : Icons.star_outline_rounded, color: Colors.amber, size: 40),
        ]),
        const SizedBox(height: 12),
        Text('$moves moves  -  ${fmtTime(seconds)}'),
        if (newBest)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('New best!', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
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
          StatChip(Icons.timer_rounded, fmtTime(seconds)),
          StatChip(Icons.check_circle_rounded, '${matched.length ~/ 2}/${lv.pairs}'),
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
                    ),
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
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: faceUp ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        builder: (c, v, _) {
          final showFront = v > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(v * pi),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: showFront ? (matched ? Colors.green.shade100 : cs.surface) : cs.primary,
                border: Border.all(color: showFront && matched ? Colors.green : cs.primary, width: 2),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))],
              ),
              alignment: Alignment.center,
              child: showFront
                  ? Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.rotationY(pi),
                      child: Text(emoji, style: TextStyle(fontSize: fontSize)),
                    )
                  : Icon(Icons.psychology_rounded, color: cs.onPrimary.withValues(alpha: 0.8), size: fontSize),
            ),
          );
        },
      ),
    );
  }
}
