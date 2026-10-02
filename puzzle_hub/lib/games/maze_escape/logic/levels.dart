/// Level definitions + star rules (pure Dart).
const int kLevelCount = 30;

class LabLevel {
  const LabLevel(this.level, this.size, this.fogRadius, this.limited, this.torches, this.seed);
  final int level;
  final int size;

  /// 0 = no fog, otherwise visible radius in cells.
  final int fogRadius;

  /// Whether a move limit applies (limit = 3 x optimal).
  final bool limited;
  final int torches;
  final int seed;

  int moveLimit(int optimal) => limited ? optimal * 3 : 0;

  static LabLevel of(int level) {
    final size = 7 + ((level - 1) * 14 / (kLevelCount - 1)).round();
    final fog = level < 8 ? 0 : (level < 16 ? 4 : (level < 24 ? 3 : 2));
    return LabLevel(level, size, fog, level % 5 == 0, 3, 1000 + level * 7919);
  }
}

/// Stars by moves vs optimal. Using a torch caps the result at 2 stars.
int labStars(int moves, int optimal, {int torchesUsed = 0}) {
  final r = moves / (optimal <= 0 ? 1 : optimal);
  var s = r <= 2.0 ? 3 : (r <= 3.5 ? 2 : 1);
  if (torchesUsed > 0 && s > 2) s = 2;
  return s;
}

class ForkLevel {
  const ForkLevel(this.level, this.forks, this.options, this.resetOnWrong, this.lanterns, this.seed);
  final int level;
  final int forks;
  final int options;

  /// A wrong turn sends the player all the way back to the first fork.
  final bool resetOnWrong;
  final int lanterns;
  final int seed;

  static ForkLevel of(int level) {
    final forks = 3 + ((level - 1) * 5 / (kLevelCount - 1)).round();
    final options = 3 + (level - 1) ~/ 10;
    return ForkLevel(level, forks, options, level >= 6, 2, 5000 + level * 104729);
  }
}

/// Stars by wrong turns. Using the lantern caps the result at 2 stars.
int forkStars(int wrong, int forks, {bool usedHint = false}) {
  final lim = forks ~/ 2 < 1 ? 1 : forks ~/ 2;
  var s = wrong == 0 ? 3 : (wrong <= lim ? 2 : 1);
  if (usedHint && s > 2) s = 2;
  return s;
}
