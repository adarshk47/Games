import 'package:flutter/material.dart';

import '../storage.dart';
import 'strings/all.dart';
import 'strings/euro.dart';

/// Languages the user can pick in the app (independent of the phone locale).
enum AppLang {
  en('en', 'English', 'English'),
  hi('hi', 'हिन्दी', 'Hindi'),
  hinglish('hinglish', 'Hinglish', 'Hinglish'),
  te('te', 'తెలుగు', 'Telugu'),
  ta('ta', 'தமிழ்', 'Tamil'),
  pa('pa', 'ਪੰਜਾਬੀ', 'Punjabi'),
  bho('bho', 'भोजपुरी', 'Bhojpuri'),
  mr('mr', 'मराठी', 'Marathi'),
  sa('sa', 'संस्कृतम्', 'Sanskrit'),
  de('de', 'Deutsch', 'German'),
  fr('fr', 'Français', 'French'),
  es('es', 'Español', 'Spanish'),
  it('it', 'Italiano', 'Italian');

  const AppLang(this.code, this.nativeName, this.englishName);
  final String code;
  final String nativeName;
  final String englishName;

  /// German, French, Spanish and Italian live in strings/euro.dart instead of
  /// the per-module tables.
  bool get isEuro => index >= AppLang.de.index;

  /// Languages every per-module string table must contain.
  static List<AppLang> get tableLangs => [for (final l in values) if (!l.isEuro) l];

  /// Locale used for Flutter's built-in widget texts (date picker etc.).
  /// Bhojpuri falls back to Hindi and Hinglish to English.
  Locale get materialLocale => switch (this) {
        AppLang.bho || AppLang.sa => const Locale('hi'),
        AppLang.hinglish => const Locale('en'),
        _ => Locale(code),
      };

  /// Where to look when a string is missing in this language.
  List<String> get fallbacks => switch (this) {
        AppLang.bho => const ['bho', 'hi', 'en'],
        AppLang.mr => const ['mr', 'hi', 'en'],
        AppLang.sa => const ['sa', 'hi', 'en'],
        AppLang.hinglish => const ['hinglish', 'en'],
        AppLang.en => const ['en'],
        _ => [code, 'en'],
      };
}

/// App-wide language state. The choice is global (also used on the lock screen).
class I18n {
  I18n._();

  static const _key = 'set.lang';
  static final ValueNotifier<AppLang> lang = ValueNotifier(AppLang.en);

  /// Bumped on every [set] (even to the same language) so listeners such as
  /// the first-run gate rebuild.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  /// True once the user picked a language (first-run picker shown otherwise).
  static bool get chosen => Storage.globalString(_key) != null;

  static Future<void> init() async {
    final code = Storage.globalString(_key);
    lang.value = AppLang.values.firstWhere((l) => l.code == code, orElse: () => AppLang.en);
  }

  static Future<void> set(AppLang l) async {
    await Storage.setGlobalString(_key, l.code);
    lang.value = l;
    revision.value++;
  }
}

/// Translate [key] into the current language. `{name}` placeholders are
/// replaced from [args]. Missing keys fall back (see [AppLang.fallbacks]),
/// then to [fallback], then to the key itself so a gap is visible but never crashes.
String tr(String key, [Map<String, Object?> args = const {}, String? fallback]) {
  final entry = allStrings[key];
  // European languages live in their own tables (strings/euro.dart).
  String? s = euroStrings[I18n.lang.value.code]?[key];
  if (s == null && entry != null) {
    for (final c in I18n.lang.value.fallbacks) {
      s = entry[c];
      if (s != null) break;
    }
  }
  s ??= fallback ?? key;
  if (args.isEmpty) return s;
  return s.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) => '${args[m.group(1)] ?? m.group(0)}');
}

/// Languages to show first for a country (the rest follow). India gets its
/// Indian languages first; elsewhere English leads.
List<AppLang> languagesFor(String? countryCode) {
  final first = switch (countryCode) {
    'IN' => const [AppLang.hi, AppLang.hinglish, AppLang.en, AppLang.mr, AppLang.te, AppLang.ta, AppLang.pa, AppLang.bho, AppLang.sa],
    'NP' => const [AppLang.hi, AppLang.bho, AppLang.en],
    'PK' => const [AppLang.pa, AppLang.en, AppLang.hi],
    'LK' || 'SG' || 'MY' => const [AppLang.en, AppLang.ta],
    'FJ' || 'MU' || 'TT' || 'GY' || 'SR' => const [AppLang.en, AppLang.hi, AppLang.bho],
    'AE' || 'SA' || 'QA' || 'KW' || 'OM' || 'BH' => const [AppLang.en, AppLang.hi, AppLang.hinglish, AppLang.te, AppLang.ta, AppLang.mr],
    'DE' || 'AT' || 'LI' => const [AppLang.de, AppLang.en],
    'CH' => const [AppLang.de, AppLang.fr, AppLang.it, AppLang.en],
    'FR' || 'MC' || 'LU' => const [AppLang.fr, AppLang.en],
    'BE' => const [AppLang.fr, AppLang.en, AppLang.de],
    'CA' => const [AppLang.en, AppLang.fr, AppLang.hi, AppLang.pa],
    'ES' || 'MX' || 'AR' || 'CO' || 'CL' || 'PE' || 'VE' || 'EC' || 'UY' => const [AppLang.es, AppLang.en],
    'IT' || 'SM' => const [AppLang.it, AppLang.en],
    _ => const [AppLang.en],
  };
  return [...first, ...AppLang.values.where((l) => !first.contains(l))];
}
