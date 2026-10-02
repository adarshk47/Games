import '../../core/storage.dart';
import 'logic/arrows_logic.dart';

class ArrowsProgress {
  static const _kLastTier = 'arrows.lastTier';
  static String _done(ArrowsTier t) => 'arrows.${t.id}.completed';
  static String _best(ArrowsTier t, int level) => 'arrows.${t.id}.stars.$level';

  static ArrowsTier get lastTier => ArrowsTier.fromId(Storage.getString(_kLastTier));
  static Future<void> setLastTier(ArrowsTier t) => Storage.setString(_kLastTier, t.id);

  /// Highest completed level of the tier.
  static int completed(ArrowsTier t) => Storage.getInt(_done(t));
  static bool isUnlocked(ArrowsTier t, int level) => level <= completed(t) + 1;
  static bool isDone(ArrowsTier t, int level) => level <= completed(t);
  static int stars(ArrowsTier t, int level) => Storage.getInt(_best(t, level));
  static int totalStars(ArrowsTier t) {
    var s = 0;
    for (var l = 1; l <= ArrowsLevels.count; l++) {
      s += stars(t, l);
    }
    return s;
  }

  static Future<void> complete(ArrowsTier t, int level, int stars) async {
    if (level > completed(t)) await Storage.setInt(_done(t), level);
    if (stars > Storage.getInt(_best(t, level))) {
      await Storage.setInt(_best(t, level), stars);
    }
  }
}
