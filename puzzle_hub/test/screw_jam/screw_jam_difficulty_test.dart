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

/// Loss rate (percent) of a naive player over levels [from]..[to] of [t].
double _lossRate(SjTier t, {required bool greedy, int from = 1, int to = kSjLevels, int runs = 4}) {
  var lost = 0, total = 0;
  for (var n = from; n <= to; n++) {
    final lv = sjGenerate(t, n);
    for (var r = 0; r < runs; r++) {
      final rng = Random(n * 31 + r * 7 + t.index * 1000);
      if (!_play(lv, rng, greedy: greedy)) lost++;
      total++;
    }
  }
  return lost * 100 / total;
}

String _pct(double v) => '${v.toStringAsFixed(1)}%';

void main() {
  // Before the hard / extreme rework (same players, same seeds):
  //   hard:    greedy lost 1.3%, random 92.8%
  //   extreme: greedy lost 8.3%, random 100%
  test('naive players lose far more often on hard / extreme', () {
    final greedy = {for (final t in SjTier.values) t: _lossRate(t, greedy: true)};
    final random = {for (final t in SjTier.values) t: _lossRate(t, greedy: false)};
    for (final t in SjTier.values) {
      final bands = [
        for (var b = 0; b < 4; b++) _pct(_lossRate(t, greedy: true, from: b * 25 + 1, to: b * 25 + 25)),
      ];
      // ignore: avoid_print
      print('${t.id}: greedy loses ${_pct(greedy[t]!)} (levels 1-25/26-50/51-75/76-100: ${bands.join(' / ')}), '
          'random loses ${_pct(random[t]!)}');
    }
    // Easy / medium untouched.
    expect(greedy[SjTier.easy], lessThan(5));
    expect(greedy[SjTier.medium], lessThan(5));
    // Hard / extreme: the greedy player now loses most of the time.
    expect(greedy[SjTier.hard]!, greaterThan(40));
    expect(greedy[SjTier.extreme]!, greaterThan(greedy[SjTier.hard]!));
    expect(greedy[SjTier.extreme]!, greaterThan(65));
    // Later levels are at least as hard as the first ones.
    for (final t in [SjTier.hard, SjTier.extreme]) {
      expect(_lossRate(t, greedy: true, from: 76, to: 100), greaterThanOrEqualTo(_lossRate(t, greedy: true, from: 1, to: 25)));
    }
  });

  test('hard / extreme solutions need the tray but still allow 3 stars', () {
    for (final t in [SjTier.hard, SjTier.extreme]) {
      var usesTray = 0;
      for (var n = 1; n <= kSjLevels; n++) {
        final lv = sjGenerate(t, n);
        final g = SjGame(lv);
        for (final s in lv.solution) {
          g.tap(s);
        }
        expect(g.won, isTrue);
        expect(g.peakTray, lessThanOrEqualTo(sjSpec(t).trayUse), reason: '${t.id} L$n');
        expect(sjStars(peakTray: g.peakTray, trayCapacity: lv.trayCapacity, continues: 0), 3);
        if (g.peakTray > 0) usesTray++;
      }
      expect(usesTray, greaterThan(80), reason: t.id);
    }
  });
}
