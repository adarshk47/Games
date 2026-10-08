import '../../core/economy/level_gate.dart';
import '../../core/i18n/i18n.dart';
import '../../core/storage.dart';
import 'logic/screw_jam_logic.dart';

/// Persisted progress, all under `screw_jam.<tier>.*`.
///
/// Levels are free in sequence: `unlocked` is the next unbeaten level (the
/// free frontier), every cleared level stays open and so does the level right
/// after a cleared one. Any other level can be bought through [LevelGate]
/// (plays stored under `screw_jam.<tier>.skip.<n>`).
class SjProgress {
  SjProgress._();

  static const lastTierKey = 'screw_jam.tier';

  static String key(SjTier t, String what) => 'screw_jam.${t.id}.$what';

  /// [LevelGate] prefix of a tier.
  static String gate(SjTier t) => 'screw_jam.${t.id}';

  /// Next level in sequence (free frontier, 1..kSjLevels).
  static int unlocked(SjTier t) => Storage.getInt(key(t, 'unlocked'), 1).clamp(1, kSjLevels);

  static int stars(SjTier t, int level) => Storage.getInt(key(t, 'stars.$level'));

  static bool isDone(SjTier t, int level) => stars(t, level) > 0;

  static int completed(SjTier t) => [for (var l = 1; l <= kSjLevels; l++) if (isDone(t, l)) l].length;

  /// Open without paying: up to the frontier, cleared levels and the level
  /// after a cleared one.
  static bool isFree(SjTier t, int level) =>
      level <= unlocked(t) || isDone(t, level) || (level > 1 && isDone(t, level - 1));

  /// The `freeUpTo` handed to [LevelGate] for [level]: [level] itself when it
  /// is free, else the closest free level below it.
  static int freeUpTo(SjTier t, int level) {
    var l = level;
    while (l > 1 && !isFree(t, l)) {
      l--;
    }
    return l;
  }

  /// Plays left on a bought level (0 for free / not bought levels).
  static int playsLeft(SjTier t, int level) => isFree(t, level) ? 0 : LevelGate.playsLeft(gate(t), level);

  static bool canPlay(SjTier t, int level) => isFree(t, level) || playsLeft(t, level) > 0;

  /// Counts one play of a bought level (no-op for free levels).
  static Future<void> start(SjTier t, int level) => LevelGate.onStart(gate(t), freeUpTo(t, level), level);

  /// Last played level of the tier (falls back to the frontier when it is
  /// not playable any more).
  static int current(SjTier t) {
    final l = Storage.getInt(key(t, 'level'), 1).clamp(1, kSjLevels);
    return canPlay(t, l) ? l : unlocked(t);
  }

  static Future<void> setCurrent(SjTier t, int level) => Storage.setInt(key(t, 'level'), level);

  static Future<void> complete(SjTier t, int level, int stars) async {
    if (stars > SjProgress.stars(t, level)) await Storage.setInt(key(t, 'stars.$level'), stars);
    await LevelGate.onCleared(gate(t), level);
    var u = Storage.getInt(key(t, 'unlocked'), 1);
    if (level < u) return;
    if (level == u) u++;
    // Skipped levels cleared earlier extend the free run.
    while (u < kSjLevels && isDone(t, u)) {
      u++;
    }
    final next = u.clamp(1, kSjLevels);
    if (Storage.getInt(key(t, 'unlocked'), 1) < next) await Storage.setInt(key(t, 'unlocked'), next);
  }
}

String sjTierName(SjTier t) => tr('common.tier.${t.id}');
