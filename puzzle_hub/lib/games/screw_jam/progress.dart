import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import 'logic/screw_jam_logic.dart';

/// Persisted progress, all under `screw_jam.<tier>.*`.
class SjProgress {
  SjProgress._();

  static const lastTierKey = 'screw_jam.tier';

  static String key(SjTier t, String what) => 'screw_jam.${t.id}.$what';

  /// Highest playable level (1..kSjLevels).
  static int unlocked(SjTier t) => Storage.getInt(key(t, 'unlocked'), 1).clamp(1, kSjLevels);

  static int stars(SjTier t, int level) => Storage.getInt(key(t, 'stars.$level'));

  static bool isDone(SjTier t, int level) => stars(t, level) > 0;

  static int completed(SjTier t) => [for (var l = 1; l <= kSjLevels; l++) if (isDone(t, l)) l].length;

  /// Last played level of the tier.
  static int current(SjTier t) => Storage.getInt(key(t, 'level'), 1).clamp(1, unlocked(t));

  static Future<void> setCurrent(SjTier t, int level) => Storage.setInt(key(t, 'level'), level);

  static Future<void> complete(SjTier t, int level, int stars) async {
    if (stars > SjProgress.stars(t, level)) await Storage.setInt(key(t, 'stars.$level'), stars);
    final next = (level + 1).clamp(1, kSjLevels);
    if (Storage.getInt(key(t, 'unlocked'), 1) < next) await Storage.setInt(key(t, 'unlocked'), next);
  }

  /// Bought unlock of [level] (must be the first locked one).
  static Future<void> buyUnlock(SjTier t, int level) async {
    if (Storage.getInt(key(t, 'unlocked'), 1) < level) await Storage.setInt(key(t, 'unlocked'), level);
  }
}

String sjTierName(SjTier t) => tr('common.tier.${t.id}');
