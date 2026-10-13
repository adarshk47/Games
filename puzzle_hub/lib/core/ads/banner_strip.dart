import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_service.dart';

/// A standard 320×50 banner for menu screens (never on top of gameplay).
/// Takes no space until an ad has loaded, and none for ad-free players.
class BannerStrip extends StatefulWidget {
  const BannerStrip({super.key});

  /// Height reserved while a banner is showing (screens pad by this).
  static const height = 54.0;

  /// True while a banner is on screen.
  static final ValueNotifier<bool> showing = ValueNotifier<bool>(false);

  @override
  State<BannerStrip> createState() => _BannerStripState();
}

class _BannerStripState extends State<BannerStrip> {
  BannerAd? _ad;
  bool _loaded = false;

  bool get _wanted => AdsService.available && !AdsService.adFree;

  @override
  void initState() {
    super.initState();
    AdsService.changes.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    AdsService.changes.removeListener(_sync);
    _ad?.dispose();
    BannerStrip.showing.value = false;
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    if (!_wanted) {
      _ad?.dispose();
      _ad = null;
      if (_loaded) setState(() => _loaded = false);
      BannerStrip.showing.value = false;
      return;
    }
    if (_ad != null) return;
    try {
      _ad = BannerAd(
        adUnitId: AdIds.banner,
        size: AdSize.banner,
        request: const AdRequest(),
        listener: BannerAdListener(
          onAdLoaded: (_) {
            if (!mounted) return;
            setState(() => _loaded = true);
            BannerStrip.showing.value = true;
          },
          onAdFailedToLoad: (ad, e) {
            debugPrint('banner load failed: ${e.message}');
            ad.dispose();
            if (identical(_ad, ad)) _ad = null;
            if (mounted) setState(() => _loaded = false);
            BannerStrip.showing.value = false;
          },
        ),
      )..load();
    } catch (e) {
      _ad = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null || !_wanted) return const SizedBox.shrink();
    return SizedBox(
      height: BannerStrip.height,
      child: Center(
        child: SizedBox(
          width: ad.size.width.toDouble(),
          height: ad.size.height.toDouble(),
          child: AdWidget(ad: ad),
        ),
      ),
    );
  }
}
