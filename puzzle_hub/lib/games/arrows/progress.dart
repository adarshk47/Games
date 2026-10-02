import '../../core/storage.dart';

class ArrowsProgress {
  static const _kCompleted = 'arrows.completed'; // highest completed level
  static String _best(int level) => 'arrows.stars.$level';

  static int get completed => Storage.getInt(_kCompleted);
  static bool isUnlocked(int level) => level <= completed + 1;
  static bool isDone(int level) => level <= completed;
  static int stars(int level) => Storage.getInt(_best(level));

  static Future<void> complete(int level, int stars) async {
    if (level > completed) await Storage.setInt(_kCompleted, level);
    if (stars > Storage.getInt(_best(level))) {
      await Storage.setInt(_best(level), stars);
    }
  }
}
