import 'dart:math';

/// A chain of forks. At every fork exactly one option is the correct trail.
class ForkPath {
  ForkPath(this.optionCount, this.correct);
  final int optionCount;

  /// Correct option index for each fork.
  final List<int> correct;

  int get forkCount => correct.length;

  bool isCorrect(int fork, int option) => correct[fork] == option;

  /// Seeded generator. Consecutive forks avoid repeating the same position so
  /// the player cannot just guess "always the same one".
  static ForkPath generate(int seed, int forks, int options) {
    final rnd = Random(seed);
    final c = <int>[];
    for (var i = 0; i < forks; i++) {
      var v = rnd.nextInt(options);
      if (i > 0 && options > 1 && v == c[i - 1]) v = (v + 1 + rnd.nextInt(options - 1)) % options;
      c.add(v);
    }
    return ForkPath(options, c);
  }
}
