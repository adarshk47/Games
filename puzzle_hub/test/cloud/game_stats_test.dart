import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/cloud/game_stats.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final writes = <(String, Map<String, Object>)>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    writes.clear();
    GameStats.writeOverride = (id, d) async => writes.add((id, d));
  });
  tearDown(() => GameStats.writeOverride = null);

  test('each open counts one play', () async {
    GameStats.played('chess');
    await Future<void>.delayed(Duration.zero);
    expect(writes.single.$1, 'chess');
    expect(writes.single.$2, {'plays': 1});
  });

  test('first rating adds a rating; changing it moves the star bucket', () async {
    expect(await GameStats.rate('sudoku', 4), isTrue);
    expect(writes.last.$2, {'stars': 4, 'r4': 1, 'ratings': 1});
    expect(GameStats.myRating('sudoku'), 4);

    expect(await GameStats.rate('sudoku', 5), isTrue);
    expect(writes.last.$2, {'stars': 1, 'r5': 1, 'r4': -1});
    expect(GameStats.myRating('sudoku'), 5);

    writes.clear();
    expect(await GameStats.rate('sudoku', 5), isTrue);
    expect(writes, isEmpty, reason: 'same rating: nothing to write');
  });
}
