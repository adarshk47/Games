import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/registry.dart';

void main() {
  test('registry has 5 games with unique ids', () {
    expect(games.length, 5);
    expect(games.map((g) => g.id).toSet().length, 5);
  });
}
