import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/games/registry.dart';

void main() {
  test('registry ids are unique and only enabled games are in the hub', () {
    expect(allGames.map((g) => g.id).toSet().length, allGames.length);
    expect(games.every((g) => g.enabled), isTrue);
    expect(games.length, allGames.where((g) => g.enabled).length);
    expect(games.isNotEmpty, isTrue);
  });
}
