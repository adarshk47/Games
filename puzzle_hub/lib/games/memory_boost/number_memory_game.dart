import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/storage.dart';
import 'logic/number_logic.dart';
import 'mb_widgets.dart';

String numberBestKey(int lives) => 'memory.number.best.$lives';

enum _Phase { setup, show, input, feedback }

class NumberMemoryScreen extends StatefulWidget {
  const NumberMemoryScreen({super.key});
  @override
  State<NumberMemoryScreen> createState() => _NumberMemoryScreenState();
}

class _NumberMemoryScreenState extends State<NumberMemoryScreen> {
  _Phase phase = _Phase.setup;
  int maxLives = 3;
  int lives = 3;
  int level = 1; // current digits
  int reached = 0; // levels cleared
  String number = '';
  String answer = '';
  bool lastOk = true;
  int token = 0;

  @override
  void dispose() {
    token++;
    super.dispose();
  }

  void _begin(int lv) {
    maxLives = lv;
    lives = lv;
    level = 1;
    reached = 0;
    _show();
  }

  Future<void> _show() async {
    final my = ++token;
    number = generateNumber(digitsForLevel(level));
    answer = '';
    setState(() => phase = _Phase.show);
    await Future.delayed(displayDuration(number.length));
    if (!mounted || my != token) return;
    setState(() => phase = _Phase.input);
  }

  void _key(String k) {
    if (phase != _Phase.input) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (k == '<') {
        if (answer.isNotEmpty) answer = answer.substring(0, answer.length - 1);
      } else if (answer.length < number.length + 2) {
        answer += k;
      }
    });
  }

  Future<void> _submit() async {
    if (phase != _Phase.input || answer.isEmpty) return;
    final ok = isCorrectAnswer(number, answer);
    setState(() {
      lastOk = ok;
      phase = _Phase.feedback;
      if (ok) {
        reached = level;
      } else {
        lives--;
      }
    });
    ok ? HapticFeedback.lightImpact() : HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    if (ok) {
      level++;
      _show();
    } else if (lives <= 0) {
      await _gameOver();
    } else {
      _show(); // same length, new number
    }
  }

  Future<void> _gameOver() async {
    final newBest = Storage.setBest(numberBestKey(maxLives), reached);
    final choice = await showResultDialog(
      context,
      title: 'Game over',
      body: [
        Text('Level reached: $reached', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(newBest && reached > 0 ? 'New best!' : 'Best: ${Storage.getInt(numberBestKey(maxLives))}'),
      ],
    );
    if (!mounted) return;
    if (choice == DialogChoice.retry) {
      _begin(maxLives);
    } else {
      setState(() => phase = _Phase.setup);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Number Memory')),
      body: SafeArea(child: phase == _Phase.setup ? _setup() : _play()),
    );
  }

  Widget _setup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.pin_rounded, size: 64),
          const SizedBox(height: 12),
          const Text('Memorize the number, then type it. Each round adds a digit.', textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FilledButton(onPressed: () => _begin(3), child: Text('Normal - 3 lives (best ${Storage.getInt(numberBestKey(3))})')),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: () => _begin(1), child: Text('Sudden death - 1 life (best ${Storage.getInt(numberBestKey(1))})')),
        ]),
      ),
    );
  }

  Widget _play() {
    final cs = Theme.of(context).colorScheme;
    final big = Theme.of(context).textTheme.displayMedium!.copyWith(fontWeight: FontWeight.bold, letterSpacing: 4);
    Widget center;
    switch (phase) {
      case _Phase.show:
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          FittedBox(child: Text(number, style: big)),
          const SizedBox(height: 24),
          TweenAnimationBuilder<double>(
            key: ValueKey(number + token.toString()),
            tween: Tween(begin: 1, end: 0),
            duration: displayDuration(number.length),
            builder: (c, v, _) => SizedBox(width: 220, child: LinearProgressIndicator(value: v, borderRadius: BorderRadius.circular(8))),
          ),
        ]);
      case _Phase.input:
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('What was the number?'),
          const SizedBox(height: 12),
          FittedBox(child: Text(answer.isEmpty ? '_' : answer, style: big)),
        ]);
      case _Phase.feedback:
        center = Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(lastOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
              size: 56, color: lastOk ? Colors.green : cs.error),
          const SizedBox(height: 8),
          Text(lastOk ? 'Correct!' : 'It was $number', style: Theme.of(context).textTheme.titleLarge),
          if (!lastOk) Text('You typed $answer'),
        ]);
      case _Phase.setup:
        center = const SizedBox();
    }
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          StatChip(Icons.layers_rounded, 'Level $level'),
          Row(children: [
            for (var i = 0; i < maxLives; i++)
              Icon(i < lives ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: Colors.redAccent),
          ]),
          StatChip(Icons.emoji_events_rounded, 'Best ${Storage.getInt(numberBestKey(maxLives))}'),
        ]),
      ),
      Expanded(child: Center(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey('$phase$level$lives'), child: center)))),
      _keypad(),
    ]);
  }

  Widget _keypad() {
    final enabled = phase == _Phase.input;
    Widget key(String label, {VoidCallback? onTap, Widget? child}) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FilledButton.tonal(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              onPressed: enabled ? (onTap ?? () => _key(label)) : null,
              child: child ?? Text(label, style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
    Widget row(List<Widget> c) => Row(children: c);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        row([key('1'), key('2'), key('3')]),
        row([key('4'), key('5'), key('6')]),
        row([key('7'), key('8'), key('9')]),
        row([
          key('<', child: const Icon(Icons.backspace_rounded)),
          key('0'),
          key('OK', onTap: _submit, child: const Icon(Icons.check_rounded)),
        ]),
      ]),
    );
  }
}
