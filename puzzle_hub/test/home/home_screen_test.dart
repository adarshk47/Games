import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzle_hub/core/rewards.dart';
import 'package:puzzle_hub/core/storage.dart';
import 'package:puzzle_hub/core/ui/app_theme.dart';
import 'package:puzzle_hub/core/ui/settings_sheet.dart';
import 'package:puzzle_hub/games/registry.dart';
import 'package:puzzle_hub/home/games_tab.dart';
import 'package:puzzle_hub/home/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _setup([Map<String, Object> prefs = const {}]) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.of(prefs));
  await Storage.init();
  Storage.userPrefix = '';
  AppThemeController.current.value = 0;
  await AppThemeController.init();
  Rewards.reload();
}

Future<void> _pumpHome(WidgetTester t, Size size) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  await t.pumpWidget(const MaterialApp(home: HomeScreen()));
  await t.pump(const Duration(seconds: 2));
}

int _stackIndex(WidgetTester t) => t.widget<IndexedStack>(find.byType(IndexedStack)).index!;

void main() {
  for (final size in const [Size(320, 480), Size(390, 844), Size(1024, 1366)]) {
    testWidgets('home builds with 4 tabs and switches tabs at $size', (t) async {
      await _setup();
      await _pumpHome(t, size);
      expect(t.takeException(), isNull);

      for (final id in ['games', 'daily', 'shop', 'profile']) {
        expect(find.byKey(ValueKey('nav_$id')), findsOneWidget);
      }
      expect(_stackIndex(t), 0);
      expect(find.text('Master G'), findsOneWidget);
      expect(find.text('GAME OF THE DAY'), findsOneWidget);

      await t.tap(find.byKey(const ValueKey('nav_shop')));
      await t.pump(const Duration(milliseconds: 500));
      expect(_stackIndex(t), 2);
      await t.tap(find.byKey(const ValueKey('nav_daily')));
      await t.pump(const Duration(milliseconds: 500));
      expect(_stackIndex(t), 1);
      await t.tap(find.byKey(const ValueKey('nav_profile')));
      await t.pump(const Duration(milliseconds: 500));
      expect(_stackIndex(t), 3);
      await t.tap(find.byKey(const ValueKey('nav_games')));
      await t.pump(const Duration(milliseconds: 500));
      expect(_stackIndex(t), 0);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('only enabled games appear in the grid', (t) async {
    await _setup();
    await _pumpHome(t, const Size(1024, 2400));
    for (final g in allGames) {
      expect(find.byKey(ValueKey('game_${g.id}'), skipOffstage: false), g.enabled ? findsOneWidget : findsNothing);
    }
  });

  test('game of the day rotates by date and is always an enabled game', () {
    final a = gameOfTheDay(games, DateTime(2026, 10, 4));
    final b = gameOfTheDay(games, DateTime(2026, 10, 5));
    expect(games, contains(a));
    if (games.length > 1) expect(a, isNot(b));
    expect(gameOfTheDay(games, DateTime(2026, 10, 4, 23)), a);
  });

  test('theme switch persists across restarts', () async {
    await _setup();
    expect(await AppThemeController.select(1), isTrue);
    expect(AppThemeController.theme.id, 'ocean');
    AppThemeController.current.value = 0;
    await AppThemeController.init();
    expect(AppThemeController.current.value, 1);
    // Locked themes cannot be selected without buying.
    expect(await AppThemeController.select(3), isFalse);
    expect(AppThemeController.current.value, 1);
  });

  testWidgets('locked theme purchase from settings spends coins', (t) async {
    await _setup({'coins': 1000});
    expect(Rewards.coins.value, 1000);
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(child: TextButton(onPressed: () => showSettingsSheet(ctx), child: const Text('open'))),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    const sunset = ValueKey('theme_swatch_sunset');
    expect(find.byKey(sunset), findsOneWidget);
    expect(AppThemeController.isUnlocked(2), isFalse);
    await t.tap(find.byKey(sunset));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('theme_buy_confirm')));
    await t.pumpAndSettle();

    final price = AppThemeController.themes[2].price;
    expect(Rewards.coins.value, 1000 - price);
    expect(Storage.getInt('coins'), 1000 - price);
    expect(AppThemeController.isUnlocked(2), isTrue);
    expect(AppThemeController.current.value, 2);
    expect(Storage.getString('theme.unlocked'), contains('sunset'));

    // Free theme applies immediately without spending.
    await t.tap(find.byKey(const ValueKey('theme_swatch_ocean')));
    await t.pumpAndSettle();
    expect(AppThemeController.current.value, 1);
    expect(Rewards.coins.value, 1000 - price);
  });

  testWidgets('settings sheet opens from home at 320x480 without overflow', (t) async {
    await _setup();
    await _pumpHome(t, const Size(320, 480));
    await t.tap(find.byKey(const ValueKey('home_settings')));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(ThemePicker), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('buying without enough coins fails and spends nothing', () async {
    await _setup({'coins': 100});
    expect(await AppThemeController.buy(5), ThemeBuyResult.notEnoughCoins);
    expect(Rewards.coins.value, 100);
    expect(AppThemeController.isUnlocked(5), isFalse);
  });
}
