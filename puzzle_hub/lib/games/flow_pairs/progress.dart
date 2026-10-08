import '../../core/economy/level_gate.dart';
import '../../core/storage.dart';
import 'logic/flow_logic.dart';

/// Persisted progress under `flow.<tier>.*`.
///
/// Levels are free in sequence: `completed` is the highest level cleared in
/// order, so `completed + 1` is the next unbeaten level (the free frontier).
/// Cleared levels stay open and so does the level right after a cleared one.
/// Any other level can be bought through [LevelGate] (plays stored under
/// `flow.<tier>.skip.<n>`).
class FlowProgress {
  static const _kLastTier = 'flow.lastTier';
  static String _done(FlowTier t) => 'flow.${t.id}.completed';
  static String _best(FlowTier t, int level) => 'flow.${t.id}.stars.$level';

  /// [LevelGate] prefix of a tier.
  static String gate(FlowTier t) => 'flow.${t.id}';

  static FlowTier get lastTier => FlowTier.fromId(Storage.getString(_kLastTier));
  static Future<void> setLastTier(FlowTier t) => Storage.setString(_kLastTier, t.id);

  /// Highest level of the tier cleared in sequence.
  static int completed(FlowTier t) => Storage.getInt(_done(t));

  /// Next level in sequence (free frontier).
  static int frontier(FlowTier t) => (completed(t) + 1).clamp(1, FlowLevels.count);

  static bool isDone(FlowTier t, int level) => level <= completed(t) || stars(t, level) > 0;

  /// Number of cleared levels (in sequence or skipped ahead).
  static int doneCount(FlowTier t) => [for (var l = 1; l <= FlowLevels.count; l++) if (isDone(t, l)) l].length;

  /// Open without paying.
  static bool isFree(FlowTier t, int level) =>
      level <= completed(t) + 1 || isDone(t, level) || (level > 1 && isDone(t, level - 1));

  /// The `freeUpTo` handed to [LevelGate] for [level].
  static int freeUpTo(FlowTier t, int level) {
    var l = level;
    while (l > 1 && !isFree(t, l)) {
      l--;
    }
    return l;
  }

  /// Plays left on a bought level (0 for free / not bought levels).
  static int playsLeft(FlowTier t, int level) => isFree(t, level) ? 0 : LevelGate.playsLeft(gate(t), level);

  static bool canPlay(FlowTier t, int level) => isFree(t, level) || playsLeft(t, level) > 0;

  /// Counts one play of a bought level (no-op for free levels).
  static Future<void> start(FlowTier t, int level) => LevelGate.onStart(gate(t), freeUpTo(t, level), level);

  static int stars(FlowTier t, int level) => Storage.getInt(_best(t, level));
  static int totalStars(FlowTier t) {
    var s = 0;
    for (var l = 1; l <= FlowLevels.count; l++) {
      s += stars(t, l);
    }
    return s;
  }

  static Future<void> complete(FlowTier t, int level, int earned) async {
    if (earned > Storage.getInt(_best(t, level))) {
      await Storage.setInt(_best(t, level), earned);
    }
    await LevelGate.onCleared(gate(t), level);
    var c = completed(t);
    if (level > c + 1) return;
    if (level == c + 1) c = level;
    // Skipped levels cleared earlier extend the sequence.
    while (c < FlowLevels.count && stars(t, c + 1) > 0) {
      c++;
    }
    if (c > completed(t)) await Storage.setInt(_done(t), c);
  }
}
