import 'dart:math';

import 'focus_common.dart';
import 'focus_difficulty.dart';

class OddRound {
  const OddRound({
    required this.size,
    required this.oddIndex,
    required this.hue,
    required this.saturation,
    required this.baseLightness,
    required this.oddLightness,
  });
  final int size;
  final int oddIndex;
  final double hue; // 0..360
  final double saturation;
  final double baseLightness;
  final double oddLightness;
  int get tiles => size * size;
  double get diff => (oddLightness - baseLightness).abs();
}

class OddGenerator {
  OddGenerator([Random? rng, FocusParams? params])
      : _rng = rng ?? Random(),
        params = params ?? focusParams(FocusMode.odd, FocusTier.medium);
  final Random _rng;
  final FocusParams params;

  static int gridSizeFor(FocusParams p, int score) =>
      (p.oddStartGrid + score ~/ p.oddGridStep).clamp(p.oddStartGrid, p.oddMaxGrid);

  /// Lightness difference of the odd tile: shrinks with score down to a floor.
  static double differenceFor(FocusParams p, int score) =>
      max(p.oddMinDiff, p.oddStartDiff * pow(p.oddDecay, score).toDouble());

  int gridSize(int score) => gridSizeFor(params, score);
  double difference(int score) => differenceFor(params, score);

  OddRound next(int score) {
    final size = gridSize(score);
    final d = difference(score);
    final base = 0.40 + _rng.nextDouble() * 0.25; // 0.40..0.65
    final odd = base + (_rng.nextBool() ? d : -d);
    return OddRound(
      size: size,
      oddIndex: _rng.nextInt(size * size),
      hue: _rng.nextDouble() * 360,
      saturation: 0.6 + _rng.nextDouble() * 0.2,
      baseLightness: base,
      oddLightness: odd.clamp(0.1, 0.9),
    );
  }
}
