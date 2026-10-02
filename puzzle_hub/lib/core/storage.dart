import 'package:shared_preferences/shared_preferences.dart';

/// Thin wrapper over SharedPreferences. Call [Storage.init] once in main().
/// Games should namespace keys with their id, e.g. `sudoku.best.easy`.
class Storage {
  Storage._();
  static late SharedPreferences _p;

  static Future<void> init() async => _p = await SharedPreferences.getInstance();

  static int getInt(String key, [int def = 0]) => _p.getInt(key) ?? def;
  static Future<void> setInt(String key, int v) => _p.setInt(key, v);
  static bool getBool(String key, [bool def = false]) => _p.getBool(key) ?? def;
  static Future<void> setBool(String key, bool v) => _p.setBool(key, v);
  static String? getString(String key) => _p.getString(key);
  static Future<void> setString(String key, String v) => _p.setString(key, v);

  /// Keeps the higher value; returns true if [v] is a new best.
  static bool setBest(String key, int v) {
    if (v > getInt(key)) {
      setInt(key, v);
      return true;
    }
    return false;
  }
}
