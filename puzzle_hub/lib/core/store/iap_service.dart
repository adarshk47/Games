import 'dart:async';

import '../release_stage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../account/account_service.dart';
import '../app_info.dart';
import '../cloud/cloud_auth.dart';
import '../cloud/cloud_service.dart';
import '../storage.dart';

/// Ad-free plans sold through Google Play Billing. Create these one-time
/// products in Play Console (Monetize → Products → One-time products) with
/// exactly these ids. 1 month / 1 year are consumable (can be bought again
/// to extend), lifetime is bought once.
enum IapPlan {
  month('adfree_1m', Duration(days: 30), 49),
  year('adfree_1y', Duration(days: 365), 399),
  lifetime('adfree_lifetime', null, 499);

  const IapPlan(this.id, this.duration, this.regularRupees);
  final String id;

  /// Null = forever.
  final Duration? duration;

  /// Normal price shown struck through during a sale.
  final int regularRupees;

  static IapPlan? byId(String id) {
    for (final p in values) {
      if (p.id == id) return p;
    }
    return null;
  }
}

/// Google Play purchases: loads the products, buys, grants ad-free time and
/// restores lifetime purchases. The grant is stored in per-user storage, so
/// it also syncs to the player's cloud account.
class IapService {
  IapService._();
  static final IapService I = IapService._();

  /// Diwali sale: struck-through regular prices are shown until this moment
  /// (end of 17 Nov 2026, India time). Change the Play prices back after it.
  static final saleEnds = DateTime.utc(2026, 11, 17, 18, 30);

  /// New Year sale (2.7.0 only), 20 Dec 2026 – 5 Jan 2027 (IST). Set the Play
  /// prices to ₹19 / ₹199 / ₹299 for these dates in Play Console; the app
  /// shows the regular price struck through and each plan's real discount.
  static final newYearStarts = DateTime.utc(2026, 12, 19, 18, 30);
  static final newYearEnds = DateTime.utc(2027, 1, 5, 18, 30);

  static bool get diwaliSale => DateTime.now().toUtc().isBefore(saleEnds);
  static bool get newYearSale {
    final now = DateTime.now().toUtc();
    return kStage >= 3 && now.isAfter(newYearStarts) && now.isBefore(newYearEnds);
  }

  static bool get saleOn => diwaliSale || newYearSale;

  static const _kUntil = 'iap.adfree.until';
  static const _kLifetime = 'iap.adfree.lifetime';

  /// Products loaded from Play (empty until loaded / when unavailable).
  final ValueNotifier<Map<String, ProductDetails>> products = ValueNotifier(const {});

  /// Fires after a purchase is granted (UI shows a thank-you).
  final ValueNotifier<int> granted = ValueNotifier(0);

  /// Last purchase error to show, if any.
  final ValueNotifier<String?> error = ValueNotifier(null);

  StreamSubscription<List<PurchaseDetails>>? _sub;
  bool _available = false;
  bool get available => _available;

  /// Ad-free bought with real money is active.
  static bool get active {
    try {
      if (Storage.getBool(_kLifetime)) return true;
      final ms = Storage.getInt(_kUntil);
      return ms > 0 && DateTime.fromMillisecondsSinceEpoch(ms).isAfter(DateTime.now());
    } catch (_) {
      return false;
    }
  }

  static bool get lifetime => Storage.getBool(_kLifetime);

  static DateTime? get until {
    final ms = Storage.getInt(_kUntil);
    return ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Refunds: after refunding an order in Play Console the developer creates
  /// Firestore `iap_revoked/{uid}` (uid from the purchases log). The app then
  /// removes this player's paid ad-free time, and ads come back.
  static const _kRevokedAt = 'iap.revoked.at';

  Future<void> checkRevoked() async {
    final u = CloudAuth.I.user.value;
    if (!CloudService.available || u == null) return;
    try {
      final d = await FirebaseFirestore.instance.collection('iap_revoked').doc(u.uid).get().timeout(const Duration(seconds: 10));
      if (!d.exists) return;
      final at = d.data()?['at'];
      final ms = at is Timestamp ? at.millisecondsSinceEpoch : 1;
      // Handle each revoke once, so the player can buy again afterwards.
      if (Storage.getInt(_kRevokedAt) >= ms) return;
      await Storage.setInt(_kRevokedAt, ms);
      await Storage.setInt(_kUntil, 0);
      await Storage.setBool(_kLifetime, false);
    } catch (e) {
      debugPrint('iap revoke check: $e');
    }
  }

  Future<void> start() async {
    unawaited(checkRevoked());
    if (kIsWeb) return;
    try {
      _available = await InAppPurchase.instance.isAvailable();
    } catch (e) {
      debugPrint('iap unavailable: $e');
      _available = false;
    }
    if (!_available) return;
    _sub ??= InAppPurchase.instance.purchaseStream.listen(_onPurchases, onError: (Object e) => debugPrint('iap stream: $e'));
    await loadProducts();
    await checkLifetimeOwned();
  }

  /// Refunded lifetime purchase: Google Play no longer lists it as owned, so
  /// ads come back by themselves. Only acts on a successful answer from Play
  /// (offline / errors never remove ad-free). Monthly / yearly packs are
  /// consumed when bought, so Play cannot report their refunds to the app:
  /// those are handled with `iap_revoked/{uid}` ([checkRevoked]).
  Future<void> checkLifetimeOwned() async {
    if (!_available || !lifetime || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final addition = InAppPurchase.instance.getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final r = await addition.queryPastPurchases().timeout(const Duration(seconds: 15));
      if (r.error != null) return;
      final owned = r.pastPurchases.any((p) => p.productID == IapPlan.lifetime.id && p.status != PurchaseStatus.error);
      if (!owned) {
        await Storage.setBool(_kLifetime, false);
        granted.value++;
      }
    } catch (e) {
      debugPrint('iap lifetime check: $e');
    }
  }

  Future<void> loadProducts() async {
    if (!_available) return;
    try {
      final r = await InAppPurchase.instance.queryProductDetails({for (final p in IapPlan.values) p.id});
      products.value = {for (final d in r.productDetails) d.id: d};
      if (r.notFoundIDs.isNotEmpty) debugPrint('iap products not found: ${r.notFoundIDs}');
    } catch (e) {
      debugPrint('iap products: $e');
    }
  }

  /// Starts Google Play's purchase sheet. Returns false if it could not open.
  Future<bool> buy(IapPlan plan) async {
    final d = products.value[plan.id];
    if (!_available || d == null) return false;
    error.value = null;
    final param = PurchaseParam(productDetails: d);
    try {
      return plan == IapPlan.lifetime
          ? await InAppPurchase.instance.buyNonConsumable(purchaseParam: param)
          : await InAppPurchase.instance.buyConsumable(purchaseParam: param, autoConsume: true);
    } catch (e) {
      debugPrint('iap buy: $e');
      return false;
    }
  }

  /// Brings back a lifetime purchase on a new phone / after reinstalling.
  Future<void> restore() async {
    if (!_available) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('iap restore: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final p in list) {
      switch (p.status) {
        case PurchaseStatus.purchased:
          await _grant(p);
          unawaited(_log(p));
        case PurchaseStatus.restored:
          await _grant(p);
        case PurchaseStatus.error:
          error.value = p.error?.message;
        case PurchaseStatus.canceled:
        case PurchaseStatus.pending:
          break;
      }
      if (p.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(p);
        } catch (e) {
          debugPrint('iap complete: $e');
        }
      }
    }
  }

  Future<void> _grant(PurchaseDetails p) async {
    final plan = IapPlan.byId(p.productID);
    if (plan == null) return;
    // Each purchase is granted once (restores repeat old purchases).
    final key = 'iap.done.${p.purchaseID ?? p.verificationData.serverVerificationData.hashCode}';
    if (Storage.getBool(key)) return;
    await Storage.setBool(key, true);
    if (plan.duration == null) {
      await Storage.setBool(_kLifetime, true);
    } else {
      final now = DateTime.now();
      final cur = until;
      final base = cur != null && cur.isAfter(now) ? cur : now;
      await Storage.setInt(_kUntil, base.add(plan.duration!).millisecondsSinceEpoch);
    }
    granted.value++;
  }

  /// Writes `purchases/{orderId}` so the developer can see in Firebase who
  /// bought what (Play Console only shows order ids). Needs a signed-in
  /// player; never throws.
  Future<void> _log(PurchaseDetails p) async {
    final u = CloudAuth.I.user.value;
    if (!CloudService.available || u == null) return;
    final d = products.value[p.productID];
    final order = p.purchaseID ?? 'p${DateTime.now().millisecondsSinceEpoch}';
    try {
      await FirebaseFirestore.instance.collection('purchases').doc(order.replaceAll('/', '_')).set({
        'uid': u.uid,
        'email': u.email ?? '',
        'name': AccountService.I.name,
        'country': AccountService.I.country ?? '',
        'product': p.productID,
        'price': d?.price ?? '',
        'amount': d?.rawPrice ?? 0,
        'currency': d?.currencyCode ?? '',
        'orderId': p.purchaseID ?? '',
        'token': p.verificationData.serverVerificationData,
        'sale': saleOn,
        'appVersion': AppInfo.version,
        'at': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 15));
    } catch (e) {
      debugPrint('purchase log: $e');
    }
  }

  @visibleForTesting
  Future<void> debugGrant(PurchaseDetails p) => _grant(p);
}
