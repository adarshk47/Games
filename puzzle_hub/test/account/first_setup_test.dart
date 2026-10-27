import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/account/account_service.dart';
import 'package:puzzle_hub/core/account/setup_screen.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final size in const [Size(320, 560), Size(390, 844)]) {
    testWidgets('first start: English by default, pick country A–Z and language at $size', (t) async {
      SharedPreferences.setMockInitialValues({});
      await Storage.init();
      Storage.userPrefix = '';
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);

      await t.pumpWidget(const MaterialApp(home: FirstSetupScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(t.takeException(), isNull);
      expect(I18n.lang.value, AppLang.en, reason: 'English is the default');
      expect(find.text('Welcome!'), findsOneWidget);

      // Countries in alphabetical order in the sheet.
      await t.tap(find.byKey(const ValueKey('setup_country')));
      await t.pump(const Duration(milliseconds: 800));
      final names = [
        for (final e in t.widgetList<ListTile>(find.byWidgetPredicate((w) => w is ListTile && '${w.key}'.contains('country_'))))
          ((e.title as Text).data!)
      ];
      expect(names, [...names]..sort());
      await t.enterText(find.byType(TextField), 'United States');
      await t.pump(const Duration(milliseconds: 800));
      await t.tap(find.byKey(const ValueKey('country_US')));
      await t.pump(const Duration(milliseconds: 800));
      expect(AccountService.I.country, isNull, reason: 'saved only on Continue');

      await t.tap(find.byKey(const ValueKey('setup_lang_hi')));
      await t.pump();
      await t.tap(find.byKey(const ValueKey('setup_continue')));
      await t.pump(const Duration(milliseconds: 300));
      expect(AccountService.I.country, 'US');
      expect(I18n.chosen, isTrue);
      expect(I18n.lang.value, AppLang.hi);
      expect(t.takeException(), isNull);
      await I18n.set(AppLang.en);
    });
  }
}
