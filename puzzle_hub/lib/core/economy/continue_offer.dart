import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../ui/ui.dart';
import '../cheer.dart';

/// What the player is trying to get when out of free help.
enum OfferKind { hint, undo, extraLife, unlockLevel }

/// Default coin prices for the shared continue offer.
class Prices {
  Prices._();
  static const hint = 20;
  static const undo = 10;
  static const extraLife = 30;
  static const unlockLevel = 150;
  static const adFreePass = AdsService.adFreePrice;

  static int of(OfferKind k) => switch (k) {
    OfferKind.hint => hint,
    OfferKind.undo => undo,
    OfferKind.extraLife => extraLife,
    OfferKind.unlockLevel => unlockLevel,
  };
}

({String title, String emoji, String message}) _copy(OfferKind k) =>
    switch (k) {
      OfferKind.hint => (
        title: tr('offer.hint.title'),
        emoji: '💡',
        message: tr('offer.hint.msg'),
      ),
      OfferKind.undo => (
        title: tr('offer.undo.title'),
        emoji: '↩️',
        message: tr('offer.undo.msg'),
      ),
      OfferKind.extraLife => (
        title: tr('offer.life.title'),
        emoji: '❤️',
        message: tr('offer.life.msg'),
      ),
      OfferKind.unlockLevel => (
        title: tr('offer.unlock.title'),
        emoji: '🔓',
        message: tr('offer.unlock.msg'),
      ),
    };

/// Shared "Use N coins / Watch ad / Cancel" dialog used by every game.
/// Returns true if the player paid (coins or rewarded ad) and the game should
/// grant the item.
Future<bool> showContinueOffer(
  BuildContext context,
  OfferKind kind, {
  int? price,
}) async {
  final cost = price ?? Prices.of(kind);
  final r = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'offer',
    barrierColor: Colors.black.withValues(alpha: 0.6),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (_, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
    pageBuilder: (_, _, _) => _OfferDialog(kind: kind, price: cost),
  );
  // Declining an extra chance means the game is lost.
  if (r != true && kind == OfferKind.extraLife) Cheer.lose();
  return r ?? false;
}

class _OfferDialog extends StatefulWidget {
  const _OfferDialog({required this.kind, required this.price});
  final OfferKind kind;
  final int price;

  @override
  State<_OfferDialog> createState() => _OfferDialogState();
}

class _OfferDialogState extends State<_OfferDialog> {
  bool _busy = false;
  String? _error;

  Future<void> _useCoins() async {
    setState(() => _busy = true);
    final ok = await Rewards.spend(widget.price, reason: widget.kind.name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = tr('offer.not_enough');
      });
    }
  }

  Future<void> _watchAd() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await AdsService.showRewarded(reason: widget.kind.name);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _busy = false;
        _error = tr('shop.no_ad');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _copy(widget.kind);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Material(
          color: Colors.transparent,
          child: GlassCard(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            radius: 32,
            glow: Pal.gold,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF2A1F63).withValues(alpha: 0.96),
                const Color(0xFF140E38).withValues(alpha: 0.96),
              ],
            ),
            // Scrolls on short screens (e.g. 320x480) instead of overflowing.
            child: SingleChildScrollView(
              child: ValueListenableBuilder<int>(
                valueListenable: Rewards.coins,
                builder: (_, bal, _) {
                  final canAfford = bal >= widget.price;
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 50)),
                      const SizedBox(height: 8),
                      Text(
                        c.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Pal.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Pal.textDim,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${tr('offer.balance')} ',
                            style: const TextStyle(
                              color: Pal.textDim,
                              fontSize: 14,
                            ),
                          ),
                          const Text('🪙', style: TextStyle(fontSize: 15)),
                          const SizedBox(width: 4),
                          Text(
                            '$bal',
                            style: const TextStyle(
                              color: Pal.gold,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: Center(
                          child: PremiumButton(
                            label: tr('offer.use_coins', {
                              'coins': widget.price,
                            }),
                            icon: Icons.monetization_on_rounded,
                            onTap: _busy || !canAfford ? null : _useCoins,
                          ),
                        ),
                      ),
                      if (AdsService.featuresOn) ...[
                        const SizedBox(height: 10),
                        PremiumButton(
                          label: _busy
                              ? tr('offer.loading')
                              : tr('offer.watch_ad'),
                          icon: Icons.ondemand_video_rounded,
                          color: const Color(0xFF4DA8FF),
                          onTap: _busy ? null : _watchAd,
                        ),
                      ],
                      if (_error != null || !canAfford) ...[
                        const SizedBox(height: 10),
                        Text(
                          _error ??
                              tr('offer.need_more', {'n': widget.price - bal}),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Pal.danger,
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: Text(
                          tr('common.cancel'),
                          style: const TextStyle(
                            color: Pal.textDim,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
