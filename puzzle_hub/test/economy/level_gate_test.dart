import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/economy/level_gate.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
  });

  test('price is 100 coins per skipped level, free in sequence', () {
    expect(LevelGate.skipPrice(12, 12), 0);
    expect(LevelGate.skipPrice(12, 5), 0);
    expect(LevelGate.skipPrice(12, 13), 100);
    expect(LevelGate.skipPrice(12, 50), 3800);
  });

  test('a bought level has 10 plays, clearing removes the counter', () async {
    const p = 'demo.easy';
    expect(LevelGate.canPlay(p, 3, 9), isFalse);
    await Storage.setInt('$p.skip.9', LevelGate.maxPlays);
    expect(LevelGate.canPlay(p, 3, 9), isTrue);
    for (var i = 0; i < LevelGate.maxPlays; i++) {
      await LevelGate.onStart(p, 3, 9);
    }
    expect(LevelGate.playsLeft(p, 9), 0);
    expect(LevelGate.canPlay(p, 3, 9), isFalse);
    await Storage.setInt('$p.skip.9', 4);
    await LevelGate.onCleared(p, 9);
    expect(LevelGate.playsLeft(p, 9), 0);
  });

  test('free levels never consume plays', () async {
    await LevelGate.onStart('demo.easy', 5, 4);
    expect(LevelGate.playsLeft('demo.easy', 4), 0);
  });
}
