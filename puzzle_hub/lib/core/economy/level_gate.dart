import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import '../ui/ui.dart';

/// Level-skip rules shared by every level-based game:
///  * Playing levels one by one is always free.
///  * Jumping ahead to a locked level costs [pricePerGap] coins for every level
///    skipped beyond the furthest free level ([skipPrice]).
///  * A bought level can be played [maxPlays] times. Clearing it unlocks it for
///    good; if all plays are used without clearing it, it locks again.
///
/// Storage keys live under the game's own progress prefix, e.g.
/// `arrow_maze.easy` -> `arrow_maze.easy.skip.50` = plays left.
class LevelGate {
  LevelGate._();

  static const int pricePerGap = 100;
  static const int maxPlays = 10;

  /// [freeUpTo] = highest level the player may open for free (the next level
  /// in sequence). Returns 0 when [level] is already free.
  static int skipPrice(int freeUpTo, int level) => level <= freeUpTo ? 0 : (level - freeUpTo) * pricePerGap;

  static String _key(String prefix, int level) => '$prefix.skip.$level';

  /// Plays left on a bought (skipped) level; 0 when none were bought.
  static int playsLeft(String prefix, int level) => Storage.getInt(_key(prefix, level));

  /// True when [level] may be opened: free in sequence, or bought with plays left.
  static bool canPlay(String prefix, int freeUpTo, int level) =>
      level <= freeUpTo || playsLeft(prefix, level) > 0;

  /// Call when a bought level is started (each play / replay counts once).
  /// Free levels are unaffected.
  static Future<void> onStart(String prefix, int freeUpTo, int level) async {
    if (level <= freeUpTo) return;
    final left = playsLeft(prefix, level);
    if (left > 0) await Storage.setInt(_key(prefix, level), left - 1);
  }

  /// Call when [level] is cleared: a bought level stops counting plays (the
  /// game's own progress now treats it as unlocked).
  static Future<void> onCleared(String prefix, int level) => Storage.remove(_key(prefix, level));

  /// Shows the price dialog and, if the player confirms and can afford it,
  /// spends the coins and grants [maxPlays] plays. Returns true when bought.
  static Future<bool> buy(BuildContext context, {required String prefix, required int freeUpTo, required int level}) async {
    final price = skipPrice(freeUpTo, level);
    if (price == 0) return true;
    final gap = level - freeUpTo;
    var confirmed = false;
    await showPremiumDialog(
      context,
      emoji: '🔓',
      title: tr('common.skip.title', {'n': level}),
      message: tr('common.skip.body', {'from': freeUpTo, 'gap': gap, 'price': price, 'plays': maxPlays}),
      color: Pal.gold,
      dismissible: true,
      actions: [
        DialogAction(tr('common.cancel'), () {}),
        DialogAction(tr('common.skip.buy', {'price': price}), () => confirmed = true, primary: true),
      ],
    );
    if (!confirmed) return false;
    final bought = await Rewards.spend(price);
    if (bought) {
      await Storage.setInt(_key(prefix, level), maxPlays);
    } else if (context.mounted) {
      await showPremiumDialog(
        context,
        emoji: '🪙',
        title: tr('common.skip.not_enough_title'),
        message: tr('common.skip.not_enough', {'price': price}),
        dismissible: true,
        actions: [DialogAction(tr('common.ok'), () {})],
      );
    }
    return bought;
  }
}
