import 'dart:math';

import 'focus_common.dart';
import 'focus_difficulty.dart';

/// The ink colors / words used by Color vs Word (first N are used per tier).
enum StroopColor {
  red('RED', 0xFFFF4D5E),
  blue('BLUE', 0xFF4D8DFF),
  green('GREEN', 0xFF34D399),
  yellow('YELLOW', 0xFFFFD84D),
  purple('PURPLE', 0xFFB66BFF),
  orange('ORANGE', 0xFFFF9140),
  pink('PINK', 0xFFFF6FB5), // close to red / purple
  cyan('CYAN', 0xFF2DD4EF); // close to blue / green

  const StroopColor(this.label, this.argb);
  final String label;
  final int argb;
}

class StroopRound {
  const StroopRound(this.word, this.ink, this.options);
  final StroopColor word;
  final StroopColor ink; // the correct answer
  final List<StroopColor> options;
  bool isCorrect(StroopColor pick) => pick == ink;
}

class StroopGenerator {
  StroopGenerator([Random? rng, FocusParams? params])
      : _rng = rng ?? Random(),
        params = params ?? focusParams(FocusMode.stroop, FocusTier.medium);
  final Random _rng;
  final FocusParams params;

  /// Number of answer buttons grows with rounds solved, capped by the tier.
  static int optionCountFor(FocusParams p, int solved) =>
      (p.stroopMinOptions + solved ~/ p.stroopOptionStep).clamp(p.stroopMinOptions, min(p.stroopMaxOptions, p.stroopPool));

  int optionCount(int solved) => optionCountFor(params, solved);

  StroopRound next(int solved) {
    final all = StroopColor.values.take(params.stroopPool).toList();
    final ink = all[_rng.nextInt(all.length)];
    StroopColor word;
    do {
      word = all[_rng.nextInt(all.length)];
    } while (word == ink);
    final others = all.where((c) => c != ink).toList()..shuffle(_rng);
    final opts = <StroopColor>[ink, ...others.take(optionCount(solved) - 1)]..shuffle(_rng);
    return StroopRound(word, ink, opts);
  }
}
