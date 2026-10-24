import 'dart:convert';
import 'dart:math' as math;

import '../../../core/storage.dart';

/// Small age groups a player can pick (15+). [center] is the typical age
/// used to read the norm tables; results are shown as one of these ranges.
enum AgeGroup {
  a15(15, 17),
  a18(18, 20),
  a21(21, 24),
  a25(25, 29),
  a30(30, 34),
  a35(35, 39),
  a40(40, 44),
  a45(45, 49),
  a50(50, 54),
  a55(55, 59),
  a60(60, 64),
  a65(65, null);

  const AgeGroup(this.from, this.to);
  final int from;
  final int? to;

  String get label => to == null ? '$from+' : '$from–$to';
  double get center => to == null ? from + 3.0 : (from + to!) / 2;

  /// The group a (brain) age falls into.
  static AgeGroup of(num age) {
    for (final g in values.reversed) {
      if (age >= g.from) return g;
    }
    return values.first;
  }

  static AgeGroup? fromName(String? n) {
    for (final g in values) {
      if (g.name == n) return g;
    }
    return null;
  }
}

/// The five quick tests of one Brain Age check.
enum BrainTest { reaction, memory, math, stroop, pattern, order, grid }

/// Rough norms for each test per age group (mean, sd), from typical results
/// of these classic tasks on a phone. Reaction is milliseconds (lower is
/// better), the rest are correct answers / span (higher is better).
/// For fun and practice only, not a medical measure.
class BrainNorms {
  static const _centers = [17, 25, 35, 45, 55, 65];
  static const _mean = {
    BrainTest.reaction: [310.0, 320.0, 335.0, 350.0, 370.0, 395.0],
    BrainTest.memory: [7.0, 7.2, 7.0, 6.7, 6.4, 6.0],
    BrainTest.math: [16.0, 18.0, 17.0, 16.0, 14.5, 13.0],
    BrainTest.stroop: [22.0, 23.0, 21.0, 19.0, 17.0, 15.0],
    BrainTest.pattern: [6.0, 6.5, 6.0, 5.5, 5.0, 4.5],
    // Seconds to tap 1..16 in order (lower is better).
    BrainTest.order: [14.0, 14.5, 15.5, 17.0, 19.0, 22.0],
    // Squares remembered on a 4×4 / 5×5 grid.
    BrainTest.grid: [7.0, 7.0, 6.5, 6.0, 5.5, 5.0],
  };
  static const _sd = {
    BrainTest.reaction: 55.0,
    BrainTest.memory: 1.3,
    BrainTest.math: 5.0,
    BrainTest.stroop: 5.0,
    BrainTest.pattern: 2.0,
    BrainTest.order: 4.0,
    BrainTest.grid: 1.5,
  };

  static bool lowerIsBetter(BrainTest t) => t == BrainTest.reaction || t == BrainTest.order;

  /// Mean for [g], read between the anchor ages of the table.
  static double mean(BrainTest t, AgeGroup g) {
    final m = _mean[t]!;
    final a = g.center.clamp(_centers.first.toDouble(), _centers.last.toDouble());
    for (var i = 0; i < _centers.length - 1; i++) {
      if (a <= _centers[i + 1]) {
        final f = (a - _centers[i]) / (_centers[i + 1] - _centers[i]);
        return m[i] + (m[i + 1] - m[i]) * f;
      }
    }
    return m.last;
  }
  static double sd(BrainTest t) => _sd[t]!;

  /// How many standard deviations better (+) or worse (-) than the group.
  static double z(BrainTest t, AgeGroup g, double score) {
    final d = (score - mean(t, g)) / sd(t);
    return lowerIsBetter(t) ? -d : d;
  }
}

/// Result of one full check.
class BrainResult {
  BrainResult({required this.group, required this.scores, required this.at});
  final AgeGroup group;
  final Map<BrainTest, double> scores;
  final DateTime at;

  /// A full Brain Age check (old checks had 5 tests, new ones 7).
  bool get isFull => scores.length >= 5;

  /// Each standard deviation is worth about 8 "brain years".
  static const yearsPerSd = 8.0;

  double zOf(BrainTest t) => BrainNorms.z(t, group, scores[t] ?? 0).clamp(-3.0, 3.0);

  double get z {
    if (scores.isEmpty) return 0;
    return scores.keys.map(zOf).reduce((a, b) => a + b) / scores.length;
  }

  /// "Your brain works like a N-year-old" (15..85).
  int get brainAge => (group.center - z * yearsPerSd).round().clamp(15, 85);

  int ageOf(BrainTest t) => (group.center - zOf(t) * yearsPerSd).round().clamp(15, 85);

  /// The age range shown to the player (e.g. "21–24").
  AgeGroup get brainGroup => AgeGroup.of(brainAge);
  AgeGroup groupOf(BrainTest t) => AgeGroup.of(ageOf(t));

  /// Brain range younger than (or same as) the real one.
  bool get youngerOrSame => brainGroup.index <= group.index;

  /// Share of the age group this result beats (1..99).
  int get percentile => (_phi(z) * 100).round().clamp(1, 99);

  int percentileOf(BrainTest t) => (_phi(zOf(t)) * 100).round().clamp(1, 99);

  /// Normal CDF (Abramowitz–Stegun approximation).
  static double _phi(double x) {
    final t = 1 / (1 + 0.2316419 * x.abs());
    final d = 0.3989423 * math.exp(-x * x / 2);
    final p = d * t * (0.3193815 + t * (-0.3565638 + t * (1.781478 + t * (-1.821256 + t * 1.330274))));
    return x >= 0 ? 1 - p : p;
  }

  Map<String, Object> toJson() => {
        'g': group.name,
        'at': at.millisecondsSinceEpoch,
        's': {for (final e in scores.entries) e.key.name: e.value},
      };

  static BrainResult? fromJson(Map<String, dynamic> j) {
    final g = AgeGroup.fromName(j['g'] as String?);
    if (g == null) return null;
    final s = (j['s'] as Map).cast<String, dynamic>();
    return BrainResult(
      group: g,
      at: DateTime.fromMillisecondsSinceEpoch(j['at'] as int),
      scores: {
        for (final t in BrainTest.values)
          if (s[t.name] is num) t: (s[t.name] as num).toDouble()
      },
    );
  }
}

/// Saved age group and history of checks (newest last, max 60).
class BrainStore {
  static const _kGroup = 'brain_age.group';
  static const _kHistory = 'brain_age.history';
  static const maxHistory = 60;

  static AgeGroup? get group => AgeGroup.fromName(Storage.getString(_kGroup));
  static Future<void> setGroup(AgeGroup g) => Storage.setString(_kGroup, g.name);

  static List<BrainResult> history() {
    final raw = Storage.getString(_kHistory);
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          ?BrainResult.fromJson((j as Map).cast<String, dynamic>())
      ];
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(BrainResult r) async {
    final h = history()..add(r);
    while (h.length > maxHistory) {
      h.removeAt(0);
    }
    await Storage.setString(_kHistory, jsonEncode([for (final x in h) x.toJson()]));
  }

  /// Personal best raw score of one test (null = never played).
  static double? bestOf(BrainTest t) {
    final v = history().map((r) => r.scores[t]).whereType<double>();
    if (v.isEmpty) return null;
    return BrainNorms.lowerIsBetter(t) ? v.reduce(math.min) : v.reduce(math.max);
  }

  /// First ever score of one test (to show how much practice helped).
  static double? firstOf(BrainTest t) {
    for (final r in history()) {
      final v = r.scores[t];
      if (v != null) return v;
    }
    return null;
  }

  /// The test that needs practice most (lowest z in the last full check).
  static BrainTest? weakest() {
    final h = history().where((r) => r.isFull);
    if (h.isEmpty) return null;
    final r = h.last;
    return r.scores.keys.reduce((a, b) => r.zOf(a) <= r.zOf(b) ? a : b);
  }

  /// Best (youngest) brain age so far.
  static int? best() {
    final h = history().where((r) => r.isFull);
    if (h.isEmpty) return null;
    return h.map((r) => r.brainAge).reduce(math.min);
  }
}

// ---------------------------------------------------------------- generators

/// Mental-math question with four choices.
class MathQ {
  MathQ(this.text, this.answer, this.choices);
  final String text;
  final int answer;
  final List<int> choices;

  static MathQ make(math.Random r, int level) {
    late String text;
    late int ans;
    switch (r.nextInt(level < 4 ? 2 : 4)) {
      case 0:
        final a = 2 + r.nextInt(level < 6 ? 40 : 90), b = 2 + r.nextInt(level < 6 ? 40 : 90);
        text = '$a + $b';
        ans = a + b;
      case 1:
        final a = 20 + r.nextInt(80), b = 2 + r.nextInt(a - 1);
        text = '$a − $b';
        ans = a - b;
      case 2:
        final a = 2 + r.nextInt(11), b = 2 + r.nextInt(level < 8 ? 9 : 14);
        text = '$a × $b';
        ans = a * b;
      default:
        final b = 2 + r.nextInt(9), q = 2 + r.nextInt(11);
        text = '${b * q} ÷ $b';
        ans = q;
    }
    final set = <int>{ans};
    while (set.length < 4) {
      final off = (1 + r.nextInt(math.max(3, ans ~/ 6 + 2))) * (r.nextBool() ? 1 : -1);
      // Near misses, sometimes off by ten (a typical carrying slip).
      final c = ans + (r.nextInt(3) == 0 ? (r.nextBool() ? 10 : -10) : off);
      if (c >= 0) set.add(c);
    }
    final choices = set.toList()..shuffle(r);
    return MathQ(text, ans, choices);
  }
}

/// "What comes next?" number sequence with four choices.
class PatternQ {
  PatternQ(this.shown, this.answer, this.choices, this.kind);
  final List<int> shown;
  final int answer;
  final List<int> choices;

  /// Rule id, used for the explanation tip ('add', 'mul', 'alt', 'square', 'fib', 'grow').
  final String kind;

  static PatternQ make(math.Random r, int level) {
    final kinds = level < 3 ? ['add', 'mul', 'grow'] : ['add', 'mul', 'alt', 'square', 'fib', 'grow'];
    final kind = kinds[r.nextInt(kinds.length)];
    final seq = <int>[];
    switch (kind) {
      case 'add':
        final a = 1 + r.nextInt(20), d = 2 + r.nextInt(9);
        for (var i = 0; i < 6; i++) {
          seq.add(a + d * i);
        }
      case 'mul':
        final a = 1 + r.nextInt(4), m = 2 + r.nextInt(2);
        for (var i = 0; i < 6; i++) {
          seq.add(a * math.pow(m, i).toInt());
        }
      case 'alt':
        final a = 5 + r.nextInt(20), d1 = 2 + r.nextInt(6), d2 = 1 + r.nextInt(4);
        var v = a;
        for (var i = 0; i < 6; i++) {
          seq.add(v);
          v += i.isEven ? d1 : -d2;
        }
      case 'square':
        final s = 1 + r.nextInt(5);
        for (var i = 0; i < 6; i++) {
          seq.add((s + i) * (s + i));
        }
      case 'fib':
        var a = 1 + r.nextInt(3), b = a + 1 + r.nextInt(3);
        for (var i = 0; i < 6; i++) {
          seq.add(a);
          final c = a + b;
          a = b;
          b = c;
        }
      default: // grow: differences grow by one
        var v = 1 + r.nextInt(10), d = 1 + r.nextInt(3);
        for (var i = 0; i < 6; i++) {
          seq.add(v);
          v += d;
          d++;
        }
    }
    final ans = seq.last;
    final set = <int>{ans};
    var k = 1;
    while (set.length < 4) {
      final c = ans + (k.isOdd ? k : -k) * (1 + r.nextInt(3));
      if (c >= 0) set.add(c);
      k++;
    }
    return PatternQ(seq.sublist(0, 5), ans, set.toList()..shuffle(r), kind);
  }
}
