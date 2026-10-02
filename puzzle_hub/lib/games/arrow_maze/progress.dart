import '../../core/storage.dart';
import 'logic/arrow_maze_logic.dart';

/// Persistent per-tier level progress (Storage keys `arrow_maze.<tier>.*`).
class ArrowMazeProgress {
  static String _k(MazeTier t, String s) => 'arrow_maze.${t.key}.$s';

  static int stars(MazeTier t, int level) =>
      Storage.getInt(_k(t, 'stars.$level'));
  static bool isDone(MazeTier t, int level) => stars(t, level) > 0;
  static bool isUnlocked(MazeTier t, int level) =>
      level <= 1 || isDone(t, level - 1);

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

  static void complete(MazeTier t, int level, int stars) {
    if (stars > ArrowMazeProgress.stars(t, level)) {
      Storage.setInt(_k(t, 'stars.$level'), stars);
    }
    if (level > Storage.getInt(_k(t, 'best'))) {
      Storage.setInt(_k(t, 'best'), level);
    }
  }

  static MazeTier? get lastTier {
    final i = Storage.getInt('arrow_maze.lastTier', -1);
    return i >= 0 && i < MazeTier.values.length ? MazeTier.values[i] : null;
  }

  static void setLastTier(MazeTier t) =>
      Storage.setInt('arrow_maze.lastTier', t.index);
}
