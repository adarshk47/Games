import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../account/account_service.dart';
import '../i18n/i18n.dart';
import '../rewards.dart';
import '../storage.dart';
import 'cloud_service.dart';
import 'leaderboard_service.dart';
import 'referral_service.dart';
import 'sync_service.dart';

/// Signed-in Firebase user (plain value, so UI/tests need no Firebase types).
@immutable
class CloudUser {
  const CloudUser({required this.uid, this.email, this.name, this.emailVerified = false, this.isGoogle = false});
  final String uid;
  final String? email;
  final String? name;
  final bool emailVerified;
  final bool isGoogle;

  /// Email/password accounts should verify their email; Google ones are verified.
  bool get needsVerification => !isGoogle && !emailVerified;
}

enum DeleteOutcome { done, needsReauth, failed }

/// Firebase Authentication: Google Sign-In and Email/Password. Every method is
/// a no-op returning an error text when [CloudService.available] is false.
///
/// Methods returning `Future<String?>` yield null on success, '' when the
/// user cancelled, or a friendly error message.
class CloudAuth {
  CloudAuth._();
  static final CloudAuth I = CloudAuth._();

  final ValueNotifier<CloudUser?> user = ValueNotifier(null);

  StreamSubscription<User?>? _sub;
  Future<void>? _googleInit;
  bool _wasLocalLoggedIn = false;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  void start() {
    _sub ??= _auth.userChanges().listen((u) {
      final before = user.value?.uid;
      user.value = u == null ? null : _map(u);
      if (u != null && u.uid != before) _onCloudUser();
    });
    AccountService.I.addListener(_onLocalChanged);
    _wasLocalLoggedIn = AccountService.I.loggedIn;
  }

  static CloudUser _map(User u) => CloudUser(
        uid: u.uid,
        email: u.email,
        name: u.displayName,
        emailVerified: u.emailVerified,
        isGoogle: u.providerData.any((p) => p.providerId == 'google.com'),
      );

  void _onLocalChanged() {
    final now = AccountService.I.loggedIn;
    if (now && !_wasLocalLoggedIn && user.value != null) _onCloudUser();
    _wasLocalLoggedIn = now;
  }

  /// Links the cloud uid to the local account and syncs.
  void _onCloudUser() {
    final u = user.value;
    if (u == null || !AccountService.I.loggedIn) return;
    if (AccountService.I.cloudUid != u.uid) AccountService.I.linkCloud(u.uid, email: u.email);
    SyncService.I.syncNow();
  }

  /// After a successful sign-in: make sure a local account exists (guest ->
  /// cloud upgrade keeps all local progress, it is merged into the cloud).
  Future<void> _completeSignIn(User u) async {
    final a = AccountService.I;
    if (!a.hasAccount || !a.loggedIn) {
      final fallback = (u.email ?? '').split('@').first;
      await a.loginWithoutPin((u.displayName?.trim().isNotEmpty ?? false) ? u.displayName! : (fallback.isEmpty ? 'Player' : fallback));
      Rewards.reload();
    }
    user.value = _map(u);
    await a.linkCloud(u.uid, email: u.email);
    await SyncService.I.syncNow();
    unawaited(ReferralService.I.tryCredit());
  }

  Future<void> _ensureGoogle() => _googleInit ??= GoogleSignIn.instance.initialize();

  Future<String?> signInWithGoogle() async {
    if (!CloudService.available) return CloudService.pendingText;
    try {
      await _ensureGoogle();
      final acc = await GoogleSignIn.instance.authenticate();
      final idToken = acc.authentication.idToken;
      if (idToken == null) return tr('cloud.err.google_no_token');
      final res = await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: idToken));
      if (res.user != null) await _completeSignIn(res.user!);
      return null;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return '';
      debugPrint('google sign-in: $e');
      return tr('cloud.err.google_retry');
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e.code);
    } catch (e) {
      debugPrint('google sign-in: $e');
      return tr('cloud.err.google_retry');
    }
  }

  Future<String?> signUpWithEmail({required String email, required String password, String? name}) async {
    if (!CloudService.available) return CloudService.pendingText;
    try {
      final res = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      final u = res.user;
      if (u == null) return tr('cloud.err.signup_failed');
      if (name != null && name.trim().isNotEmpty) await u.updateDisplayName(name.trim());
      try {
        await u.sendEmailVerification();
      } catch (_) {}
      await _completeSignIn(_auth.currentUser ?? u);
      return null;
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e.code);
    } catch (e) {
      return tr('cloud.err.signup_retry');
    }
  }

  Future<String?> signInWithEmail({required String email, required String password}) async {
    if (!CloudService.available) return CloudService.pendingText;
    try {
      final res = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      if (res.user != null) await _completeSignIn(res.user!);
      return null;
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e.code);
    } catch (e) {
      return tr('cloud.err.signin_retry');
    }
  }

  Future<String?> sendPasswordReset(String email) async {
    if (!CloudService.available) return CloudService.pendingText;
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e.code);
    } catch (_) {
      return tr('cloud.err.reset_failed');
    }
  }

  Future<String?> sendVerification() async {
    final u = CloudService.available ? _auth.currentUser : null;
    if (u == null) return tr('cloud.err.not_signed_in');
    try {
      await u.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e.code);
    } catch (_) {
      return tr('cloud.err.verify_failed');
    }
  }

  /// Re-reads the user (e.g. after they clicked the verification link).
  Future<void> reload() async {
    final u = CloudService.available ? _auth.currentUser : null;
    if (u == null) return;
    try {
      await u.reload();
      final fresh = _auth.currentUser;
      user.value = fresh == null ? null : _map(fresh);
    } catch (_) {}
  }

  /// Final sync, then sign out of Firebase/Google. Local data stays.
  Future<void> signOut() async {
    if (!CloudService.available) return;
    await SyncService.I.syncNow();
    try {
      await _auth.signOut();
      if (_googleInit != null) await GoogleSignIn.instance.signOut();
    } catch (e) {
      debugPrint('sign out: $e');
    }
    user.value = null;
    // Leaderboard "already submitted" cache belongs to the old cloud user.
    if (Storage.userPrefix.isNotEmpty) await Storage.clearPrefix('${Storage.userPrefix}cloud.lb.');
    await AccountService.I.unlinkCloud();
  }

  /// Google users re-pick their account; email users pass [password].
  Future<String?> reauthenticate({String? password}) async {
    final u = CloudService.available ? _auth.currentUser : null;
    if (u == null) return tr('cloud.err.not_signed_in');
    try {
      if (user.value?.isGoogle ?? false) {
        await _ensureGoogle();
        final acc = await GoogleSignIn.instance.authenticate();
        final t = acc.authentication.idToken;
        if (t == null) return tr('cloud.err.google_failed');
        await u.reauthenticateWithCredential(GoogleAuthProvider.credential(idToken: t));
      } else {
        if (password == null || u.email == null) return tr('cloud.err.password_required');
        await u.reauthenticateWithCredential(EmailAuthProvider.credential(email: u.email!, password: password));
      }
      return null;
    } on GoogleSignInException catch (e) {
      return e.code == GoogleSignInExceptionCode.canceled ? '' : tr('cloud.err.google_failed');
    } on FirebaseAuthException catch (e) {
      return friendlyAuthError(e.code);
    } catch (_) {
      return tr('cloud.err.reauth_failed');
    }
  }

  /// Deletes the cloud data (user doc, leaderboard entries, referral record)
  /// and the Firebase Auth user. Local data is deleted by the caller.
  Future<DeleteOutcome> deleteCloudAccount() async {
    final u = CloudService.available ? _auth.currentUser : null;
    if (u == null) return DeleteOutcome.done;
    try {
      await LeaderboardService.I.deleteMine(u.uid);
      await ReferralService.I.deleteMine(u.uid);
      await SyncService.I.deleteRemote(u.uid);
    } catch (e) {
      debugPrint('delete cloud data: $e');
      return DeleteOutcome.failed;
    }
    try {
      await u.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') return DeleteOutcome.needsReauth;
      debugPrint('delete auth user: $e');
      return DeleteOutcome.failed;
    } catch (e) {
      return DeleteOutcome.failed;
    }
    try {
      if (_googleInit != null) await GoogleSignIn.instance.disconnect();
    } catch (_) {}
    user.value = null;
    return DeleteOutcome.done;
  }

  static String friendlyAuthError(String code) => switch (code) {
        'invalid-email' => tr('cloud.err.invalid_email'),
        'user-disabled' => tr('cloud.err.user_disabled'),
        'user-not-found' || 'wrong-password' || 'invalid-credential' => tr('cloud.err.wrong_credentials'),
        'email-already-in-use' => tr('cloud.err.email_in_use'),
        'weak-password' => tr('cloud.err.weak_password'),
        'too-many-requests' => tr('cloud.err.too_many'),
        'network-request-failed' => tr('cloud.err.no_internet'),
        'account-exists-with-different-credential' => tr('cloud.err.other_method'),
        'requires-recent-login' => tr('cloud.err.recent_login'),
        'operation-not-allowed' => tr('cloud.err.not_enabled'),
        _ => tr('cloud.err.unknown', {'code': code}),
      };
}
