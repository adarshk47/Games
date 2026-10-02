import 'dart:math';

import 'focus_common.dart';
import 'focus_difficulty.dart';

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
  RuleGenerator([Random? rng, FocusParams? params])
      : _rng = rng ?? Random(),
        params = params ?? focusParams(FocusMode.rule, FocusTier.medium);
  final Random _rng;
  final FocusParams params;
  Rule? _last;
  int _sameRun = 0;

  /// Probability that the rule flips; rises with rounds solved.
  static double flipChanceFor(FocusParams p, int score) =>
      (p.flipStart + score * p.flipGrowth).clamp(p.flipStart, p.flipMax);

  RuleRound next(int score) {
    Rule rule;
    if (_last == null) {
      rule = Rule.values[_rng.nextInt(2)];
    } else {
      final flip = _sameRun >= params.maxSameRun || _rng.nextDouble() < flipChanceFor(params, score);
      rule = flip ? (_last == Rule.sameColor ? Rule.sameShape : Rule.sameColor) : _last!;
    }
    _sameRun = rule == _last ? _sameRun + 1 : 1;
    _last = rule;

    final nc = params.ruleColors.clamp(2, ruleColors.length);
    final ns = params.ruleShapes.clamp(2, SymShape.values.length);
    final a = Sym(SymShape.values[_rng.nextInt(ns)], _rng.nextInt(nc));
    final yes = _rng.nextBool();
    var shapeIdx = _rng.nextInt(ns);
    var color = _rng.nextInt(nc);
    if (rule == Rule.sameColor) {
      color = yes ? a.colorIndex : _different(color, a.colorIndex, nc);
    } else {
      shapeIdx = yes ? a.shape.index : _different(shapeIdx, a.shape.index, ns);
    }
    return RuleRound(rule, a, Sym(SymShape.values[shapeIdx], color));
  }

  int _different(int v, int not, int n) => v == not ? (v + 1 + _rng.nextInt(n - 1)) % n : v;
}
