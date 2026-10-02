import 'dart:math';

/// The six ink colors / words used by Color vs Word.
enum StroopColor {
  red('RED', 0xFFFF4D5E),
  blue('BLUE', 0xFF4D8DFF),
  green('GREEN', 0xFF34D399),
  yellow('YELLOW', 0xFFFFD84D),
  purple('PURPLE', 0xFFB66BFF),
  orange('ORANGE', 0xFFFF9140);

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
  StroopGenerator([Random? rng]) : _rng = rng ?? Random();
  final Random _rng;

  /// Number of answer buttons grows from 4 to 6 with rounds solved.
  static int optionCount(int solved) => solved < 10 ? 4 : (solved < 20 ? 5 : 6);

  StroopRound next(int solved) {
    final all = StroopColor.values;
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
