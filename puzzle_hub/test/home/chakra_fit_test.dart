import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:puzzle_hub/home/game_chakra.dart';

void main() {
  test('every game fits on the chakra on common phone widths', () {
    for (final w in [320.0, 360.0, 393.0, 412.0, 460.0]) {
      final size = w - 36;
      expect(GameChakra.overflowOf(games, size), isEmpty, reason: 'width $w');
      expect(GameChakra.itemSize(size, games.length), greaterThanOrEqualTo(40));
    }
  });
}
