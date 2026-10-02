import 'package:flutter/foundation.dart';

import '../../core/storage.dart';
import 'logic/levels.dart';

enum MazeMode { labyrinth, fork }

/// Storage helpers. Keys: `maze.<lab|fork>.<tier>.stars.N`, `maze.lastTier`.
class MazeProgress {
  MazeProgress._();

  /// Bumped on every save so level-select pages refresh.
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static String _p(MazeMode m) => m == MazeMode.labyrinth ? 'lab' : 'fork';
  static String key(MazeMode m, MazeTier t, int level) => 'maze.${_p(m)}.${t.name}.stars.$level';

  static int stars(MazeMode m, MazeTier t, int level) => Storage.getInt(key(m, t, level));

  static bool unlocked(MazeMode m, MazeTier t, int level) => level <= 1 || stars(m, t, level - 1) > 0;

  static int totalStars(MazeMode m, MazeTier t) {
    var s = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      s += stars(m, t, l);
    }
    return s;
  }

  static int completed(MazeMode m, MazeTier t) {
    var n = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      if (stars(m, t, l) > 0) n++;
    }
    return n;
  }

  static void save(MazeMode m, MazeTier t, int level, int stars) {
    if (stars > MazeProgress.stars(m, t, level)) Storage.setInt(key(m, t, level), stars);
    tick.value++;
  }

  static const _kLast = 'maze.lastTier';

  static MazeTier get lastTier {
    final i = Storage.getInt(_kLast);
    return MazeTier.values[i.clamp(0, MazeTier.values.length - 1)];
  }

  static set lastTier(MazeTier t) => Storage.setInt(_kLast, t.index);
}
