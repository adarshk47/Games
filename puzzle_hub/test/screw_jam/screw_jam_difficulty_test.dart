import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/screw_jam/logic/screw_jam_logic.dart';

/// Plays [lv] with a naive strategy: a tap that fits a box if there is one
/// (when [greedy]), else any free screw. Returns true on a win.
bool _play(SjLevel lv, Random rng, {required bool greedy}) {
  final g = SjGame(lv);
  while (!g.over) {
    final moves = g.removable.toList();
    if (moves.isEmpty) return false;
    final fit = greedy ? [for (final m in moves) if (g.slotFor(m) != null) m] : const <int>[];
    final pool = fit.isNotEmpty ? fit : moves;
    g.tap(pool[rng.nextInt(pool.length)]);
  }
  return g.won;
}

/// Loss rate (percent) of a naive player over all levels of [t].
double sjNaiveLossRate(SjTier t, {required bool greedy, int runs = 4}) {
  var lost = 0, total = 0;
  for (var n = 1; n <= kSjLevels; n++) {
    final lv = sjGenerate(t, n);
    for (var r = 0; r < runs; r++) {
      final rng = Random(n * 31 + r * 7 + t.index * 1000);
      if (!_play(lv, rng, greedy: greedy)) lost++;
      total++;
    }
  }
  return lost * 100 / total;
}

void main() {
  test('naive players lose far more often on hard / extreme', () {
    final greedy = {for (final t in SjTier.values) t: sjNaiveLossRate(t, greedy: true)};
    final random = {for (final t in SjTier.values) t: sjNaiveLossRate(t, greedy: false)};
    for (final t in SjTier.values) {
      // ignore: avoid_print
      print('${t.id}: greedy loses ${greedy[t]!.toStringAsFixed(1)}%, random loses ${random[t]!.toStringAsFixed(1)}%');
    }
  });
}
