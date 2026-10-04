import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/audio.dart';
import '../../core/i18n/i18n.dart';
import '../../core/rewards.dart';
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
  String _msg = tr('mom_memory.lullaby_tap_start');
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
    _play(tr('mom_memory.watch'));
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
      AppAudio.play(Sound.pop);
      AppAudio.haptic();
      await _wait(700);
      if (!mounted || id != _run) return;
      setState(() => _lit = -1);
      await _wait(350);
    }
    if (!mounted || id != _run) return;
    setState(() {
      _listening = true;
      _msg = tr('mom_memory.your_turn');
    });
  }

  Future<void> _tap(int pad) async {
    if (!_listening) return;
    AppAudio.play(Sound.pop);
    AppAudio.haptic();
    setState(() => _lit = pad);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted && _listening) setState(() => _lit = -1);
    });
    final r = checkTap(_seq, _input, pad);
    if (r == TapResult.wrong) {
      _listening = false;
      await _wait(500);
      if (!mounted) return;
      _play(tr('mom_memory.lullaby_retry', {'msg': pick(gentle)}));
    } else if (r == TapResult.right) {
      setState(() => _input++);
    } else {
      _listening = false;
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted) AppAudio.play(Sound.success);
      });
      final len = _seq.length;
      Storage.setBest('mom.lullaby.best', len);
      recordPlay();
      Rewards.onLevelComplete(
        'mom_memory',
        'lullaby-N$len',
        stars: len >= 8 ? 3 : (len >= 5 ? 2 : 1),
      );
      setState(() => _msg = '${pick(praise)} ($len)');
      await _wait(1100);
      if (!mounted) return;
      _seq = extendPattern(_seq, _rng);
      _play(tr('mom_memory.lullaby_longer'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final best = Storage.getInt('mom.lullaby.best');
    return MmPage(
      title: tr('mom_memory.lullaby_title'),
      actions: [
        BarAction(
          icon: Icons.refresh_rounded,
          tooltip: tr('common.new_game'),
          onTap: () {
            _run++;
            setState(() {
              _started = false;
              _seq = [];
              _lit = -1;
              _listening = false;
              _msg = tr('mom_memory.lullaby_tap_start');
            });
          },
        ),
      ],
      body: Column(
        children: [
          const SizedBox(height: 10),
          Text(
            _started
                ? tr('mom_memory.lullaby_status', {
                    'n': _seq.length,
                    'best': best,
                  })
                : tr('mom_memory.lullaby_best_len', {'best': best}),
            style: const TextStyle(
              color: Pal.textDim,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              _msg,
              key: ValueKey(_msg),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Pal.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_started && _listening)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _seq.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < _input ? Mm.rose : Pal.glassBorder,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (_, c) {
                  const gap = 14.0;
                  final s = math
                      .min((c.maxWidth - gap) / 2, (c.maxHeight - gap * 2) / 3)
                      .clamp(60.0, 170.0);
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
                                  opacity: _lit == i || _listening || !_started
                                      ? 1
                                      : 0.8,
                                  duration: const Duration(milliseconds: 300),
                                  child: PastelTile(
                                    color: Mm.pads[i],
                                    selected: _lit == i,
                                    dim: _lit != i,
                                    radius: 36,
                                    child: Text(
                                      _lit == i ? '✨' : '',
                                      style: const TextStyle(fontSize: 30),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (!_started)
            PremiumButton(
              label: tr('mom_memory.start'),
              icon: Icons.nightlight_round,
              color: Mm.rose,
              onTap: _start,
            ),
          if (_started && !_listening)
            const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Text('🎵', style: TextStyle(fontSize: 22)),
            ),
          const SizedBox(height: 6),
          const MmFootnote(),
        ],
      ),
    );
  }
}
