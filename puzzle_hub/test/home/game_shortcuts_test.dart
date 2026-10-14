import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/shortcuts/game_shortcuts.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
  });

  test('widget links point to a game', () {
    expect(GameShortcuts.idFromUri(Uri.parse('masterg://game/sudoku')), 'sudoku');
    expect(GameShortcuts.idFromUri(Uri.parse('https://x.y/game/sudoku')), isNull);
    expect(GameShortcuts.idFromUri(null), isNull);
  });

  test('3 games: most recently played first, then the hub order', () async {
    expect(GameShortcuts.pick(games).map((g) => g.id), games.take(3).map((g) => g.id));
    await GameShortcuts.played('sudoku', games);
    await GameShortcuts.played('chess', games);
    await GameShortcuts.played('sudoku', games);
    final ids = GameShortcuts.pick(games).map((g) => g.id).toList();
    expect(ids.take(2), ['sudoku', 'chess']);
    expect(ids, hasLength(3));
  });
}
