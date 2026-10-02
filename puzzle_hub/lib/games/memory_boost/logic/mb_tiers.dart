import 'card_deck.dart';

/// Difficulty tier shared by the three Memory Boost mini games.
enum Tier {
  easy('Easy', 'easy'),
  medium('Medium', 'medium'),
  hard('Hard', 'hard'),
  extreme('Extreme', 'extreme');

  final String label;
  final String key;
  const Tier(this.label, this.key);

  static Tier fromIndex(int i) => Tier.values[i.clamp(0, Tier.values.length - 1)];
}

// ---------------------------------------------------------------- Card Match

class CardTierParams {
  final List<CardLevel> levels;

  /// How long a mismatched pair stays visible before flipping back.
  final int flipBackMs;

  /// All cards are shown face up for this long at the start (0 = none).
  final int peekMs;

  /// Seconds allowed per pair (null = no limit).
  final int? secondsPerPair;
  const CardTierParams(this.levels, this.flipBackMs, this.peekMs, [this.secondsPerPair]);

  /// Time limit in seconds for [level] (null when the tier has no limit).
  int? timeLimit(int level) => secondsPerPair == null ? null : levels[level].pairs * secondsPerPair!;
}

const Map<Tier, CardTierParams> cardTierParams = {
  Tier.easy: CardTierParams([CardLevel(2, 2), CardLevel(2, 3), CardLevel(3, 4), CardLevel(4, 4)], 1200, 0),
  Tier.medium: CardTierParams(cardLevels, 800, 0),
  Tier.hard: CardTierParams([CardLevel(3, 4), CardLevel(4, 4), CardLevel(4, 5), CardLevel(5, 6)], 500, 0),
  Tier.extreme: CardTierParams([CardLevel(5, 6), CardLevel(6, 6)], 350, 1500, 8),
};

String cardStarsKey(Tier t, int level) => 'memory.cards.${t.key}.stars.$level';
String cardMovesKey(Tier t, int level) => 'memory.cards.${t.key}.moves.$level';
String cardRewardKey(Tier t, int level) => 'cards-${t.key}-L${level + 1}';

// -------------------------------------------------------------------- Simon

class SimonTierParams {
  final int pads;

  /// Lit time for the first step, minimum lit time, and ms removed per step.
  final int baseMs, minMs, decayMs;

  /// Mistakes allowed; each forgiven mistake replays the pattern.
  final int chances;
  const SimonTierParams(this.pads, this.baseMs, this.minMs, this.decayMs, this.chances);
}

const Map<Tier, SimonTierParams> simonTierParams = {
  Tier.easy: SimonTierParams(4, 800, 450, 15, 2),
  Tier.medium: SimonTierParams(4, 600, 220, 20, 1),
  Tier.hard: SimonTierParams(4, 420, 160, 20, 1),
  Tier.extreme: SimonTierParams(6, 300, 110, 15, 1),
};

String simonBestKeyFor(Tier t) => 'memory.simon.${t.key}.best';
String simonRewardKey(Tier t, int milestone) => 'simon-${t.key}-$milestone';

// ------------------------------------------------------------------- Number

class NumberTierParams {
  final int startDigits, lives;

  /// Display time = baseMs + perDigitMs * digits.
  final int baseMs, perDigitMs;
  const NumberTierParams(this.startDigits, this.lives, this.baseMs, this.perDigitMs);

  Duration displayFor(int digits) => Duration(milliseconds: baseMs + perDigitMs * digits);
  int digitsForRound(int round) => startDigits + round - 1;
}

const Map<Tier, NumberTierParams> numberTierParams = {
  Tier.easy: NumberTierParams(1, 3, 1000, 800),
  Tier.medium: NumberTierParams(2, 3, 800, 700),
  Tier.hard: NumberTierParams(4, 2, 500, 450),
  Tier.extreme: NumberTierParams(6, 1, 300, 300),
};

String numberBestKeyFor(Tier t) => 'memory.number.${t.key}.best';
String numberRewardKey(Tier t, int n) => 'number-${t.key}-$n';

String tierPrefKey(String game) => 'memory.$game.tier';
