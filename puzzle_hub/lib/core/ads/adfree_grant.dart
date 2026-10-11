import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../account/account_service.dart';
import '../app_info.dart';
import '../cloud/cloud_auth.dart';
import '../cloud/cloud_service.dart';
import '../storage.dart';

/// Ad-free periods a player can ask the developer for.
enum AdFreeRequestPlan {
  m1('1 month', 30),
  m3('3 months', 91),
  m6('6 months', 182),
  y1('1 year', 365),
  y5('5 years', 1826);

  const AdFreeRequestPlan(this.english, this.days);
  final String english;
  final int days;
}

/// "Remove ads completely" by developer approval.
///
/// The player sends a request email (name, user id, plan, date and time). The
/// developer approves it by creating, in the Firebase console,
/// `adfree_grants/{USER_ID} = { until: <timestamp>, plan: "3 months" }`.
/// Until that time the app shows no ads. Deleting the document or moving
/// `until` into the past brings ads back at the next app start.
class AdFreeGrant {
  AdFreeGrant._();

  static const supportEmail = 'aiforsmart@gmail.com';
  static const _kUntil = 'adfree.grant.until';
  static const _kReqAt = 'adfree.request.at';
  static const _kReqPlan = 'adfree.request.plan';

  /// Approved ad-free end time (cached so it also works offline).
  static final ValueNotifier<DateTime?> until = ValueNotifier(null);

  static bool get active {
    final u = until.value;
    return u != null && u.isAfter(DateTime.now());
  }

  static DateTime? get requestedAt {
    final ms = Storage.getInt(_kReqAt);
    return ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static AdFreeRequestPlan? get requestedPlan {
    final n = Storage.getString(_kReqPlan);
    for (final p in AdFreeRequestPlan.values) {
      if (p.name == n) return p;
    }
    return null;
  }

  static void _loadCache() {
    final ms = Storage.getInt(_kUntil);
    until.value = ms <= 0 ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// Startup / after login: read this player's grant from Firestore.
  static Future<void> refresh() async {
    _loadCache();
    final uid = CloudService.available ? CloudAuth.I.user.value?.uid : null;
    if (uid == null) return;
    try {
      final d = await FirebaseFirestore.instance
          .collection('adfree_grants')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));
      final t = d.data()?['until'];
      final u = t is Timestamp ? t.toDate() : null;
      await Storage.setInt(_kUntil, u?.millisecondsSinceEpoch ?? 0);
      until.value = u;
    } catch (e) {
      debugPrint(
        'ad-free grant refresh failed: $e',
      ); // keep cached value offline
    }
  }

  /// Opens an email to the developer with everything needed to approve.
  /// Returns false when the player is not signed in (the user id is needed).
  static Future<bool> sendRequest(AdFreeRequestPlan plan) async {
    final user = CloudService.available ? CloudAuth.I.user.value : null;
    if (user == null) return false;
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final when =
        '${two(now.day)}-${two(now.month)}-${now.year} ${two(now.hour)}:${two(now.minute)}';
    final a = AccountService.I;
    final body =
        '''Hello,

I would like to remove all ads in ${AppInfo.name}.

Requested period: ${plan.english}
Request date & time: $when
Name: ${a.name}
User ID: ${user.uid}
Email: ${user.email ?? '-'}
Country: ${a.country ?? '-'}
App version: ${AppInfo.version}

(Developer: approve by creating adfree_grants/${user.uid} with field "until" in Firestore.)''';
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      query:
          'subject=${Uri.encodeComponent('${AppInfo.name} – Ad-free request (${plan.english})')}'
          '&body=${Uri.encodeComponent(body)}',
    );
    await Storage.setInt(_kReqAt, now.millisecondsSinceEpoch);
    await Storage.setString(_kReqPlan, plan.name);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('mailto failed: $e');
    }
    return true;
  }
}
