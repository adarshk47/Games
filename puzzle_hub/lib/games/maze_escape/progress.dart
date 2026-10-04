import 'package:flutter/foundation.dart';

import '../../core/storage.dart';
import 'logic/levels.dart';

/// Storage helpers. Keys: `maze.lab.<tier>.stars.N`, `maze.lastTier`.
class MazeProgress {
  MazeProgress._();

  /// Bumped on every save so level-select pages refresh.
  static final ValueNotifier<int> tick = ValueNotifier<int>(0);

  static String key(MazeTier t, int level) => 'maze.lab.${t.name}.stars.$level';

  static int stars(MazeTier t, int level) => Storage.getInt(key(t, level));

  static bool unlocked(MazeTier t, int level) => level <= 1 || stars(t, level - 1) > 0;

  static int totalStars(MazeTier t) {
    var s = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      s += stars(t, l);
    }
    return s;
  }

  static int completed(MazeTier t) {
    var n = 0;
    for (var l = 1; l <= kLevelCount; l++) {
      if (stars(t, l) > 0) n++;
    }
    return n;
  }

  static void save(MazeTier t, int level, int stars) {
    if (stars > MazeProgress.stars(t, level)) Storage.setInt(key(t, level), stars);
    tick.value++;
  }

  static const _kLast = 'maze.lastTier';

  static MazeTier get lastTier {
    final i = Storage.getInt(_kLast);
    return MazeTier.values[i.clamp(0, MazeTier.values.length - 1)];
  }

  static set lastTier(MazeTier t) => Storage.setInt(_kLast, t.index);
}
