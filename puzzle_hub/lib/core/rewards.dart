import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'audio.dart';
import 'storage.dart';
import 'ui/palette.dart';

/// Coins + per-game records for the signed-in user. All data goes through
/// [Storage], so it is automatically per-account.
///
/// Games call:
///   Rewards.onLevelComplete('sudoku', 'easy', stars: 3);   // coins + record a win
///   Rewards.onGameEnd('focus_color', score: 120, won: true); // record only (+ small coins if won)
/// Ads can later call Rewards.addCoins(n, label: 'Ad reward').
class Rewards {
  Rewards._();

  /// Wire this to MaterialApp.navigatorKey so toasts can show above any screen.
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static final ValueNotifier<int> coins = ValueNotifier<int>(0);

  /// Call after login (and after lock/unlock) to load the user's balance.
  static void reload() => coins.value = Storage.getInt('coins');

  static Future<void> addCoins(int n, {String? label, bool playSound = true}) async {
    if (n <= 0) return;
    if (playSound) AppAudio.play(Sound.coin);
    final v = Storage.getInt('coins') + n;
    await Storage.setInt('coins', v);
    Storage.setInt('coins.earned', Storage.getInt('coins.earned') + n);
    coins.value = v;
    _toast('+$n 🪙${label == null ? '' : '  $label'}');
  }

  /// Returns false (and spends nothing) if the user cannot afford it.
  static Future<bool> spend(int n) async {
    final v = Storage.getInt('coins');
    if (n > v) return false;
    await Storage.setInt('coins', v - n);
    coins.value = v - n;
    return true;
  }

  /// A level / puzzle was completed. First completion of [levelKey] pays full
  /// coins (10 + 5 per star); replays pay 2. Also updates the game's record.
  /// Returns the coins awarded.
  static int onLevelComplete(String gameId, String levelKey, {int stars = 0, int? score}) {
    final done = 'rec.$gameId.done.$levelKey';
    final first = !Storage.getBool(done);
    if (first) Storage.setBool(done, true);
    final reward = first ? 10 + 5 * stars.clamp(0, 3) : 2;
    _record(gameId, won: true, score: score, level: first ? 1 : 0);
    AppAudio.play(Sound.win);
    addCoins(reward, label: first ? 'Level complete!' : null, playSound: false);
    return reward;
  }

  /// A run ended (score based games). Winning pays 5 coins.
  static void onGameEnd(String gameId, {int? score, bool won = false}) {
    _record(gameId, won: won, score: score);
    if (won) addCoins(5);
  }

  static void _record(String gameId, {required bool won, int? score, int level = 0}) {
    final p = 'rec.$gameId';
    Storage.setInt('$p.plays', Storage.getInt('$p.plays') + 1);
    if (won) Storage.setInt('$p.wins', Storage.getInt('$p.wins') + 1);
    if (level > 0) Storage.setInt('$p.levels', Storage.getInt('$p.levels') + 1);
    if (score != null) Storage.setBest('$p.best', score);
    Storage.setInt('$p.last', DateTime.now().millisecondsSinceEpoch ~/ 1000);
  }

  static int plays(String g) => Storage.getInt('rec.$g.plays');
  static int wins(String g) => Storage.getInt('rec.$g.wins');
  static int levels(String g) => Storage.getInt('rec.$g.levels');
  static int best(String g) => Storage.getInt('rec.$g.best');

  static OverlayEntry? _entry;

  static void _toast(String text) {
    final overlay = navKey.currentState?.overlay;
    if (overlay == null) return;
    _entry?.remove();
    final e = OverlayEntry(
      builder: (_) => Positioned(
        top: MediaQuery.of(overlay.context).padding.top + 70,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                gradient: Pal.accent(Pal.goldDeep),
                borderRadius: BorderRadius.circular(40),
                boxShadow: [BoxShadow(color: Pal.goldDeep.withValues(alpha: 0.6), blurRadius: 24)],
                border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
              ),
              child: Text(text,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 17, decoration: TextDecoration.none)),
            )
                .animate()
                .fadeIn(duration: 250.ms)
                .slideY(begin: -0.6, end: 0, curve: Curves.easeOutBack, duration: 450.ms)
                .then(delay: 1500.ms)
                .fadeOut(duration: 350.ms),
          ),
        ),
      ),
    );
    _entry = e;
    overlay.insert(e);
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (_entry == e) {
        e.remove();
        _entry = null;
      }
    });
  }
}

/// Small gold coin pill showing the live balance.
class CoinPill extends StatelessWidget {
  const CoinPill({super.key, this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pill = ValueListenableBuilder<int>(
      valueListenable: Rewards.coins,
      builder: (_, v, _) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.28),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Pal.gold.withValues(alpha: 0.7)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Text('🪙', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text('$v', style: const TextStyle(color: Pal.gold, fontWeight: FontWeight.w900, fontSize: 15)),
        ]),
      ),
    );
    return onTap == null ? pill : GestureDetector(onTap: onTap, child: pill);
  }
}
