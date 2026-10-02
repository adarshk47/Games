import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

import '../storage.dart';

/// Single local account stored on the device: name + salted-hash PIN, optional
/// fingerprint unlock. Nothing leaves the phone. On login, [Storage.userPrefix]
/// is set so all game data/coins/records are per-user.
class AccountService extends ChangeNotifier {
  AccountService._();
  static final AccountService I = AccountService._();

  static const _kName = 'acct.name';
  static const _kSalt = 'acct.salt';
  static const _kHash = 'acct.hash';
  static const _kBio = 'acct.bio';
  static const _kId = 'acct.id';

  final LocalAuthentication _auth = LocalAuthentication();

  bool _loggedIn = false;
  bool get loggedIn => _loggedIn;
  bool get hasAccount => Storage.globalString(_kHash) != null;
  String get name => Storage.globalString(_kName) ?? '';
  bool get biometricEnabled => Storage.globalBool(_kBio);

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
        localizedReason: 'Fingerprint se unlock karein',
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

  Future<void> rename(String newName) async {
    await Storage.setGlobalString(_kName, newName.trim());
    notifyListeners();
  }

  void lock() {
    _loggedIn = false;
    Storage.userPrefix = '';
    notifyListeners();
  }

  /// Erases the account and all of its saved game data (caller must confirm with PIN).
  Future<void> deleteAccount() async {
    final id = Storage.globalString(_kId);
    if (id != null) await Storage.clearPrefix('$id.');
    for (final k in [_kName, _kSalt, _kHash, _kBio, _kId]) {
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
