import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences. Call [Storage.init] once in main().
///
/// Every normal accessor (getInt/setInt/...) is automatically namespaced to the
/// signed-in local user via [userPrefix], so each account keeps its own game
/// progress, records and coins. Games just keep using `sudoku.best.easy` style
/// keys. Account data itself uses the `global*` accessors (not namespaced).
class Storage {
  Storage._();
  static late SharedPreferences _p;

  /// Set by AccountService on login/logout, e.g. `u1.`. Empty = no user.
  static String userPrefix = '';

  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static String _k(String key) => '$userPrefix$key';

  static int getInt(String key, [int def = 0]) => _p.getInt(_k(key)) ?? def;
  static Future<void> setInt(String key, int v) => _p.setInt(_k(key), v);
  static bool getBool(String key, [bool def = false]) => _p.getBool(_k(key)) ?? def;
  static Future<void> setBool(String key, bool v) => _p.setBool(_k(key), v);
  static String? getString(String key) => _p.getString(_k(key));
  static Future<void> setString(String key, String v) => _p.setString(_k(key), v);
  static Future<void> remove(String key) => _p.remove(_k(key));

  /// Keeps the higher value; returns true if [v] is a new best.
  static bool setBest(String key, int v) {
    if (v > getInt(key)) {
      setInt(key, v);
      return true;
    }
    return false;
  }

  // Not namespaced: account/profile data.
  static String? globalString(String key) => _p.getString(key);
  static Future<void> setGlobalString(String key, String v) => _p.setString(key, v);
  static bool globalBool(String key, [bool def = false]) => _p.getBool(key) ?? def;
  static Future<void> setGlobalBool(String key, bool v) => _p.setBool(key, v);
  static Future<void> removeGlobal(String key) => _p.remove(key);

  /// Removes every key belonging to [prefix] (used when deleting an account).
  static Future<void> clearPrefix(String prefix) async {
    for (final k in _p.getKeys().where((k) => k.startsWith(prefix)).toList()) {
      await _p.remove(k);
    }
  }
}
