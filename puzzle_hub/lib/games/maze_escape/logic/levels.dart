/// Level definitions + star rules (pure Dart).
const int kLevelCount = 30;

/// Difficulty tier, applies to both modes.
enum MazeTier {
  easy('Easy'),
  medium('Medium'),
  hard('Hard'),
  extreme('Extreme');

  const MazeTier(this.label);
  final String label;
}

/// Linear interpolation of [a]..[b] over levels 1..[kLevelCount].
int _lerp(int a, int b, int level) => a + ((level - 1) * (b - a) / (kLevelCount - 1)).round();

class LabLevel {
  const LabLevel(this.tier, this.level, this.size, this.fogRadius, this.limitFactor, this.torches, this.seed);
  final MazeTier tier;
  final int level;
  final int size;

  /// 0 = no fog, otherwise visible radius in cells.
  final int fogRadius;

  /// Move limit = optimal x factor; 0 = no limit.
  final double limitFactor;
  final int torches;
  final int seed;

  bool get limited => limitFactor > 0;

  int moveLimit(int optimal) => limited ? (optimal * limitFactor).ceil() : 0;

  static LabLevel of(MazeTier tier, int level) {
    final seed = 1000 + level * 7919 + tier.index * 100003;
    switch (tier) {
      case MazeTier.easy:
        return LabLevel(tier, level, _lerp(7, 11, level), 0, 0, 3, seed);
      case MazeTier.medium:
        return LabLevel(tier, level, _lerp(9, 15, level), level < 10 ? 0 : 4, level % 5 == 0 ? 4 : 0, 3, seed);
      case MazeTier.hard:
        return LabLevel(tier, level, _lerp(11, 19, level), 3, 3.0, 2, seed);
      case MazeTier.extreme:
        return LabLevel(tier, level, _lerp(15, 25, level), 2, 2.5, 1, seed);
    }
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
  const ForkLevel(this.tier, this.level, this.forks, this.options, this.resetFrom, this.lanterns, this.seed);
  final MazeTier tier;
  final int level;
  final int forks;
  final int options;

  /// A wrong turn at fork index >= [resetFrom] sends the player back to the
  /// first fork. A large value means never.
  final int resetFrom;
  final int lanterns;
  final int seed;

  bool get resetOnWrong => resetFrom < 1000;

  static ForkLevel of(MazeTier tier, int level) {
    final seed = 5000 + level * 104729 + tier.index * 1000003;
    switch (tier) {
      case MazeTier.easy:
        return ForkLevel(tier, level, _lerp(3, 4, level), 3, 1000, 3, seed);
      case MazeTier.medium:
        return ForkLevel(tier, level, _lerp(4, 6, level), level < 15 ? 3 : 4, 1000, 2, seed);
      case MazeTier.hard:
        return ForkLevel(tier, level, _lerp(5, 8, level), level < 15 ? 4 : 5, 2, 2, seed);
      case MazeTier.extreme:
        return ForkLevel(tier, level, _lerp(6, 10, level), level < 15 ? 5 : 6, 0, 1, seed);
    }
  }
}

/// Stars by wrong turns. Using the lantern caps the result at 2 stars.
int forkStars(int wrong, int forks, {bool usedHint = false}) {
  final lim = forks ~/ 2 < 1 ? 1 : forks ~/ 2;
  var s = wrong == 0 ? 3 : (wrong <= lim ? 2 : 1);
  if (usedHint && s > 2) s = 2;
  return s;
}
