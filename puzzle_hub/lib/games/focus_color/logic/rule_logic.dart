import 'dart:math';

enum Rule { sameColor, sameShape }

enum SymShape { circle, square, triangle, star, diamond }

class Sym {
  const Sym(this.shape, this.colorIndex);
  final SymShape shape;
  final int colorIndex; // index into [ruleColors]
}

/// ARGB values for symbol colors.
const ruleColors = <int>[0xFFFF4D5E, 0xFF4D8DFF, 0xFF34D399, 0xFFFFD84D, 0xFFB66BFF];

class RuleRound {
  const RuleRound(this.rule, this.a, this.b);
  final Rule rule;
  final Sym a;
  final Sym b;

  /// The correct answer to "does the rule hold?".
  bool get answer => rule == Rule.sameColor ? a.colorIndex == b.colorIndex : a.shape == b.shape;
}

class RuleGenerator {
  RuleGenerator([Random? rng]) : _rng = rng ?? Random();
  final Random _rng;
  Rule? _last;
  int _sameRun = 0;

  /// Probability that the rule flips; rises with rounds solved.
  static double flipChance(int score) => (0.45 + score * 0.02).clamp(0.45, 0.85);

  RuleRound next(int score) {
    Rule rule;
    if (_last == null) {
      rule = Rule.values[_rng.nextInt(2)];
    } else {
      final flip = _sameRun >= 3 || _rng.nextDouble() < flipChance(score);
      rule = flip ? (_last == Rule.sameColor ? Rule.sameShape : Rule.sameColor) : _last!;
    }
    _sameRun = rule == _last ? _sameRun + 1 : 1;
    _last = rule;

    final a = Sym(SymShape.values[_rng.nextInt(SymShape.values.length)], _rng.nextInt(ruleColors.length));
    final yes = _rng.nextBool();
    var shapeIdx = _rng.nextInt(SymShape.values.length);
    var color = _rng.nextInt(ruleColors.length);
    if (rule == Rule.sameColor) {
      color = yes ? a.colorIndex : _different(color, a.colorIndex, ruleColors.length);
    } else {
      shapeIdx = yes ? a.shape.index : _different(shapeIdx, a.shape.index, SymShape.values.length);
    }
    return RuleRound(rule, a, Sym(SymShape.values[shapeIdx], color));
  }

  int _different(int v, int not, int n) => v == not ? (v + 1 + _rng.nextInt(n - 1)) % n : v;
}
