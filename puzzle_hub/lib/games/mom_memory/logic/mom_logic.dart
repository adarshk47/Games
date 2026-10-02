import 'dart:math';

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
  const MatchLevel(this.label, this.rows, this.cols);
  final String label;
  final int rows, cols;
  int get pairs => rows * cols ~/ 2;
}

const matchLevels = [
  MatchLevel('Aasaan', 3, 4),
  MatchLevel('Madhyam', 4, 4),
  MatchLevel('Thoda alag', 4, 5),
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
  const BagItem(this.emoji, this.hi, this.en);
  final String emoji, hi, en;
}

const bagItems = [
  BagItem('👕', 'Kapde', 'Clothes'),
  BagItem('🧼', 'Sabun', 'Soap'),
  BagItem('🪥', 'Brush', 'Toothbrush'),
  BagItem('📄', 'Kagaz', 'Documents'),
  BagItem('📱', 'Phone', 'Phone'),
  BagItem('🔌', 'Charger', 'Charger'),
  BagItem('🧦', 'Moze', 'Socks'),
  BagItem('🍼', 'Bottle', 'Baby bottle'),
  BagItem('🧸', 'Khilona', 'Soft toy'),
  BagItem('🧴', 'Lotion', 'Lotion'),
  BagItem('🧣', 'Shawl', 'Shawl'),
  BagItem('👶', 'Baby suit', 'Baby suit'),
  BagItem('💧', 'Paani', 'Water'),
  BagItem('🍪', 'Snacks', 'Snacks'),
  BagItem('🪮', 'Kanghi', 'Comb'),
  BagItem('👓', 'Chashma', 'Glasses'),
  BagItem('🧻', 'Tissue', 'Tissues'),
  BagItem('🩴', 'Chappal', 'Slippers'),
  BagItem('📖', 'Kitaab', 'Book'),
  BagItem('🧢', 'Topi', 'Baby cap'),
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
  const BreathColor(this.name, this.argb);
  final String name;
  final int argb;
}

const breathColors = [
  BreathColor('Gulabi', 0xFFFF8FB8),
  BreathColor('Jamuni', 0xFFB794FF),
  BreathColor('Neela', 0xFF7CC4FF),
  BreathColor('Hara', 0xFF7EE8B5),
  BreathColor('Peela', 0xFFFFD98A),
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

const mmFootnote =
    'Sirf manoranjan aur halki dimaagi kasrat ke liye, medical salah nahi.';
