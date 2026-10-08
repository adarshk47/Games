import '../../core/economy/level_gate.dart';
import '../../core/storage.dart';
import 'logic/arrow_maze_logic.dart';

/// Persistent per-tier level progress (Storage keys `arrow_maze.<tier>.*`).
class ArrowMazeProgress {
  static String _k(MazeTier t, String s) => 'arrow_maze.${t.key}.$s';

  /// LevelGate prefix of a tier, e.g. `arrow_maze.easy`.
  static String gatePrefix(MazeTier t) => 'arrow_maze.${t.key}';

  static int stars(MazeTier t, int level) =>
      Storage.getInt(_k(t, 'stars.$level'));
  static bool isDone(MazeTier t, int level) => stars(t, level) > 0;

  /// Unlocked for good: in sequence, cleared, after a cleared level, or bought with
  /// the old one-off unlock (legacy key kept valid).
  static bool isUnlocked(MazeTier t, int level) =>
      level <= 1 ||
      isDone(t, level) ||
      isDone(t, level - 1) ||
      isBought(t, level);

  /// Legacy: levels unlocked early by the old unlock offer.
  static bool isBought(MazeTier t, int level) =>
      Storage.getBool(_k(t, 'unlockedBought.$level'));

  /// Highest level that is free in sequence (the next unbeaten one).
  static int freeUpTo(MazeTier t) => nextLevel(t);

  /// Plays left on a level skipped to with coins (0 when free / not bought).
  static int skipPlaysLeft(MazeTier t, int level) =>
      isUnlocked(t, level) ? 0 : LevelGate.playsLeft(gatePrefix(t), level);

  static bool canPlay(MazeTier t, int level) =>
      isUnlocked(t, level) || skipPlaysLeft(t, level) > 0;

  /// Counts one play of a bought level (free levels are unaffected).
  static Future<void> onStart(MazeTier t, int level) async {
    if (isUnlocked(t, level)) return;
    await LevelGate.onStart(gatePrefix(t), freeUpTo(t), level);
  }

  static int completed(MazeTier t) {
    var n = 0;
    for (var l = 1; l <= t.count; l++) {
      if (isDone(t, l)) n++;
    }
    return n;
  }

  /// The first level not yet completed (or the last one when all are done).
  static int nextLevel(MazeTier t) {
    for (var l = 1; l <= t.count; l++) {
      if (!isDone(t, l)) return l;
    }
    return t.count;
  }

  static Future<void> complete(MazeTier t, int level, int stars) async {
    if (stars > ArrowMazeProgress.stars(t, level)) {
      await Storage.setInt(_k(t, 'stars.$level'), stars);
    }
    if (level > Storage.getInt(_k(t, 'best'))) {
      await Storage.setInt(_k(t, 'best'), level);
    }
    await LevelGate.onCleared(gatePrefix(t), level);
  }

  static MazeTier? get lastTier {
    final i = Storage.getInt('arrow_maze.lastTier', -1);
    return i >= 0 && i < MazeTier.values.length ? MazeTier.values[i] : null;
  }

  static void setLastTier(MazeTier t) =>
      Storage.setInt('arrow_maze.lastTier', t.index);
}
