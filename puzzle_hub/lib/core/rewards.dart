import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'ads/ads_service.dart';
import 'audio.dart';
import 'i18n/i18n.dart';
import 'storage.dart';
import 'ui/palette.dart';

/// Coins + per-game records for the signed-in user. All data goes through
/// [Storage], so it is automatically per-account.
///
/// Games call:
///   Rewards.onLevelComplete('sudoku', 'easy', stars: 3);   // coins + record a win
///   Rewards.onGameEnd('focus_color', score: 120, won: true); // record only (+ small coins if won)
/// Ads call Rewards.addCoins(n, label: 'Ad reward').
///
/// Broadcast to listeners (daily quests, achievements, leaderboard, referral).
class RewardEvent {
  const RewardEvent({required this.gameId, required this.type, this.levelKey, this.stars = 0, this.score, this.won = false, this.firstTime = false});
  final String gameId;

  /// 'level' (onLevelComplete) or 'run' (onGameEnd).
  final String type;
  final String? levelKey;
  final int stars;
  final int? score;
  final bool won;
  final bool firstTime;
}

class Rewards {
  Rewards._();

  static final StreamController<RewardEvent> _events = StreamController<RewardEvent>.broadcast();

  /// Every completed level / finished run, after records and coins are updated.
  static Stream<RewardEvent> get events => _events.stream;

  /// Wire this to MaterialApp.navigatorKey so toasts can show above any screen.
  static final GlobalKey<NavigatorState> navKey = GlobalKey<NavigatorState>();

  static final ValueNotifier<int> coins = ValueNotifier<int>(0);

  // ---- Coin ledger ----------------------------------------------------------
  // 'coins'        current balance (kept for backwards compatibility)
  // 'coins.earned' monotonic total ever earned
  // 'coins.spent'  monotonic total ever spent
  // Invariant: coins == coins.earned - coins.spent. Both totals only grow, so a
  // cloud merge can simply take the max of each and recompute the balance.
  static const kBalance = 'coins';
  static const kEarned = 'coins.earned';
  static const kSpent = 'coins.spent';

  /// Reward amounts (kept low so coins feel earned).
  static const firstClearBase = 3;
  static const firstClearPerStar = 1;
  static const replayReward = 1;
  static const runWinReward = 2;

  static int get earned => Storage.getInt(kEarned);
  static int get spent => Storage.getInt(kSpent);
  static int get balance => Storage.getInt(kBalance);

  /// Call after login (and after lock/unlock) to load the user's balance.
  /// Also repairs / migrates the ledger so balance == earned - spent.
  static void reload() {
    _normalizeLedger();
    coins.value = Storage.getInt(kBalance);
  }

  static void _normalizeLedger() {
    final bal = Storage.getInt(kBalance).clamp(0, 1 << 31);
    final sp = Storage.getInt(kSpent).clamp(0, 1 << 31);
    final storedEarned = Storage.getInt(kEarned, -1);
    // Missing earned (old installs) -> derive it; otherwise never shrink it.
    final e = storedEarned < 0 ? bal + sp : (storedEarned > bal + sp ? storedEarned : bal + sp);
    _writeLedger(e, e - bal);
  }

  static void _writeLedger(int earnedTotal, int spentTotal) {
    Storage.setInt(kEarned, earnedTotal);
    Storage.setInt(kSpent, spentTotal);
    Storage.setInt(kBalance, earnedTotal - spentTotal);
  }

  /// Merge totals coming from another device / the cloud: takes the max of
  /// each monotonic counter and recomputes the balance.
  static void mergeLedger({required int earned, required int spent}) {
    _normalizeLedger();
    final e = earned > Rewards.earned ? earned : Rewards.earned;
    var s = spent > Rewards.spent ? spent : Rewards.spent;
    if (s > e) s = e;
    _writeLedger(e, s);
    coins.value = e - s;
  }

  static Future<void> addCoins(int n, {String? label, bool playSound = true}) async {
    if (n <= 0) return;
    if (playSound) AppAudio.play(Sound.coin);
    _normalizeLedger();
    final e = earned + n;
    final s = spent;
    _writeLedger(e, s);
    coins.value = e - s;
    _toast('+$n 🪙${label == null ? '' : '  $label'}');
  }

  /// Returns false (and spends nothing) if the user cannot afford it.
  static Future<bool> spend(int n) async {
    if (n < 0) return false;
    _normalizeLedger();
    final e = earned;
    final s = spent;
    if (n > e - s) return false;
    if (n == 0) return true;
    _writeLedger(e, s + n);
    coins.value = e - s - n;
    return true;
  }

  /// Coins paid for a level completion (pure, for UI / tests).
  static int levelReward({required bool firstTime, int stars = 0}) =>
      firstTime ? firstClearBase + firstClearPerStar * stars.clamp(0, 3) : replayReward;

  /// A level / puzzle was completed. First completion of [levelKey] pays
  /// 3 + 1 per star; replays pay 1. Also updates the game's record.
  /// Returns the coins awarded.
  static int onLevelComplete(String gameId, String levelKey, {int stars = 0, int? score}) {
    final done = 'rec.$gameId.done.$levelKey';
    final first = !Storage.getBool(done);
    if (first) Storage.setBool(done, true);
    final reward = levelReward(firstTime: first, stars: stars);
    _record(gameId, won: true, score: score, level: first ? 1 : 0);
    AppAudio.play(Sound.win);
    addCoins(reward, label: first ? tr('common.level_complete') : null, playSound: false);
    _events.add(RewardEvent(gameId: gameId, type: 'level', levelKey: levelKey, stars: stars, score: score, won: true, firstTime: first));
    try {
      AdsService.onLevelCompleted(gameId: gameId);
    } catch (_) {}
    return reward;
  }

  /// A run ended (score based games). Winning pays 2 coins.
  static void onGameEnd(String gameId, {int? score, bool won = false}) {
    _record(gameId, won: won, score: score);
    if (won) addCoins(runWinReward);
    _events.add(RewardEvent(gameId: gameId, type: 'run', score: score, won: won));
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
