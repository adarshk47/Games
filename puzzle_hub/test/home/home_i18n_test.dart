import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/account/auth_screens.dart';
import 'package:puzzle_hub/core/i18n/i18n.dart';
import 'package:puzzle_hub/core/i18n/strings/account.dart';
import 'package:puzzle_hub/core/i18n/strings/home.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/core/ui/app_theme.dart';
import 'package:puzzle_hub/core/ui/settings_sheet.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:puzzle_hub/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _langs = ['en', 'hi', 'hinglish', 'te', 'ta', 'pa', 'bho', 'mr', 'sa'];

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)\}').allMatches(s).map((m) => m.group(1)!).toSet();

Future<void> _setup() async {
  SharedPreferences.setMockInitialValues({});
  await Storage.init();
  Storage.userPrefix = '';
  AppThemeController.current.value = 0;
  await AppThemeController.init();
  Rewards.reload();
}

void main() {
  tearDown(() => I18n.lang.value = AppLang.en);

  test('AppLang codes match the languages every entry must have', () {
    expect(AppLang.values.map((l) => l.code).toList(), _langs);
  });

  for (final (name, table) in [('homeStrings', homeStrings), ('accountStrings', accountStrings)]) {
    test('$name: every key has all 7 languages with identical placeholders', () {
      expect(table, isNotEmpty);
      for (final MapEntry(:key, :value) in table.entries) {
        expect(value.keys.toSet(), _langs.toSet(), reason: key);
        final ph = _placeholders(value['en']!);
        for (final l in _langs) {
          expect(value[l]!.trim(), isNotEmpty, reason: '$key [$l]');
          expect(_placeholders(value[l]!), ph, reason: '$key [$l]');
        }
      }
    });
  }

  test('every registry game has a localized title and subtitle', () {
    for (final g in allGames) {
      expect(homeStrings, contains('game.${g.id}.title'));
      expect(homeStrings, contains('game.${g.id}.subtitle'));
    }
    I18n.lang.value = AppLang.hi;
    final sudoku = allGames.firstWhere((g) => g.id == 'sudoku');
    expect(sudoku.title, 'Sudoku');
    expect(sudoku.subtitle, homeStrings['game.sudoku.subtitle']!['hi']);
  });

  test('theme names are localized', () {
    I18n.lang.value = AppLang.ta;
    expect(AppThemeController.themes.first.name, homeStrings['home.theme.royal']!['ta']);
    I18n.lang.value = AppLang.en;
    expect(AppThemeController.themes.first.name, 'Royal Purple');
  });

  for (final lang in AppLang.values) {
    testWidgets('HomeScreen, settings and welcome build in ${lang.code}', (t) async {
      await _setup();
      I18n.lang.value = lang;
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);

      await t.pumpWidget(const MaterialApp(home: HomeScreen()));
      await t.pump(const Duration(seconds: 2));
      expect(t.takeException(), isNull);
      expect(find.text(tr('home.nav.games')), findsOneWidget);

      for (final id in ['daily', 'shop', 'profile', 'games']) {
        await t.tap(find.byKey(ValueKey('nav_$id')));
        await t.pump(const Duration(milliseconds: 500));
        expect(t.takeException(), isNull, reason: 'tab $id');
      }

      await t.tap(find.byKey(const ValueKey('home_settings')));
      await t.pump();
      await t.pump(const Duration(seconds: 1));
      expect(find.byType(ThemePicker), findsOneWidget);
      expect(find.text(tr('home.settings.theme')), findsOneWidget);
      expect(t.takeException(), isNull);

      await t.pumpWidget(const MaterialApp(home: WelcomeScreen()));
      await t.pump(const Duration(seconds: 1));
      expect(find.text(tr('account.welcome_title')), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}
