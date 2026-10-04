import 'dart:async';
import 'dart:io' show Platform;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:play_install_referrer/play_install_referrer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../account/account_service.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import 'cloud_auth.dart';
import 'cloud_service.dart';
import 'sync_service.dart';

/// Invite friends: the share link carries `referrer=ref_<uid>`; Google Play
/// hands it to the new install via the Install Referrer API.
///
/// When the invitee (logged in) completes their first level, one Firestore
/// transaction creates `referrals/{inviteeUid}` (one credit per invitee) and
/// adds 100 to the inviter's `pendingCredits` (+1 `inviteCount`, max 20); the
/// invitee gets +50 coins right away, the inviter on their next sync.
class ReferralService {
  ReferralService._();
  static final ReferralService I = ReferralService._();

  static const packageId = 'com.memorypuzzle.app';
  static const inviteeBonus = 50;
  static const inviterBonus = 100;
  static const maxInvites = 20;

  static const _kChecked = 'ref.checked';
  static const _kPending = 'ref.pendingInviter';

  StreamSubscription<RewardEvent>? _sub;
  bool _busy = false;

  static String inviteLink(String uid) => 'https://play.google.com/store/apps/details?id=$packageId&referrer=ref_$uid';

  static String inviteText(String uid, String name) => name.isEmpty
      ? tr('cloud.invite.text_anon', {'coins': inviteeBonus, 'link': inviteLink(uid)})
      : tr('cloud.invite.text', {'name': name, 'coins': inviteeBonus, 'link': inviteLink(uid)});

  /// Extracts the inviter uid from a raw install-referrer string such as
  /// `ref_abc123`, `referrer=ref_abc123` or URL-encoded variants.
  static String? parseInviter(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var s = raw;
    try {
      s = Uri.decodeComponent(raw);
    } catch (_) {}
    final m = RegExp(r'(?:^|[=&?\s])ref_([A-Za-z0-9]{6,128})').firstMatch(s);
    return m?.group(1);
  }

  String? get pendingInviter => Storage.globalString(_kPending);

  /// First launch only: store the pending inviter from the Play referrer.
  Future<void> captureInstallReferrer() async {
    if (Storage.globalBool(_kChecked)) return;
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final d = await PlayInstallReferrer.installReferrer.timeout(const Duration(seconds: 5));
      final inviter = parseInviter(d.installReferrer);
      if (inviter != null) await Storage.setGlobalString(_kPending, inviter);
      await Storage.setGlobalBool(_kChecked, true);
    } catch (e) {
      // Not installed from Play / service unavailable: try again next launch.
      debugPrint('install referrer: $e');
    }
  }

  void start() {
    _sub ??= Rewards.events.listen((e) {
      if (e.type == 'level' && pendingInviter != null) tryCredit();
    });
  }

  /// True once any level was completed (`rec.<game>.levels` > 0).
  static bool hasCompletedLevel(Map<String, Object> keys) =>
      keys.entries.any((e) => e.key.startsWith('rec.') && e.key.endsWith('.levels') && e.value is int && (e.value as int) > 0);

  /// Credits the referral once the invitee is logged in and has completed a
  /// level. Safe to call often.
  Future<void> tryCredit() async {
    final inviter = pendingInviter;
    final me = CloudAuth.I.user.value?.uid;
    if (_busy || inviter == null || me == null || !CloudService.available || !AccountService.I.loggedIn) return;
    if (inviter == me) {
      await Storage.removeGlobal(_kPending);
      return;
    }
    _busy = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!hasCompletedLevel(LocalKv(prefs).readAll(Storage.userPrefix))) return;
      final db = FirebaseFirestore.instance;
      final refDoc = db.collection('referrals').doc(me);
      final inviterDoc = db.collection('users').doc(inviter);
      Future<bool> run(bool creditInviter) => db.runTransaction<bool>((tx) async {
            final s = await tx.get(refDoc);
            if (s.exists) return false;
            tx.set(refDoc, {'inviter': inviter, 'inviterCredited': creditInviter, 'createdAt': FieldValue.serverTimestamp()});
            if (creditInviter) {
              tx.update(inviterDoc, {'pendingCredits': FieldValue.increment(inviterBonus), 'inviteCount': FieldValue.increment(1)});
            }
            return true;
          });
      bool credited;
      try {
        credited = await run(true);
      } on FirebaseException catch (e) {
        // Inviter missing or already at the cap (rules reject): still reward
        // the invitee once.
        if (e.code != 'permission-denied' && e.code != 'not-found') rethrow;
        credited = await run(false);
      }
      await Storage.removeGlobal(_kPending);
      if (credited) await Rewards.addCoins(inviteeBonus, label: tr('cloud.invite_bonus'));
    } catch (e) {
      debugPrint('referral credit: $e');
    } finally {
      _busy = false;
    }
  }

  Future<void> share() async {
    final uid = CloudAuth.I.user.value?.uid;
    if (uid == null) return;
    await SharePlus.instance.share(ShareParams(text: inviteText(uid, AccountService.I.name), subject: tr('cloud.invite.subject')));
  }

  Future<void> deleteMine(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('referrals').doc(uid).delete();
    } catch (_) {}
  }
}
