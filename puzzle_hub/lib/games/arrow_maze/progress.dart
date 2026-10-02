import '../../core/storage.dart';
import 'logic/arrow_maze_logic.dart';

/// Persistent level progress (Storage keys `arrow_maze.*`).
class ArrowMazeProgress {
  static int stars(int level) => Storage.getInt('arrow_maze.stars.$level');
  static bool isDone(int level) => stars(level) > 0;
  static bool isUnlocked(int level) => level <= 1 || isDone(level - 1);

  static int get completed {
    var n = 0;
    for (var l = 1; l <= ArrowMazeLevels.count; l++) {
      if (isDone(l)) n++;
    }
    return n;
  }

  static void complete(int level, int stars) {
    if (stars > ArrowMazeProgress.stars(level)) {
      Storage.setInt('arrow_maze.stars.$level', stars);
    }
    if (level > Storage.getInt('arrow_maze.best')) {
      Storage.setInt('arrow_maze.best', level);
    }
  }
}
