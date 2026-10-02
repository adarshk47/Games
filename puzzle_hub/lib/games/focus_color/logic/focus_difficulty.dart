import 'focus_common.dart';

/// Difficulty tiers for every Focus Colors mode.
enum FocusTier {
  easy('Easy'),
  medium('Medium'),
  hard('Hard'),
  extreme('Extreme');

  const FocusTier(this.label);
  final String label;

  static FocusTier fromName(String? n) =>
      FocusTier.values.firstWhere((t) => t.name == n, orElse: () => FocusTier.medium);
}

/// All tunable parameters for one (mode, tier) pair. Pure data.
class FocusParams {
  const FocusParams({
    required this.seconds,
    required this.lives,
    required this.wrongPenalty,
    required this.starScale,
    // Stroop
    this.stroopPool = 6,
    this.stroopMinOptions = 4,
    this.stroopMaxOptions = 6,
    this.stroopOptionStep = 10,
    this.bonusEvery = 8,
    this.bonusSeconds = 2,
    // Odd one out
    this.oddStartGrid = 2,
    this.oddMaxGrid = 7,
    this.oddGridStep = 3,
    this.oddStartDiff = 0.22,
    this.oddMinDiff = 0.035,
    this.oddDecay = 0.93,
    // Rule
    this.ruleColors = 5,
    this.ruleShapes = 5,
    this.flipStart = 0.45,
    this.flipGrowth = 0.02,
    this.flipMax = 0.85,
    this.maxSameRun = 3,
  });

  final int seconds;

  /// 0 = unlimited (mistakes cost time instead of lives).
  final int lives;

  /// Seconds lost on a mistake (odd / rule modes without a life limit).
  final double wrongPenalty;
  final double starScale;

  final int stroopPool;
  final int stroopMinOptions;
  final int stroopMaxOptions;
  final int stroopOptionStep;
  final int bonusEvery; // 0 = no time bonus
  final int bonusSeconds;

  final int oddStartGrid;
  final int oddMaxGrid;
  final int oddGridStep;
  final double oddStartDiff;
  final double oddMinDiff;
  final double oddDecay;

  final int ruleColors;
  final int ruleShapes;
  final double flipStart;
  final double flipGrowth;
  final double flipMax;
  final int maxSameRun;
}

const _stroop = <FocusTier, FocusParams>{
  FocusTier.easy: FocusParams(
      seconds: 75,
      lives: 4,
      wrongPenalty: 0,
      starScale: 0.7,
      stroopPool: 4,
      stroopMinOptions: 3,
      stroopMaxOptions: 4,
      bonusEvery: 6,
      bonusSeconds: 3),
  FocusTier.medium: FocusParams(seconds: 60, lives: 3, wrongPenalty: 0, starScale: 1),
  FocusTier.hard: FocusParams(
      seconds: 50,
      lives: 2,
      wrongPenalty: 0,
      starScale: 1.3,
      stroopPool: 7,
      stroopMinOptions: 5,
      stroopMaxOptions: 7,
      stroopOptionStep: 8,
      bonusEvery: 10),
  FocusTier.extreme: FocusParams(
      seconds: 40,
      lives: 1,
      wrongPenalty: 0,
      starScale: 1.6,
      stroopPool: 8,
      stroopMinOptions: 6,
      stroopMaxOptions: 8,
      stroopOptionStep: 6,
      bonusEvery: 0),
};

const _odd = <FocusTier, FocusParams>{
  FocusTier.easy: FocusParams(
      seconds: 40,
      lives: 0,
      wrongPenalty: 1,
      starScale: 0.7,
      oddMaxGrid: 5,
      oddGridStep: 4,
      oddStartDiff: 0.26,
      oddMinDiff: 0.09,
      oddDecay: 0.95),
  FocusTier.medium: FocusParams(seconds: 30, lives: 0, wrongPenalty: 2, starScale: 1),
  FocusTier.hard: FocusParams(
      seconds: 30,
      lives: 0,
      wrongPenalty: 3,
      starScale: 1.3,
      oddStartGrid: 3,
      oddStartDiff: 0.16,
      oddMinDiff: 0.025,
      oddDecay: 0.92),
  FocusTier.extreme: FocusParams(
      seconds: 25,
      lives: 1,
      wrongPenalty: 0,
      starScale: 1.6,
      oddStartGrid: 4,
      oddMaxGrid: 8,
      oddGridStep: 2,
      oddStartDiff: 0.10,
      oddMinDiff: 0.015,
      oddDecay: 0.92),
};

const _rule = <FocusTier, FocusParams>{
  FocusTier.easy: FocusParams(
      seconds: 40,
      lives: 0,
      wrongPenalty: 1,
      starScale: 0.7,
      ruleColors: 3,
      ruleShapes: 3,
      flipStart: 0.25,
      flipGrowth: 0.01,
      flipMax: 0.5,
      maxSameRun: 5),
  FocusTier.medium: FocusParams(seconds: 30, lives: 0, wrongPenalty: 2, starScale: 1),
  FocusTier.hard: FocusParams(seconds: 30, lives: 0, wrongPenalty: 3, starScale: 1.3, flipStart: 0.6, flipMax: 0.9, maxSameRun: 2),
  FocusTier.extreme: FocusParams(
      seconds: 25, lives: 1, wrongPenalty: 0, starScale: 1.6, flipStart: 0.75, flipGrowth: 0.02, flipMax: 0.95, maxSameRun: 2),
};

FocusParams focusParams(FocusMode mode, FocusTier tier) {
  switch (mode) {
    case FocusMode.stroop:
      return _stroop[tier]!;
    case FocusMode.odd:
      return _odd[tier]!;
    case FocusMode.rule:
      return _rule[tier]!;
  }
}

/// Storage key of the best score for a mode + tier.
String focusBestKey(FocusMode mode, FocusTier tier) => 'focus.${mode.name}.${tier.name}.best';

/// Star thresholds [1, 2, 3] for a mode + tier.
List<int> focusThresholds(FocusMode mode, FocusTier tier) {
  final s = focusParams(mode, tier).starScale;
  return [for (final x in starThresholds[mode]!) (x * s).round()];
}

int focusStars(FocusMode mode, FocusTier tier, int score) {
  var n = 0;
  for (final x in focusThresholds(mode, tier)) {
    if (score >= x) n++;
  }
  return n;
}
