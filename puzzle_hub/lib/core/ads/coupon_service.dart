import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../cloud/cloud_service.dart';
import '../storage.dart';

/// Result of redeeming a coupon code.
enum CouponResult { ok, invalid, inactive, offline }

/// "No ads" coupons controlled from Firestore.
///
/// The developer creates documents in the `coupons` collection, for example
/// `coupons/IDEAL2026 = { active: true, noAds: true }`. A player who redeems the
/// code never sees ads. Setting `active: false` (or deleting the document)
/// brings ads back for everyone who used it the next time the app starts.
/// Codes can only be read one by one (rules forbid listing), never written.
class CouponService {
  CouponService._();

  static const _kCode = 'coupon.code';
  static const _kActive = 'coupon.noads';

  /// Cached on-device state so it works offline; refreshed at startup.
  static final ValueNotifier<bool> noAds = ValueNotifier(false);

  static String? get code => Storage.getString(_kCode);

  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// Call after login (per-account storage) and at startup.
  static Future<void> refresh() async {
    noAds.value = Storage.getBool(_kActive);
    final c = code;
    if (c == null || c.isEmpty || !CloudService.available) return;
    try {
      final d = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(c)
          .get()
          .timeout(const Duration(seconds: 10));
      final ok = d.exists && _valid(d.data());
      await Storage.setBool(_kActive, ok);
      noAds.value = ok;
    } catch (e) {
      debugPrint('coupon refresh failed: $e'); // keep the cached state offline
    }
  }

  static Future<CouponResult> redeem(String raw) async {
    final c = normalize(raw);
    if (c.length < 4 || c.length > 40 || c.contains('/')) {
      return CouponResult.invalid;
    }
    if (!CloudService.available) return CouponResult.offline;
    try {
      final d = await FirebaseFirestore.instance
          .collection('coupons')
          .doc(c)
          .get()
          .timeout(const Duration(seconds: 10));
      if (!d.exists) return CouponResult.invalid;
      if (!_valid(d.data())) return CouponResult.inactive;
      await Storage.setString(_kCode, c);
      await Storage.setBool(_kActive, true);
      noAds.value = true;
      return CouponResult.ok;
    } catch (e) {
      debugPrint('coupon redeem failed: $e');
      return CouponResult.offline;
    }
  }

  static bool _valid(Map<String, dynamic>? d) {
    if (d == null || d['active'] != true) return false;
    if (d.containsKey('noAds') && d['noAds'] != true) return false;
    final exp = d['expiresAt'];
    if (exp is Timestamp && exp.toDate().isBefore(DateTime.now())) return false;
    return true;
  }
}
