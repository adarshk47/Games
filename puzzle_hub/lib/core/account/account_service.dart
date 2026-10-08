import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../i18n/i18n.dart';
import '../storage.dart';

/// Single local account stored on the device: name + salted-hash PIN (optional
/// app lock), optional fingerprint unlock. It can be linked to a Firebase uid
/// ([cloudUid]) for cloud sync; the PIN never leaves the phone. On login, [Storage.userPrefix]
/// is set so all game data/coins/records are per-user.
class AccountService extends ChangeNotifier {
  AccountService._();
  static final AccountService I = AccountService._();

  static const _kName = 'acct.name';
  static const _kSalt = 'acct.salt';
  static const _kHash = 'acct.hash';
  static const _kBio = 'acct.bio';
  static const _kId = 'acct.id';
  static const _kCloudUid = 'acct.cloudUid';
  static const _kCloudEmail = 'acct.cloudEmail';
  static const _kNoPin = 'GUEST_NO_PIN';
  static const _kCountry = 'acct.country';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  bool get hasAccount => Storage.globalString(_kHash) != null;
  String get name => Storage.globalString(_kName) ?? '';

  /// False for guest / "play without PIN" accounts (no app lock).
  bool get hasPin {
    final h = Storage.globalString(_kHash);
    return h != null && h != _kNoPin;
  }

  /// Firebase uid linked to this local account (null = not linked).
  String? get cloudUid => Storage.globalString(_kCloudUid);
  String? get cloudEmail => Storage.globalString(_kCloudEmail);
  bool get biometricEnabled => Storage.globalBool(_kBio);

  /// ISO code of the player's country (asked before sign-in); null = not chosen yet.
  String? get country => Storage.globalString(_kCountry);

  Future<void> setCountry(String code) async {
    await Storage.setGlobalString(_kCountry, code);
    notifyListeners();
  }

  /// True only for the very first session after registering (for "Welcome").
  bool justRegistered = false;

  static String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();

  Future<bool> biometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> register({required String name, required String pin, required bool useBiometric}) async {
    final salt = List.generate(16, (_) => Random.secure().nextInt(256)).join('-');
    final id = 'u${DateTime.now().millisecondsSinceEpoch}';
    await Storage.setGlobalString(_kName, name.trim());
    await Storage.setGlobalString(_kSalt, salt);
    await Storage.setGlobalString(_kHash, _hash(pin, salt));
    await Storage.setGlobalString(_kId, id);
    await Storage.setGlobalBool(_kBio, useBiometric);
    justRegistered = true;
    _enter();
  }

  bool verifyPin(String pin) {
    final salt = Storage.globalString(_kSalt);
    final hash = Storage.globalString(_kHash);
    return salt != null && hash != null && _hash(pin, salt) == hash;
  }

  /// Allows guest access or playing without creating/entering a PIN.
  Future<void> loginWithoutPin([String guestName = 'Player']) async {
    if (!hasAccount) {
      final salt = List.generate(16, (_) => Random.secure().nextInt(256)).join('-');
      final id = 'u_guest';
      await Storage.setGlobalString(_kName, guestName.trim().isEmpty ? 'Player' : guestName.trim());
      await Storage.setGlobalString(_kSalt, salt);
      await Storage.setGlobalString(_kHash, _kNoPin);
      await Storage.setGlobalString(_kId, id);
      await Storage.setGlobalBool(_kBio, false);
      justRegistered = true;
    }
    justRegistered = false;
    _enter();
  }

  /// Returns true and enters the account if the PIN is right.
  bool loginWithPin(String pin) {
    if (!verifyPin(pin)) return false;
    justRegistered = false;
    _enter();
    return true;
  }

  Future<bool> loginWithBiometric() async {
    if (!biometricEnabled) return false;
    try {
      final ok = await _auth.authenticate(
        localizedReason: tr('account.fingerprint_unlock'),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (ok) {
        justRegistered = false;
        _enter();
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> setBiometric(bool on) async {
    await Storage.setGlobalBool(_kBio, on);
    notifyListeners();
  }

  Future<bool> changePin(String oldPin, String newPin) async {
    if (!verifyPin(oldPin)) return false;
    final salt = Storage.globalString(_kSalt)!;
    await Storage.setGlobalString(_kHash, _hash(newPin, salt));
    return true;
  }

  /// Adds an optional PIN lock to a guest / cloud account that has none.
  Future<void> setPin(String pin) async {
    var salt = Storage.globalString(_kSalt);
    if (salt == null) {
      salt = List.generate(16, (_) => Random.secure().nextInt(256)).join('-');
      await Storage.setGlobalString(_kSalt, salt);
    }
    await Storage.setGlobalString(_kHash, _hash(pin, salt));
    notifyListeners();
  }

  /// Removes the PIN lock (and fingerprint unlock).
  Future<void> removePin() async {
    await Storage.setGlobalString(_kHash, _kNoPin);
    await Storage.setGlobalBool(_kBio, false);
    notifyListeners();
  }

  Future<void> linkCloud(String uid, {String? email}) async {
    await Storage.setGlobalString(_kCloudUid, uid);
    if (email != null) {
      await Storage.setGlobalString(_kCloudEmail, email);
    } else {
      await Storage.removeGlobal(_kCloudEmail);
    }
    notifyListeners();
  }

  Future<void> unlinkCloud() async {
    await Storage.removeGlobal(_kCloudUid);
    await Storage.removeGlobal(_kCloudEmail);
    await Storage.removeGlobal('cloud.lastSync');
    notifyListeners();
  }

  Future<void> rename(String newName) async {
    await Storage.setGlobalString(_kName, newName.trim());
    notifyListeners();
  }

  void lock() {
    _loggedIn = false;
    Storage.userPrefix = '';
    notifyListeners();
  }

  /// Erases the local account and all of its saved game data (caller must
  /// confirm, and delete cloud data first via CloudAuth.deleteCloudAccount).
  Future<void> deleteAccount() async {
    final id = Storage.globalString(_kId);
    if (id != null) await Storage.clearPrefix('$id.');
    for (final k in [_kName, _kSalt, _kHash, _kBio, _kId, _kCloudUid, _kCloudEmail, 'cloud.lastSync']) {
      await Storage.removeGlobal(k);
    }
    lock();
  }

  void _enter() {
    Storage.userPrefix = '${Storage.globalString(_kId)}.';
    _loggedIn = true;
    notifyListeners();
  }
}
