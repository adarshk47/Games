import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../account/account_service.dart';
import '../app_info.dart';
import '../cloud/cloud_auth.dart';
import '../cloud/cloud_service.dart';
import '../storage.dart';

/// Result of redeeming a coupon code.
enum CouponResult { ok, invalid, inactive, offline, signin, notForYou }

/// "No ads" coupons controlled from Firestore (see docs/COUPONS_GUIDE.md).
///
/// * `coupons/{CODE} = { active: true }` – a code anyone signed in can use.
///   Optional: `uids: [...]` and/or `emails: [...]` limit it to those players,
///   `expiresAt: <timestamp>` ends it, `noAds: false` disables it.
/// * Each use is logged in `coupons/{CODE}/redemptions/{USER_ID}` (name,
///   email, country, date, app version) so the developer sees who uses it.
/// * Revoking: `active: false` turns the code off for everyone; setting
///   `revoked: true` on (or deleting) one redemption turns it off for that
///   player. The app re-checks at start and whenever the Shop opens.
class CouponService {
  CouponService._();

  static const _kCode = 'coupon.code';
  static const _kActive = 'coupon.noads';

  /// Cached on-device state so it works offline; refreshed at startup.
  static final ValueNotifier<bool> noAds = ValueNotifier(false);

  static String? get code => Storage.getString(_kCode);

  static String normalize(String raw) =>
      raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

  static DocumentReference<Map<String, dynamic>> _doc(String c) =>
      FirebaseFirestore.instance.collection('coupons').doc(c);

  /// Call after login (per-account storage), at startup and when the Shop opens.
  static Future<void> refresh() async {
    noAds.value = Storage.getBool(_kActive);
    final c = code;
    if (c == null || c.isEmpty || !CloudService.available) return;
    final user = CloudAuth.I.user.value;
    try {
      final d = await _doc(c).get().timeout(const Duration(seconds: 10));
      var ok = d.exists && _valid(d.data()) && _allowed(d.data(), user?.uid, user?.email);
      if (ok && user != null) {
        final r = await _doc(c)
            .collection('redemptions')
            .doc(user.uid)
            .get()
            .timeout(const Duration(seconds: 10));
        ok = r.exists && r.data()?['revoked'] != true;
      }
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
    final user = CloudAuth.I.user.value;
    if (user == null) return CouponResult.signin;
    try {
      final d = await _doc(c).get().timeout(const Duration(seconds: 10));
      if (!d.exists) return CouponResult.invalid;
      if (!_valid(d.data())) return CouponResult.inactive;
      if (!_allowed(d.data(), user.uid, user.email)) return CouponResult.notForYou;
      final red = _doc(c).collection('redemptions').doc(user.uid);
      final old = await red.get().timeout(const Duration(seconds: 10));
      if (old.exists && old.data()?['revoked'] == true) return CouponResult.inactive;
      if (!old.exists) {
        final a = AccountService.I;
        await red.set({
          'uid': user.uid,
          'name': a.name,
          'email': user.email ?? '',
          'country': a.country ?? '',
          'version': AppInfo.version,
          'at': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 10));
      }
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

  /// A coupon with `uids` / `emails` lists only works for those players.
  @visibleForTesting
  static bool allowedFor(Map<String, dynamic>? d, String? uid, String? email) =>
      _allowed(d, uid, email);

  static bool _allowed(Map<String, dynamic>? d, String? uid, String? email) {
    if (d == null) return false;
    final uids = d['uids'];
    final emails = d['emails'];
    final hasList = (uids is List && uids.isNotEmpty) || (emails is List && emails.isNotEmpty);
    if (!hasList) return true;
    if (uid != null && uids is List && uids.contains(uid)) return true;
    final e = email?.trim().toLowerCase();
    if (e != null && e.isNotEmpty && emails is List) {
      return emails.any((x) => '$x'.trim().toLowerCase() == e);
    }
    return false;
  }
}
