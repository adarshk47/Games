import 'package:flutter/material.dart';

import '../i18n/i18n.dart';
import '../ui/ui.dart';
import 'iap_service.dart';

/// "Remove ads" plans paid through Google Play, with the Diwali sale price
/// (regular price struck through) until [IapService.saleEnds].
class PremiumCard extends StatefulWidget {
  const PremiumCard({super.key});

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  final _iap = IapService.I;

  @override
  void initState() {
    super.initState();
    _iap.products.addListener(_refresh);
    _iap.granted.addListener(_onGranted);
    _iap.error.addListener(_onError);
    _iap.start();
  }

  @override
  void dispose() {
    _iap.products.removeListener(_refresh);
    _iap.granted.removeListener(_onGranted);
    _iap.error.removeListener(_onError);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onGranted() {
    if (!mounted) return;
    setState(() {});
    showPremiumDialog(
      context,
      title: tr('iap.thanks'),
      message: tr('iap.thanks_text'),
      emoji: '💎',
      actions: [DialogAction(tr('common.ok'), () {}, primary: true)],
    );
  }

  void _onError() {
    final e = _iap.error.value;
    if (!mounted || e == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(tr('iap.failed'))));
  }

  String _label(IapPlan p) => tr('iap.plan.${p.name}');

  Widget _row(IapPlan p) {
    final d = _iap.products.value[p.id];
    // Play shows d.price in the player's own currency ($, €, ₹ …); the
    // struck-through regular price is only known in rupees.
    // Sales: the regular price is known in rupees only (struck through for
    // Indian Play accounts); the New Year sale also shows the real discount.
    final inr = d?.currencyCode == 'INR';
    final regular = (IapService.diwaliSale || IapService.newYearSale) && inr ? '₹${p.regularRupees}' : null;
    final raw = d?.rawPrice;
    final off = IapService.newYearSale && inr && raw != null && raw < p.regularRupees
        ? ((1 - raw / p.regularRupees) * 100).round()
        : null;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_label(p), style: const TextStyle(color: Pal.text, fontWeight: FontWeight.w800, fontSize: 15)),
            Row(children: [
              if (regular != null) ...[
                Text(regular,
                    style: const TextStyle(color: Pal.textDim, fontSize: 13, decoration: TextDecoration.lineThrough, decorationThickness: 2)),
                const SizedBox(width: 6),
              ],
              Text(d?.price ?? '…', style: const TextStyle(color: Pal.gold, fontSize: 16, fontWeight: FontWeight.w900)),
              if (off != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(6)),
                  child: Text('-$off%', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
          ]),
        ),
        PremiumButton(
          key: ValueKey('iap_${p.name}'),
          label: tr('iap.buy'),
          compact: true,
          onTap: d == null || (p == IapPlan.lifetime && IapService.lifetime) ? null : () => _iap.buy(p),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = IapService.active;
    final until = IapService.until;
    return GlassCard(
      glow: Pal.gold,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('💎', style: TextStyle(fontSize: 30)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('iap.title'), style: const TextStyle(color: Pal.text, fontSize: 17, fontWeight: FontWeight.w900)),
              Text(
                active
                    ? (IapService.lifetime
                        ? tr('iap.active_forever')
                        : tr('iap.active_until', {'date': '${until!.day}/${until.month}/${until.year}'}))
                    : tr('iap.subtitle'),
                style: TextStyle(color: active ? const Color(0xFF2EE6A8) : Pal.textDim, fontSize: 12.5),
              ),
            ]),
          ),
        ]),
        if (IapService.saleOn) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF9F1C), Color(0xFFE53935)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              IapService.newYearSale ? tr('iap.sale_newyear', {'date': '5/1'}) : tr('iap.sale', {'date': '17/11'}),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ),
        ],
        if (!_iap.available)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(tr('iap.unavailable'), style: const TextStyle(color: Pal.textDim, fontSize: 12)),
          )
        else
          for (final p in IapPlan.values) _row(p),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('iap_restore'),
            onPressed: _iap.available ? _iap.restore : null,
            child: Text(tr('iap.restore'), style: const TextStyle(color: Pal.gold, fontSize: 12)),
          ),
        ),
      ]),
    );
  }
}
