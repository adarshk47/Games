import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/ads/ads_service.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/mom_memory/mom_memory_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    AdsService.suppressed = 0;
  });

  testWidgets('Mom Memory suppresses ads while open', (t) async {
    await t.pumpWidget(const MaterialApp(home: MomMemoryScreen()));
    await t.pump(const Duration(seconds: 2));
    expect(AdsService.suppressed, 1);
    await t.pumpWidget(const MaterialApp(home: SizedBox()));
    await t.pump();
    expect(AdsService.suppressed, 0);
  });
}
