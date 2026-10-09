import 'dart:async';

import 'package:flutter/material.dart';

import '../ads/ads_service.dart';
import '../economy/continue_offer.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../ui/ui.dart';
import '../economy/coin_history_screen.dart';
import '../ads/coupon_service.dart';

/// Coin shop body. Shown as a tab inside the home's bottom navigation (the
/// animated background is already behind it), so no Scaffold / back button.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  Timer? _tick;
  bool _busy = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    AdsService.changes.addListener(_refresh);
    _syncTimer();
  }

  @override
  void dispose() {
    AdsService.changes.removeListener(_refresh);
    _tick?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    _syncTimer();
    setState(() {});
  }

  /// Ticks once a second only while the ad-free countdown is visible.
  void _syncTimer() {
    if (AdsService.adFree) {
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!AdsService.adFree) {
          _tick?.cancel();
          _tick = null;
        }
        setState(() {});
      });
    } else {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> _watchAd() async {
    setState(() {
      _busy = true;
      _msg = null;
    });
    final got = await AdsService.watchAdForCoins();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _msg = got > 0 ? null : tr('shop.no_ad');
    });
  }

  Future<void> _buyPass([AdFreePlan plan = AdFreePlan.day]) async {
    final ok = await AdsService.buyAdFree(plan);
    if (!mounted) return;
    setState(() => _msg = ok ? null : tr('shop.not_enough_pass'));
    _syncTimer();
  }

  static String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ValueListenableBuilder<int>(
        valueListenable: Rewards.coins,
        builder: (_, bal, _) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _header(bal),
            const SizedBox(height: 18),
            // Ad features stay hidden until ads are switched on (features.dart).
            if (AdsService.featuresOn) ...[
              _adCard(),
              const SizedBox(height: 14),
              _passCard(bal),
            ],
            if (_msg != null) ...[
              const SizedBox(height: 10),
              Text(
                _msg!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Pal.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            _pricesCard(),
            const SizedBox(height: 14),
            _historyCard(),
            const SizedBox(height: 14),
            const _CouponCard(),
          ],
        ),
      ),
    );
  }

  Widget _header(int bal) => Row(
    children: [
      Text(
        tr('shop.title'),
        style: const TextStyle(
          color: Pal.text,
          fontSize: 30,
          fontWeight: FontWeight.w900,
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: Pal.accent(Pal.goldDeep),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Pal.goldDeep.withValues(alpha: 0.45),
              blurRadius: 18,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🪙', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              '$bal',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _iconBadge(String emoji, Color c) => Container(
    width: 52,
    height: 52,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      gradient: Pal.accent(c),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(emoji, style: const TextStyle(fontSize: 26)),
  );

  Widget _title(String t, String sub) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        t,
        style: const TextStyle(
          color: Pal.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 3),
      Text(sub, style: const TextStyle(color: Pal.textDim, fontSize: 13)),
    ],
  );

  Widget _adCard() {
    final left = AdsService.rewardedRemainingToday;
    final wait = AdsService.rewardedCooldownLeft;
    const blue = Color(0xFF4DA8FF);
    return GlassCard(
      glow: blue,
      child: Row(
        children: [
          _iconBadge('🎬', blue),
          const SizedBox(width: 14),
          Expanded(
            child: _title(
              tr('shop.watch_ad_title', {'coins': AdsService.rewardedCoins}),
              left <= 0
                  ? tr('shop.come_back')
                  : wait > Duration.zero
                  ? tr('shop.ad_wait', {'time': _fmt(wait)})
                  : tr('shop.ads_left', {
                      'left': left,
                      'cap': AdsService.dailyRewardedCap,
                    }),
            ),
          ),
          PremiumButton(
            label: _busy ? '…' : tr('shop.watch'),
            compact: true,
            color: blue,
            onTap: _busy || left <= 0 || wait > Duration.zero ? null : _watchAd,
          ),
        ],
      ),
    );
  }

  Widget _passCard(int bal) {
    final active = AdsService.adFree;
    const green = Color(0xFF2EE6A8);
    return GlassCard(
      glow: active ? Pal.success : Pal.gold,
      child: Column(
        children: [
          Row(
            children: [
              _iconBadge('🚫', active ? green : Pal.goldDeep),
              const SizedBox(width: 14),
              Expanded(
                child: _title(
                  tr('shop.pass_title'),
                  active
                      ? tr('shop.pass_active', {
                          'time': _fmt(AdsService.adFreeRemaining),
                        })
                      : tr('shop.pass_price', {
                          'coins': AdsService.adFreePrice,
                        }),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final plan in AdFreePlan.values)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${tr('shop.pass_${plan.name}')}  •  ${plan.price} 🪙',
                      style: const TextStyle(
                        color: Pal.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  PremiumButton(
                    key: ValueKey('buy_pass_${plan.name}'),
                    label: active ? tr('shop.extend') : tr('shop.buy'),
                    compact: true,
                    color: active ? green : null,
                    onTap: bal >= plan.price ? () => _buyPass(plan) : null,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _priceRow(String emoji, String label, int price) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Pal.text, fontSize: 15),
          ),
        ),
        Text(
          '$price 🪙',
          style: const TextStyle(
            color: Pal.gold,
            fontWeight: FontWeight.w800,
            fontSize: 15,
          ),
        ),
      ],
    ),
  );

  Widget _pricesCard() => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('shop.spend_title'),
          style: const TextStyle(
            color: Pal.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr('shop.spend_sub'),
          style: const TextStyle(color: Pal.textDim, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _priceRow('💡', tr('common.hint'), Prices.hint),
        _priceRow('↩️', tr('common.undo'), Prices.undo),
        _priceRow('❤️', tr('shop.extra_life'), Prices.extraLife),
        _priceRow('🔓', tr('shop.unlock_level'), Prices.unlockLevel),
      ],
    ),
  );

  Widget _stat(String label, int v, Color c) => Expanded(
    child: Column(
      children: [
        Text(
          '$v',
          style: TextStyle(color: c, fontSize: 22, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Pal.textDim, fontSize: 12)),
      ],
    ),
  );

  Widget _historyCard() => GlassCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('shop.history'),
          style: const TextStyle(
            color: Pal.text,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _stat(tr('shop.earned'), Rewards.earned, Pal.success),
            _stat(tr('shop.spent'), Rewards.spent, Pal.danger),
            _stat(tr('shop.balance'), Rewards.balance, Pal.gold),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          tr('shop.earn_tip'),
          style: const TextStyle(color: Pal.textDim, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Center(
          child: PremiumButton(
            key: const ValueKey('coin_history_btn'),
            label: tr('shop.history.open'),
            icon: Icons.receipt_long_rounded,
            compact: true,
            color: const Color(0xFF6F63B8),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CoinHistoryScreen()),
            ),
          ),
        ),
      ],
    ),
  );
}

/// "Have a coupon?" – redeems a no-ads coupon created in Firestore.
class _CouponCard extends StatefulWidget {
  const _CouponCard();

  @override
  State<_CouponCard> createState() => _CouponCardState();
}

class _CouponCardState extends State<_CouponCard> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _msg;
  bool _good = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => _busy = true);
    final r = await CouponService.redeem(_ctrl.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _good = r == CouponResult.ok;
      _msg = tr('shop.coupon.${r.name == 'ok' ? 'ok' : r.name}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: CouponService.noAds,
      builder: (_, active, _) => GlassCard(
        key: const ValueKey('coupon_card'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('shop.coupon.title'),
              style: const TextStyle(
                color: Pal.text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            if (active)
              Text(
                tr('shop.coupon.active'),
                style: const TextStyle(
                  color: Pal.success,
                  fontWeight: FontWeight.w800,
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      textCapitalization: TextCapitalization.characters,
                      style: const TextStyle(
                        color: Pal.text,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                      decoration: InputDecoration(
                        hintText: tr('shop.coupon.hint'),
                        hintStyle: const TextStyle(color: Pal.textDim),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  PremiumButton(
                    label: _busy ? '…' : tr('shop.coupon.apply'),
                    compact: true,
                    onTap: _busy ? null : _apply,
                  ),
                ],
              ),
            if (_msg != null && !active) ...[
              const SizedBox(height: 8),
              Text(
                _msg!,
                style: TextStyle(
                  color: _good ? Pal.success : Pal.danger,
                  fontSize: 13,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
