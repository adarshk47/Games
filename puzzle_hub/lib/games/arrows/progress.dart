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
  static bool isUnlocked(ArrowsTier t, int level) =>
      level <= completed(t) + 1 || isBought(t, level) || isDone(t, level - 1);
  static bool isDone(ArrowsTier t, int level) =>
      level >= 1 && (level <= completed(t) || stars(t, level) > 0);

  /// Levels unlocked early with coins / a rewarded ad.
  static String _bought(ArrowsTier t, int level) => 'arrows.${t.id}.unlockedBought.$level';
  static bool isBought(ArrowsTier t, int level) => Storage.getBool(_bought(t, level));
  static Future<void> buyUnlock(ArrowsTier t, int level) => Storage.setBool(_bought(t, level), true);

  /// The first locked level (the only one that can be bought), or null.
  static int? firstLocked(ArrowsTier t) {
    for (var l = 1; l <= ArrowsLevels.count; l++) {
      if (!isUnlocked(t, l)) return l;
    }
    return null;
  }
  static int stars(ArrowsTier t, int level) => Storage.getInt(_best(t, level));
  static int totalStars(ArrowsTier t) {
    var s = 0;
    for (var l = 1; l <= ArrowsLevels.count; l++) {
      s += stars(t, l);
    }
    return s;
  }

  static Future<void> complete(ArrowsTier t, int level, int stars) async {
    if (stars > Storage.getInt(_best(t, level))) {
      await Storage.setInt(_best(t, level), stars);
    }
    // 'completed' is the contiguous run of cleared levels; a bought level
    // cleared out of order does not mark the skipped one as done.
    var c = completed(t);
    if (level == c + 1) {
      c = level;
      while (c < ArrowsLevels.count && ArrowsProgress.stars(t, c + 1) > 0) {
        c++;
      }
      await Storage.setInt(_done(t), c);
    }
  }
}
