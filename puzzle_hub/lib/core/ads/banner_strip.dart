import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';

import 'admob_ads.dart';

import 'ads_service.dart';

/// A standard 320×50 Unity banner for menu screens (never on top of
/// gameplay). Takes (almost) no space until an ad has loaded, and none for
/// ad-free players.
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
  bool _loaded = false;
  bool _failed = false;
  BannerAd? _admob;

  bool get _wanted => AdsService.available && !AdsService.adFree;

  @override
  void initState() {
    super.initState();
    AdsService.changes.addListener(_sync);
  }

  @override
  void dispose() {
    AdsService.changes.removeListener(_sync);
    _admob?.dispose();
    BannerStrip.showing.value = false;
    super.dispose();
  }

  void _sync() {
    if (!mounted) return;
    if (!_wanted) BannerStrip.showing.value = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!_wanted || _failed) return const SizedBox.shrink();
    if (AdsService.usingAdmob) return _admobBanner();
    // The platform view must be laid out to load; it stays 1 px tall until
    // an ad is ready.
    return SizedBox(
      height: _loaded ? BannerStrip.height : 1,
      child: Center(
        child: UnityBannerAd(
          placementId: AdIds.banner,
          onLoad: (_) {
            if (!mounted) return;
            setState(() => _loaded = true);
            BannerStrip.showing.value = true;
          },
          onFailed: (_, e, m) {
            debugPrint('banner load failed: $e $m');
            if (mounted) {
              setState(() {
                _loaded = false;
                _failed = true;
              });
            }
            BannerStrip.showing.value = false;
          },
        ),
      ),
    );
  }

  Widget _admobBanner() {
    _admob ??= BannerAd(
      adUnitId: AdmobIds.banner,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) return;
          setState(() => _loaded = true);
          BannerStrip.showing.value = true;
        },
        onAdFailedToLoad: (ad, e) {
          debugPrint('admob banner failed: ${e.message}');
          ad.dispose();
          _admob = null;
          if (mounted) setState(() => _failed = true);
          BannerStrip.showing.value = false;
        },
      ),
    )..load();
    final ad = _admob!;
    if (!_loaded) return const SizedBox.shrink();
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
