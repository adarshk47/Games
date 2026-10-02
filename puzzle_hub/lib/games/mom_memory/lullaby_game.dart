import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/storage.dart';
import '../../core/ui/ui.dart';
import 'logic/mom_logic.dart';
import 'mm_common.dart';

class LullabyGame extends StatefulWidget {
  const LullabyGame({super.key});
  @override
  State<LullabyGame> createState() => _LullabyGameState();
}

class _LullabyGameState extends State<LullabyGame> {
  final _rng = math.Random();
  List<int> _seq = [];
  int _input = 0;
  int _lit = -1;
  bool _listening = false; // player's turn
  bool _started = false;
  String _msg = 'Shuru karne ke liye neeche dabaiye';
  int _run = 0; // cancels stale playback loops

  @override
  void dispose() {
    _run++;
    super.dispose();
  }

  Future<void> _wait(int ms) => Future.delayed(Duration(milliseconds: ms));

  void _start() {
    _seq = extendPattern([], _rng);
    _started = true;
    _play('Dhyaan se dekhiye');
  }

  Future<void> _play(String msg) async {
    final id = ++_run;
    setState(() {
      _listening = false;
      _input = 0;
      _msg = msg;
    });
    await _wait(900);
    for (final p in _seq) {
      if (!mounted || id != _run) return;
      setState(() => _lit = p);
      softTap();
      await _wait(700);
      if (!mounted || id != _run) return;
      setState(() => _lit = -1);
      await _wait(350);
    }
    if (!mounted || id != _run) return;
    setState(() {
      _listening = true;
      _msg = 'Ab aapki baari';
    });
  }

  Future<void> _tap(int pad) async {
    if (!_listening) return;
    softTap();
    setState(() => _lit = pad);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted && _listening) setState(() => _lit = -1);
    });
    final r = checkTap(_seq, _input, pad);
    if (r == TapResult.wrong) {
      _listening = false;
      await _wait(500);
      if (!mounted) return;
      _play('${pick(gentle)}. Pattern phir se dikhate hain');
    } else if (r == TapResult.right) {
      setState(() => _input++);
    } else {
      _listening = false;
      final len = _seq.length;
      Storage.setBest('mom.lullaby.best', len);
      recordPlay();
      setState(() => _msg = '${pick(praise)} ($len)');
      await _wait(1100);
      if (!mounted) return;
      _seq = extendPattern(_seq, _rng);
      _play('Ab thoda lamba, dhyaan se dekhiye');
    }
  }

  @override
  Widget build(BuildContext context) {
    final best = Storage.getInt('mom.lullaby.best');
    return MmPage(
      title: 'Lullaby Pattern',
      actions: [
        BarAction(
          icon: Icons.refresh_rounded,
          tooltip: 'Naya',
          onTap: () {
            _run++;
            setState(() {
              _started = false;
              _seq = [];
              _lit = -1;
              _listening = false;
              _msg = 'Shuru karne ke liye neeche dabaiye';
            });
          },
        ),
      ],
      body: Column(children: [
        const SizedBox(height: 10),
        Text(_started ? 'Lambai ${_seq.length}   •   Sabse achhi: $best' : 'Sabse achhi lambai: $best',
            style: const TextStyle(color: Pal.textDim, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(_msg,
              key: ValueKey(_msg),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Pal.text, fontSize: 18, fontWeight: FontWeight.w800)),
        ),
        if (_started && _listening)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              for (var i = 0; i < _seq.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: i < _input ? Mm.rose : Pal.glassBorder),
                ),
            ]),
          ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LayoutBuilder(builder: (_, c) {
              const gap = 14.0;
              final s = math.min((c.maxWidth - gap) / 2, (c.maxHeight - gap * 2) / 3).clamp(60.0, 170.0);
              return Center(
                child: SizedBox(
                  width: s * 2 + gap,
                  height: s * 3 + gap * 2,
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: gap,
                    crossAxisSpacing: gap,
                    children: [
                      for (var i = 0; i < lullabyPads; i++)
                        Pressable(
                          onTap: () => _tap(i),
                          child: AnimatedScale(
                            scale: _lit == i ? 1.06 : 1,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOut,
                            child: AnimatedOpacity(
                              opacity: _lit == i || _listening || !_started ? 1 : 0.8,
                              duration: const Duration(milliseconds: 300),
                              child: PastelTile(
                                color: Mm.pads[i],
                                selected: _lit == i,
                                dim: _lit != i,
                                radius: 36,
                                child: Text(_lit == i ? '✨' : '', style: const TextStyle(fontSize: 30)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
        if (!_started) PremiumButton(label: 'Shuru karein', icon: Icons.nightlight_round, color: Mm.rose, onTap: _start),
        if (_started && !_listening)
          const Padding(padding: EdgeInsets.only(bottom: 2), child: Text('🎵', style: TextStyle(fontSize: 22))),
        const SizedBox(height: 6),
        const MmFootnote(),
      ]),
    );
  }
}
