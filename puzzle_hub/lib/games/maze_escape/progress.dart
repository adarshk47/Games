import 'package:flutter/foundation.dart';

import '../../core/storage.dart';
import 'logic/levels.dart';

enum MazeMode { labyrinth, fork }

/// Storage helpers. Keys: `maze.lab.stars.N`, `maze.fork.stars.N`.
class MazeProgress {
  MazeProgress._();

  /// Bumped on every save so level-select pages refresh.
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static String _p(MazeMode m) => m == MazeMode.labyrinth ? 'lab' : 'fork';
  static String key(MazeMode m, int level) => 'maze.${_p(m)}.stars.$level';

  static int stars(MazeMode m, int level) => Storage.getInt(key(m, level));

  static bool unlocked(MazeMode m, int level) => level <= 1 || stars(m, level - 1) > 0;

  static int totalStars(MazeMode m) {
    var t = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      t += stars(m, l);
    }
    return t;
  }

  static int completed(MazeMode m) {
    var t = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      if (stars(m, l) > 0) t++;
    }
    return t;
  }

  static void save(MazeMode m, int level, int stars) {
    if (stars > MazeProgress.stars(m, level)) Storage.setInt(key(m, level), stars);
    tick.value++;
  }
}
