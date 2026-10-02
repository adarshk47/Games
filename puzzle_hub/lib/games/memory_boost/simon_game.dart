import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/storage.dart';
import 'logic/simon_logic.dart';
import 'mb_widgets.dart';

const simonBestKey = 'memory.simon.best';

enum _Phase { idle, watching, input, over }

class SimonScreen extends StatefulWidget {
  const SimonScreen({super.key});
  @override
  State<SimonScreen> createState() => _SimonScreenState();
}

class _SimonScreenState extends State<SimonScreen> {
  static const _colors = [Color(0xFFE53935), Color(0xFF43A047), Color(0xFF1E88E5), Color(0xFFFDD835)];
  final SimonLogic logic = SimonLogic();
  _Phase phase = _Phase.idle;
  int lit = -1;
  int round = 0; // bumps to cancel stale playback loops

  @override
  void dispose() {
    round++;
    super.dispose();
  }

  Future<void> _startGame() async {
    logic.reset();
    await _nextRound();
  }

  Future<void> _nextRound() async {
    final my = ++round;
    logic.addStep();
    setState(() => phase = _Phase.watching);
    await Future.delayed(const Duration(milliseconds: 700));
    final ms = SimonLogic.stepMillis(logic.length);
    for (final p in List<int>.from(logic.sequence)) {
      if (!mounted || my != round) return;
      setState(() => lit = p);
      HapticFeedback.selectionClick();
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
    HapticFeedback.lightImpact();
    setState(() => lit = pad);
    Future.delayed(const Duration(milliseconds: 160), () {
      if (mounted && phase != _Phase.watching) setState(() => lit = -1);
    });
    if (res == SequenceResult.wrong) {
      await _gameOver();
    } else if (res == SequenceResult.complete) {
      setState(() => phase = _Phase.watching);
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) _nextRound();
    }
  }

  Future<void> _gameOver() async {
    HapticFeedback.heavyImpact();
    setState(() => phase = _Phase.over);
    final streak = logic.streak;
    final newBest = Storage.setBest(simonBestKey, streak);
    final choice = await showResultDialog(
      context,
      title: 'Game over',
      body: [
        Text('Streak: $streak', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(newBest && streak > 0 ? 'New best!' : 'Best: ${Storage.getInt(simonBestKey)}'),
      ],
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
    return Scaffold(
      appBar: AppBar(title: const Text('Simon Sequence')),
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              StatChip(Icons.local_fire_department_rounded, 'Streak ${logic.streak}'),
              StatChip(Icons.emoji_events_rounded, 'Best ${Storage.getInt(simonBestKey)}'),
            ]),
          ),
          Text(status, style: Theme.of(context).textTheme.titleMedium),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [for (var i = 0; i < 4; i++) _pad(i)],
                  ),
                ),
              ),
            ),
          ),
          if (phase == _Phase.idle)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: FilledButton.icon(
                onPressed: _startGame,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Start'),
              ),
            )
          else
            const SizedBox(height: 24 + 40),
        ]),
      ),
    );
  }

  Widget _pad(int i) {
    final on = lit == i;
    final base = _colors[i];
    return GestureDetector(
      onTapDown: (_) => _tap(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: on ? base : Color.lerp(base, Colors.black, 0.45),
          borderRadius: BorderRadius.circular(24),
          boxShadow: on ? [BoxShadow(color: base.withValues(alpha: 0.8), blurRadius: 28, spreadRadius: 4)] : [],
        ),
        transform: Matrix4.diagonal3Values(on ? 1.04 : 1, on ? 1.04 : 1, 1),
        transformAlignment: Alignment.center,
      ),
    );
  }
}
