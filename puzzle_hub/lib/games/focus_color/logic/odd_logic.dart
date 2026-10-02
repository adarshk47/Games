import 'dart:math';

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
  OddGenerator([Random? rng]) : _rng = rng ?? Random();
  final Random _rng;

  /// Grid side: 2 at start, +1 every 3 points, max 7.
  static int gridSize(int score) => (2 + score ~/ 3).clamp(2, 7);

  /// Lightness difference of the odd tile: shrinks with score, floor 0.035.
  static double difference(int score) => max(0.035, 0.22 * pow(0.93, score).toDouble());

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
