import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import 'logic/hexa_sort_logic.dart';

/// Persisted progress, all under `hexa_sort.<tier>.*`.
class HsProgress {
  HsProgress._();

  static const lastTierKey = 'hexa_sort.tier';

  /// LevelGate prefix of a tier.
  static String prefix(HsTier t) => 'hexa_sort.${t.id}';

  static String key(HsTier t, String what) => '${prefix(t)}.$what';

  /// Highest level playable for free (next one in sequence).
  static int unlocked(HsTier t) => Storage.getInt(key(t, 'unlocked'), 1).clamp(1, kHsLevels);

  static int stars(HsTier t, int level) => Storage.getInt(key(t, 'stars.$level'));

  static bool isDone(HsTier t, int level) => stars(t, level) > 0;

  static int completed(HsTier t) => [for (var l = 1; l <= kHsLevels; l++) if (isDone(t, l)) l].length;

  /// Plays left on a bought (skipped) level.
  static int playsLeft(HsTier t, int level) => LevelGate.playsLeft(prefix(t), level);

  /// True when [level] may be opened (free, cleared before, or bought).
  static bool canPlay(HsTier t, int level) =>
      isDone(t, level) || LevelGate.canPlay(prefix(t), unlocked(t), level);

  /// Last played level of the tier.
  static int current(HsTier t) {
    final l = Storage.getInt(key(t, 'level'), 1).clamp(1, kHsLevels);
    return canPlay(t, l) ? l : unlocked(t);
  }

  static Future<void> setCurrent(HsTier t, int level) => Storage.setInt(key(t, 'level'), level);

  /// Counts one play of a bought level.
  static Future<void> onStart(HsTier t, int level) async {
    if (isDone(t, level)) return;
    await LevelGate.onStart(prefix(t), unlocked(t), level);
  }

  /// Saves a win. Clearing the next level in sequence advances the free
  /// level past any levels already cleared.
  static Future<void> complete(HsTier t, int level, int stars) async {
    if (stars > HsProgress.stars(t, level)) await Storage.setInt(key(t, 'stars.$level'), stars);
    await LevelGate.onCleared(prefix(t), level);
    var u = unlocked(t);
    if (level == u) {
      u = level + 1;
      while (u < kHsLevels && isDone(t, u)) {
        u++;
      }
      await Storage.setInt(key(t, 'unlocked'), u.clamp(1, kHsLevels));
    }
  }
}

String hsTierName(HsTier t) => tr('common.tier.${t.id}');
