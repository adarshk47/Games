import '../../core/storage.dart';
import 'logic/flow_logic.dart';

class FlowProgress {
  static const _kLastTier = 'flow.lastTier';
  static String _done(FlowTier t) => 'flow.${t.id}.completed';
  static String _best(FlowTier t, int level) => 'flow.${t.id}.stars.$level';

  static FlowTier get lastTier => FlowTier.fromId(Storage.getString(_kLastTier));
  static Future<void> setLastTier(FlowTier t) => Storage.setString(_kLastTier, t.id);

  /// Highest completed level of the tier.
  static int completed(FlowTier t) => Storage.getInt(_done(t));
  static bool isUnlocked(FlowTier t, int level) => level <= completed(t) + 1;
  static bool isDone(FlowTier t, int level) => level <= completed(t);
  static int stars(FlowTier t, int level) => Storage.getInt(_best(t, level));
  static int totalStars(FlowTier t) {
    var s = 0;
    for (var l = 1; l <= FlowLevels.count; l++) {
      s += stars(t, l);
    }
    return s;
  }

  static Future<void> complete(FlowTier t, int level, int stars) async {
    if (level > completed(t)) await Storage.setInt(_done(t), level);
    if (stars > Storage.getInt(_best(t, level))) {
      await Storage.setInt(_best(t, level), stars);
    }
  }
}
