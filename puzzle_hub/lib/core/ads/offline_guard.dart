import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import '../ui/ui.dart';
import 'ads_service.dart';

/// Offline play limit (keeps ads fair):
/// * after [limit] of play without internet the app asks to turn it on;
/// * switching internet off again right away does not reset the count (it is
///   only cleared after [resetAfterOnline] online);
/// * the only other way on: [coinPrice] coins or [adsNeeded] ads (watched while
///   online) for [allowance] more offline minutes;
/// * when the internet comes back after the limit, a full-screen ad shows first;
/// * ad-free players (pass / approved grant / coupon) can play offline freely.
class OfflineGuard {
  OfflineGuard._();

  static const limit = Duration(minutes: 5);
  static const resetAfterOnline = Duration(minutes: 2);
  static const allowance = Duration(minutes: 5);
  static const coinPrice = 100;
  static const adsNeeded = 2;

  static const _kOffline = 'offline.secs';
  static const _kAllowUntil = 'offline.allow_until';

  /// True while the "turn on internet" screen must cover the app.
  static final ValueNotifier<bool> blocked = ValueNotifier(false);

  static bool online = true;
  static int _onlineSecs = 0;
  static bool _adDue = false;

  @visibleForTesting
  static DateTime Function() clock = DateTime.now;

  @visibleForTesting
  static void debugReset() {
    online = true;
    _onlineSecs = 0;
    _adDue = false;
    blocked.value = false;
  }

  static int get offlineSecs => Storage.getInt(_kOffline);

  static bool get allowanceActive =>
      Storage.getInt(_kAllowUntil) > clock().millisecondsSinceEpoch;

  /// Called once per second while the app is in the foreground.
  static void tick() {
    try {
      if (AdsService.adFree) {
        blocked.value = false;
        return;
      }
      if (online) {
        blocked.value = false;
        _onlineSecs++;
        if (_adDue) {
          _adDue = false;
          AdsService.onLevelCompleted(); // back online: full-screen ad first
        }
        if (_onlineSecs >= resetAfterOnline.inSeconds && offlineSecs > 0) {
          Storage.setInt(_kOffline, 0);
        }
        return;
      }
      _onlineSecs = 0;
      final secs = offlineSecs + 1;
      Storage.setInt(_kOffline, secs);
      final over = secs >= limit.inSeconds && !allowanceActive;
      if (over) _adDue = true;
      blocked.value = over;
    } catch (_) {
      // Storage not ready (very early) – try again next second.
    }
  }

  static void _grant() {
    Storage.setInt(_kAllowUntil, clock().add(allowance).millisecondsSinceEpoch);
    blocked.value = false;
  }

  static Future<bool> buyWithCoins() async {
    if (!await Rewards.spend(coinPrice, reason: 'offline')) return false;
    _grant();
    return true;
  }

  /// Needs internet (the ads must load); [onProgress] gets 1..[adsNeeded].
  static Future<bool> buyWithAds({void Function(int)? onProgress}) async {
    for (var k = 0; k < adsNeeded; k++) {
      if (!await AdsService.showRewarded(reason: 'offline')) return false;
      onProgress?.call(k + 1);
    }
    _grant();
    return true;
  }
}

/// Wraps the app: watches connectivity, ticks [OfflineGuard] and shows the
/// "turn on internet" screen on top when needed.
class OfflineGate extends StatefulWidget {
  const OfflineGate({super.key, required this.child});
  final Widget child;

  @override
  State<OfflineGate> createState() => _OfflineGateState();
}

class _OfflineGateState extends State<OfflineGate> {
  Timer? _timer;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  static bool _isOnline(List<ConnectivityResult> r) =>
      r.any((c) => c != ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    try {
      Connectivity()
          .checkConnectivity()
          .then((r) => OfflineGuard.online = _isOnline(r))
          .catchError((_) => true);
      _sub = Connectivity().onConnectivityChanged.listen(
        (r) => OfflineGuard.online = _isOnline(r),
        onError: (_) {},
      );
    } catch (_) {
      // No plugin (tests / desktop): treat as online.
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final s = WidgetsBinding.instance.lifecycleState;
      if (s == null || s == AppLifecycleState.resumed) OfflineGuard.tick();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      widget.child,
      ValueListenableBuilder<bool>(
        valueListenable: OfflineGuard.blocked,
        builder: (_, blocked, _) =>
            blocked ? const _OfflineWall() : const SizedBox.shrink(),
      ),
    ],
  );
}

class _OfflineWall extends StatefulWidget {
  const _OfflineWall();

  @override
  State<_OfflineWall> createState() => _OfflineWallState();
}

class _OfflineWallState extends State<_OfflineWall> {
  bool _busy = false;
  String? _msg;

  Future<void> _coins() async {
    setState(() => _busy = true);
    final ok = await OfflineGuard.buyWithCoins();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = ok ? null : tr('offer.not_enough');
    });
  }

  Future<void> _ads() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final ok = await OfflineGuard.buyWithAds(
      onProgress: (n) => mounted
          ? setState(
              () => _msg = tr('undo.progress', {
                'done': n,
                'n': OfflineGuard.adsNeeded,
              }),
            )
          : null,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = ok ? null : tr('offline.ads_need_net');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        key: const ValueKey('offline_wall'),
        color: Colors.black.withValues(alpha: 0.82),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: GlassCard(
                glow: Pal.gold,
                padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('📶', style: TextStyle(fontSize: 52)),
                    const SizedBox(height: 8),
                    Text(
                      tr('offline.title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Pal.text,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr('offline.msg'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Pal.textDim, fontSize: 14),
                    ),
                    const SizedBox(height: 18),
                    PremiumButton(
                      key: const ValueKey('offline_coins'),
                      label: tr('offline.coins', {
                        'coins': OfflineGuard.coinPrice,
                      }),
                      icon: Icons.monetization_on_rounded,
                      onTap: _busy ? null : _coins,
                    ),
                    if (AdsService.featuresOn) ...[
                      const SizedBox(height: 10),
                      PremiumButton(
                        key: const ValueKey('offline_ads'),
                        label: tr('offline.ads', {'n': OfflineGuard.adsNeeded}),
                        icon: Icons.ondemand_video_rounded,
                        color: const Color(0xFF4DA8FF),
                        onTap: _busy ? null : _ads,
                      ),
                    ],
                    if (_msg != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _msg!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Pal.gold, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
