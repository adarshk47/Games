import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/registry.dart';

void main() {
  test('registry has 9 games with unique ids', () {
    expect(games.length, 9);
    expect(games.map((g) => g.id).toSet().length, 9);
  });
}
