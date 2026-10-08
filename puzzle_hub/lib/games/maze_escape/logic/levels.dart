/// Level definitions + star rules (pure Dart).
const int kLevelCount = 100;

/// Difficulty tier, for the Labyrinth.
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

/// Same as [_lerp] for fractional values.
double _lerpD(double a, double b, int level) => a + (level - 1) * (b - a) / (kLevelCount - 1);

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
        return LabLevel(tier, level, _lerp(7, 13, level), 0, 0, 3, seed);
      case MazeTier.medium:
        // Fog from level 10 (tighter from 60); every 5th level has a move limit.
        final fog = level < 10 ? 0 : (level < 60 ? 4 : 3);
        return LabLevel(tier, level, _lerp(9, 17, level), fog, level % 5 == 0 ? 4 : 0, 3, seed);
      case MazeTier.hard:
        return LabLevel(tier, level, _lerp(11, 21, level), level < 60 ? 3 : 2, _round1(_lerpD(3.0, 2.5, level)), 2, seed);
      case MazeTier.extreme:
        return LabLevel(tier, level, _lerp(15, 27, level), 2, _round1(_lerpD(2.5, 2.0, level)), 1, seed);
    }
  }
}

double _round1(double v) => (v * 10).round() / 10;

/// Stars by moves vs optimal. Using a torch caps the result at 2 stars.
int labStars(int moves, int optimal, {int torchesUsed = 0}) {
  final r = moves / (optimal <= 0 ? 1 : optimal);
  var s = r <= 2.0 ? 3 : (r <= 3.5 ? 2 : 1);
  if (torchesUsed > 0 && s > 2) s = 2;
  return s;
}

/// Game mode inside Maze Escape.
enum MazeMode {
  labyrinth('Labyrinth', 'lab'),
  memory('Memory Maze', 'mem');

  const MazeMode(this.label, this.keyPrefix);
  final String label;

  /// Storage key segment: `maze.<keyPrefix>.<tier>...`.
  final String keyPrefix;
}

/// Memory Maze level: the maze is shown for [previewMs], then goes dark and
/// must be walked from memory.
class MemLevel {
  const MemLevel(this.tier, this.level, this.size, this.previewMs, this.peeks, this.maxBumps, this.seed);
  final MazeTier tier;
  final int level;
  final int size;

  /// How long the full map is shown before it fades out.
  final int previewMs;

  /// Number of 1.5s "peeks" allowed.
  final int peeks;

  /// Bumps allowed before failing; 0 = unlimited.
  final int maxBumps;
  final int seed;

  static const int peekMs = 1500;

  static const _minSize = {MazeTier.easy: 5, MazeTier.medium: 7, MazeTier.hard: 9, MazeTier.extreme: 11};
  static const _maxSize = {MazeTier.easy: 8, MazeTier.medium: 10, MazeTier.hard: 12, MazeTier.extreme: 14};
  static const _baseSec = {MazeTier.easy: 6, MazeTier.medium: 5, MazeTier.hard: 4, MazeTier.extreme: 3};
  static const _peeks = {MazeTier.easy: 3, MazeTier.medium: 2, MazeTier.hard: 1, MazeTier.extreme: 0};

  static int minSize(MazeTier t) => _minSize[t]!;
  static int maxSize(MazeTier t) => _maxSize[t]!;
  static int baseSeconds(MazeTier t) => _baseSec[t]!;

  static MemLevel of(MazeTier tier, int level) {
    final seed = 500009 + level * 7907 + tier.index * 130003;
    final size = _lerp(_minSize[tier]!, _maxSize[tier]!, level);
    // Bigger mazes within a tier get a little extra preview time.
    final preview = _baseSec[tier]! * 1000 + (size - _minSize[tier]!) * 250;
    return MemLevel(tier, level, size, preview, _peeks[tier]!, tier == MazeTier.extreme ? 3 : 0, seed);
  }
}

/// Memory Maze stars from wall bumps (mistakes) and peeks used. Each peek
/// counts as two mistakes, so any peek caps the result at 2 stars.
int memStars(int bumps, int peeksUsed) {
  final p = bumps + 2 * peeksUsed;
  return p <= 1 ? 3 : (p <= 4 ? 2 : 1);
}
