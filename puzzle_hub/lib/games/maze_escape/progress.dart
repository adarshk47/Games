import 'package:flutter/foundation.dart';

import '../../core/economy/level_gate.dart';
import '../../core/storage.dart';
import 'logic/levels.dart';

/// Storage helpers. Keys: `maze.lab.<tier>.stars.N` (Labyrinth),
/// `maze.mem.<tier>.stars.N` (Memory Maze), `maze.lastTier`,
/// `maze.mem.lastTier`, `maze.lastMode`.
class MazeProgress {
  MazeProgress._();

  /// Bumped on every save so level-select pages refresh.
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static String key(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) =>
      'maze.${mode.keyPrefix}.${t.name}.stars.$level';

  static int stars(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) =>
      Storage.getInt(key(t, level, mode: mode));

  /// Unlocked through progress: level 1, the level after a cleared one, a
  /// cleared level itself, or a level bought under the old one-time unlock.
  static bool unlocked(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) =>
      level <= 1 ||
      stars(t, level, mode: mode) > 0 ||
      stars(t, level - 1, mode: mode) > 0 ||
      isBought(t, level, mode: mode);

  static String _boughtKey(MazeTier t, int level, MazeMode mode) =>
      'maze.${mode.keyPrefix}.${t.name}.unlockedBought.$level';

  /// Legacy: levels unlocked permanently by the old "buy next level" offer.
  static bool isBought(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) =>
      Storage.getBool(_boughtKey(t, level, mode));

  /// [LevelGate] prefix, e.g. `maze.lab.easy`.
  static String gatePrefix(MazeTier t, {MazeMode mode = MazeMode.labyrinth}) => 'maze.${mode.keyPrefix}.${t.name}';

  /// Next unbeaten level in sequence: the furthest level that is free to open.
  static int freeUpTo(MazeTier t, {MazeMode mode = MazeMode.labyrinth}) {
    for (var l = 1; l <= kLevelCount; l++) {
      if (stars(t, l, mode: mode) == 0) return l;
    }
    return kLevelCount;
  }

  /// Plays left on a level skipped to with coins (0 for free levels).
  static int playsLeft(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) =>
      unlocked(t, level, mode: mode) ? 0 : LevelGate.playsLeft(gatePrefix(t, mode: mode), level);

  /// True when the level can be opened right now (free or bought plays left).
  static bool canPlay(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) =>
      unlocked(t, level, mode: mode) || LevelGate.canPlay(gatePrefix(t, mode: mode), freeUpTo(t, mode: mode), level);

  /// Counts one play of a bought level (no-op for free levels).
  static Future<void> onStart(MazeTier t, int level, {MazeMode mode = MazeMode.labyrinth}) async {
    final free = unlocked(t, level, mode: mode) ? level : freeUpTo(t, mode: mode);
    await LevelGate.onStart(gatePrefix(t, mode: mode), free, level);
    tick.value++;
  }

  static int totalStars(MazeTier t, {MazeMode mode = MazeMode.labyrinth}) {
    var s = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      s += stars(t, l, mode: mode);
    }
    return s;
  }

  static int completed(MazeTier t, {MazeMode mode = MazeMode.labyrinth}) {
    var n = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      if (stars(t, l, mode: mode) > 0) n++;
    }
    return n;
  }

  /// Stars over all tiers of a mode.
  static int modeStars(MazeMode mode) {
    var s = 0;
    for (final t in MazeTier.values) {
      s += totalStars(t, mode: mode);
    }
    return s;
  }

  static int modeMaxStars() => MazeTier.values.length * kLevelCount * 3;

  static void save(MazeTier t, int level, int stars, {MazeMode mode = MazeMode.labyrinth}) {
    if (stars > MazeProgress.stars(t, level, mode: mode)) Storage.setInt(key(t, level, mode: mode), stars);
    LevelGate.onCleared(gatePrefix(t, mode: mode), level);
    tick.value++;
  }

  static String _lastKey(MazeMode m) => m == MazeMode.labyrinth ? 'maze.lastTier' : 'maze.${m.keyPrefix}.lastTier';

  static MazeTier lastTierOf(MazeMode m) {
    final i = Storage.getInt(_lastKey(m));
    return MazeTier.values[i.clamp(0, MazeTier.values.length - 1)];
  }

  static void setLastTier(MazeMode m, MazeTier t) => Storage.setInt(_lastKey(m), t.index);

  static MazeTier get lastTier => lastTierOf(MazeMode.labyrinth);

  static set lastTier(MazeTier t) => setLastTier(MazeMode.labyrinth, t);

  static const _kMode = 'maze.lastMode';

  static MazeMode get lastMode {
    final i = Storage.getInt(_kMode);
    return MazeMode.values[i.clamp(0, MazeMode.values.length - 1)];
  }

  static set lastMode(MazeMode m) => Storage.setInt(_kMode, m.index);
}
