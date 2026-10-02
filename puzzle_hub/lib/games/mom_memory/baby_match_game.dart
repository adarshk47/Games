import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/rewards.dart';
import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_logic.dart';
import 'mm_common.dart';

class BabyMatchGame extends StatefulWidget {
  const BabyMatchGame({super.key});
  @override
  State<BabyMatchGame> createState() => _BabyMatchGameState();
}

class _BabyMatchGameState extends State<BabyMatchGame> {
  int _level = 0;
  late List<int> _deck;
  final Set<int> _up = {};
  final Set<int> _done = {};
  int _moves = 0;
  bool _lock = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _start(0);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  void _start(int level) {
    _t?.cancel();
    setState(() {
      _level = level;
      _deck = generateMatchDeck(matchLevels[level].pairs, math.Random());
      _up.clear();
      _done.clear();
      _moves = 0;
      _lock = false;
    });
  }

  void _tap(int i) {
    if (_lock || _up.contains(i) || _done.contains(i)) return;
    softTap();
    setState(() => _up.add(i));
    if (_up.length < 2) return;
    _moves++;
    final a = _up.first, b = _up.last;
    if (_deck[a] == _deck[b]) {
      _t = Timer(const Duration(milliseconds: 450), () {
        if (!mounted) return;
        setState(() {
          _done.addAll([a, b]);
          _up.clear();
          _lock = false;
        });
        if (_done.length == _deck.length) _win();
      });
      _lock = true;
    } else {
      _lock = true;
      _t = Timer(const Duration(milliseconds: 1100), () {
        if (!mounted) return;
        setState(() {
          _up.clear();
          _lock = false;
        });
      });
    }
  }

  void _win() {
    final lv = matchLevels[_level];
    final stars = matchStars(_moves, lv.pairs);
    Storage.setBest('mom.match.stars.$_level', stars);
    final prev = Storage.getInt('mom.match.moves.$_level');
    if (prev == 0 || _moves < prev) {
      Storage.setInt('mom.match.moves.$_level', _moves);
    }
    recordPlay();
    Rewards.onLevelComplete('mom_memory', 'match-L${_level + 1}', stars: stars);
    final next = _level + 1 < matchLevels.length;
    mmDialog(
      context,
      title: pick(praise),
      message:
          '$_moves chaal mein sab jodi mil gayi. Aaram se khelne ke liye shukriya!',
      emoji: '🧸',
      stars: stars,
      actions: [
        DialogAction('Phir se', () => _start(_level)),
        if (next)
          DialogAction('Agla level', () => _start(_level + 1), primary: true),
        if (!next)
          DialogAction(
            'Menu',
            () => Navigator.of(context).maybePop(),
            primary: true,
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lv = matchLevels[_level];
    return MmPage(
      title: 'Baby Items Match',
      actions: [
        BarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Naya',
          onTap: () => _start(_level),
        ),
      ],
      body: Column(
        children: [
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (var i = 0; i < matchLevels.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _start(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: i == _level
                              ? Mm.rose.withValues(alpha: 0.85)
                              : Pal.glass,
                          border: Border.all(color: Pal.glassBorder),
                        ),
                        child: Row(
                          children: [
                            Text(
                              matchLevels[i].label,
                              style: TextStyle(
                                color: i == _level ? Mm.ink : Pal.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 6),
                            StarRow(
                              stars: Storage.getInt('mom.match.stars.$i'),
                              size: 12,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Chaal: $_moves   •   ${_done.length ~/ 2}/${lv.pairs} jodi',
              style: const TextStyle(
                color: Pal.textDim,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: LayoutBuilder(
                builder: (_, c) {
                  const gap = 10.0;
                  final w = (c.maxWidth - gap * (lv.cols - 1)) / lv.cols;
                  final h = (c.maxHeight - gap * (lv.rows - 1)) / lv.rows;
                  final s = math.min(w, h).clamp(40.0, 110.0);
                  return Center(
                    child: SizedBox(
                      width: s * lv.cols + gap * (lv.cols - 1),
                      height: s * lv.rows + gap * (lv.rows - 1),
                      child: GridView.count(
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: lv.cols,
                        mainAxisSpacing: gap,
                        crossAxisSpacing: gap,
                        children: [
                          for (var i = 0; i < _deck.length; i++)
                            _CardTile(
                              key: ValueKey('$_level-$i-${_deck[i]}'),
                              emoji: babyEmojis[_deck[i]],
                              color: Mm.pads[_deck[i] % Mm.pads.length],
                              up: _up.contains(i) || _done.contains(i),
                              matched: _done.contains(i),
                              size: s,
                              onTap: () => _tap(i),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(
              'Aaram se, koi jaldi nahi 🌸',
              style: TextStyle(color: Pal.textDim, fontSize: 13),
            ),
          ),
          const MmFootnote(),
        ],
      ),
    );
  }
}

class _CardTile extends StatelessWidget {
  const _CardTile({
    super.key,
    required this.emoji,
    required this.color,
    required this.up,
    required this.matched,
    required this.size,
    required this.onTap,
  });
  final String emoji;
  final Color color;
  final bool up, matched;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: up ? 1 : 0),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
        builder: (_, v, _) {
          final front = v > 0.5;
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(math.pi * v),
            child: front
                ? Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(math.pi),
                    child: PastelTile(
                      color: color,
                      selected: matched,
                      dim: false,
                      child: AnimatedScale(
                        scale: matched ? 1.08 : 1,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          emoji,
                          style: TextStyle(fontSize: size * 0.5),
                        ),
                      ),
                    ),
                  )
                : PastelTile(
                    color: Mm.lavender,
                    dim: true,
                    child: Text(
                      '✿',
                      style: TextStyle(
                        fontSize: size * 0.4,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}
