import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/games/business/business_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Storage.init();
    Storage.userPrefix = '';
    BusinessPlayScreen.botDelay = const Duration(milliseconds: 10);
  });

  testWidgets('setup screen builds in every language', (t) async {
    t.view.physicalSize = const Size(360, 720);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    for (final l in AppLang.values) {
      I18n.lang.value = l;
      await t.pumpWidget(MaterialApp(key: ValueKey(l), home: const BusinessScreen()));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull, reason: l.code);
      expect(find.text(tr('biz.intro')), findsOneWidget);
    }
    I18n.lang.value = AppLang.en;
  });

  for (final (cpu, world, size) in const [(true, false, Size(320, 600)), (false, true, Size(412, 892))]) {
    testWidgets('play: cpu=$cpu world=$world at $size – roll, buy, bots move', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      await t.pumpWidget(MaterialApp(home: BusinessPlayScreen(players: 4, cpu: cpu, level: 1, world: world, maxRounds: 15, seed: 11)));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
      for (var i = 0; i < 40; i++) {
        await t.pump(const Duration(milliseconds: 60));
        // Close card dialogs.
        final ok = find.text('OK');
        if (ok.evaluate().isNotEmpty) {
          await t.tap(ok.first);
          continue;
        }
        if (find.byKey(const ValueKey('biz_buy')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('biz_buy')));
        } else if (find.byKey(const ValueKey('biz_roll')).evaluate().isNotEmpty) {
          await t.tap(find.byKey(const ValueKey('biz_roll')));
        }
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }
}
