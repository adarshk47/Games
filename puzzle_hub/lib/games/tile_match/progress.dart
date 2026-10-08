import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import 'logic/tile_match_logic.dart';

/// Persisted progress, all under `tile_match.<tier>.*`.
class TmProgress {
  TmProgress._();

  static const lastTierKey = 'tile_match.tier';

  /// Storage prefix of a tier (also the [LevelGate] prefix).
  static String prefix(TmTier t) => 'tile_match.${t.id}';

  static String key(TmTier t, String what) => '${prefix(t)}.$what';

  /// Highest level that is free to open (the next one in sequence).
  static int unlocked(TmTier t) => Storage.getInt(key(t, 'unlocked'), 1).clamp(1, kTmLevels);

  static int stars(TmTier t, int level) => Storage.getInt(key(t, 'stars.$level'));

  static bool isDone(TmTier t, int level) => stars(t, level) > 0;

  static int completed(TmTier t) => [for (var l = 1; l <= kTmLevels; l++) if (isDone(t, l)) l].length;

  /// True when [level] can be opened (free, cleared or bought with plays left).
  static bool canPlay(TmTier t, int level) => LevelGate.canPlay(prefix(t), unlocked(t), level);

  static int playsLeft(TmTier t, int level) => level <= unlocked(t) ? 0 : LevelGate.playsLeft(prefix(t), level);

  /// Last played level of the tier (falls back to the free level when it
  /// can no longer be opened).
  static int current(TmTier t) {
    final l = Storage.getInt(key(t, 'level'), 1).clamp(1, kTmLevels);
    return canPlay(t, l) ? l : unlocked(t);
  }

  static Future<void> setCurrent(TmTier t, int level) => Storage.setInt(key(t, 'level'), level);

  static Future<void> complete(TmTier t, int level, int stars) async {
    if (stars > TmProgress.stars(t, level)) await Storage.setInt(key(t, 'stars.$level'), stars);
    final next = (level + 1).clamp(1, kTmLevels);
    if (Storage.getInt(key(t, 'unlocked'), 1) < next) await Storage.setInt(key(t, 'unlocked'), next);
    await LevelGate.onCleared(prefix(t), level);
  }
}

String tmTierName(TmTier t) => tr('common.tier.${t.id}');
