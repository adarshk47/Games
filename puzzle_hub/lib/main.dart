import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/account/auth_screens.dart';
import 'core/ads/ads_service.dart';
import 'core/audio.dart';
import 'core/cloud/cloud_service.dart';
import 'core/daily/reminder_service.dart';
import 'core/i18n/i18n.dart';
import 'core/rewards.dart';
import 'core/storage.dart';
import 'core/theme.dart';
import 'core/ui/app_theme.dart';
import 'home/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Storage.init();
  await I18n.init();
  await AppThemeController.init();
  await AppAudio.init();
  // Optional services: a failure here must never block the app from starting.
  for (final init in [
    CloudService.init,
    AdsService.init,
    ReminderService.init,
  ]) {
    try {
      await init();
    } catch (e) {
      debugPrint('service init failed: $e');
    }
  }
  AppAudio.startMusic();
  runApp(const PuzzleHubApp());
}

class PuzzleHubApp extends StatelessWidget {
  const PuzzleHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppThemeController.current, I18n.lang]),
      builder: (_, _) => MaterialApp(
        // Rebuild the whole app (back to home) when the language changes so every
        // screen picks up the new strings.
        key: ValueKey(I18n.lang.value),
        locale: I18n.lang.value.materialLocale,
        supportedLocales: const [
          Locale('en'),
          Locale('hi'),
          Locale('te'),
          Locale('ta'),
          Locale('pa'),
        ],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        title: 'Master G',
        debugShowCheckedModeBanner: false,
        navigatorKey: Rewards.navKey,
        theme: buildTheme(Brightness.dark),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: ThemeMode.dark,
        home: const AuthGate(home: HomeScreen()),
      ),
    );
  }
}
