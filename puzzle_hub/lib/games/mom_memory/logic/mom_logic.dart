import 'dart:math';

import '../../../core/i18n/i18n.dart';
import 'mm_text.dart';

export 'mm_text.dart';

// ---------- Baby Items Match ----------
const babyEmojis = [
  '🍼',
  '🧸',
  '👶',
  '🧷',
  '🛁',
  '🧦',
  '🎀',
  '🐥',
  '🌙',
  '🧺',
  '🦆',
  '🍪',
];

class MatchLevel {
  const MatchLevel(this.labelKey, this.rows, this.cols);
  final String labelKey; // translation key
  final int rows, cols;
  String get label => tr(labelKey);
  int get pairs => rows * cols ~/ 2;
}

const matchLevels = [
  MatchLevel('mom_memory.level_easy', 3, 4),
  MatchLevel('mom_memory.level_medium', 4, 4),
  MatchLevel('mom_memory.level_more', 4, 5),
];

/// Shuffled deck of emoji indices, each appearing exactly twice.
List<int> generateMatchDeck(int pairs, Random rng) {
  final ids = List.generate(babyEmojis.length, (i) => i)..shuffle(rng);
  final deck = [
    for (final i in ids.take(pairs)) ...[i, i],
  ]..shuffle(rng);
  return deck;
}

/// Relaxed star rating: perfect play is [pairs] moves.
int matchStars(int moves, int pairs) {
  if (moves <= pairs * 1.6) return 3;
  if (moves <= pairs * 2.6) return 2;
  return 1;
}

// ---------- Hospital Bag Recall ----------
class BagItem {
  const BagItem(this.emoji, this.names);
  final String emoji;
  final MmL<String> names; // lang -> name

  /// Name in the current language.
  String get name => mmPick(names);

  /// English name (shown as a small helper line in other languages).
  String get en => names['en']!;
}

const bagItems = [
  BagItem(
    '👕',
    {'en': 'Clothes', 'hi': 'कपड़े', 'hinglish': 'Kapde', 'te': 'బట్టలు', 'ta': 'உடைகள்', 'pa': 'ਕੱਪੜੇ', 'bho': 'कपड़ा', 'mr': "कपडे", 'sa': "वस्त्राणि"},
  ),
  BagItem(
    '🧼',
    {'en': 'Soap', 'hi': 'साबुन', 'hinglish': 'Sabun', 'te': 'సబ్బు', 'ta': 'சோப்பு', 'pa': 'ਸਾਬਣ', 'bho': 'साबुन', 'mr': "साबण", 'sa': "फेनकम्"},
  ),
  BagItem(
    '🪥',
    {'en': 'Toothbrush', 'hi': 'टूथब्रश', 'hinglish': 'Brush', 'te': 'టూత్‌బ్రష్', 'ta': 'பல் துலக்கி', 'pa': 'ਟੁੱਥਬੁਰਸ਼', 'bho': 'टूथब्रश', 'mr': "टूथब्रश", 'sa': "दन्तकूर्चः"},
  ),
  BagItem(
    '📄',
    {'en': 'Documents', 'hi': 'कागज़', 'hinglish': 'Kagaz', 'te': 'పత్రాలు', 'ta': 'ஆவணங்கள்', 'pa': 'ਕਾਗਜ਼', 'bho': 'कागज', 'mr': "कागदपत्रे", 'sa': "पत्राणि"},
  ),
  BagItem(
    '📱',
    {'en': 'Phone', 'hi': 'फ़ोन', 'hinglish': 'Phone', 'te': 'ఫోన్', 'ta': 'கைபேசி', 'pa': 'ਫ਼ੋਨ', 'bho': 'फोन', 'mr': "फोन", 'sa': "दूरवाणी"},
  ),
  BagItem(
    '🔌',
    {'en': 'Charger', 'hi': 'चार्जर', 'hinglish': 'Charger', 'te': 'ఛార్జర్', 'ta': 'சார்ஜர்', 'pa': 'ਚਾਰਜਰ', 'bho': 'चार्जर', 'mr': "चार्जर", 'sa': "आवेशकः"},
  ),
  BagItem(
    '🧦',
    {'en': 'Socks', 'hi': 'मोज़े', 'hinglish': 'Moze', 'te': 'సాక్స్', 'ta': 'காலுறை', 'pa': 'ਜੁਰਾਬਾਂ', 'bho': 'मोजा', 'mr': "मोजे", 'sa': "पादावरणे"},
  ),
  BagItem(
    '🍼',
    {'en': 'Baby bottle', 'hi': 'दूध की बोतल', 'hinglish': 'Bottle', 'te': 'పాల సీసా', 'ta': 'பால் புட்டி', 'pa': 'ਦੁੱਧ ਦੀ ਬੋਤਲ', 'bho': 'दूध के बोतल', 'mr': "दुधाची बाटली", 'sa': "दुग्धकूपी"},
  ),
  BagItem(
    '🧸',
    {'en': 'Soft toy', 'hi': 'खिलौना', 'hinglish': 'Khilona', 'te': 'బొమ్మ', 'ta': 'பொம்மை', 'pa': 'ਖਿਡੌਣਾ', 'bho': 'खिलौना', 'mr': "खेळणे", 'sa': "क्रीडनकम्"},
  ),
  BagItem(
    '🧴',
    {'en': 'Lotion', 'hi': 'लोशन', 'hinglish': 'Lotion', 'te': 'లోషన్', 'ta': 'லோஷன்', 'pa': 'ਲੋਸ਼ਨ', 'bho': 'लोशन', 'mr': "लोशन", 'sa': "लेपः"},
  ),
  BagItem(
    '🧣',
    {'en': 'Shawl', 'hi': 'शॉल', 'hinglish': 'Shawl', 'te': 'శాలువా', 'ta': 'சால்வை', 'pa': 'ਸ਼ਾਲ', 'bho': 'साल', 'mr': "शाल", 'sa': "शाटिका"},
  ),
  BagItem(
    '👶',
    {'en': 'Baby suit', 'hi': 'बेबी सूट', 'hinglish': 'Baby suit', 'te': 'పాప బట్టలు', 'ta': 'குழந்தை உடை', 'pa': 'ਬੇਬੀ ਸੂਟ', 'bho': 'बबुआ के कपड़ा', 'mr': "बाळाचे कपडे", 'sa': "शिशुवस्त्रम्"},
  ),
  BagItem(
    '💧',
    {'en': 'Water', 'hi': 'पानी', 'hinglish': 'Paani', 'te': 'నీళ్లు', 'ta': 'தண்ணீர்', 'pa': 'ਪਾਣੀ', 'bho': 'पानी', 'mr': "पाणी", 'sa': "जलम्"},
  ),
  BagItem(
    '🍪',
    {'en': 'Snacks', 'hi': 'नाश्ता', 'hinglish': 'Snacks', 'te': 'చిరుతిండి', 'ta': 'தின்பண்டம்', 'pa': 'ਸਨੈਕਸ', 'bho': 'नास्ता', 'mr': "खाऊ", 'sa': "अल्पाहारः"},
  ),
  BagItem(
    '🪮',
    {'en': 'Comb', 'hi': 'कंघी', 'hinglish': 'Kanghi', 'te': 'దువ్వెన', 'ta': 'சீப்பு', 'pa': 'ਕੰਘੀ', 'bho': 'ककही', 'mr': "कंगवा", 'sa': "कङ्कतम्"},
  ),
  BagItem(
    '👓',
    {'en': 'Glasses', 'hi': 'चश्मा', 'hinglish': 'Chashma', 'te': 'కళ్లద్దాలు', 'ta': 'கண்ணாடி', 'pa': 'ਐਨਕ', 'bho': 'चस्मा', 'mr': "चष्मा", 'sa': "उपनेत्रम्"},
  ),
  BagItem(
    '🧻',
    {'en': 'Tissues', 'hi': 'टिश्यू', 'hinglish': 'Tissue', 'te': 'టిష్యూ', 'ta': 'டிஷ்யூ', 'pa': 'ਟਿਸ਼ੂ', 'bho': 'टिसू', 'mr': "टिश्यू", 'sa': "मार्जनपत्रम्"},
  ),
  BagItem(
    '🩴',
    {'en': 'Slippers', 'hi': 'चप्पल', 'hinglish': 'Chappal', 'te': 'చెప్పులు', 'ta': 'செருப்பு', 'pa': 'ਚੱਪਲ', 'bho': 'चप्पल', 'mr': "चप्पल", 'sa': "पादुके"},
  ),
  BagItem(
    '📖',
    {'en': 'Book', 'hi': 'किताब', 'hinglish': 'Kitaab', 'te': 'పుస్తకం', 'ta': 'புத்தகம்', 'pa': 'ਕਿਤਾਬ', 'bho': 'किताब', 'mr': "पुस्तक", 'sa': "पुस्तकम्"},
  ),
  BagItem(
    '🧢',
    {'en': 'Baby cap', 'hi': 'टोपी', 'hinglish': 'Topi', 'te': 'టోపీ', 'ta': 'தொப்பி', 'pa': 'ਟੋਪੀ', 'bho': 'टोपी', 'mr': "टोपी", 'sa': "शिरस्त्रम्"},
  ),
];

class BagLevel {
  const BagLevel(this.count, this.showSeconds, this.options);
  final int count, showSeconds, options;
}

/// Grows gently: 4 items up to 10 items. Level index is clamped.
BagLevel bagLevel(int level) {
  final l = level.clamp(0, 6);
  final count = 4 + l;
  return BagLevel(count, 5 + count, min(count * 2 + 2, 20).clamp(8, 20));
}

class BagRound {
  BagRound(this.shown, this.options);
  final List<int> shown; // indices into bagItems
  final List<int> options; // shuffled, includes all shown
}

BagRound buildBagRound(BagLevel lv, Random rng) {
  final all = List.generate(bagItems.length, (i) => i)..shuffle(rng);
  final shown = all.take(lv.count).toList();
  final extra = all.skip(lv.count).take(lv.options - lv.count);
  final options = [...shown, ...extra]..shuffle(rng);
  return BagRound(shown, options);
}

/// Wrong picks are reported separately and never make the score negative.
({int correct, int wrong}) scoreBag(Iterable<int> picked, Iterable<int> shown) {
  final s = shown.toSet();
  final p = picked.toSet();
  return (
    correct: p.where(s.contains).length,
    wrong: p.where((x) => !s.contains(x)).length,
  );
}

int bagStars(int correct, int total) {
  if (total == 0) return 0;
  final r = correct / total;
  if (r >= 0.9) return 3;
  if (r >= 0.6) return 2;
  return 1;
}

// ---------- Lullaby Pattern ----------
const lullabyPads = 6;

List<int> extendPattern(List<int> seq, Random rng) {
  var n = rng.nextInt(lullabyPads);
  if (seq.isNotEmpty && n == seq.last) {
    n = (n + 1 + rng.nextInt(lullabyPads - 1)) % lullabyPads;
  }
  return [...seq, n];
}

enum TapResult { wrong, right, complete }

/// [index] is the position the player is about to tap.
TapResult checkTap(List<int> seq, int index, int pad) {
  if (index < 0 || index >= seq.length || seq[index] != pad) {
    return TapResult.wrong;
  }
  return index == seq.length - 1 ? TapResult.complete : TapResult.right;
}

// ---------- Breathe & Focus ----------
enum BreathPhase { inhale, hold, exhale }

const inhaleSec = 4, holdSec = 4, exhaleSec = 6;
const breathCycleSec = inhaleSec + holdSec + exhaleSec;

({BreathPhase phase, double progress}) breathAt(double seconds) {
  final t = seconds % breathCycleSec;
  if (t < inhaleSec) {
    return (phase: BreathPhase.inhale, progress: t / inhaleSec);
  }
  if (t < inhaleSec + holdSec) {
    return (phase: BreathPhase.hold, progress: (t - inhaleSec) / holdSec);
  }
  return (
    phase: BreathPhase.exhale,
    progress: (t - inhaleSec - holdSec) / exhaleSec,
  );
}

/// Circle scale 0..1 across the cycle (0 = small, 1 = full).
double breathScale(double seconds) {
  final b = breathAt(seconds);
  switch (b.phase) {
    case BreathPhase.inhale:
      return b.progress;
    case BreathPhase.hold:
      return 1;
    case BreathPhase.exhale:
      return 1 - b.progress;
  }
}

class BreathColor {
  const BreathColor(this.names, this.argb);
  final MmL<String> names; // lang -> colour name
  final int argb;
  String get name => mmPick(names);
}

const breathColors = [
  BreathColor(
    {'en': 'Pink', 'hi': 'गुलाबी', 'hinglish': 'Gulabi', 'te': 'గులాబీ', 'ta': 'இளஞ்சிவப்பு', 'pa': 'ਗੁਲਾਬੀ', 'bho': 'गुलाबी', 'mr': "गुलाबी", 'sa': "पाटलः"},
    0xFFFF8FB8,
  ),
  BreathColor(
    {'en': 'Purple', 'hi': 'जामुनी', 'hinglish': 'Jamuni', 'te': 'ఊదా', 'ta': 'ஊதா', 'pa': 'ਜਾਮਣੀ', 'bho': 'बैंगनी', 'mr': "जांभळा", 'sa': "धूम्रवर्णः"},
    0xFFB794FF,
  ),
  BreathColor(
    {'en': 'Blue', 'hi': 'नीला', 'hinglish': 'Neela', 'te': 'నీలం', 'ta': 'நீலம்', 'pa': 'ਨੀਲਾ', 'bho': 'नीला', 'mr': "निळा", 'sa': "नीलः"},
    0xFF7CC4FF,
  ),
  BreathColor(
    {'en': 'Green', 'hi': 'हरा', 'hinglish': 'Hara', 'te': 'ఆకుపచ్చ', 'ta': 'பச்சை', 'pa': 'ਹਰਾ', 'bho': 'हरियर', 'mr': "हिरवा", 'sa': "हरितः"},
    0xFF7EE8B5,
  ),
  BreathColor(
    {'en': 'Yellow', 'hi': 'पीला', 'hinglish': 'Peela', 'te': 'పసుపు', 'ta': 'மஞ்சள்', 'pa': 'ਪੀਲਾ', 'bho': 'पियर', 'mr': "पिवळा", 'sa': "पीतः"},
    0xFFFFD98A,
  ),
];

/// Question options: the correct color index plus 2 distractors, shuffled.
List<int> colorOptions(int correct, Random rng) {
  final others = List.generate(breathColors.length, (i) => i)..remove(correct);
  others.shuffle(rng);
  return [correct, ...others.take(2)]..shuffle(rng);
}

// ---------- Daily streak ----------
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Returns the new streak when playing on [today]. Gentle: same-day keeps,
/// next day increments, a gap restarts at 1.
int nextStreak(String? lastDay, int streak, DateTime today) {
  if (lastDay == null || streak <= 0) return 1;
  if (lastDay == dayKey(today)) return streak;
  final y = DateTime(today.year, today.month, today.day - 1);
  return lastDay == dayKey(y) ? streak + 1 : 1;
}

/// Gentle disclaimer shown under every Mom Memory screen.
String get mmFootnote => tr('mom_memory.footnote');
