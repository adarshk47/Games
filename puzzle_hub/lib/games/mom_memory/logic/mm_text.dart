import '../../../core/i18n/i18n.dart';

/// Language codes every Mom Memory text must provide.
const mmLangs = ['en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho', 'mr', 'sa'];

/// A piece of content in all languages: lang code -> value.
typedef MmL<T> = Map<String, T>;

/// Picks the value for the current app language (with the usual fallbacks).
T mmPick<T>(MmL<T> m) {
  for (final c in I18n.lang.value.fallbacks) {
    final v = m[c];
    if (v != null) return v;
  }
  return m['en'] ?? m.values.first;
}
