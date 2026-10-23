import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/core/ui/app_layout.dart';
import 'package:puzzle_hub/core/ui/app_theme.dart';
import 'package:puzzle_hub/core/ui/settings_sheet.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:puzzle_hub/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.of(prefs));
  await Storage.init();
  Storage.userPrefix = '';
  AppThemeController.current.value = 0;
  AppLayoutController.current.value = AppLayout.classic;
  await AppThemeController.init();
  Rewards.reload();
}

int _themeIndex(String id) => AppThemeController.themes.indexWhere((t) => t.id == id);

Future<void> _pumpHome(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(const MaterialApp(home: HomeScreen()));
  await t.pump(const Duration(seconds: 2));
  // Dismiss the once-per-launch welcome dialog (if any) shown over home.
  t.state<NavigatorState>(find.byType(Navigator).first).popUntil((r) => r.isFirst);
  await t.pump(const Duration(milliseconds: 500));
}

Future<void> _openSettings(WidgetTester t) async {
  await t.tap(find.byKey(const ValueKey('home_settings')));
  await t.pump();
  await t.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() {
    I18n.lang.value = AppLang.en;
    AppLayoutController.current.value = AppLayout.classic;
    AppThemeController.current.value = 0;
  });

  test('festive themes exist: Utsav is free, Diwali Night is priced', () async {
    await _setup();
    final utsav = AppThemeController.themes[_themeIndex('utsav')];
    final diwali = AppThemeController.themes[_themeIndex('diwali')];
    expect(utsav.festive && diwali.festive, isTrue);
    expect(utsav.free, isTrue);
    expect(diwali.free, isFalse);
    expect(await AppThemeController.select(_themeIndex('utsav')), isTrue);
    expect(AppThemeController.theme.id, 'utsav');
    expect(await AppThemeController.select(_themeIndex('diwali')), isFalse);
    // The original themes keep their indices (saved choices stay valid).
    expect(AppThemeController.themes.take(6).map((t) => t.id).toList(),
        ['royal', 'ocean', 'sunset', 'emerald', 'rose', 'midnight']);
  });

  test('layout choice persists globally under set.layout', () async {
    await _setup();
    // New installs default to the Arcade home and the Utsav theme.
    expect(AppLayoutController.layout, AppLayout.arcade);
    expect(AppThemeController.theme.id, 'utsav');
    await AppLayoutController.select(AppLayout.festive);
    expect(Storage.globalString('set.layout'), 'festive');
    AppLayoutController.current.value = AppLayout.classic;
    await AppThemeController.init(); // also restores the layout
    expect(AppLayoutController.festive, isTrue);

    await _setup({'set.layout': 'bogus'});
    expect(AppLayoutController.layout, AppLayout.arcade);
    // Players still on the old default chakra move to Arcade once...
    await _setup({'set.layout': 'chakra'});
    expect(AppLayoutController.layout, AppLayout.arcade);
    // ...but after that a chakra picked in Settings stays.
    await _setup({'set.layout': 'chakra', 'set.layout.arcade': true});
    expect(AppLayoutController.layout, AppLayout.chakra);
    await _setup({'set.layout': 'classic', 'set.theme': '0'});
    expect(AppLayoutController.layout, AppLayout.classic);
    expect(AppThemeController.theme.id, 'royal');
  });

  for (final size in const [Size(320, 480), Size(390, 844)]) {
    testWidgets('switch layout and theme from settings at $size', (t) async {
      await _setup({'set.layout': 'classic', 'set.theme': '0'});
      await _pumpHome(t, size);
      expect(find.byKey(const ValueKey('classic_layout')), findsOneWidget);

      await _openSettings(t);
      expect(find.byType(LayoutPicker), findsOneWidget);
      final festiveOpt = find.byKey(const ValueKey('layout_option_festive'));
      await t.ensureVisible(festiveOpt);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(festiveOpt);
      await t.pump(const Duration(milliseconds: 300));
      expect(AppLayoutController.festive, isTrue);
      expect(Storage.globalString('set.layout'), 'festive');

      final utsav = find.byKey(const ValueKey('theme_swatch_utsav'));
      await t.ensureVisible(find.byType(ThemePicker));
      await t.pump(const Duration(milliseconds: 300));
      await t.scrollUntilVisible(utsav, 150,
          scrollable: find.descendant(of: find.byType(ThemePicker), matching: find.byType(Scrollable)));
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(utsav, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 300));
      expect(AppThemeController.theme.id, 'utsav');
      expect(t.takeException(), isNull);

      // Close the sheet; the games tab now shows the festive layout.
      Navigator.of(t.element(find.byType(LayoutPicker))).pop();
      await t.pump(const Duration(seconds: 1));
      expect(find.byKey(const ValueKey('festive_layout')), findsOneWidget);
      expect(find.byKey(const ValueKey('festive_toran')), findsOneWidget);
      expect(find.byKey(const ValueKey('home_banner')), findsOneWidget);
      expect(t.takeException(), isNull);

      // And back to classic.
      await _openSettings(t);
      final classicOpt = find.byKey(const ValueKey('layout_option_classic'));
      await t.ensureVisible(classicOpt);
      await t.pump(const Duration(milliseconds: 300));
      await t.tap(classicOpt);
      await t.pump(const Duration(milliseconds: 300));
      expect(AppLayoutController.layout, AppLayout.classic);
      expect(t.takeException(), isNull);
      await t.pump(const Duration(seconds: 2));
      await t.pumpWidget(const SizedBox());
      await t.pump(const Duration(seconds: 1));
    });
  }

  for (final lang in AppLang.values) {
    testWidgets('festive home renders in ${lang.code} without overflow', (t) async {
      for (final theme in ['utsav', 'diwali']) {
        await _setup({
          'set.layout': 'festive',
          'set.theme': '${_themeIndex(theme)}',
        });
        I18n.lang.value = lang;
        for (final size in const [Size(320, 480), Size(390, 844), Size(320, 3200)]) {
          await _pumpHome(t, size);
          expect(t.takeException(), isNull, reason: '$theme $size');
          expect(find.byKey(const ValueKey('festive_layout')), findsOneWidget);
          expect(find.text(tr('home.game_of_the_day')), findsOneWidget);
          if (size.height > 3000) {
            for (final g in games) {
              expect(find.byKey(ValueKey('game_${g.id}')), findsOneWidget, reason: g.id);
            }
          }
        }
        await _openSettings(t);
        expect(find.text(tr('home.settings.layout')), findsOneWidget);
        expect(find.text(tr('home.layout.festive')), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      }
    });
  }

  for (final lang in AppLang.values) {
    testWidgets('arcade home (default) renders in ${lang.code} without overflow', (t) async {
      await _setup();
      I18n.lang.value = lang;
      for (final size in const [Size(320, 480), Size(390, 844), Size(360, 3200)]) {
        await _pumpHome(t, size);
        expect(t.takeException(), isNull, reason: '$size');
        expect(find.byKey(const ValueKey('arcade_layout')), findsOneWidget);
        expect(find.text(tr('home.game_of_the_day')), findsOneWidget);
        if (size.height > 3000) {
          expect(find.byKey(const ValueKey('arcade_featured')), findsOneWidget);
          expect(find.text(tr('home.shelf.top')), findsOneWidget);
        }
      }
      await _openSettings(t);
      expect(find.text(tr('home.layout.arcade')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });

    testWidgets('chakra home renders in ${lang.code} without overflow', (t) async {
      await _setup({'set.layout': 'chakra', 'set.layout.arcade': true});
      I18n.lang.value = lang;
      for (final size in const [Size(320, 480), Size(390, 844), Size(360, 3200)]) {
        await _pumpHome(t, size);
        expect(t.takeException(), isNull, reason: '$size');
        expect(find.byKey(const ValueKey('chakra_layout')), findsOneWidget);
        if (size.height > 3000) {
          for (final g in games) {
            expect(find.byKey(ValueKey('game_${g.id}')), findsOneWidget, reason: g.id);
          }
          // Turning the wheel keeps every game reachable.
          await t.drag(find.byKey(const ValueKey('chakra_hub')), const Offset(120, 0));
          await t.timedDrag(find.byKey(const ValueKey('game_chakra')), const Offset(0, 140),
              const Duration(milliseconds: 300));
          await t.pump(const Duration(milliseconds: 300));
          expect(t.takeException(), isNull);
        }
      }
      await _openSettings(t);
      expect(find.text(tr('home.layout.chakra')), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
