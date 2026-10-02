/// Shared helpers for the Focus Colors modes (pure Dart, no Flutter).
enum FocusMode { stroop, odd, rule }

/// Score multiplier from the current streak: x1 .. x5.
int comboMultiplier(int streak) => (1 + streak ~/ 5).clamp(1, 5);

/// Points for a correct answer at [streak] (streak before this answer).
int pointsFor(int streak) => 10 * comboMultiplier(streak);

/// Star thresholds per mode: [1 star, 2 stars, 3 stars].
const Map<FocusMode, List<int>> starThresholds = {
  FocusMode.stroop: [150, 400, 800],
  FocusMode.odd: [8, 16, 26],
  FocusMode.rule: [150, 400, 800],
};

int starsFor(FocusMode mode, int score) {
  final t = starThresholds[mode]!;
  var s = 0;
  for (final x in t) {
    if (score >= x) s++;
  }
  return s;
}
