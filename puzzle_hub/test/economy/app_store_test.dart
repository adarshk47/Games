import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/core/store/app_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Always implements Random {
  _Always(this.v);
  final double v;
  @override
  double nextDouble() => v;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => true;
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
  });
  tearDown(() {
    AppStore.reviewOverride = null;
    AppStore.random = Random();
  });

  test('rating prompt: not before 3 wins, random, at most once a week', () async {
    var asked = 0;
    AppStore.reviewOverride = () async => asked++;
    AppStore.random = _Always(0); // the dice always say "ask"
    expect(await AppStore.onWin(), isFalse);
    expect(await AppStore.onWin(), isFalse);
    expect(await AppStore.onWin(), isTrue);
    expect(asked, 1);
    // Same week: never again, even with lucky dice.
    expect(await AppStore.onWin(), isFalse);
    expect(asked, 1);
  });

  test('rating prompt is skipped when the dice say no', () async {
    var asked = 0;
    AppStore.reviewOverride = () async => asked++;
    AppStore.random = _Always(0.99);
    for (var i = 0; i < 10; i++) {
      await AppStore.onWin();
    }
    expect(asked, 0);
  });
}
